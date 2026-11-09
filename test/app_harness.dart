import 'package:brahma_core/brahma_core.dart';
import 'package:chanda/app/app.dart';
import 'package:chanda/app/providers.dart';
import 'package:chanda/app/session.dart';
import 'package:chanda/domain/offers.dart';
import 'package:chanda/domain/query.dart';
import 'package:chanda/domain/reading.dart';
import 'package:chanda/domain/shop_search.dart';
import 'package:chanda/domain/shops.dart';
import 'package:chanda/domain/vault.dart';
import 'package:chanda/domain/web_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support.dart';

/// The whole app over a fresh in-memory vault, for widget tests. Shop pages
/// are never loaded: price checks read [pages].
class AppHarness {
  AppHarness(this.tester);
  final WidgetTester tester;
  late AppSession session;

  Vault get vault => session.vault;

  /// Opens the database; [seed] runs before the app starts.
  Future<void> open({Future<void> Function(Vault v)? seed}) async {
    await tester.runAsync(() async {
      final store = await Store.open(memoryDatabase());
      session = AppSession(KeyVault(MemorySecretStore(), chandaIdentity), store, Vault(store));
      // A fresh install asks about sync and offers the tour first; tests of
      // the app itself skip both.
      await session.db.setLocalSetting('onboarding.sync', 'done');
      await session.db.setLocalSetting('tour.offered', 'yes');
      await seed?.call(session.vault);
    });
  }

  /// [offers]: what each shop's search lists, by shop id (others list
  /// nothing).
  Future<void> run({
    Map<String, Evidence> pages = const {},
    Map<String, List<Offer>> offers = const {},
    http.Client? ai,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...chandaOverrides(session),
          readerProvider.overrideWithValue(TablePageReader(pages)),
          searcherProvider.overrideWithValue(TableSearcher(offers)),
          if (ai != null) aiClientProvider.overrideWithValue(ai),
        ],
        retry: (_, _) => null,
        child: const ChandaApp(),
      ),
    );
    await settle();
  }

  Future<void> close() async {
    // Disposing the scope stops the check and sync timers.
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => session.db.close());
  }

  /// Lets database work (real I/O) and animations finish.
  Future<void> settle() async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> tap(Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle();
  }

  Future<void> tapText(String text) => tap(find.text(text).last);

  /// Goes to a top-level page through the rail (desktop) or the dock
  /// (phone).
  Future<void> go(String page) async {
    final rail = find.descendant(of: find.byType(NavigationRail), matching: find.text(page));
    if (rail.evaluate().isNotEmpty) return tap(rail);
    await tap(
      find.descendant(of: find.byWidgetPredicate((w) => '${w.runtimeType}' == '_Dock'), matching: find.byTooltip(page)),
    );
  }

  void desktop() => _size(const Size(1400, 900));

  void phone() => _size(const Size(390, 844));

  void _size(Size s) {
    tester.view.physicalSize = s;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
}

/// Product pages from a table instead of the web.
class TablePageReader implements PageReader {
  const TablePageReader(this.pages);
  final Map<String, Evidence> pages;

  @override
  Future<Evidence> read(Uri url) async => pages['$url'] ?? (throw StateError('No page for $url'));
}

/// Shop searches from a table instead of the web.
class TableSearcher implements ShopSearcher {
  const TableSearcher(this.offers);
  final Map<String, List<Offer>> offers;

  @override
  bool get available => true;

  @override
  Future<List<Offer>> search(Shop shop, Query q) async => offers[shop.id] ?? const [];
}

/// A small vault: two lists, a dropped price and a target reached.
Future<void> seedVault(Vault v) async {
  final wish = await v.defaultList();
  final office = await v.addList('Home office');
  final lamp = await v.saveReading(
    reading(url: 'https://www.amazon.co.uk/dp/B000000001', title: 'Brass desk lamp', price: 4599),
    listId: office,
    tags: 'desk',
  );
  await v.recordCheck((await v.item(lamp))!, reading(price: 3999), const []);
  await v.saveReading(
    reading(url: 'https://www.aliexpress.com/item/1005.html', title: 'Round blue-light glasses', price: 899),
    listId: wish,
    target: 900,
  );
  await v.saveReading(
    reading(url: 'https://www.shein.co.uk/Skirt-p-123.html', title: 'Pleated midi skirt', price: 1650),
    listId: wish,
  );
}
