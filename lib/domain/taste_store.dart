import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart';

import '../db/database.dart';
import 'embeddings.dart';
import 'offers.dart';
import 'picture_index.dart';
import 'pictures.dart';
import 'query.dart';
import 'taste.dart';
import 'vault.dart';

/// Synced preferences: taste suggestions on or off ('off' turns them off),
/// and the attributes the user muted (a JSON list of "kind:value").
const tastePref = 'chanda.taste';
const tasteMutedPref = 'chanda.tasteMuted';

/// Device-only: the "rate a few" card's skips and pause.
const ratePromptSetting = 'chanda.ratePrompt';

/// The export format's name and version.
const tasteFormat = 'chanda.taste/1';

/// Implicit evidence: a saved, unrated item counts as a weak 3.6 stars, a
/// bought one as a weak 4.
const _savedStars = 3.6, _savedWeight = 0.3, _boughtStars = 4.0, _boughtWeight = 0.5;

/// The user's ratings and what the taste model is built from.
class TasteStore {
  TasteStore(this.store, {this.labels = const []});
  final Store store;

  /// The picture labels (for naming what a thing is); empty when not loaded.
  final List<PictureLabel> labels;

  AppDatabase get db => store.db as AppDatabase;
  Vault get _vault => Vault(store);

  // ---- ratings ----

  Future<List<Rating>> ratings() =>
      (db.select(db.chandaRatings)
            ..where((t) => t.deleted.not())
            ..orderBy([(t) => OrderingTerm.desc(t.at)]))
          .get();

  Future<Rating?> ratingOf(String url) async => (await (db.select(
    db.chandaRatings,
  )..where((t) => t.url.equals(url) & t.deleted.not())).get()).firstOrNull;

  /// Rates the thing at [url] 1-5 stars, replacing an earlier rating.
  /// "Not for me" is a 1-star rating with [source] 'not-for-me'.
  Future<void> rate({
    required String url,
    required String title,
    required int stars,
    String shop = '',
    String image = '',
    int? price,
    String currency = '',
    String source = 'rated',
    String? at,
  }) async {
    if (stars < 1 || stars > 5) throw RangeError.range(stars, 1, 5, 'stars');
    final id = (await ratingOf(url))?.id ?? newId();
    await store.save(
      db.chandaRatings,
      ChandaRatingsCompanion.insert(
        id: id,
        url: url,
        title: title,
        shop: Value(shop),
        image: Value(image),
        price: Value(price),
        currency: Value(currency),
        stars: stars,
        at: at ?? nowIso(),
        source: Value(source),
      ),
      id,
    );
  }

  Future<void> rateItem(VaultItem i, int stars) => rate(
    url: i.url,
    title: i.title,
    stars: stars,
    shop: i.shop,
    image: imagesOf(i).firstOrNull ?? '',
    price: i.price,
    currency: i.currency,
  );

  Future<void> rateOffer(ShopOffer o, int stars, {String source = 'rated'}) => rate(
    url: o.url,
    title: o.title,
    stars: stars,
    shop: o.shop,
    image: o.image,
    price: o.price,
    currency: o.currency,
    source: source,
  );

  Future<void> unrate(String url) async {
    final r = await ratingOf(url);
    if (r != null) await store.remove(db.chandaRatings, r.id);
  }

  // ---- settings ----

  Future<bool> on() async => await _vault.pref(tastePref) != 'off';

  Future<void> setOn(bool on) => _vault.setPref(tastePref, on ? 'on' : 'off');

  Future<Set<String>> muted() async {
    try {
      return {for (final a in jsonDecode(await _vault.pref(tasteMutedPref) ?? '[]') as List) '$a'};
    } on Object {
      return {};
    }
  }

  Future<void> setMuted(Set<String> muted) =>
      _vault.setPref(tasteMutedPref, jsonEncode(muted.toList()..sort()));

  Future<void> mute(String attribute) async => setMuted({...await muted(), attribute});

  Future<void> unmute(String attribute) async => setMuted({...await muted()}..remove(attribute));

  // ---- the "rate a few" card ----

  /// Whether the card may show: not while paused after three skips in a row.
  Future<bool> mayAskToRate({DateTime? now}) async {
    final s = await _promptState();
    final until = DateTime.tryParse('${s['until'] ?? ''}');
    return until == null || (now ?? DateTime.now()).toUtc().isAfter(until);
  }

  /// Notes a skip; the third in a row pauses the card for a week.
  Future<void> skippedRating({DateTime? now}) async {
    final s = await _promptState();
    final skips = ((s['skips'] as num?)?.toInt() ?? 0) + 1;
    await db.setLocalSetting(
      ratePromptSetting,
      jsonEncode(
        skips >= 3
            ? {'skips': 0, 'until': nowIso((now ?? DateTime.now()).add(const Duration(days: 7)))}
            : {'skips': skips},
      ),
    );
  }

  /// A rating from the card clears the skips.
  Future<void> ratedFromPrompt() => db.setLocalSetting(ratePromptSetting, jsonEncode({'skips': 0}));

  Future<Map<String, Object?>> _promptState() async {
    try {
      return (jsonDecode(await db.localSetting(ratePromptSetting) ?? '{}') as Map).cast<String, Object?>();
    } on Object {
      return {};
    }
  }

  /// Up to [n] saved things the user has not rated, newest first.
  Future<List<VaultItem>> toRate({int n = 3}) async {
    final rated = {for (final r in await ratings()) r.url};
    final items = (await _vault.items())..sort((a, b) => b.added.compareTo(a.added));
    return items.where((i) => !rated.contains(i.url)).take(n).toList();
  }

  // ---- what the model sees ----

  /// Model inputs for [things], with their picture and meaning vectors where
  /// the device has them.
  Future<List<TasteInput>> inputs(List<Thing> things) async {
    final pictures = await PictureIndex(db).vectors([
      for (final t in things)
        if (t.image.isNotEmpty) t.image,
    ]);
    final texts = await _textVectors({for (final t in things) t.title});
    return [
      for (final t in things) inputOf(t, picture: pictures[t.image], text: texts[t.title], labels: labels),
    ];
  }

  /// Meaning vectors kept by smarter search, by title (none when it is off).
  Future<Map<String, Float32List>> _textVectors(Set<String> titles) async {
    if (titles.isEmpty) return const {};
    final exists = await db
        .customSelect("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'chanda_vectors'")
        .get();
    if (exists.isEmpty) return const {};
    final all = titles.toList();
    final out = <String, Float32List>{};
    for (var at = 0; at < all.length; at += 500) {
      final part = all.sublist(at, min(at + 500, all.length));
      final rows = await db
          .customSelect(
            'SELECT text, vec FROM chanda_vectors WHERE text IN (${List.filled(part.length, '?').join(',')})',
            variables: [for (final t in part) Variable(t)],
          )
          .get();
      for (final r in rows) {
        out[r.read<String>('text')] = vectorOf(r.read<Uint8List>('vec'));
      }
    }
    return out;
  }

  /// Every piece of evidence: ratings, then saved and bought things the
  /// user has not rated.
  Future<List<TasteSignal>> signals() async {
    final rs = await ratings();
    final rated = {for (final r in rs) r.url};
    final items = [
      for (final i in await _vault.items())
        if (!rated.contains(i.url)) i,
    ];
    final things = [...rs.map(Thing.ofRating), ...items.map(Thing.ofItem)];
    final ins = await inputs(things);
    return [
      for (var k = 0; k < rs.length; k++) TasteSignal(ins[k], rs[k].stars.toDouble()),
      for (var k = 0; k < items.length; k++)
        items[k].bought
            ? TasteSignal(ins[rs.length + k], _boughtStars, weight: _boughtWeight)
            : TasteSignal(ins[rs.length + k], _savedStars, weight: _savedWeight),
    ];
  }

  /// "For you": offers found in earlier searches that are not saved and
  /// not rated, ranked by taste, each with why. Empty when taste is off or
  /// there is nothing to learn from yet.
  Future<List<(ShopOffer, Suggestion)>> forYou({int limit = 12, Random? random}) async {
    if (!await on()) return const [];
    final sig = await signals();
    if (sig.isEmpty) return const [];
    final skip = {for (final i in await _vault.items()) i.url, for (final r in await ratings()) r.url};
    final offers =
        await (db.select(db.chandaOffers)
              ..orderBy([(t) => OrderingTerm.desc(t.seen)])
              ..limit(400))
            .get();
    final fresh = <String, ShopOffer>{};
    for (final o in offers) {
      if (!skip.contains(o.url)) fresh.putIfAbsent(o.url, () => o);
    }
    if (fresh.isEmpty) return const [];
    final cands = await inputs([for (final o in fresh.values) Thing.ofOffer(o)]);
    return [
      for (final s in rank(cands, sig, muted: await muted(), random: random).take(limit))
        (fresh[s.input.key]!, s),
    ];
  }

  /// [things] in taste order, best first; the same order when taste is off
  /// or there is nothing to learn from yet. Never adds or drops any.
  Future<List<T>> reorder<T>(List<T> things, Thing Function(T) thing) async {
    if (things.length < 2 || !await on()) return things;
    final sig = await signals();
    if (sig.isEmpty) return things;
    final ins = await inputs([for (final t in things) thing(t)]);
    final at = <String, List<int>>{};
    for (var k = 0; k < ins.length; k++) {
      (at[ins[k].key] ??= []).add(k);
    }
    final order = rank(ins, sig, muted: await muted(), random: Random(0));
    final out = <T>[];
    final done = <String>{};
    for (final s in order) {
      if (done.add(s.input.key)) out.addAll([for (final k in at[s.input.key]!) things[k]]);
    }
    return out;
  }

  // ---- export, import, reset ----

  /// Everything the taste model is built from, as JSON the user can keep.
  Future<String> export() async => const JsonEncoder.withIndent(' ').convert({
    'format': tasteFormat,
    'exported': nowIso(),
    'pictureSeed': pictureSeed,
    'textSeed': textSeed,
    'muted': (await muted()).toList()..sort(),
    'ratings': [
      for (final r in await ratings())
        {
          'url': r.url,
          'title': r.title,
          'shop': r.shop,
          'image': r.image,
          'price': r.price,
          'currency': r.currency,
          'stars': r.stars,
          'at': r.at,
          'source': r.source,
        },
    ],
  });

  /// Reads an export: ratings join the user's own (the newer of two for the
  /// same page wins) and muted attributes are added. Returns how many
  /// ratings were taken. Throws [FormatException] for anything else.
  Future<int> import(String json) async {
    final Object? data;
    try {
      data = jsonDecode(json);
    } on FormatException {
      throw const FormatException('This is not a taste export.');
    }
    if (data is! Map || data['format'] != tasteFormat) {
      throw const FormatException('This is not a taste export (chanda.taste/1).');
    }
    final mine = {for (final r in await ratings()) r.url: r};
    var taken = 0;
    for (final r in (data['ratings'] as List?) ?? const []) {
      if (r is! Map) continue;
      final url = '${r['url'] ?? ''}';
      final stars = r['stars'];
      final at = DateTime.tryParse('${r['at'] ?? ''}');
      if (!(Uri.tryParse(url)?.isScheme('https') ?? false) &&
          !(Uri.tryParse(url)?.isScheme('http') ?? false)) {
        continue;
      }
      if (stars is! int || stars < 1 || stars > 5 || at == null) continue;
      if (mine[url] case final m? when m.at.compareTo(nowIso(at)) >= 0) continue;
      final source = r['source'] == 'not-for-me' ? 'not-for-me' : 'rated';
      final image = '${r['image'] ?? ''}';
      await rate(
        url: url,
        title: _clip('${r['title'] ?? ''}', 300),
        stars: stars,
        shop: _clip('${r['shop'] ?? ''}', 100),
        image: image.startsWith('http') ? _clip(image, 2000) : '',
        price: r['price'] is int ? r['price'] as int : null,
        currency: _clip('${r['currency'] ?? ''}', 3),
        source: source,
        at: nowIso(at),
      );
      taken++;
    }
    final m = data['muted'];
    if (m is List) {
      await setMuted({
        ...await muted(),
        for (final a in m)
          if (a is String && a.contains(':') && a.length <= 100) a,
      });
    }
    return taken;
  }

  /// Forgets every rating and muted attribute.
  Future<void> reset() async {
    for (final r in await ratings()) {
      await store.remove(db.chandaRatings, r.id);
    }
    await setMuted({});
  }
}

String _clip(String s, int n) => s.length <= n ? s : s.substring(0, n);

/// Something the user could buy, as the taste model needs it, from
/// wherever it came from.
class Thing {
  const Thing({
    required this.url,
    required this.title,
    this.shop = '',
    this.brand = '',
    this.image = '',
    this.price,
  });

  Thing.ofItem(VaultItem i)
    : this(
        url: i.url,
        title: i.title,
        shop: i.shop,
        brand: i.brand,
        image: imagesOf(i).firstOrNull ?? '',
        price: i.price,
      );

  Thing.ofFound(Offer o) : this(url: o.url, title: o.title, shop: o.shop, image: o.image, price: o.price);

  Thing.ofOffer(ShopOffer o) : this(url: o.url, title: o.title, shop: o.shop, image: o.image, price: o.price);

  Thing.ofRating(Rating r) : this(url: r.url, title: r.title, shop: r.shop, image: r.image, price: r.price);

  final String url;
  final String title;
  final String shop;
  final String brand;
  final String image;

  /// Minor units.
  final int? price;
}

/// The model's view of [t]: what it is (from its picture, else its title),
/// its colour and material (from its title, else its picture), its shop,
/// brand and price.
TasteInput inputOf(Thing t, {Float32List? picture, Float32List? text, List<PictureLabel> labels = const []}) {
  final words = t.title.toLowerCase().split(RegExp(r'[^\p{L}\p{N}-]+', unicode: true));
  final tags = picture != null && labels.isNotEmpty ? pictureTags(picture, labels) : null;
  return TasteInput(
    key: t.url,
    title: t.title,
    shop: t.shop,
    brand: t.brand,
    category: tags?.category ?? categoryOf(t.title, labels),
    colour: words.firstWhere(colours.contains, orElse: () => tags?.colour ?? ''),
    material: words.firstWhere(materials.contains, orElse: () => ''),
    price: t.price == null ? null : t.price! / 100,
    picture: picture,
    text: text,
  );
}

/// The picture label category named in [title] ("Men's Navy Linen Shirt" →
/// "shirt"); the longest name wins, so "polo shirt" beats "shirt". Plurals
/// count. '' when none is.
String categoryOf(String title, List<PictureLabel> labels) {
  final t = ' ${title.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')} ';
  var best = '';
  for (final l in labels) {
    if (l.kind != 'category' || l.name.length <= best.length) continue;
    final n = l.name.replaceAll('-', ' ');
    if (t.contains(' $n ') || t.contains(' ${n}s ') || t.contains(' ${n}es ')) best = l.name;
  }
  return best;
}
