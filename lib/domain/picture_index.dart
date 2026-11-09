import 'dart:math';
import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../db/database.dart';
import 'embeddings.dart';
import 'images.dart';
import 'pictures.dart';
import 'vault.dart';

/// A picture to put in the index: its address, and how to get its bytes
/// (a kept copy or a download).
typedef PictureSource = (String url, Future<Uint8List?> Function() bytes);

/// Picture vectors kept on this device by picture address
/// (`chanda_pictures`, never synced). A picture that could not be read is
/// kept with an empty vector so it is not fetched again.
class PictureIndex {
  PictureIndex(this.db);
  final AppDatabase db;

  /// The kept vectors of [urls] (unreadable pictures left out).
  Future<Map<String, Float32List>> vectors(Iterable<String> urls) async {
    final all = urls.toSet().toList();
    final out = <String, Float32List>{};
    for (var at = 0; at < all.length; at += 500) {
      final part = all.sublist(at, min(at + 500, all.length));
      final rows = await db
          .customSelect(
            'SELECT url, vec FROM chanda_pictures WHERE url IN (${List.filled(part.length, '?').join(',')})',
            variables: [for (final u in part) Variable(u)],
          )
          .get();
      for (final r in rows) {
        final bytes = r.read<Uint8List>('vec');
        if (bytes.isNotEmpty) out[r.read<String>('url')] = vectorOf(bytes);
      }
    }
    return out;
  }

  Future<Set<String>> _known(List<String> urls) async {
    final out = <String>{};
    for (var at = 0; at < urls.length; at += 500) {
      final part = urls.sublist(at, min(at + 500, urls.length));
      final rows = await db
          .customSelect(
            'SELECT url FROM chanda_pictures WHERE url IN (${List.filled(part.length, '?').join(',')})',
            variables: [for (final u in part) Variable(u)],
          )
          .get();
      out.addAll(rows.map((r) => r.read<String>('url')));
    }
    return out;
  }

  /// Puts up to [cap] of [want] that are not in the index yet through the
  /// picture model. Returns how many were added.
  Future<int> fill(PictureEmbedder e, List<PictureSource> want, {int cap = 24}) async {
    final known = await _known([for (final (u, _) in want) u]);
    final todo = <PictureSource>[];
    final seen = <String>{};
    for (final w in want) {
      if (todo.length >= cap) break;
      if (w.$1.isEmpty || known.contains(w.$1) || !seen.add(w.$1)) continue;
      todo.add(w);
    }
    if (todo.isEmpty) return 0;
    final bytes = await Future.wait([for (final (_, get) in todo) get().catchError((_) => null)]);
    final readable = [
      for (var i = 0; i < todo.length; i++)
        if (bytes[i] != null) i,
    ];
    final vecs = await e.embed([for (final i in readable) bytes[i]!]);
    final byUrl = <String, Float32List?>{for (final (u, _) in todo) u: null};
    for (var k = 0; k < readable.length; k++) {
      byUrl[todo[readable[k]].$1] = vecs[k];
    }
    await db.batch((b) {
      for (final MapEntry(key: url, value: v) in byUrl.entries) {
        b.customStatement('INSERT OR REPLACE INTO chanda_pictures (url, vec) VALUES (?, ?)', [
          url,
          v == null ? Uint8List(0) : vectorBytes(v),
        ]);
      }
    });
    return byUrl.length;
  }

  /// The pictures among [among] that look most like [v], closest first:
  /// at least [floor] alike, at most [limit].
  Future<List<(String, double)>> nearest(
    Float32List v,
    Iterable<String> among, {
    int limit = 24,
    double floor = 0.5,
  }) async {
    final vecs = await vectors(among);
    final scored = [
      for (final MapEntry(key: url, value: w) in vecs.entries)
        if (cosine(v, w) case final s when s >= floor) (url, s),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).toList();
  }

  /// Fills the index from the first pictures of saved things and of the
  /// offers found most lately, [cap] at a time.
  Future<int> fillFromVault(PictureEmbedder e, Vault v, {int cap = 24}) async {
    final items = await v.items();
    final offers =
        await (db.select(db.chandaOffers)
              ..orderBy([(t) => OrderingTerm.desc(t.seen)])
              ..limit(200))
            .get();
    return fill(e, [
      for (final i in items)
        if (imagesOf(i).firstOrNull case final url?) (url, () => firstPicture(i.id, url)),
      for (final o in offers)
        if (o.image.startsWith('http')) (o.image, () => fetchImage(o.image)),
    ], cap: cap);
  }

  /// Saved things and found offers that look like picture vector [v],
  /// closest first: alike enough, and not far behind the closest.
  Future<(List<VaultItem>, List<ShopOffer>)> lookAlike(Float32List v, Vault vault, {int limit = 24}) async {
    final items = <String, VaultItem>{for (final i in await vault.items()) ?imagesOf(i).firstOrNull: i};
    final offers = <String, ShopOffer>{
      for (final o in await db.select(db.chandaOffers).get())
        if (o.image.startsWith('http')) o.image: o,
    };
    final near = await nearest(v, {...items.keys, ...offers.keys}, limit: limit * 2, floor: 0.55);
    final best = near.firstOrNull?.$2 ?? 0;
    final keep = [
      for (final (url, s) in near)
        if (s >= best - 0.2) url,
    ];
    final seen = <String>{};
    return (
      [for (final u in keep) ?items[u]].take(limit).toList(),
      [
        for (final u in keep)
          if (offers[u] case final o? when items[u] == null && seen.add(o.url)) o,
      ].take(limit).toList(),
    );
  }

  Future<void> clear() => db.customStatement('DELETE FROM chanda_pictures');
}
