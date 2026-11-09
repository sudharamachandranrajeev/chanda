import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:chanda/domain/local_search.dart';
import 'package:chanda/domain/offers.dart';
import 'package:chanda/domain/picture_index.dart';
import 'package:chanda/domain/pictures.dart';
import 'package:chanda/domain/taste_store.dart';
import 'package:chanda/domain/vault.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

final _labels = [
  for (final c in ['shirt', 'polo shirt', 't-shirt', 'dress', 'glasses'])
    PictureLabel('category', c, Float32List(4)),
];

Offer _offer(String slug, String title, {int price = 2500}) => Offer(
  shop: 'example',
  url: 'https://shop.example/p/$slug',
  title: title,
  price: price,
  currency: 'GBP',
  image: 'https://img.example/$slug.jpg',
);

void main() {
  late Vault v;
  late TasteStore t;

  setUp(() async {
    v = await memoryVault();
    t = TasteStore(v.store, labels: _labels);
  });

  test('a rating per page: rating again replaces it, unrate removes it', () async {
    await t.rate(url: 'https://a.example/1', title: 'Navy shirt', stars: 4);
    await t.rate(url: 'https://a.example/1', title: 'Navy shirt', stars: 2);
    expect((await t.ratings()).single.stars, 2);
    expect(() => t.rate(url: 'https://a.example/1', title: 'x', stars: 6), throwsRangeError);
    await t.unrate('https://a.example/1');
    expect(await t.ratings(), isEmpty);
  });

  test('saved and bought things count as weak evidence, ratings as full', () async {
    final lamp = await saved(v, reading(url: 'https://www.amazon.co.uk/dp/B000000001', title: 'Brass lamp'));
    await saved(v, reading(url: 'https://www.amazon.co.uk/dp/B000000002', title: 'Oak desk'));
    await v.updateItem(lamp.copyWith(bought: true));
    await t.rate(url: 'https://www.amazon.co.uk/dp/B000000002', title: 'Oak desk', stars: 5);
    final s = await t.signals();
    expect(s, hasLength(2));
    expect(
      [for (final x in s) (x.input.title, x.stars, x.weight)],
      [('Oak desk', 5.0, 1.0), ('Brass lamp', 4.0, 0.5)],
    );
  });

  test('what a thing is, its colour and material come from its title', () {
    final x = inputOf(
      const Thing(url: 'u', title: "Men's Navy Linen Polo Shirts", price: 2599, shop: 'example'),
      labels: _labels,
    );
    expect((x.category, x.colour, x.material, x.price), ('polo shirt', 'navy', 'linen', 25.99));
    expect(categoryOf('Cotton T-Shirt, white', _labels), 't-shirt');
    expect(categoryOf('Shirtdress', _labels), '');
  });

  test('For you: unseen offers only, liked looks first, nothing when off', () async {
    final search = LocalSearch(v.store);
    await search.keepOffers([
      _offer('a', 'Navy linen shirt'),
      _offer('b', 'Red sequin dress'),
      _offer('c', 'Navy cotton shirt'),
      _offer('d', 'Round glasses'),
    ], 'q');
    await t.rate(url: 'https://shop.example/p/a', title: 'Navy linen shirt', stars: 5, shop: 'example');
    await t.rate(url: 'https://shop.example/p/b', title: 'Red sequin dress', stars: 1, shop: 'example');
    final s = await t.forYou(random: Random(1));
    expect(s.map((x) => x.$1.title), ['Navy cotton shirt', 'Round glasses']);
    expect(s.first.$2.because?.title, 'Navy linen shirt');
    await t.setOn(false);
    expect(await t.forYou(), isEmpty);
  });

  test('reorder keeps every thing and only changes the order', () async {
    await t.rate(url: 'https://shop.example/p/x', title: 'Navy linen shirt', stars: 5);
    final things = ['Red dress', 'Navy shirt', 'Glasses', 'Red dress'];
    final out = await t.reorder(things, (s) => Thing(url: 'https://shop.example/p/$s', title: s));
    expect(out.first, 'Navy shirt');
    expect([...out]..sort(), [...things]..sort());
  });

  test('export and import: newer ratings win, bad rows are skipped', () async {
    await t.rate(url: 'https://a.example/1', title: 'Old', stars: 2, at: '2026-01-01T00:00:00.000Z');
    await t.rate(url: 'https://a.example/2', title: 'Mine', stars: 5, at: '2026-06-01T00:00:00.000Z');
    await t.mute('colour:red');
    final out = jsonDecode(await t.export()) as Map;
    expect(out['format'], 'chanda.taste/1');
    expect((out['ratings'] as List), hasLength(2));

    final other = TasteStore((await memoryVault()).store);
    await other.rate(url: 'https://a.example/1', title: 'Newer', stars: 4, at: '2026-03-01T00:00:00.000Z');
    await other.rate(url: 'https://a.example/2', title: 'Older', stars: 1, at: '2026-02-01T00:00:00.000Z');
    final file = jsonDecode(await other.export()) as Map;
    (file['ratings'] as List)
      ..add({'url': 'javascript:alert(1)', 'stars': 5, 'at': '2026-03-01T00:00:00Z'})
      ..add({'url': 'https://a.example/3', 'stars': 9, 'at': '2026-03-01T00:00:00Z'});
    expect(await t.import(jsonEncode(file)), 1);
    final byUrl = {for (final r in await t.ratings()) r.url: (r.title, r.stars)};
    expect(byUrl, {'https://a.example/1': ('Newer', 4), 'https://a.example/2': ('Mine', 5)});
    expect(await t.muted(), {'colour:red'});
    expect(() => t.import('{"format":"other"}'), throwsFormatException);

    await t.reset();
    expect(await t.ratings(), isEmpty);
    expect(await t.muted(), isEmpty);
  });

  test('the rate card pauses for a week after three skips', () async {
    final now = DateTime.utc(2026, 11, 9);
    for (var i = 0; i < 2; i++) {
      await t.skippedRating(now: now);
    }
    expect(await t.mayAskToRate(now: now), isTrue);
    await t.skippedRating(now: now);
    expect(await t.mayAskToRate(now: now.add(const Duration(days: 6))), isFalse);
    expect(await t.mayAskToRate(now: now.add(const Duration(days: 8))), isTrue);
  });

  test('toRate offers saved things not yet rated', () async {
    await saved(v, reading(url: 'https://www.amazon.co.uk/dp/B000000001', title: 'Lamp'));
    await saved(v, reading(url: 'https://www.amazon.co.uk/dp/B000000002', title: 'Desk'));
    await t.rate(url: 'https://www.amazon.co.uk/dp/B000000001', title: 'Lamp', stars: 3);
    expect((await t.toRate()).map((i) => i.title), ['Desk']);
  });

  test('picture index: unreadable pictures are kept as such, nearest by looks', () async {
    final index = PictureIndex(t.db);
    final e = _FakePictures();
    final added = await index.fill(e, [
      ('https://img.example/a.jpg', () async => Uint8List.fromList([1, 0])),
      ('https://img.example/b.jpg', () async => Uint8List.fromList([0, 1])),
      ('https://img.example/c.jpg', () async => null),
      ('https://img.example/a.jpg', () async => Uint8List.fromList([1, 0])),
    ]);
    expect(added, 3);
    expect(await index.fill(e, [('https://img.example/c.jpg', () async => Uint8List(1))]), 0);
    expect((await index.vectors(['https://img.example/a.jpg', 'https://img.example/c.jpg'])).keys, [
      'https://img.example/a.jpg',
    ]);
    final near = await index.nearest(unit([0.9, 0.1]), [
      'https://img.example/a.jpg',
      'https://img.example/b.jpg',
    ]);
    expect(near.map((n) => n.$1), ['https://img.example/a.jpg']);
    expect(e.calls, 1);
  });
}

/// Treats the bytes as the picture vector.
class _FakePictures implements PictureEmbedder {
  var calls = 0;
  @override
  Future<List<Float32List?>> embed(List<Uint8List> pictures) async {
    calls++;
    return [
      for (final p in pictures) unit([for (final b in p) b.toDouble()]),
    ];
  }
}
