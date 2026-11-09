import 'dart:io';

import 'package:chanda/domain/reading.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chromium.dart';

/// Runs the in-page evidence script over a made-up product page in headless
/// Chromium, as the in-app browser runs it over a shop's page.
void main() {
  test(
    'the evidence script reads drawn prices and picks the product picture',
    () async {
      final tmp = await Directory.systemTemp.createTemp('chanda_evidence');
      addTearDown(() => tmp.delete(recursive: true));
      String svg(int w, int h) =>
          '<svg xmlns="http://www.w3.org/2000/svg" width="$w" height="$h"><rect width="$w" height="$h"/></svg>';
      File('${tmp.path}/product.svg').writeAsStringSync(svg(600, 600));
      File('${tmp.path}/banner.svg').writeAsStringSync(svg(1600, 200));
      File('${tmp.path}/icon.svg').writeAsStringSync(svg(64, 64));
      final page = File('${tmp.path}/page.html')
        ..writeAsStringSync('''<!doctype html><meta charset="utf-8"><title>Brass desk lamp | Example</title>
<body style="margin:0;font-family:sans-serif">
<img src="banner.svg" width="1600" height="200">
<img src="icon.svg" width="64" height="64">
<div style="display:flex;gap:24px">
  <img src="product.svg" width="420" height="420">
  <div>
    <h1>Brass desk lamp with dimmer</h1>
    <span style="font-size:32px;font-weight:700">£45.99</span>
    <s style="font-size:14px">£59.99</s>
    <p>In stock. Free delivery.</p>
  </div>
</div>
<pre id="out"></pre>
<script>addEventListener('load', () => { document.getElementById('out').textContent = $evidenceScript; });</script>
</body>''');
      // Served over HTTP: the script keeps only web pictures.
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((req) async {
        final f = File('${tmp.path}${req.uri.path}');
        if (f.existsSync()) {
          req.response.headers.contentType = f.path.endsWith('.svg')
              ? ContentType('image', 'svg+xml')
              : ContentType.html;
          await req.response.addStream(f.openRead());
        } else {
          req.response.statusCode = HttpStatus.notFound;
        }
        await req.response.close();
      });
      final url = Uri.parse('http://127.0.0.1:${server.port}/page.html');
      final e = Evidence.fromJson(await dumpOut(chromium!, tmp, page, url: url));
      expect(e.h1, 'Brass desk lamp with dimmer');
      expect(e.images, isNotEmpty);
      expect(e.images.first, endsWith('product.svg'));
      expect(e.images.where((i) => i.endsWith('icon.svg') || i.endsWith('banner.svg')), isEmpty);
      final r = readProduct(e, hint: 'GBP');
      expect((r.price, r.was, r.currency), (4599, 5999, 'GBP'));
    },
    timeout: const Timeout(Duration(seconds: 90)),
    skip: chromium == null ? 'Chromium is not installed' : null,
  );
}
