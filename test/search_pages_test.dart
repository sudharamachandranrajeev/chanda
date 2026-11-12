import 'dart:io';

import 'package:chanda/domain/offers.dart';
import 'package:chanda/domain/query.dart';
import 'package:chanda/domain/shops.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chromium.dart';

/// Replays the offer reader over real search pages saved from the test
/// shops (test/live_pages/search, not committed: the shops' own pages), in
/// headless Chromium. Each must give a page of priced, linked products that
/// match the search they were saved for ("reading glasses").
void main() {
  test(
    'a made-up results page: adverts skipped, screen-reader words and invisible characters dropped',
    () async {
      final tmp = await Directory.systemTemp.createTemp('chanda_search');
      addTearDown(() => tmp.delete(recursive: true));
      String tile(String name, String price, {String href = '', String label = ''}) =>
          '<li class="product-card"><a href="${href.isEmpty ? '/p/${name.hashCode.abs()}' : href}">'
          '<img alt="$name" src="data:image/gif;base64,R0lGODlhAQABAAAAACw="><h3>$name</h3></a>$label'
          '<span class="vp-price-amount"><span class="sr-only">Current price</span> $price</span></li>';
      final replay = File('${tmp.path}/page.html')
        ..writeAsStringSync(
          '<!doctype html><meta charset="utf-8"><base href="https://shop.example/">'
          '<div class="promo-box"><a href="/deal">Deal of the day</a><b>£5.00</b></div>'
          '<ul>${tile('Trail walking shoe\u200b one', '£79.99')}${tile('Hiking shoe two', '£49.99')}'
          '${tile('Slip-on walker three', '£39.99')}'
          '${tile('Paid placement', '£9.99', href: 'https://shop.example/sspa/click?x=1')}'
          '${tile('Labelled advert', '£19.99', label: '<span>Sponsored</span>')}</ul>'
          '<pre id="out"></pre><script>document.getElementById("out").textContent = $offerScript;</script>',
        );
      final shop = shopFor(Uri.parse('https://shop.example/'));
      final offers = parseOffers(shop, await dumpOut(chromium!, tmp, replay));
      expect(offers.map((o) => (o.title, o.price)), [
        ('Trail walking shoe one', 7999),
        ('Hiking shoe two', 4999),
        ('Slip-on walker three', 3999),
      ]);
    },
    timeout: const Timeout(Duration(seconds: 120)),
    skip: chromium == null ? 'Chromium is not installed' : null,
  );

  final dir = Directory('test/live_pages/search');
  final pages = dir.existsSync()
      ? (dir.listSync().whereType<File>().where((f) => f.path.endsWith('.html')).toList()
          ..sort((a, b) => a.path.compareTo(b.path)))
      : const <File>[];

  for (final page in pages) {
    final name = page.uri.pathSegments.last.replaceAll('.html', '');
    test(
      'saved search page $name lists its products',
      () async {
        final tmp = await Directory.systemTemp.createTemp('chanda_search');
        addTearDown(() => tmp.delete(recursive: true));
        final html = page
            .readAsStringSync()
            .replaceFirst(RegExp('^<!doctype html>', caseSensitive: false), '')
            .replaceAll(RegExp(r'<script[^>]*\bsrc=[^>]*>\s*</script>', caseSensitive: false), '');
        final at = html.lastIndexOf('</body>');
        final shop = shopById(name)!;
        final replay = File('${tmp.path}/page.html')
          ..writeAsStringSync(
            '<!doctype html><meta charset="utf-8"><base href="${shop.home}">'
            '${at < 0 ? html : html.substring(0, at)}'
            '<pre id="out"></pre><script>document.getElementById("out").textContent = $offerScript;</script>'
            '</body></html>',
          );
        final offers = parseOffers(shop, await dumpOut(chromium!, tmp, replay));
        final ranked = rankOffers(readQuery('reading glasses'), offers);
        // ignore: avoid_print
        print(
          '$name: ${offers.length} offers, ${ranked.length} match\n${[for (final o in ranked.take(6)) '  ${o.price} ${o.currency} was ${o.was} ★${o.rating} (${o.reviews}) ${o.title.length > 60 ? o.title.substring(0, 60) : o.title}\n    ${o.url}'].join('\n')}',
        );
        expect(ranked.length, greaterThanOrEqualTo(8));
        expect(ranked.every((o) => o.currency == 'GBP'), isTrue);
        expect(ranked.every((o) => Uri.parse(o.url).host.endsWith(shop.domains.first)), isTrue);
      },
      timeout: const Timeout(Duration(seconds: 120)),
      skip: chromium == null ? 'Chromium is not installed' : null,
    );
  }
}
