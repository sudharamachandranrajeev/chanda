import 'dart:convert';
import 'dart:io';

import 'package:chanda/domain/reading.dart';
import 'package:chanda/domain/shops.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chromium.dart';

/// Replays the reader over real product pages saved from the test shops,
/// offline in headless Chromium: each must read the price, currency and
/// title it showed live (kept beside it in `<name>.json`). The pages are the
/// shops' own and stay on this machine (test/live_pages is not committed),
/// so this runs only where pages were saved. Pages without a .json file
/// print what they read, to check by eye and record.
void main() {
  final dir = Directory('test/live_pages');
  final pages = dir.existsSync()
      ? (dir.listSync().whereType<File>().where((f) => f.path.endsWith('.html')).toList()
          ..sort((a, b) => a.path.compareTo(b.path)))
      : const <File>[];

  for (final page in pages) {
    final name = page.uri.pathSegments.last.replaceAll('.html', '');
    test(
      'saved page $name reads as it did live',
      () async {
        final tmp = await Directory.systemTemp.createTemp('chanda_replay');
        addTearDown(() => tmp.delete(recursive: true));
        // No outside scripts: the page is replayed as it was drawn.
        final html = page
            .readAsStringSync()
            .replaceFirst(RegExp('^<!doctype html>', caseSensitive: false), '')
            .replaceAll(RegExp(r'<script[^>]*\bsrc=[^>]*>\s*</script>', caseSensitive: false), '');
        final at = html.lastIndexOf('</body>');
        final replay = File('${tmp.path}/page.html')
          ..writeAsStringSync(
            '<!doctype html><meta charset="utf-8">${at < 0 ? html : html.substring(0, at)}'
            '<pre id="out"></pre><script>document.getElementById("out").textContent = $evidenceScript;</script>'
            '</body></html>',
          );
        final shop = shopById(name.split('.').first);
        // The replay is a local file; read it as if it were at its shop, so
        // the shop's name comes off titles as it does live.
        final dumped = jsonDecode(await dumpOut(chromium!, tmp, replay)) as Map;
        if (shop != null) dumped['url'] = shop.home;
        final evidence = Evidence.fromJson(dumped);
        final r = readProduct(evidence, hint: shop?.currency ?? 'GBP');
        final got = {
          'title': r.title,
          'price': r.price,
          'currency': r.currency,
          'was': r.was,
          'layer': r.layer,
          'confidence': r.confidence,
          'inStock': r.inStock,
          'images': r.images.length,
          'variant': r.variant,
          'rating': r.rating,
          'reviews': r.reviews,
          'seller': r.seller,
          'brand': r.brand,
          'warnings': r.warnings,
          'prices': [for (final p in evidence.prices.take(5)) '${p.text} ${p.size} ${p.struck} ${p.score}'],
        };
        final expected = File(page.path.replaceAll('.html', '.json'));
        if (!expected.existsSync()) {
          // ignore: avoid_print
          print('$name: ${const JsonEncoder.withIndent('  ').convert(got)}');
          return;
        }
        final want = jsonDecode(expected.readAsStringSync()) as Map;
        expect(r.price, want['price'], reason: 'price');
        expect(r.currency, want['currency'], reason: 'currency');
        expect(r.title, want['title'], reason: 'title');
      },
      timeout: const Timeout(Duration(seconds: 120)),
      skip: chromium == null ? 'Chromium is not installed' : null,
    );
  }
}
