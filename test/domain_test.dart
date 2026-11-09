import 'package:chanda/domain/links.dart';
import 'package:chanda/domain/money.dart';
import 'package:chanda/domain/shops.dart';
import 'package:chanda/domain/watch.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  group('parsePrice', () {
    void reads(String text, int minor, String currency, {String? hint}) =>
        expect(parsePrice(text, hint: hint), (minor: minor, currency: currency), reason: text);

    test('reads prices written the common ways', () {
      reads('£1,234.56', 123456, 'GBP');
      reads('1.234,56 €', 123456, 'EUR');
      reads('US \$12.99', 1299, 'USD');
      reads('₹1,299', 129900, 'INR');
      reads('12,99 zł', 1299, 'PLN');
      reads('CHF 12.50', 1250, 'CHF');
      reads('1 234,5 €', 123450, 'EUR');
    });

    test('reads fullwidth signs and digits', () {
      reads('￡1.37', 137, 'GBP');
      reads('￥１，２８０', 1280, 'JPY', hint: 'JPY');
      reads('＄12.99', 1299, 'USD', hint: 'USD');
    });

    test('joins a price drawn in parts', () {
      reads('£8 . 42', 842, 'GBP');
      reads('12 ,99 €', 1299, 'EUR');
    });

    test('lets the page settle ambiguous marks', () {
      reads('¥1,280', 1280, 'JPY', hint: 'JPY');
      reads('¥1,280', 128000, 'CNY', hint: 'CNY');
      reads('\$5', 500, 'CAD', hint: 'CAD');
      reads('\$5', 500, 'USD', hint: 'GBP');
    });

    test('reads three digits after a lone separator as thousands', () {
      reads('1,280', 128000, 'GBP', hint: 'GBP');
      reads('£1.280', 128000, 'GBP');
    });

    test('gives nothing without a number or a currency', () {
      expect(parsePrice('Out of stock', hint: 'GBP'), isNull);
      expect(parsePrice('12.99'), isNull);
    });

    test('rounds a fraction finer than the minor unit', () {
      expect(parseAmount('1,280.5', scale: 0), 1281);
      expect(parseAmount('1,234.567'), 123457);
    });
  });

  group('links', () {
    test('Amazon links are cut to the product', () {
      final u = cleanLink(
        Uri.parse(
          'https://www.amazon.co.uk/OPULIZE-Classic/dp/B01KW9ZHU6/ref=sr_1_3?tag=someone-21&keywords=glasses&th=1',
        ),
      );
      expect('$u', 'https://www.amazon.co.uk/dp/B01KW9ZHU6');
    });

    test('tracking and affiliate parameters go; the rest stays', () {
      final u = cleanLink(
        Uri.parse('https://shop.example.com/item?id=7&colour=red&utm_source=x&gclid=1&aff_id=9&spm=a.b#reviews'),
      );
      expect(u.queryParameters, {'id': '7', 'colour': 'red'});
      expect(u.fragment, isEmpty);
    });

    test('the first link in shared text is found', () {
      expect(
        '${linkIn('Look at this! https://www.temu.com/uk/lamp-g-123.html.')}',
        'https://www.temu.com/uk/lamp-g-123.html',
      );
      expect(linkIn('no link here'), isNull);
    });

    test('payment and sign-in pages are private', () {
      expect(isPrivatePage(Uri.parse('https://www.paypal.com/checkoutnow')), isTrue);
      expect(isPrivatePage(Uri.parse('https://www.amazon.co.uk/ap/signin')), isTrue);
      expect(isPrivatePage(Uri.parse('https://www.shein.co.uk/checkout/')), isTrue);
      expect(isPrivatePage(Uri.parse('https://shop.example.com/my-account')), isTrue);
      expect(isPrivatePage(Uri.parse('https://www.amazon.co.uk/dp/B01KW9ZHU6')), isFalse);
      expect(isPrivatePage(Uri.parse('https://shop.example.com/paying-guide')), isFalse);
    });

    test('Google sign-in is recognised', () {
      expect(isGoogleSignIn(Uri.parse('https://accounts.google.com/o/oauth2/v2/auth')), isTrue);
      expect(isGoogleSignIn(Uri.parse('https://www.google.com/search')), isFalse);
    });
  });

  group('shops', () {
    test('catalogue shops are found by any of their domains', () {
      expect(shopFor(Uri.parse('https://m.shein.com/uk/x-p-123.html')).id, 'shein');
      expect(shopFor(Uri.parse('https://www.aliexpress.us/item/1005.html')).id, 'aliexpress');
      expect(
        shopFor(Uri.parse('https://www.amazon.co.uk/dp/B01KW9ZHU6')).keyOf(Uri.parse('/dp/B01KW9ZHU6')),
        'B01KW9ZHU6',
      );
    });

    test('another shop takes its currency and origin from its domain', () {
      final de = shopFor(Uri.parse('https://www.beispiel.de/p/1'));
      expect((de.id, de.currency, de.fromAbroad), ('beispiel.de', 'EUR', true));
      final uk = shopFor(Uri.parse('https://www.example.co.uk/p/1'));
      expect((uk.currency, uk.fromAbroad), ('GBP', false));
      expect(shopOf('beispiel.de').currency, 'EUR');
    });
  });

  group('landed cost', () {
    const fx = FxRates('GBP', '2026-11-06', {'USD': 1.25, 'JPY': 190.0});

    test('a UK price is what you pay', () {
      final l = landedCost(price: 4599, currency: 'GBP', home: 'GBP', fromAbroad: false, fx: null)!;
      expect((l.total, l.parts.length, l.estimate), (4599, 1, false));
    });

    test('low-value goods priced in pounds from abroad already carry VAT', () {
      final l = landedCost(price: 1000, shipping: 199, currency: 'GBP', home: 'GBP', fromAbroad: true, fx: fx)!;
      expect(l.total, 1199);
      expect(l.estimate, isFalse);
    });

    test('low-value goods priced abroad add UK VAT in case it was not charged', () {
      final l = landedCost(price: 2000, currency: 'USD', home: 'GBP', fromAbroad: true, fx: fx)!;
      expect(l.parts.first, ('Price', 1600));
      expect(l.total, 1600 + 320);
      expect(l.estimate, isTrue);
    });

    test('over £135, duty, import VAT and the handling fee are added', () {
      final l = landedCost(
        price: 20000,
        currency: 'GBP',
        home: 'GBP',
        fromAbroad: true,
        fx: fx,
        rules: const UkImportRules(dutyPercent: 10, handlingFee: 800),
      )!;
      expect(l.parts, [('Price', 20000), ('Customs duty', 2000), ('Import VAT', 4400), ('Handling fee', 800)]);
      expect(l.total, 27200);
    });

    test('a currency with no rate gives no total', () {
      expect(landedCost(price: 100, currency: 'XYZ', home: 'GBP', fromAbroad: true, fx: fx), isNull);
      expect(landedCost(price: 100, currency: 'USD', home: 'GBP', fromAbroad: true, fx: null), isNull);
    });

    test('rates convert between minor units of different sizes', () {
      expect(fx.toBase(1900, 'JPY'), 1000);
      expect(fx.toBase(1250, 'USD'), 1000);
      expect(fx.toBase(500, 'GBP'), 500);
      expect(FxRates.fromJson(fx.toJson())!.rates, fx.rates);
    });
  });

  group('alerts', () {
    test('a drop of at least the set share alerts; a small one does not', () async {
      final v = await memoryVault();
      final item = await saved(v, reading(price: 10000));
      expect(alertsFor(item, reading(price: 9400), before: 10000).map((a) => a.kind), ['drop']);
      expect(alertsFor(item, reading(price: 9600), before: 10000), isEmpty);
      expect(alertsFor(item, reading(price: 9600), before: 10000, dropPercent: 3).map((a) => a.kind), ['drop']);
      expect(alertsFor(item, reading(price: 10500), before: 10000), isEmpty);
    });

    test('reaching the target beats a plain drop, once', () async {
      final v = await memoryVault();
      final item = await saved(v, reading(price: 10000), target: 9000);
      expect(alertsFor(item, reading(price: 8900), before: 10000).map((a) => a.kind), ['target']);
      // Already under the target: no second target alert, only a real drop.
      expect(alertsFor(item, reading(price: 8800), before: 8900), isEmpty);
      expect(alertsFor(item, reading(price: 8000), before: 8900).map((a) => a.kind), ['drop']);
    });

    test('back in stock alerts; out of stock and other currencies do not', () async {
      final v = await memoryVault();
      final item = await saved(v, reading(price: 10000));
      expect(alertsFor(item, reading(price: 10000), before: 10000, beforeStock: false).map((a) => a.kind), ['stock']);
      expect(alertsFor(item, reading(price: 5000, inStock: false), before: 10000), isEmpty);
      expect(alertsFor(item, reading(price: 5000, currency: 'EUR'), before: 10000), isEmpty);
    });
  });

  group('when to check', () {
    final now = DateTime.utc(2026, 11, 9, 12);

    test('daily, or every 6 hours when watched closely, doubling after failures', () async {
      final v = await memoryVault();
      final item = await saved(v, reading());
      expect(checkEvery(item), const Duration(hours: 24));
      expect(checkEvery(item.copyWith(watchClose: true)), const Duration(hours: 6));
      expect(checkEvery(item.copyWith(failures: 1)), const Duration(hours: 48));
      expect(checkEvery(item.copyWith(failures: 9)), const Duration(days: 4));
    });

    test('due a day after the last check, give or take an hour', () async {
      final v = await memoryVault();
      final item = (await saved(v, reading())).copyWith(checked: Value(now.toIso8601String()));
      final next = nextCheck(item);
      expect(next.difference(now).inMinutes, inInclusiveRange(23 * 60, 25 * 60));
      expect(nextCheck(item), next, reason: 'the same every time');
      expect(isDue(item, now.add(const Duration(hours: 22)), present: false), isFalse);
      expect(isDue(item, now.add(const Duration(hours: 26)), present: false), isTrue);
      expect(isDue(item.copyWith(checked: const Value(null)), now, present: false), isTrue);
    });

    test('bought, gone and attended-only items wait', () async {
      final v = await memoryVault();
      final later = now.add(const Duration(days: 30));
      final amazon = await saved(v, reading());
      final shein = await saved(v, reading(url: 'https://www.shein.co.uk/Lamp-p-123.html'));
      expect(isDue(amazon.copyWith(bought: true), later, present: true), isFalse);
      expect(isDue(amazon.copyWith(status: 'gone'), later, present: true), isFalse);
      expect(isDue(amazon.copyWith(status: 'needs-you'), later, present: false), isFalse);
      expect(isDue(shein, later, present: false), isFalse);
      expect(isDue(shein, later, present: true), isTrue);
    });

    test('ages read plainly', () {
      String at(Duration d) => now.subtract(d).toIso8601String();
      expect(ago(at(const Duration(seconds: 20)), now), 'just now');
      expect(ago(at(const Duration(minutes: 5)), now), '5 min ago');
      expect(ago(at(const Duration(hours: 3)), now), '3 h ago');
      expect(ago(at(const Duration(days: 1, hours: 2)), now), '1 day ago');
      expect(ago(null, now), 'never');
      expect(freshness(at(const Duration(hours: 25)), now), Freshness.fresh);
      expect(freshness(at(const Duration(hours: 30)), now), Freshness.stale);
    });
  });
}
