import 'package:chanda/app/modules.dart';
import 'package:chanda/db/database.dart';
import 'package:chanda/domain/checker.dart';
import 'package:chanda/domain/reading.dart';
import 'package:chanda/ui/save_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
