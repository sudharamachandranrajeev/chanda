import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:chanda/app/app.dart';
import 'package:chanda/app/modules.dart';
import 'package:chanda/app/providers.dart';
import 'package:chanda/db/database.dart';
import 'package:chanda/domain/ai_reader.dart';
import 'package:chanda/domain/checker.dart';
import 'package:chanda/domain/local_search.dart';
import 'package:chanda/domain/offers.dart';
import 'package:chanda/domain/pictures.dart';
import 'package:chanda/domain/reading.dart';
import 'package:chanda/domain/similar_shops.dart';
import 'package:chanda/domain/taste_store.dart';
import 'package:chanda/ui/photo_search.dart';
import 'package:chanda/ui/save_flow.dart';
import 'package:chanda/ui/vault_page.dart' show ItemCard;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;

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
    Finder card(String title) => find.descendant(of: find.byType(ItemCard), matching: find.text(title));
    expect(card('Brass desk lamp'), findsOneWidget);
    expect(card('Pleated midi skirt'), findsOneWidget);
    expect(find.text('£39.99'), findsOneWidget);

    await app.tapText('Home office');
    expect(find.text('Rate a few?'), findsNothing, reason: 'only on the whole vault');
    expect(find.text('Pleated midi skirt'), findsNothing);
    expect(card('Brass desk lamp'), findsOneWidget);

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

  testWidgets("a garment named only by the shop's category is tagged so it can be tried on", (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run();
    final context = tester.element(find.byType(Scaffold).first);
    showSaveSheet(
      context,
      const Reading(
        url: 'https://www.shop.example/p/ridley',
        title: 'The Ridley 32',
        price: 4000,
        currency: 'GBP',
        category: 'Men > Clothing > Jeans',
      ),
    );
    await app.settle();
    // The tag shows in the sheet, where the user can remove it.
    expect(find.widgetWithText(TextField, 'jeans'), findsOneWidget);
    await app.tapText('Save to vault');
    expect((await tester.runAsync(app.vault.items))!.single.tags, 'jeans');
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
                'text': jsonEncode({
                  'title': 'Linen shirt',
                  'price': '£24.99',
                  'currency': 'GBP',
                  'in_stock': true,
                }),
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
      const Reading(
        url: 'https://www.hacoo.com/p/1',
        title: 'Linen shirt',
        currency: 'GBP',
        text: 'Linen shirt £24.99',
      ),
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

  testWidgets('Settings offers both models, taste, AI reading and AI try-on, all off at first', (
    tester,
  ) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run();
    await app.go('Settings');
    await tester.scrollUntilVisible(
      find.text('Smarter search'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Download (252 MB)'), findsOneWidget);
    expect(find.text('Download (94 MB)'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('AI reading'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Your taste'), findsOneWidget);
    expect(find.text('0 ratings so far'), findsOneWidget);
    // AI try-on: off, a key for each service, Gemini's paid switch off.
    await tester.scrollUntilVisible(
      find.text('My Gemini key is on a paid plan'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('AI try-on'), findsOneWidget);
    expect(find.text('Add key'), findsNWidgets(4));
    // eBay search: off until the user adds their own keys, which stay on this device.
    await tester.scrollUntilVisible(find.text('eBay search'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Add keys'), findsOneWidget);
    expect(find.text('No keys'), findsOneWidget);
    expect(find.text('No key'), findsNWidgets(3));
    expect(
      tester
          .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'My Gemini key is on a paid plan'))
          .value,
      isFalse,
    );
    await app.close();
  });

  testWidgets('rating: the rate card, stars on an item, and For you with Not for me', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open(
      seed: (v) async {
        await seedVault(v);
        await LocalSearch(v.store).keepOffers(const [
          Offer(
            shop: 'amazon-uk',
            url: 'https://www.amazon.co.uk/dp/B0LAMP0009',
            title: 'Brass floor lamp',
            price: 7999,
            currency: 'GBP',
          ),
          Offer(
            shop: 'amazon-uk',
            url: 'https://www.amazon.co.uk/dp/B0SKIRT009',
            title: 'Pleated maxi skirt',
            price: 3500,
            currency: 'GBP',
          ),
        ], 'lamp');
      },
    );
    await app.run();
    final taste = TasteStore(app.session.store);

    await app.waitFor(find.text('Rate a few?'));
    expect(find.text('Rate a few?'), findsOneWidget);
    await app.tap(find.byTooltip('5: Love it').first);
    expect(await tester.runAsync(() async => (await taste.ratings()).length), 1);
    await app.tapText('Not now');
    expect(find.text('Rate a few?'), findsNothing);

    await app.tapText('Brass desk lamp');
    expect(find.text('Your rating'), findsOneWidget);
    await app.tap(find.byTooltip('4: Like it').first);
    final lamp = await tester.runAsync(() => taste.ratingOf('https://www.amazon.co.uk/dp/B000000001'));
    expect(lamp?.stars, 4);
    await tester.pageBack();
    await app.settle();

    await app.go('Search');
    await app.waitFor(find.text('For you'));
    expect(find.text('For you'), findsOneWidget);
    expect(find.text('Brass floor lamp'), findsOneWidget);
    await app.tap(find.byTooltip('Why this, and less like it').first);
    await app.tapText('Not for me');
    final rs = await tester.runAsync(() => taste.ratings());
    expect(rs!.where((r) => r.source == 'not-for-me'), hasLength(1));
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('search by photo names what it shows and searches the shops for it', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open(seed: seedVault);
    final labels = await tester.runAsync(loadLabels);
    final glasses = labels!.firstWhere((l) => l.name == 'glasses').vec;
    await app.run(extra: [pictureEmbedderProvider.overrideWith((_) => _OnePicture(glasses))]);
    final nav = Navigator.of(tester.element(find.byType(ChandaHome)));
    unawaited(nav.push(MaterialPageRoute<void>(builder: (_) => PhotoSearchPage(_png))));
    await app.waitFor(find.text('It looks like'));
    expect(find.text('It looks like'), findsOneWidget);
    expect(find.text('glasses'), findsOneWidget);
    await app.tap(find.textContaining('Search the shops for'));
    await app.settle();
    expect(find.text('Search'), findsWidgets);
    expect(find.textContaining('glasses'), findsWidgets);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets(
    'Shops like yours: check a shop, add it to search, remove it; add any shop by one results page',
    (tester) async {
      final app = AppHarness(tester)..desktop();
      await app.open(seed: seedVault);
      await app.run(
        offers: {
          'shop.example': const [
            Offer(
              shop: 'shop.example',
              url: 'https://www.shop.example/p/1',
              title: 'Walnut desk lamp',
              price: 3500,
              currency: 'GBP',
            ),
          ],
        },
        extra: [
          shopFactsProvider.overrideWith(
            (ref, home) async => ShopFacts(
              domain: registrableDomain(Uri.parse(home).host),
              registered: 2001,
              registryChecked: true,
              secure: true,
              pageRead: true,
              company: 'Example Retail Ltd',
              search: '${home}search?q={q}',
            ),
          ),
        ],
      );
      await app.go('Shops');
      await app.waitFor(find.text('Shops like yours'));
      final first = find.byWidgetPredicate((w) => w is ListTile && '${w.key}'.contains('similar-')).first;
      final name = ((tester.widget<ListTile>(first).title! as Text).data)!;

      await app.tap(find.descendant(of: first, matching: find.byTooltip('Check this shop')));
      await app.waitFor(find.text('2001'));
      expect(find.text('Example Retail Ltd'), findsOneWidget);
      expect(find.text('Read what buyers say'), findsOneWidget);
      await app.tapText('Close');

      await app.tap(find.descendant(of: first, matching: find.byTooltip('Add to my search')));
      await app.waitFor(find.text('You added it'));
      expect(find.byTooltip('Stop searching $name'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(ListTile), matching: find.text(name)),
        findsNothing,
        reason: 'no longer suggested',
      );
      await app.tap(find.byTooltip('Stop searching $name'));
      expect(find.text('You added it'), findsNothing);

      await app.tapText('Add a shop to search');
      await tester.enterText(
        find.byType(TextField).at(0),
        'https://www.shop.example/search?q=desk+lamp&sort=new',
      );
      await tester.enterText(find.byType(TextField).at(1), 'chair');
      await app.tap(find.widgetWithText(FilledButton, 'Add'));
      expect(find.textContaining('Those words are not in that address'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(1), 'Desk lamp');
      await app.tap(find.widgetWithText(FilledButton, 'Add'));
      await app.waitFor(find.byTooltip('Stop searching Shop'));

      await app.go('Search');
      await tester.enterText(find.byType(TextField).first, 'desk lamp');
      await app.tap(find.widgetWithText(FilledButton, 'Search'));
      await app.waitFor(find.text('Walnut desk lamp'));
      expect(find.text('Walnut desk lamp'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await app.close();
    },
  );

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
          Offer(
            shop: 'amazon-uk',
            url: 'https://www.amazon.co.uk/dp/B0LAMP0001',
            title: 'Brass desk lamp, LED',
            price: 2999,
            currency: 'GBP',
            rating: 4.6,
            reviews: 120,
          ),
          Offer(
            shop: 'amazon-uk',
            url: 'https://www.amazon.co.uk/dp/B0LAMP0002',
            title: 'Marble desk lamp',
            price: 8999,
            currency: 'GBP',
          ),
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
    expect(
      find.text('Shops that need you'),
      findsOneWidget,
      reason: 'walled shops get live panels in Search',
    );
    expect(find.text('Shein'), findsOneWidget);
    expect(find.text('Temu'), findsOneWidget);
    expect(find.text('Live page of Shein'), findsOneWidget);
    expect(find.text('Live page of Temu'), findsNothing, reason: 'one panel alive at a time');
    expect(find.text('Add these results'), findsNothing);
    expect(find.text('Hacoo'), findsNothing, reason: 'Hacoo has no web search');

    // Tapping the budget off widens it.
    await app.tap(find.byTooltip('Remove'));
    await app.settle();
    expect(find.text('Marble desk lamp'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets(
    'a panel\'s products join the results, say how they were read, and the shop is tried hidden next',
    (tester) async {
      final app = AppHarness(tester)..desktop();
      await app.open();
      await app.run(
        offers: {
          'amazon-uk': const [
            Offer(
              shop: 'amazon-uk',
              url: 'https://www.amazon.co.uk/dp/B0LAMP0001',
              title: 'Brass desk lamp, LED',
              price: 2999,
              currency: 'GBP',
            ),
          ],
        },
      );
      await app.go('Search');
      await tester.enterText(find.byType(TextField).first, 'brass desk lamp');
      await app.tap(find.widgetWithText(FilledButton, 'Search'));
      await app.settle();
      expect(find.text('Brass desk lamp from the panel'), findsNothing);
      final container = ProviderScope.containerOf(tester.element(find.byType(ChandaApp)));
      expect(container.read(shopPassesProvider).tryHidden('shein'), isFalse);

      await app.tapText('Pass Shein');
      expect(find.text('Brass desk lamp from the panel'), findsOneWidget);
      expect(find.text('Brass desk lamp, LED'), findsOneWidget);
      expect(find.textContaining('Read from screen'), findsOneWidget);
      expect(find.text('Shein · 1'), findsWidgets);
      expect(container.read(shopPassesProvider).tryHidden('shein'), isTrue);

      // Another tab: the first panel stays for a minute, the second shows.
      await app.tapText('Temu');
      expect(find.text('Live page of Temu'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await app.close();
    },
  );

  testWidgets('a result card says why it matched', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run(
      offers: {
        'amazon-uk': const [
          Offer(
            shop: 'amazon-uk',
            url: 'https://www.amazon.co.uk/dp/B0SHOE0001',
            title: 'Trail walking shoes, slip on',
            price: 4999,
            currency: 'GBP',
          ),
          Offer(
            shop: 'amazon-uk',
            url: 'https://www.amazon.co.uk/dp/B0SHOE0002',
            title: 'Walking shoes',
            price: 3999,
            currency: 'GBP',
          ),
        ],
      },
    );
    await app.go('Search');
    await tester.enterText(find.byType(TextField).first, 'walking shoes for all terrains, easy slip in');
    await app.tap(find.widgetWithText(FilledButton, 'Search'));
    await app.settle();
    expect(find.text('All-terrain'), findsOneWidget, reason: 'a chip for what was asked');
    expect(find.text('Slip-on'), findsOneWidget);
    expect(find.text('Trail walking shoes, slip on'), findsOneWidget);
    expect(find.text('Walking shoes'), findsOneWidget, reason: 'the old two-thirds rule dropped these');
    expect(find.textContaining('Matches: All-terrain, Slip-on'), findsOneWidget);
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
          Offer(
            shop: 'aliexpress',
            url: 'https://www.aliexpress.com/item/2001.html',
            title: 'Brass desk lamp with switch',
            price: 1999,
            currency: 'GBP',
          ),
          Offer(
            shop: 'aliexpress',
            url: 'https://www.aliexpress.com/item/2002.html',
            title: 'Oak bookshelf',
            price: 999,
            currency: 'GBP',
          ),
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

/// A 1×1 picture.
final _png = Uint8List.fromList(img.encodePng(img.Image(width: 1, height: 1)));

/// Sees the same thing in every picture.
class _OnePicture implements PictureEmbedder {
  const _OnePicture(this.v);
  final Float32List v;
  @override
  Future<List<Float32List?>> embed(List<Uint8List> pictures) async => [for (final _ in pictures) v];
}
