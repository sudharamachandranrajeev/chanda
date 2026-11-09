// Starts Chanda with a demo vault, for screenshots and trying the screens
// without saving real products. Run it against a scratch data folder:
//
//   XDG_DATA_HOME=/tmp/chanda-demo flutter run -d linux -t tool/demo_main.dart
//
// DEMO_IMAGES may name a folder of pictures (0.png, 1.png, …), one per item.
import 'dart:io';
import 'dart:math';

import 'package:brahma_core/brahma_core.dart';
import 'package:chanda/app/app.dart';
import 'package:chanda/app/providers.dart';
import 'package:chanda/app/session.dart';
import 'package:chanda/app/settings_page.dart';
import 'package:chanda/db/database.dart';
import 'package:chanda/domain/images.dart';
import 'package:chanda/domain/reading.dart';
import 'package:chanda/domain/vault.dart';
import 'package:chanda/domain/watch.dart';
import 'package:chanda/ui/alerts_page.dart';
import 'package:chanda/ui/browser_page.dart';
import 'package:chanda/ui/item_page.dart';
import 'package:chanda/ui/shops_page.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _demo = [
  // title, shop link, price now (pence), price history step, was, stock, tags
  ('Linen relaxed shirt, sage', 'https://www.amazon.co.uk/dp/B0DEMO0001', 2499, 300, 3299, true, 'summer'),
  ('Round blue-light glasses', 'https://www.aliexpress.com/item/1005000000001.html', 899, 150, null, true, 'desk'),
  (
    'Pleated midi skirt, black',
    'https://www.shein.co.uk/Pleated-Midi-Skirt-p-1000001.html',
    1650,
    0,
    null,
    true,
    'summer',
  ),
  ('Brass desk lamp with dimmer', 'https://www.amazon.co.uk/dp/B0DEMO0002', 4599, -400, null, true, 'desk,gift'),
  (
    'Ceramic pour-over coffee set',
    'https://www.temu.com/uk/pour-over-set-g-6010000001.html',
    1299,
    200,
    1899,
    false,
    'gift',
  ),
  (
    'Wool-blend overcoat, camel',
    'https://www.aliexpress.com/item/1005000000002.html',
    14900,
    1200,
    null,
    true,
    'winter',
  ),
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = await AppSession.open(KeyVault(const DeviceSecretStore(), chandaIdentity));
  final v = session.vault;
  if ((await v.items()).isEmpty) await _seed(session, v);
  // Straight to the screens: no first-run questions or tour.
  for (final k in ['onboarding.sync', 'tour.offered']) {
    await session.db.setLocalSetting(k, nowIso());
  }
  // DEMO_PAGE opens one screen on its own: item, alerts, shops, settings, or
  // browse (DEMO_URL in the in-app browser).
  final first = (await v.items()).firstWhere((i) => i.title.startsWith('Brass'));
  final Widget? page = switch (Platform.environment['DEMO_PAGE']) {
    'item' => ItemPage(first.id),
    'alerts' => const AlertsPage(),
    'shops' => const ShopsPage(),
    'settings' => const SettingsPage(),
    // Reads a real product page in the in-app browser and offers to save it.
    'browse' => BrowserPage(
      url: Uri.parse(Platform.environment['DEMO_URL']!),
      saveOnLoad: Platform.environment['DEMO_SAVE'] != '0',
    ),
    _ => null,
  };
  runApp(
    ProviderScope(
      overrides: chandaOverrides(session, theme: Platform.environment['DEMO_THEME'] ?? 'lagoon'),
      child: page == null ? const ChandaApp() : ChandaApp(home: page),
    ),
  );
}

Future<void> _seed(AppSession s, Vault v) async {
  final wish = await v.addList('Wishlist');
  final home = await v.addList('Home office');
  final rnd = Random(7);
  final now = DateTime.now().toUtc();
  for (final (n, (title, url, price, step, was, stock, tags)) in _demo.indexed) {
    final id = await v.saveReading(
      Reading(
        url: url,
        title: title,
        currency: 'GBP',
        price: price + step,
        was: was,
        layer: 'json-ld',
        rating: 4.1 + n / 10,
        reviews: 120 + 37 * n,
      ),
      listId: tags.contains('desk') ? home : wish,
      tags: tags,
      target: n == 1 ? 900 : null,
    );
    // Back-date the first point and add a few checks since.
    final db = s.db;
    final points = await v.history(id);
    final first = points.first;
    await s.store.save(db.chandaPrices, first.copyWith(seen: nowIso(now.subtract(const Duration(days: 30)))), first.id);
    var p = price + step;
    for (var d = 24; d >= 0; d -= 6) {
      p = d == 0 ? price : p + (rnd.nextInt(5) - 2) * 50;
      final pid = newId();
      await s.store.save(
        db.chandaPrices,
        ChandaPricesCompanion.insert(
          id: pid,
          itemId: id,
          price: p,
          currency: 'GBP',
          seen: nowIso(now.subtract(Duration(days: d, hours: 1))),
        ),
        pid,
      );
    }
    final item = (await v.item(id))!;
    await v.updateItem(
      item.copyWith(
        price: Value(price),
        inStock: stock,
        checked: Value(nowIso(now.subtract(Duration(hours: 2 + n)))),
        status: n == 4 ? 'needs-you' : 'ok',
      ),
    );
    if (n == 0) await v.addAlert(id, Alert('drop', before: price + step, after: price, currency: 'GBP'));
    if (n == 1) await v.addAlert(id, Alert('target', before: price + step, after: price, currency: 'GBP'));
    final pics = Platform.environment['DEMO_IMAGES'];
    if (pics != null && File('$pics/$n.png').existsSync()) {
      final dir = await imageDir(id);
      await dir.create(recursive: true);
      await File('$pics/$n.png').copy('${dir.path}/0');
    }
  }
}
