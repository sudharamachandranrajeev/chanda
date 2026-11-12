import 'dart:typed_data';

import 'package:chanda/domain/offers.dart';
import 'package:chanda/domain/panel_script.dart';
import 'package:chanda/domain/screen_text.dart';
import 'package:chanda/domain/screen_tiles.dart';
import 'package:chanda/domain/shops.dart';
import 'package:flutter_test/flutter_test.dart';

ScreenLine line(String text, double left, double top, {double width = 200, double height = 24}) =>
    ScreenLine(text, left: left, top: top, width: width, height: height);

void main() {
  // Two columns of product tiles on a 1000 px wide screenshot: a picture
  // 200 px tall, then the name over one or two lines, then the price.
  final lines = [
    line('Merino hiking socks', 20, 260),
    line('for walking, 3 pairs', 20, 288),
    line('£12.99', 20, 320, height: 34),
    line('£18.00', 120, 324, height: 20),
    line('Slip on trail shoe', 520, 260),
    line('£54.50', 520, 292, height: 34),
    line('Free delivery', 520, 330),
    line('Trail walking boot', 20, 560),
    line('£79.00', 20, 592, height: 34),
    line('-20%', 300, 100),
  ];
  final boxes = [
    const ScreenBox('https://shop.example/p/1', left: 20, top: 50, width: 200, height: 200),
    const ScreenBox('https://shop.example/p/2', left: 520, top: 50, width: 200, height: 200),
    const ScreenBox('https://shop.example/p/3', left: 20, top: 350, width: 200, height: 200),
  ];

  group('with the page\'s picture links', () {
    test('each picture takes the text under it', () {
      final tiles = screenTiles(lines, boxes);
      final byLink = {for (final t in tiles) t.href: t};
      expect(
        byLink.keys,
        containsAll(['https://shop.example/p/1', 'https://shop.example/p/2', 'https://shop.example/p/3']),
      );
      expect(byLink['https://shop.example/p/1']!.title, 'Merino hiking socks for walking, 3 pairs');
      expect(byLink['https://shop.example/p/1']!.price, '£12.99');
      expect(byLink['https://shop.example/p/1']!.was, '£18.00', reason: 'the larger sum is the old price');
      expect(byLink['https://shop.example/p/2']!.title, 'Slip on trail shoe');
      expect(byLink['https://shop.example/p/2']!.price, '£54.50');
      expect(byLink['https://shop.example/p/3']!.price, '£79.00');
    });

    test('text of one tile does not leak into the tile below', () {
      final t = screenTiles(lines, boxes).firstWhere((t) => t.href.endsWith('/p/3'));
      expect(t.title, 'Trail walking boot');
    });

    test('a picture with no price under it is no product', () {
      expect(screenTiles([line('Just some words here', 20, 260)], boxes), isEmpty);
    });
  });

  group('without links on the page: columns, each tile closing at its price', () {
    test('two columns come out as separate tiles, with points to find links at', () {
      final tiles = screenTiles(lines, const [], width: 1000);
      expect(tiles.map((t) => t.price).toSet(), {'£12.99', '£54.50', '£79.00'});
      final socks = tiles.firstWhere((t) => t.price == '£12.99');
      expect(socks.title, 'Merino hiking socks for walking, 3 pairs');
      expect(socks.was, '£18.00');
      expect(socks.href, isEmpty);
      expect(socks.probes, isNotEmpty);
      expect(tiles.firstWhere((t) => t.price == '£54.50').title, 'Slip on trail shoe');
    });

    test('discount, delivery and rating lines are not names or prices', () {
      expect(isPriceLine(line('Free delivery £2.99', 0, 0), 'GBP'), isFalse);
      expect(isPriceLine(line('-20%', 0, 0), 'GBP'), isFalse);
      expect(isPriceLine(line('Was £15.00', 0, 0), 'GBP'), isFalse);
      expect(isPriceLine(line('£15.00', 0, 0), 'GBP'), isTrue);
      expect(isPriceLine(line('12,99 €', 0, 0), 'EUR'), isTrue);
    });
  });

  group('what comes out is read like any tiles, marked as read from the screen', () {
    test('as offers with the screen source', () {
      final shop = shopFor(Uri.parse('https://shop.example/'));
      final tiles = [for (final t in screenTiles(lines, boxes)) t.toJson()];
      final offers = parseOffers(shop, tiles, source: OfferSource.screen);
      expect(offers, hasLength(3));
      expect(offers.every((o) => o.source == OfferSource.screen), isTrue);
      expect(offers.firstWhere((o) => o.url.endsWith('/p/1')).price, 1299);
    });

    test('a view is read from the page script\'s answer, in screenshot pixels', () {
      final v = readView(
        '{"w":500,"h":400,"top":30,"bottom":250,"sy":120,'
        '"boxes":[{"href":"https://s.example/p/9","x":10,"y":20,"w":100,"h":80}],'
        '"links":[{"href":"https://s.example/p/9","x":10,"y":120,"w":100,"h":20}]}',
        scale: 2,
      );
      expect((v.width, v.height, v.top, v.bottom, v.scrollY), (500, 400, 60, 500, 120));
      expect((v.boxes.single.left, v.boxes.single.top, v.boxes.single.width), (20, 40, 200));
      expect(v.links.single.top, 240);
      expect(readView('nonsense', scale: 2).isEmpty, isTrue);
      // Without a band, the whole view is clear.
      final whole = readView('{"w":500,"h":400}', scale: 1);
      expect((whole.top, whole.bottom), (0, 400));
    });
  });

  group('reading several screenfuls', () {
    const links = [
      ScreenBox('https://shop.example/c/shoes', left: 0, top: 0, width: 1000, height: 900),
      ScreenBox('https://shop.example/p/7', left: 10, top: 250, width: 300, height: 120),
    ];

    test('a probe takes the smallest link holding it', () {
      expect(linkAt(const [(50, 300)], links), 'https://shop.example/p/7');
      expect(linkAt(const [(500, 50)], links), 'https://shop.example/c/shoes');
      expect(linkAt(const [(5000, 50), (50, 300)], links), 'https://shop.example/p/7');
      expect(linkAt(const [(5000, 50)], links), isEmpty);
    });

    test('tiles without a picture link get the link under their text', () {
      final view = ScreenView(width: 1000, height: 900, top: 0, bottom: 900, scrollY: 0, links: links);
      final tiles = viewTiles(
        [line('Merino hiking socks', 20, 260), line('£12.99', 20, 300)],
        view,
        hint: 'GBP',
      );
      expect(tiles.single.href, 'https://shop.example/p/7');
    });

    test('the name is read over the price, past shop furniture', () {
      const box = ScreenBox('https://shop.example/p/5', left: 20, top: 0, width: 300, height: 200);
      final tiles = screenTiles(
        [
          line('+6 other colours/patterns', 20, 210),
          line('Sponsored', 20, 240),
          line('Waterproof trail runner', 20, 270),
          line('£39.99', 20, 310, height: 34),
          line('eligible order to UK or Ireland', 20, 350),
          line('Add to basket', 20, 380),
        ],
        const [box],
      );
      expect(tiles.single.title, 'Waterproof trail runner');
    });

    test('a tile whose name is cut off at the top of the band is not read', () {
      const box = ScreenBox('https://shop.example/p/6', left: 20, top: -200, width: 300, height: 200);
      final tiles = screenTiles(
        [
          line('£39.99', 20, 10, height: 34),
          line('100+ bought in past month', 20, 50),
          line('eligible order to UK or Ireland', 20, 80),
        ],
        const [box],
      );
      expect(tiles, isEmpty);
    });

    test('steps: past the header to the first picture, then by part of the band', () {
      const top = ScreenView(width: 1000, height: 600, top: 0, bottom: 600, scrollY: 0, next: 900);
      expect(screenStep(top), 892);
      expect(worthReading(top), isFalse, reason: 'pictures further down, none here');
      const covered = ScreenView(width: 1000, height: 600, top: 0, bottom: 300, scrollY: 0, next: 100);
      expect(screenStep(covered), 150, reason: 'half the band when a notice covers the rest');
      const full = ScreenView(
        width: 1000,
        height: 600,
        top: 0,
        bottom: 600,
        scrollY: 0,
        next: 100,
        boxes: [ScreenBox('https://shop.example/p/1', left: 0, top: 100, width: 200, height: 200)],
      );
      expect(screenStep(full), 340);
      expect(worthReading(full), isTrue);
      const plain = ScreenView(width: 1000, height: 600, top: 0, bottom: 600, scrollY: 0);
      expect(worthReading(plain), isTrue, reason: 'a page with no pictures is read by its text alone');
    });

    test('a product seen on two screenfuls is kept once', () {
      const a = ScreenTile(title: 'Trail shoe', price: '£54.50', href: 'https://shop.example/p/1');
      const b = ScreenTile(title: 'Trail shoe (cut)', price: '£54.50', href: 'https://shop.example/p/1');
      const c = ScreenTile(title: 'Hiking sock', price: '£9.99');
      const d = ScreenTile(title: 'Hiking sock', price: '£9.99');
      final merged = mergeTiles([
        [a, c],
        [b, d],
      ]);
      expect(merged.map((t) => t.title), ['Trail shoe (cut)', 'Hiking sock'], reason: 'the longer name wins');
    });

    test('a price far out of line with the rest is a misread', () {
      expect(plausiblePrices([3409, 2052, 1323, 8028100, 732], (p) => p), [3409, 2052, 1323, 732]);
      expect(plausiblePrices([3409, 8028100], (p) => p), [3409, 8028100], reason: 'too few to compare');
      expect(plausiblePrices([3409, 2052, 9], (p) => p), [3409, 2052]);
    });

    test('the scroll script only scrolls', () {
      final js = scrollByScript(512.4);
      expect(js, contains('scrollTo'));
      expect(js, contains('512'));
      expect(js, isNot(contains('.click(')));
      expect(viewScript, isNot(contains('.click(')));
      expect(viewScript, contains('getBoundingClientRect'));
    });

    test('the height of a PNG comes from its header', () {
      final png = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52, //
        0, 0, 5, 0, 0, 0, 2, 0x9C,
      ]);
      expect(pngHeight(png), 668);
      expect(pngHeight(Uint8List(10)), 0);
    });
  });

  group('the panel script', () {
    test('reads on change, and keeps away from sign-in, payment and check pages', () {
      expect(panelScript, contains('MutationObserver'));
      expect(panelScript, contains("callHandler('tiles'"));
      expect(panelScript, contains('isPrivate'));
      expect(panelScript, contains('bgn_verification'));
      expect(panelScript, isNot(contains('.click(')));
      expect(panelScript, isNot(contains('.submit(')));
    });
  });
}
