import 'package:chanda/db/database.dart';
import 'package:chanda/domain/checker.dart';
import 'package:chanda/domain/frame_size.dart';
import 'package:chanda/domain/html_evidence.dart';
import 'package:chanda/domain/reading.dart';
import 'package:chanda/domain/size_chart.dart';
import 'package:chanda/domain/vault.dart';
import 'package:chanda/domain/watch.dart';
import 'package:chanda/domain/web_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

const _url = 'https://www.example.co.uk/p/lamp';

String _page({String head = '', String body = ''}) =>
    '<!doctype html><html><head><title>Brass lamp | Example Shop</title>$head</head><body>$body</body></html>';

/// Serves a fixed list of evidence, one per load, and counts the loads.
class _FakeReader implements PageReader {
  _FakeReader(this.pages);
  final List<Object> pages;
  var loads = 0;

  @override
  Future<Evidence> read(Uri url) async {
    final p = pages[loads.clamp(0, pages.length - 1)];
    loads++;
    if (p is Exception) throw p;
    return p as Evidence;
  }
}

class _FakeSender implements AlertSender {
  final sent = <List<AlertEvent>>[];

  @override
  Future<void> send(VaultItem item, List<AlertEvent> alerts) async => sent.add(alerts);
}

Evidence _priced(
  int pounds, {
  bool inStock = true,
  String url = 'https://www.amazon.co.uk/dp/B000000001',
}) => Evidence(
  url: url,
  h1: 'Desk lamp',
  ld: [
    '{"@type":"Product","name":"Desk lamp","offers":{"@type":"Offer","price":"$pounds.00",'
        '"priceCurrency":"GBP","availability":"https://schema.org/${inStock ? 'InStock' : 'OutOfStock'}"}}',
  ],
);

void main() {
  group('reading a product page', () {
    test('structured product data gives price, stock and details', () {
      final r = readProduct(
        htmlEvidence(
          _page(
            head:
                '<script type="application/ld+json">{"@context":"https://schema.org","@type":"Product",'
                '"name":"Brass desk lamp","brand":{"@type":"Brand","name":"Lumen"},"gtin13":"5012345678900",'
                '"image":["https://img.example.co.uk/1.jpg"],'
                '"aggregateRating":{"ratingValue":"4.4","reviewCount":"231"},'
                '"offers":{"@type":"Offer","price":"45.99","priceCurrency":"GBP",'
                '"availability":"https://schema.org/InStock"}}</script>',
            body: '<h1>Brass desk lamp</h1>',
          ),
          _url,
        ),
        hint: 'GBP',
      );
      expect((r.title, r.price, r.currency, r.inStock), ('Brass desk lamp', 4599, 'GBP', true));
      expect((r.brand, r.gtin, r.rating, r.reviews), ('Lumen', '5012345678900', 4.4, 231));
      expect(r.images, ['https://img.example.co.uk/1.jpg']);
      expect(r.usable, isTrue);
    });

    test('out of stock is read from the offer', () {
      expect(readProduct(_priced(20, inStock: false), hint: 'GBP').inStock, isFalse);
    });

    test('shop meta tags are read when there is no structured data', () {
      final r = readProduct(
        htmlEvidence(
          _page(
            head:
                '<meta property="og:title" content="Brass desk lamp">'
                '<meta property="product:price:amount" content="24.50">'
                '<meta property="product:price:currency" content="EUR">',
          ),
          'https://www.beispiel.de/p/lampe',
        ),
        hint: 'EUR',
      );
      expect((r.title, r.price, r.currency), ('Brass desk lamp', 2450, 'EUR'));
    });

    test('the drawn price wins over a struck-out one, which becomes "was"', () {
      final r = readProduct(
        const Evidence(
          url: _url,
          h1: 'Brass desk lamp',
          prices: [
            PriceSeen('£18.99', size: 14, struck: true, score: 5),
            PriceSeen('£12.99', size: 28, score: 10),
          ],
        ),
        hint: 'GBP',
      );
      expect((r.price, r.was), (1299, 1899));
    });

    test('a check page is never read as a price', () {
      final r = readProduct(const Evidence(url: _url, check: true), hint: 'GBP');
      expect(r.check, isTrue);
      expect(r.usable, isFalse);
    });

    test('the shop name comes off the title', () {
      final r = readProduct(htmlEvidence(_page(), _url), hint: 'GBP');
      expect(r.title, 'Brass lamp');
    });
  });

  group('vault', () {
    test('saving the same product twice updates one item', () async {
      final v = await memoryVault();
      final list = await v.defaultList();
      final a = await v.saveReading(
        reading(url: 'https://www.amazon.co.uk/x/dp/B000000001?tag=x-21'),
        listId: list,
      );
      final b = await v.saveReading(
        reading(url: 'https://www.amazon.co.uk/dp/B000000001', price: 3999),
        listId: list,
      );
      expect(b, a);
      expect((await v.items()).single.price, 3999);
      expect((await v.item(a))!.url, 'https://www.amazon.co.uk/dp/B000000001');
      expect((await v.history(a)).map((p) => p.price), [4599, 3999]);
    });

    test('a typed price is kept as the user\'s own', () async {
      final v = await memoryVault();
      final item = await saved(v, reading(price: null));
      expect(item.checked, isNull);
      await v.setManualPrice(item, 1250);
      final now = (await v.item(item.id))!;
      expect((now.price, now.layer, now.status), (1250, 'typed', 'ok'));
      expect((await v.history(item.id)).single.source, 'manual');
    });

    test('lists hold items; removing a list removes its items', () async {
      final v = await memoryVault();
      final office = await v.addList('Home office');
      await v.saveReading(reading(), listId: office);
      expect((await v.lists()).map((l) => l.name), contains('Home office'));
      await v.removeList(office);
      expect(await v.items(), isEmpty);
    });

    test('removing an item forgets its frame size and size chart on this device', () async {
      final v = await memoryVault();
      final a = await saved(v, reading());
      final b = await saved(v, reading(url: 'https://www.amazon.co.uk/dp/B000000002', title: 'Other lamp'));
      for (final id in [a.id, b.id]) {
        await v.db.setLocalSetting(frameSetting(id), '{}');
        await v.db.setLocalSetting(sizeChartSetting(id), 'none');
      }
      await v.removeItem(a.id);
      expect(await v.db.localSetting(frameSetting(a.id)), isNull);
      expect(await v.db.localSetting(sizeChartSetting(a.id)), isNull);
      expect(await v.db.localSetting(frameSetting(b.id)), '{}');
      expect(await v.db.localSetting(sizeChartSetting(b.id)), 'none');
    });

    test('failures count towards the back-off; a good check resets them', () async {
      final v = await memoryVault();
      var item = await saved(v, reading());
      await v.recordTrouble(item, 'failed');
      item = (await v.item(item.id))!;
      expect((item.status, item.failures), ('failed', 1));
      await v.recordCheck(item, reading(price: 4000), const []);
      item = (await v.item(item.id))!;
      expect((item.status, item.failures, item.price), ('ok', 0, 4000));
      expect((await v.previousPrices())[item.id], 4599);
    });

    test('alerts are stored and marked seen', () async {
      final v = await memoryVault();
      final item = await saved(v, reading());
      await v.addAlert(item.id, const Alert('drop', before: 4599, after: 3999, currency: 'GBP'));
      expect((await v.alerts()).single.seen, isFalse);
      await v.markAlertsSeen();
      expect((await v.alerts()).single.seen, isTrue);
    });

    test('the alert threshold is a preference', () async {
      final v = await memoryVault();
      expect(await v.dropPercent(), 5);
      await v.setPref(dropPercentPref, '10');
      expect(await v.dropPercent(), 10);
    });
  });

  group('checker', () {
    Checker checker(Vault v, PageReader r, AlertSender s, {bool present = false}) =>
        Checker(v, reader: r, notifier: s, present: present, gap: Duration.zero, confirmAfter: Duration.zero);

    test('a confirmed drop alerts once, after two reads agree', () async {
      final v = await memoryVault();
      final item = await saved(v, reading(price: 5000));
      final reader = _FakeReader([_priced(40)]);
      final sender = _FakeSender();
      expect(await checker(v, reader, sender).check(item), CheckResult.alerted);
      expect(reader.loads, 2);
      expect(sender.sent.single.single.kind, 'drop');
      expect((await v.item(item.id))!.price, 4000);
    });

    test('a drop the second read does not show is kept quiet', () async {
      final v = await memoryVault();
      final item = await saved(v, reading(price: 5000));
      final sender = _FakeSender();
      final result = await checker(v, _FakeReader([_priced(40), _priced(50)]), sender).check(item);
      expect(result, CheckResult.ok);
      expect(sender.sent, isEmpty);
      expect((await v.item(item.id))!.price, 5000);
    });

    test('a check page needs the user; a missing page is gone', () async {
      final v = await memoryVault();
      final item = await saved(v, reading());
      final s = _FakeSender();
      expect(
        await checker(v, _FakeReader([const Evidence(url: _url, check: true)]), s).check(item),
        CheckResult.needsYou,
      );
      expect((await v.item(item.id))!.status, 'needs-you');
      expect(await checker(v, _FakeReader([const PageGone()]), s).check(item), CheckResult.gone);
      expect(await checker(v, _FakeReader([Exception('offline')]), s).check(item), CheckResult.failed);
      expect((await v.item(item.id))!.failures, 1);
    });

    test('a run skips the rest of a shop once it shows a check page', () async {
      final v = await memoryVault();
      await saved(v, reading(price: null, url: 'https://www.amazon.co.uk/dp/B000000001'));
      await saved(v, reading(price: null, url: 'https://www.amazon.co.uk/dp/B000000002'));
      final reader = _FakeReader([const Evidence(url: _url, check: true)]);
      final report = await checker(v, reader, _FakeSender()).run();
      expect(reader.loads, 1);
      expect(report.results.values, unorderedEquals([CheckResult.needsYou, CheckResult.skipped]));
    });
  });
}
