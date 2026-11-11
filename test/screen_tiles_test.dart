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

    test('picture boxes and probes are read from the page scripts\' answers', () {
      final r = readBoxes(
        '{"w":500,"h":400,"boxes":[{"href":"https://s.example/p/9","x":10,"y":20,"w":100,"h":80}]}',
        scale: 2,
      );
      expect((r.width, r.height), (500, 400));
      expect((r.boxes.single.left, r.boxes.single.top, r.boxes.single.width), (20, 40, 200));
      expect(readBoxes('nonsense', scale: 2).boxes, isEmpty);
      expect(linkProbeScript(const [(10.0, 20.0)]), contains('elementsFromPoint'));
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
