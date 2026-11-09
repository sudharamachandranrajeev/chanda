import 'dart:convert';

import 'package:chanda/app/modules.dart';
import 'package:chanda/db/database.dart';
import 'package:chanda/domain/ai_reader.dart';
import 'package:chanda/domain/checker.dart';
import 'package:chanda/domain/local_search.dart';
import 'package:chanda/domain/offers.dart';
import 'package:chanda/domain/reading.dart';
import 'package:chanda/ui/save_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'app_harness.dart';
import 'support.dart';

/// Smoke tests: every page builds, empty and with data, on desktop and
/// phone widths, without throwing or overflowing; and the main flows.
void main() {
  integration();
  final pages = [for (final d in allDestinations) d.label];

  testWidgets('every page builds on a desktop window, empty and with data', (tester) async {
    for (final seeded in [false, true]) {
      final app = AppHarness(tester)..desktop();
      await app.open(seed: seeded ? seedVault : null);
      await app.run();
      for (final label in pages) {
        await app.go(label);
        expect(tester.takeException(), isNull, reason: '$label (seeded: $seeded)');
      }
      await app.close();
    }
  });

  testWidgets('every page builds on a phone', (tester) async {
    final app = AppHarness(tester)..phone();
    await app.open(seed: seedVault);
    await app.run();
    for (final label in pages) {
      await app.go(label);
      expect(tester.takeException(), isNull, reason: label);
    }
    await app.close();
  });

  testWidgets('the vault shows saved items, filters by list and opens one', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open(seed: seedVault);
    await app.run();
    expect(find.text('Brass desk lamp'), findsOneWidget);
    expect(find.text('Pleated midi skirt'), findsOneWidget);
    expect(find.text('£39.99'), findsOneWidget);

    await app.tapText('Home office');
    expect(find.text('Pleated midi skirt'), findsNothing);
    expect(find.text('Brass desk lamp'), findsOneWidget);

    await app.tapText('Brass desk lamp');
    expect(find.text('Price history'), findsOneWidget);
    expect(find.textContaining('Buy at Amazon UK'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('a product read from a page is saved to the vault', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run();
    final context = tester.element(find.byType(Scaffold).first);
    showSaveSheet(
      context,
      reading(url: 'https://www.temu.com/uk/lamp-g-601.html', title: 'Ceramic pour-over set', price: 1299),
    );
    await app.settle();
    expect(find.text('Save from Temu'), findsOneWidget);
    await app.tapText('Save to vault');
    final items = (await tester.runAsync(app.vault.items))!;
    expect(items.single.title, 'Ceramic pour-over set');
    expect(items.single.price, 1299);
    expect(find.text('Ceramic pour-over set'), findsOneWidget);
    await app.close();
  });

  testWidgets('Read with AI fills the price for the user to confirm, with their own key', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open(seed: (v) => v.store.db.setLocalSetting(aiKeySetting, 'sk-ant-test-0123456789abcdefghij'));
    String? key;
    await app.run(
      ai: MockClient((req) async {
        key = req.headers['x-api-key'];
        return http.Response(
          jsonEncode({
            'stop_reason': 'end_turn',
            'content': [
              {
                'type': 'text',
                'text': jsonEncode({'title': 'Linen shirt', 'price': '£24.99', 'currency': 'GBP', 'in_stock': true}),
              },
            ],
          }),
          200,
        );
      }),
    );
    final context = tester.element(find.byType(Scaffold).first);
    showSaveSheet(
      context,
      const Reading(url: 'https://www.hacoo.com/p/1', title: 'Linen shirt', currency: 'GBP', text: 'Linen shirt £24.99'),
    );
    await app.settle();
    expect(find.text('No price found'), findsOneWidget);
    await app.tapText('Read with AI');
    expect(key, 'sk-ant-test-0123456789abcdefghij');
    expect(find.textContaining('please confirm'), findsOneWidget);
    await app.tapText('Save to vault');
    expect((await tester.runAsync(app.vault.items))!.single.price, 2499);
    await app.close();
  });

  testWidgets('Settings offers smarter search and AI reading, both off at first', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run();
    await app.go('Settings');
    await tester.scrollUntilVisible(find.text('Smarter search'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Download ('), findsOneWidget);
    expect(find.text('Add key'), findsOneWidget);
    await app.close();
  });

  testWidgets('"Check now" reads the page again and records the new price', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open(seed: seedVault);
    await app.run(
      pages: {
        'https://www.amazon.co.uk/dp/B000000001': const Evidence(
          url: 'https://www.amazon.co.uk/dp/B000000001',
          h1: 'Brass desk lamp',
          ld: [
            '{"@type":"Product","name":"Brass desk lamp","offers":{"price":"41.00","priceCurrency":"GBP",'
                '"availability":"https://schema.org/InStock"}}',
          ],
        ),
      },
    );
    await app.tapText('Brass desk lamp');
    await app.tapText('Check now');
    await app.settle();
    final lamp = (await tester.runAsync(app.vault.items))!.firstWhere((i) => i.title == 'Brass desk lamp');
    expect(lamp.price, 4100);
    expect(find.text('£41.00'), findsWidgets);
    await app.close();
  });

  testWidgets('a search finds the vault item and the shops\' offers, with chips to tap off', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open(seed: seedVault);
    await app.run(
      offers: {
        'amazon-uk': const [
          Offer(shop: 'amazon-uk', url: 'https://www.amazon.co.uk/dp/B0LAMP0001', title: 'Brass desk lamp, LED', price: 2999, currency: 'GBP', rating: 4.6, reviews: 120),
          Offer(shop: 'amazon-uk', url: 'https://www.amazon.co.uk/dp/B0LAMP0002', title: 'Marble desk lamp', price: 8999, currency: 'GBP'),
        ],
      },
    );
    await app.go('Search');
    await tester.enterText(find.byType(TextField).first, 'desk lamp under £50');
    await app.tap(find.widgetWithText(FilledButton, 'Search'));
    await app.settle();
    expect(find.text('Under £50.00'), findsOneWidget);
    expect(find.text('In your vault'), findsOneWidget);
    expect(find.text('Brass desk lamp'), findsOneWidget);
    expect(find.text('Brass desk lamp, LED'), findsOneWidget);
    expect(find.text('Marble desk lamp'), findsNothing, reason: 'over budget');
    expect(find.text('Search Shein'), findsOneWidget, reason: 'walled shops open in the browser');

    // Tapping the budget off widens it.
    await app.tap(find.byTooltip('Remove'));
    await app.settle();
    expect(find.text('Marble desk lamp'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('an item finds itself at other shops; a likely match is confirmed and becomes the best deal', (
    tester,
  ) async {
    final app = AppHarness(tester)..desktop();
    await app.open(seed: seedVault);
    await app.run(
      offers: {
        'aliexpress': const [
          Offer(shop: 'aliexpress', url: 'https://www.aliexpress.com/item/2001.html', title: 'Brass desk lamp with switch', price: 1999, currency: 'GBP'),
          Offer(shop: 'aliexpress', url: 'https://www.aliexpress.com/item/2002.html', title: 'Oak bookshelf', price: 999, currency: 'GBP'),
        ],
      },
    );
    await app.tapText('Brass desk lamp');
    await app.tapText('Find');
    await app.settle();
    expect(find.text('Same product? AliExpress'), findsOneWidget);
    expect(find.text('Oak bookshelf'), findsNothing);
    await app.tapText('Yes');
    await app.settle();
    expect(find.text('Best deal'), findsOneWidget);
    expect(find.textContaining('less delivered than the next'), findsOneWidget);
    final item = (await tester.runAsync(app.vault.items))!.firstWhere((i) => i.title == 'Brass desk lamp');
    final answers = (await tester.runAsync(() => LocalSearch(app.session.store).matchesFor(item.id)))!;
    expect(answers, {'https://www.aliexpress.com/item/2001.html': 'same'});
    expect(tester.takeException(), isNull);
    await app.close();
  });
}

/// Cross-feature: a drop found by the checker reaches the vault card and the
/// Alerts page, and the sender is told once.
void integration() {
  testWidgets('a confirmed drop shows on the vault card and in Alerts', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open(seed: seedVault);
    final sent = <int>[];
    await tester.runAsync(() async {
      final item = (await app.vault.items()).firstWhere((i) => i.title == 'Pleated midi skirt');
      const url = 'https://www.shein.co.uk/Skirt-p-123.html';
      final checker = Checker(
        app.vault,
        reader: const TablePageReader({
          url: Evidence(
            url: url,
            h1: 'Pleated midi skirt',
            ld: [
              '{"@type":"Product","name":"Pleated midi skirt","offers":{"price":"12.00","priceCurrency":"GBP",'
                  '"availability":"https://schema.org/InStock"}}',
            ],
          ),
        }),
        notifier: _Count(sent),
        present: true,
        gap: Duration.zero,
        confirmAfter: Duration.zero,
      );
      expect(await checker.check(item), CheckResult.alerted);
    });
    expect(sent, [1]);
    await app.run();
    expect(find.text('£12.00'), findsOneWidget);
    expect(find.textContaining('−27%'), findsOneWidget);
    await app.go('Alerts');
    expect(find.text('Pleated midi skirt'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await app.close();
  });
}

class _Count implements AlertSender {
  _Count(this.sent);
  final List<int> sent;

  @override
  Future<void> send(VaultItem item, List<AlertEvent> alerts) async => sent.add(alerts.length);
}
