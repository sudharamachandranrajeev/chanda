import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chanda/domain/compare.dart';
import 'package:chanda/domain/embeddings.dart';
import 'package:chanda/domain/local_search.dart';
import 'package:chanda/domain/matching.dart';
import 'package:chanda/domain/money.dart';
import 'package:chanda/domain/offers.dart';
import 'package:chanda/domain/query.dart';
import 'package:chanda/domain/shop_search.dart';
import 'package:chanda/domain/shops.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;

import 'support.dart';

Offer offer(String title, int price, {String shop = 'amazon-uk', String? url, String currency = 'GBP'}) => Offer(
  shop: shop,
  url: url ?? 'https://www.amazon.co.uk/dp/B0${title.hashCode.abs().toString().padLeft(8, '0').substring(0, 8)}',
  title: title,
  price: price,
  currency: currency,
);

/// Stands in for the meaning model: texts that name the same concept get
/// the same unit vector.
class _ConceptEmbedder implements Embedder {
  static const concepts = [
    ['glasses', 'specs', 'brille'],
    ['lamp', 'light'],
    ['shirt', 'top'],
  ];
  var calls = 0;

  @override
  Future<List<Float32List>> embed(List<String> texts) async {
    calls++;
    return [
      for (final t in texts)
        () {
          final v = Float32List(concepts.length + 1);
          final i = concepts.indexWhere((c) => c.any(t.toLowerCase().contains));
          v[i < 0 ? concepts.length : i] = 1;
          return v;
        }(),
    ];
  }
}

void main() {
  group('reading a search', () {
    test('budget, size, colour, material and shop become chips', () {
      final q = readQuery('black linen shirt size M under £30 on Amazon');
      expect(q.words, 'shirt');
      expect(q.maxPrice, 3000);
      expect(q.minPrice, isNull);
      expect(q.of('size'), ['m']);
      expect(q.of('colour'), ['black']);
      expect(q.of('material'), ['linen']);
      expect(q.of('shop'), ['amazon-uk']);
      expect(q.facets.firstWhere((f) => f.kind == 'budget').label, 'Under £30.00');
    });

    test('ranges, minimums and shoe sizes', () {
      final r = readQuery('trainers £20-40 uk 9');
      expect((r.minPrice, r.maxPrice), (2000, 4000));
      expect(r.of('size'), ['uk 9']);
      expect(r.words, 'trainers');
      expect(readQuery('lamp over 15').minPrice, 1500);
      expect(readQuery('jeans 32W 30L').of('size'), ['w32 l30']);
    });

    test('a chip tapped off is gone; one word alone is vague', () {
      final q = readQuery('red dress');
      expect(q.without(q.facets.single).facets, isEmpty);
      expect(readQuery('dress').vague, isTrue);
      expect(readQuery('summer dress').vague, isFalse);
      expect(readQuery('dress under £20').vague, isFalse);
    });

    test('colours and materials must be in the title', () {
      final q = readQuery('grey wool scarf');
      expect(fitsFacets(q, 'Wool scarf, gray'), isTrue);
      expect(fitsFacets(q, 'Grey cotton scarf'), isFalse);
    });

    test('shop search pages', () {
      expect('${shopById('amazon-uk')!.searchFor('reading glasses')}', 'https://www.amazon.co.uk/s?k=reading%20glasses');
      expect(
        '${shopById('aliexpress')!.searchFor('Reading glasses +2.0')}',
        'https://www.aliexpress.com/w/wholesale-reading-glasses-2-0.html',
      );
      expect(shopById('amazon-uk')!.searchHidden, isTrue);
      expect(shopById('shein')!.searchHidden, isFalse);
      expect(shopFor(Uri.parse('https://example.com/')).searchFor('x'), isNull);
    });
  });

  group('offers', () {
    final amazon = shopById('amazon-uk')!;

    test('tiles are read with the page\'s own currency marks', () {
      final offers = parseOffers(
        amazon,
        jsonEncode([
          {'title': 'Reading glasses +2.0', 'price': '£8.42', 'was': '£9.67', 'url': 'https://www.amazon.co.uk/x/dp/B01KW9ZHU6?ref=sr', 'rating': 4.6, 'reviews': 1602},
          {'title': 'Reading glasses +2.0', 'price': '£8.42', 'url': 'https://www.amazon.co.uk/dp/B01KW9ZHU6'},
          {'title': 'Learn more', 'price': '£1.00', 'url': 'https://www.amazon.co.uk/gp/browse.html?node=1'},
          {'title': 'No price', 'price': '', 'url': 'https://www.amazon.co.uk/dp/B000000002'},
        ]),
      );
      expect(offers.length, 1, reason: 'the same link once; a link that is not a product page is dropped');
      final o = offers.single;
      expect((o.price, o.was, o.currency, o.rating, o.reviews), (842, 967, 'GBP', 4.6, 1602));
      expect(o.url, 'https://www.amazon.co.uk/dp/B01KW9ZHU6');
    });

    test('fullwidth pound signs read as pounds', () {
      final o = parseOffers(shopById('aliexpress')!, [
        {'title': 'Folding reading glasses', 'price': '￡1.30', 'url': 'https://www.aliexpress.com/item/1005.html?x=1'},
      ]).single;
      expect((o.price, o.currency), (130, 'GBP'));
    });

    test('ranking keeps matches within the budget, best match first then cheapest', () {
      final q = readQuery('reading glasses under £10');
      final ranked = rankOffers(q, [
        offer('Reading glasses black', 900),
        offer('Reading glasses blue light', 500),
        offer('Reading lamp', 300),
        offer('Reading glasses titanium', 1500),
        offer('Glasses', 200),
      ]);
      expect(ranked.map((o) => o.title), ['Reading glasses blue light', 'Reading glasses black']);
    });
  });

  group('same product?', () {
    test('barcodes are checked and settle it', () {
      expect(gtin14('5 012345 678900'), '05012345678900');
      expect(gtin14('5012345678901'), '', reason: 'wrong check digit');
      expect(gtin14('012345678905'), '00012345678905', reason: 'UPC-A');
      const a = Listing(title: 'Lamp', gtin: '5012345678900');
      expect(match(a, const Listing(title: 'Something else', gtin: '05012345678900')), Verdict.same);
      expect(match(a, const Listing(title: 'Lamp', gtin: '4006381333931')), Verdict.different);
    });

    test('brand and model number make it the same', () {
      expect(
        match(
          const Listing(title: 'Sony WH-1000XM5 Wireless Headphones, Black', brand: 'Sony'),
          const Listing(title: 'SONY WH1000XM5 noise cancelling headphones black'),
        ),
        Verdict.same,
      );
      expect(modelsIn('Pack of 2 OPULIZE PEP 500ml A2342 2pcs'), {'A2342'});
    });

    test('different sizes, capacities and strengths never merge', () {
      expect(
        match(const Listing(title: 'Phone 128GB blue', brand: 'X'), const Listing(title: 'Phone 256GB blue', brand: 'X')),
        Verdict.different,
      );
      expect(
        match(
          const Listing(title: 'Linen shirt', variant: {'Size': 'M'}),
          const Listing(title: 'Linen shirt', variant: {'Size': 'L'}),
        ),
        Verdict.different,
      );
      expect(
        match(const Listing(title: 'Water bottle 1L steel'), const Listing(title: 'Steel water bottle 1.0L')),
        Verdict.likely,
      );
    });

    test('like pictures or words make it likely, for the user to confirm', () {
      expect(
        match(
          const Listing(title: 'Lamp', dhash: 'ffff0000ffff0000'),
          const Listing(title: 'Light', dhash: 'ffff0000ffff0003'),
        ),
        Verdict.likely,
      );
      expect(
        match(const Listing(title: 'Brass desk lamp with USB'), const Listing(title: 'Brass desk lamp, USB port')),
        Verdict.likely,
      );
      expect(match(const Listing(title: 'Brass desk lamp'), const Listing(title: 'Oak bookshelf')), Verdict.different);
    });

    test('a picture keeps its hash when resized; another picture does not', () {
      img.Image picture(bool flip) {
        final p = img.Image(width: 200, height: 160);
        for (var y = 0; y < 160; y++) {
          for (var x = 0; x < 200; x++) {
            final v = flip ? (x * 255 ~/ 200) : (((x ~/ 25) + (y ~/ 20)).isEven ? 230 : 20);
            p.setPixelRgb(x, y, v, v, (v + y) % 256);
          }
        }
        return p;
      }

      final a = dhashOf(img.encodePng(picture(false)))!;
      final small = dhashOf(img.encodeJpg(img.copyResize(picture(false), width: 100), quality: 70))!;
      final other = dhashOf(img.encodePng(picture(true)))!;
      expect(a.length, 16);
      expect(hamming(a, small), lessThanOrEqualTo(8));
      expect(hamming(a, other), greaterThan(8));
      expect(dhashOf(utf8.encode('not a picture')), isNull);
    });
  });

  group('best deal', () {
    final now = DateTime.utc(2026, 11, 9, 12);
    final fresh = now.subtract(const Duration(hours: 2)).toIso8601String();
    Deal deal(String shop, int price, {double? rating, int? reviews, bool inStock = true, int? shipping, String? seen}) =>
        Deal(
          shop: shopOf(shop),
          url: 'https://$shop/p',
          title: 'Lamp',
          price: price,
          currency: 'GBP',
          seen: seen ?? fresh,
          rating: rating,
          reviews: reviews,
          inStock: inStock,
          shipping: shipping,
        );

    test('the cheapest delivered, in stock, from a well-rated seller', () {
      final (all, best) = compareDeals(
        [
          deal('amazon-uk', 2000, rating: 4.5, reviews: 300),
          deal('example.co.uk', 1500, rating: 3.1, reviews: 900),
          deal('shop.co.uk', 1200, inStock: false),
          deal('other.co.uk', 1800, shipping: 399),
        ],
        home: 'GBP',
        fx: null,
        now: now,
      );
      expect(all.map((c) => c.landed!.total), [1200, 1500, 2000, 2199]);
      expect(best!.deal.deal.shop.id, 'amazon-uk');
      expect(
        best.reason,
        '£1.99 less delivered than the next; a cheaper one is out of stock; '
        'a cheaper one is rated under 4.0; rated 4.5 by 300.',
      );
    });

    test('a low rating from a few reviews does not rule a seller out; old prices are flagged', () {
      final (_, best) = compareDeals(
        [deal('example.co.uk', 900, rating: 2.0, reviews: 3, seen: '2026-11-01T00:00:00Z')],
        home: 'GBP',
        fx: null,
        now: now,
      );
      expect(best!.reason, 'The only one in stock from a well-rated seller; rated 2.0 by 3; its price is over a day old.');
    });

    test('no total without an exchange rate, and no best without one', () {
      final (all, best) = compareDeals(
        [Deal(shop: shopOf('beispiel.de'), url: 'u', title: 't', price: 100, currency: 'EUR', seen: null)],
        home: 'GBP',
        fx: null,
      );
      expect((all.single.landed, best), (null, null));
      const fx = FxRates('GBP', '2026-11-06', {'EUR': 1.2});
      expect(
        compareDeals(
          [Deal(shop: shopOf('beispiel.de'), url: 'u', title: 't', price: 1200, currency: 'EUR', seen: null)],
          home: 'GBP',
          fx: fx,
        ).$2!.deal.landed!.estimate,
        isTrue,
      );
    });
  });

  group('searching the device', () {
    test('words by prefix, then any part of a title; facets filter', () async {
      final v = await memoryVault();
      final f = LocalSearch(v.store);
      await saved(v, reading(title: 'Brass desk lamp', price: 4599));
      await saved(v, reading(url: 'https://www.amazon.co.uk/dp/B000000002', title: 'Black linen shirt', price: 2500));
      await f.keepOffers([offer('Brass floor lamp', 9900)], 'lamp');

      expect((await f.search(readQuery('lamp'))).map((h) => h.title), containsAll(['Brass desk lamp', 'Brass floor lamp']));
      expect((await f.search(readQuery('lam'))).map((h) => h.title), hasLength(2), reason: 'prefix');
      expect((await f.search(readQuery('ass des'))).map((h) => h.title), ['Brass desk lamp'], reason: 'substring');
      expect((await f.search(readQuery('lamp under £50'))).map((h) => h.title), ['Brass desk lamp']);
      expect((await f.search(readQuery('black shirt'))).map((h) => h.title), ['Black linen shirt']);
      expect(await f.search(readQuery('white shirt')), isEmpty);
      expect(await f.search(readQuery('lamp', ), offers: false), hasLength(1));
    });

    test('smarter search finds by meaning, fused with the words', () async {
      final v = await memoryVault();
      final e = _ConceptEmbedder();
      final f = LocalSearch(v.store, embedder: e);
      await saved(v, reading(title: 'Reading glasses +2.0', price: 999));
      await saved(v, reading(url: 'https://www.amazon.co.uk/dp/B000000002', title: 'Lesebrille Herren', price: 1299));
      await saved(v, reading(url: 'https://www.amazon.co.uk/dp/B000000003', title: 'Brass desk lamp', price: 4599));

      expect((await f.search(readQuery('specs'))).map((h) => h.title), unorderedEquals(['Reading glasses +2.0', 'Lesebrille Herren']));
      final both = (await f.search(readQuery('glasses'))).map((h) => h.title).toList();
      expect(both.first, 'Reading glasses +2.0', reason: 'in both rankings, so first');
      expect(both, contains('Lesebrille Herren'));
      expect((await f.search(readQuery('specs under £10'))).map((h) => h.title), ['Reading glasses +2.0']);

      final before = e.calls;
      await f.search(readQuery('light'));
      expect(e.calls - before, 1, reason: 'titles already embedded: only the query');
      expect(await LocalSearch(v.store).search(readQuery('specs')), isEmpty, reason: 'off: words only');
    });

    test('answers are kept and rule offers out of the candidates', () async {
      final v = await memoryVault();
      final f = LocalSearch(v.store);
      final item = await saved(v, reading(title: 'Brass desk lamp USB'));
      final a = offer('Brass desk lamp with USB port', 3999);
      final b = offer('Brass desk lamp USB charging', 4200);
      await f.keepOffers([a, b, offer('Oak bookshelf', 5000)], 'lamp');
      expect((await f.candidatesFor(item)).map((o) => o.title), unorderedEquals([a.title, b.title]));
      await f.answer(item.id, b.url, same: false);
      await f.answer(item.id, a.url, same: true);
      expect((await f.candidatesFor(item)).map((o) => o.title), [a.title]);
      expect(await f.matchesFor(item.id), {a.url: 'same', b.url: 'different'});
      await f.answer(item.id, a.url, same: false);
      expect((await f.matchesFor(item.id))[a.url], 'different', reason: 'answered again, not twice');
    });
  });

  group('meaning model', () {
    test('mean pooling skips padding and makes unit vectors', () {
      // Two texts, three tokens, two dimensions; the second text has one
      // real token.
      final hidden = [1.0, 0.0, 3.0, 0.0, 9.0, 9.0, 0.0, 2.0, 5.0, 5.0, 5.0, 5.0];
      final v = meanPool(hidden, [1, 1, 0, 1, 0, 0], batch: 2, seq: 3);
      expect(v[0], [1.0, 0.0]);
      expect(v[1], [0.0, 1.0]);
      expect(vectorOf(vectorBytes(v[1])), v[1]);
      expect(cosine(v[0], v[1]), 0);
    });

    test('rank fusion and the nearness cut', () {
      expect(fuseRankings([
        ['a', 'b', 'c'],
        ['c', 'a'],
      ]), ['a', 'c', 'b']);
      expect(nearest({'jeans': 0.75, 'shoes': 0.37, 'mug': 0.05}), ['jeans']);
      expect(nearest({'glasses': 0.62, 'brille': 0.42, 'mug': 0.29}), ['glasses', 'brille']);
      expect(nearest({'shoes': 0.24}), isEmpty);
    });

    test('download keeps only files that match their checksum', () async {
      final dir = await Directory.systemTemp.createTemp('chanda_model');
      addTearDown(() => dir.delete(recursive: true));
      final body = utf8.encode('model bytes');
      final good = ModelFile('m.onnx', body.length, '${sha256.convert(body)}');
      final client = MockClient((_) async => http.Response.bytes(body, 200));
      final seen = <int>[];
      await downloadModel(dir, client: client, files: [good], progress: seen.add);
      expect(File('${dir.path}/m.onnx').readAsBytesSync(), body);
      expect(seen.last, body.length);

      final bad = ModelFile('t.json', body.length, '0' * 64);
      await expectLater(downloadModel(dir, client: client, files: [bad]), throwsFormatException);
      expect(dir.listSync().map((f) => f.uri.pathSegments.last), ['m.onnx'], reason: 'no part file left behind');
    });

    test('the pinned files', () {
      expect(modelFiles.map((f) => f.name), ['model_optimized.onnx', 'tokenizer.json']);
      expect(modelBytes, 235052644 + 17083009);
      expect(modelFiles.first.url.toString(), contains('faf4aa4225822f3bc6376869cb1164e8e3feedd0'));
    });
  });

  group('searching shops', () {
    test('three at a time; walled shops go to the browser; checks are reported', () async {
      final s = _FakeSearcher();
      final states = <String>[];
      final done = searchShops(s, readQuery('lamp'), [
        ...shops,
        Shop(id: 'a.co.uk', name: 'A', domains: const ['a.co.uk'], home: 'https://a.co.uk/', currency: 'GBP', search: 'https://a.co.uk/s?q={q}'),
        Shop(id: 'b.co.uk', name: 'B', domains: const ['b.co.uk'], home: 'https://b.co.uk/', currency: 'GBP', search: 'https://b.co.uk/s?q={q}'),
      ]).listen((r) => states.add('${r.shop.id}:${r.state.name}'));
      await done.asFuture<void>();
      expect(s.most, 3);
      for (final walled in ['shein', 'temu', 'hacoo']) {
        expect(states, contains('$walled:inBrowser'));
      }
      expect(states, containsAll(['amazon-uk:done', 'aliexpress:check', 'a.co.uk:done', 'b.co.uk:failed']));
    });

    test('a named shop is the only one searched', () async {
      final states = await searchShops(_FakeSearcher(), readQuery('lamp on temu'), shops).map((r) => r.shop.id).toSet();
      expect(states, {'temu'});
    });
  });
}

class _FakeSearcher implements ShopSearcher {
  int running = 0, most = 0;

  @override
  bool get available => true;

  @override
  Future<List<Offer>> search(Shop shop, Query q) async {
    running++;
    if (running > most) most = running;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    running--;
    return switch (shop.id) {
      'aliexpress' => throw const ShopCheck('AliExpress'),
      'b.co.uk' => throw StateError('offline'),
      _ => [offer('Lamp', 1000, shop: shop.id)],
    };
  }
}
