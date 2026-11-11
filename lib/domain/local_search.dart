import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart' hide Query;

import '../db/database.dart';
import 'embeddings.dart';
import 'matching.dart';
import 'offers.dart';
import 'query.dart';
import 'shops.dart';
import 'vault.dart' show nowIso;

/// A search hit on the device: a vault item or a cached offer.
class Hit {
  const Hit.item(VaultItem this.item) : offer = null;
  const Hit.offer(ShopOffer this.offer) : item = null;

  final VaultItem? item;
  final ShopOffer? offer;

  String get title => item?.title ?? offer!.title;
}

/// Searches what is on the device (the vault and offers found before) with
/// SQLite full-text search, and keeps found offers and the user's "same
/// product?" answers.
class LocalSearch {
  LocalSearch(this.store, {this.embedder});
  final Store store;

  /// The downloaded meaning model ("Smarter search"), when turned on.
  final Embedder? embedder;

  AppDatabase get db => store.db as AppDatabase;

  /// Rebuilds the full-text index from the vault and the offer cache. Cheap
  /// for a vault's size; run before a search so edits always show.
  Future<void> reindex() => db.transaction(() async {
    await db.customStatement('DELETE FROM chanda_words');
    await db.customStatement('DELETE FROM chanda_grams');
    final items = await (db.select(db.chandaItems)..where((t) => t.deleted.not())).get();
    for (final i in items) {
      final extra = [
        i.brand,
        i.tags.replaceAll(',', ' '),
        i.note,
        ...Listing.variantOf(i.variant).values,
        shopOf(i.shop).name,
        i.description.length > 400 ? i.description.substring(0, 400) : i.description,
      ].join(' ');
      await _index(i.id, 'item', i.title, extra);
    }
    for (final o in await db.select(db.chandaOffers).get()) {
      await _index(o.id, 'offer', o.title, shopOf(o.shop).name);
    }
  });

  Future<void> _index(String ref, String kind, String title, String extra) async {
    await db.customStatement('INSERT INTO chanda_words (ref, kind, title, extra) VALUES (?, ?, ?, ?)', [
      ref,
      kind,
      title,
      extra,
    ]);
    await db.customStatement('INSERT INTO chanda_grams (ref, kind, title) VALUES (?, ?, ?)', [
      ref,
      kind,
      title,
    ]);
  }

  /// Vault items and cached offers for [q], best first (bm25: title words
  /// count more than notes and tags), then filtered by its facets. Words
  /// match by prefix ("glass" finds "glasses"); when none match, any part of
  /// a title does (trigrams), then a plain substring.
  Future<List<Hit>> search(Query q, {bool offers = true}) async {
    await reindex();
    final words = _tokens(q.words);
    final refs = <(String, String)>[];
    if (words.isNotEmpty) {
      final match = words.map((w) => '"${w.replaceAll('"', '')}"*').join(' AND ');
      refs.addAll(
        await _refs(
          'SELECT ref, kind FROM chanda_words WHERE chanda_words MATCH ? '
          'ORDER BY bm25(chanda_words, 0, 0, 4.0, 1.0)',
          [match],
        ),
      );
      final long = words.where((w) => w.length >= 3).toList();
      if (refs.isEmpty && long.isNotEmpty) {
        refs.addAll(
          await _refs('SELECT ref, kind FROM chanda_grams WHERE chanda_grams MATCH ? ORDER BY rank', [
            long.map((w) => '"${w.replaceAll('"', '')}"').join(' AND '),
          ]),
        );
      }
      if (refs.isEmpty) {
        refs.addAll(
          await _refs(
            'SELECT ref, kind FROM chanda_words WHERE ${[for (final _ in words) 'title LIKE ?'].join(' AND ')}',
            [for (final w in words) '%$w%'],
          ),
        );
      }
      if (embedder case final e?) {
        final near = await _nearest(e, q.words);
        final fused = fuseRankings([refs.toList(), near]);
        refs
          ..clear()
          ..addAll(fused);
      }
    } else {
      refs.addAll(await _refs('SELECT ref, kind FROM chanda_words', const []));
    }

    final itemIds = [
      for (final (r, k) in refs)
        if (k == 'item') r,
    ];
    final offerIds = [
      for (final (r, k) in refs)
        if (k == 'offer' && offers) r,
    ];
    final items = {
      for (final i in await (db.select(db.chandaItems)..where((t) => t.id.isIn(itemIds))).get()) i.id: i,
    };
    final cached = {
      for (final o in await (db.select(db.chandaOffers)..where((t) => t.id.isIn(offerIds))).get()) o.id: o,
    };
    final shopsWanted = q.of('shop').toSet();
    bool inBudget(int? price, String currency) =>
        currency != q.currency ||
        price == null ||
        ((q.minPrice == null || price >= q.minPrice!) && (q.maxPrice == null || price <= q.maxPrice!));
    final out = <Hit>[];
    for (final (r, k) in refs) {
      if (items[r] case final i? when k == 'item') {
        if ((shopsWanted.isEmpty || shopsWanted.contains(i.shop)) &&
            inBudget(i.price, i.currency) &&
            fitsFacets(q, i.title, extra: '${Listing.variantOf(i.variant).values.join(' ')} ${i.tags}') &&
            _fitsSize(q, i)) {
          out.add(Hit.item(i));
        }
      } else if (cached[r] case final o? when k == 'offer') {
        if ((shopsWanted.isEmpty || shopsWanted.contains(o.shop)) &&
            inBudget(o.price, o.currency) &&
            fitsFacets(q, o.title)) {
          out.add(Hit.offer(o));
        }
      }
    }
    return out;
  }

  /// Vault items and offers close in meaning to [text], closest first.
  /// Vectors are kept per title and made again only when a title changes.
  Future<List<(String, String)>> _nearest(Embedder e, String text) async {
    await db.customStatement(
      'CREATE TABLE IF NOT EXISTS chanda_vectors (ref TEXT PRIMARY KEY, kind TEXT NOT NULL, text TEXT NOT NULL, '
      'vec BLOB NOT NULL)',
    );
    await db.customStatement('DELETE FROM chanda_vectors WHERE ref NOT IN (SELECT ref FROM chanda_words)');
    final stale = [
      for (final row
          in await db
              .customSelect(
                'SELECT w.ref AS ref, w.kind AS kind, w.title AS title FROM chanda_words w '
                'LEFT JOIN chanda_vectors v ON v.ref = w.ref WHERE v.text IS NULL OR v.text != w.title',
              )
              .get())
        (row.read<String>('ref'), row.read<String>('kind'), row.read<String>('title')),
    ];
    for (var at = 0; at < stale.length; at += 32) {
      final part = stale.sublist(at, min(at + 32, stale.length));
      final vecs = await e.embed([for (final (_, _, t) in part) t]);
      await db.batch((b) {
        for (var i = 0; i < part.length; i++) {
          b.customStatement(
            'INSERT OR REPLACE INTO chanda_vectors (ref, kind, text, vec) VALUES (?, ?, ?, ?)',
            [part[i].$1, part[i].$2, part[i].$3, vectorBytes(vecs[i])],
          );
        }
      });
    }
    final want = (await e.embed([text])).single;
    final scores = {
      for (final row in await db.customSelect('SELECT ref, kind, vec FROM chanda_vectors').get())
        (row.read<String>('ref'), row.read<String>('kind')): cosine(
          want,
          vectorOf(row.read<Uint8List>('vec')),
        ),
    };
    return nearest(scores);
  }

  /// With Smarter search on, how close in meaning each of [offers]' titles
  /// is to [q] (cosine, by [Offer.id]); empty with it off. Title vectors are
  /// kept for the session, so a search adding shops embeds only new titles.
  Future<Map<String, double>> meaningOf(Query q, Iterable<Offer> offers) async {
    final e = embedder;
    final text = [
      q.words,
      ...q.facets.where((f) => f.kind == 'attribute').map((f) => f.label),
    ].join(' ').trim();
    if (e == null || text.isEmpty) return const {};
    final todo = {
      for (final o in offers)
        if (!_titleVectors.containsKey(o.title)) o.title,
    }.toList();
    for (var at = 0; at < todo.length; at += 32) {
      final part = todo.sublist(at, min(at + 32, todo.length));
      final vecs = await e.embed(part);
      for (var i = 0; i < part.length; i++) {
        _titleVectors[part[i]] = vecs[i];
      }
    }
    final want = (await e.embed([text])).single;
    return {for (final o in offers) o.id: cosine(want, _titleVectors[o.title]!)};
  }

  final _titleVectors = <String, Float32List>{};

  Future<List<(String, String)>> _refs(String sql, List<Object> args) async => [
    for (final row in await db.customSelect(sql, variables: [for (final a in args) Variable(a)]).get())
      (row.read<String>('ref'), row.read<String>('kind')),
  ];

  /// A size facet keeps items saved in that size (from their chosen
  /// options or title); items with no size recorded are kept.
  bool _fitsSize(Query q, VaultItem i) {
    final want = q.of('size').toList();
    if (want.isEmpty) return true;
    final sizes = Listing.variantOf(i.variant).entries
        .where((e) => e.key.toLowerCase().contains('size'))
        .map((e) => e.value.toLowerCase().trim())
        .toList();
    if (sizes.isEmpty) return true;
    return sizes.any((s) => want.any((w) => s == w || s.replaceAll(' ', '') == w.replaceAll(' ', '')));
  }

  /// Keeps offers a shop's search listed, for searching offline and for
  /// comparing; a later search updates them. Offers not seen for 30 days go.
  /// Offers read off a screenshot are not kept: their prices are not sure
  /// enough to compare or alert on until the product page is read.
  Future<void> keepOffers(Iterable<Offer> offers, String query) async {
    final now = nowIso();
    await db.batch((b) {
      for (final o in offers) {
        if (o.source == OfferSource.screen) continue;
        b.insert(
          db.chandaOffers,
          ChandaOffersCompanion.insert(
            id: o.id,
            shop: o.shop,
            url: o.url,
            title: o.title,
            image: Value(o.image),
            price: Value(o.price),
            currency: o.currency,
            was: Value(o.was),
            rating: Value(o.rating),
            reviews: Value(o.reviews),
            inStock: Value(o.inStock),
            query: Value(query),
            seen: now,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
    final old = nowIso(DateTime.now().subtract(const Duration(days: 30)));
    await (db.delete(db.chandaOffers)..where((t) => t.seen.isSmallerThanValue(old))).go();
  }

  Future<void> setHash(String offerId, String dhash) => (db.update(
    db.chandaOffers,
  )..where((t) => t.id.equals(offerId))).write(ChandaOffersCompanion(dhash: Value(dhash)));

  /// Cached offers that could be [i] at other shops: those whose title
  /// shares at least half of its words, that the user has not ruled out.
  Future<List<ShopOffer>> candidatesFor(VaultItem i) async {
    final answers = await matchesFor(i.id);
    final words = _tokens(i.title).where((w) => w.length > 2).toList();
    if (words.isEmpty) return const [];
    final all = await (db.select(db.chandaOffers)..where((t) => t.url.equals(i.url).not())).get();
    return [
      for (final o in all)
        if (answers[o.url] != 'different' && similarityOf(i.title, o.title) >= 0.5) o,
    ];
  }

  // ---- "same product?" answers ----

  Future<Map<String, String>> matchesFor(String itemId) async => {
    for (final m in await (db.select(
      db.chandaMatches,
    )..where((t) => t.itemId.equals(itemId) & t.deleted.not())).get())
      m.url: m.verdict,
  };

  /// Remembers the user's answer, on every device, so it is asked once.
  Future<void> answer(String itemId, String url, {required bool same}) async {
    final old = await (db.select(
      db.chandaMatches,
    )..where((t) => t.itemId.equals(itemId) & t.url.equals(url) & t.deleted.not())).getSingleOrNull();
    final id = old?.id ?? newId();
    await store.save(
      db.chandaMatches,
      ChandaMatchesCompanion.insert(id: id, itemId: itemId, url: url, verdict: same ? 'same' : 'different'),
      id,
    );
  }
}

List<String> _tokens(String s) =>
    s.toLowerCase().split(RegExp(r'[^\p{L}\p{N}]+', unicode: true)).where((w) => w.isNotEmpty).toList();

/// The offer cache entry as an [Offer].
Offer offerOf(ShopOffer o) => Offer(
  shop: o.shop,
  url: o.url,
  title: o.title,
  image: o.image,
  price: o.price ?? 0,
  currency: o.currency,
  was: o.was,
  rating: o.rating,
  reviews: o.reviews,
  inStock: o.inStock,
);

/// [Listing] for a vault item, for [match].
Listing listingOf(VaultItem i, {String dhash = ''}) => Listing(
  title: i.title,
  brand: i.brand,
  gtin: i.gtin,
  mpn: i.mpn,
  variant: Listing.variantOf(i.variant),
  dhash: dhash,
);

String encodeVariant(Map<String, String> v) => jsonEncode(v);
