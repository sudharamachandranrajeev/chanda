import 'dart:convert';

import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart';

import '../db/database.dart';
import 'frame_size.dart';
import 'links.dart';
import 'reading.dart';
import 'shops.dart';
import 'size_chart.dart';
import 'watch.dart';

/// Synced preference keys.
const homeCurrencyPref = 'chanda.currency';
const dropPercentPref = 'chanda.dropPercent';
const ntfyPref = 'chanda.ntfy';
const dutyPref = 'chanda.dutyPercent';
const handlingPref = 'chanda.handlingFee';

/// Device-only settings.
const themeSetting = 'chanda.theme';
const fxSetting = 'chanda.fx';
const backgroundSetting = 'chanda.background';
const notifySetting = 'chanda.notify';

/// How the vault is sorted.
enum VaultSort { added, priceLow, priceHigh, drop, title }

String nowIso([DateTime? t]) => (t ?? DateTime.now()).toUtc().toIso8601String();

/// Chanda's write path and the reads screens share.
class Vault {
  Vault(this.store);
  final Store store;

  AppDatabase get db => store.db as AppDatabase;

  // ---- lists ----

  Future<List<VaultList>> lists() =>
      (db.select(db.chandaLists)
            ..where((t) => t.deleted.not())
            ..orderBy([(t) => OrderingTerm.asc(t.ord), (t) => OrderingTerm.asc(t.created)]))
          .get();

  Future<String> addList(String name) async {
    final all = await lists();
    final id = newId();
    await store.save(
      db.chandaLists,
      ChandaListsCompanion.insert(id: id, name: name.trim(), created: nowIso(), ord: Value(all.length)),
      id,
    );
    return id;
  }

  Future<void> renameList(VaultList l, String name) =>
      store.save(db.chandaLists, l.copyWith(name: name.trim()), l.id);

  /// Deletes a list and every item in it.
  Future<void> removeList(String id) async {
    for (final i in await items(listId: id)) {
      await removeItem(i.id);
    }
    await store.remove(db.chandaLists, id);
  }

  /// The list to save into when none is chosen: the first, made on demand.
  Future<String> defaultList() async => (await lists()).firstOrNull?.id ?? await addList('Wishlist');

  // ---- items ----

  Future<List<VaultItem>> items({String? listId, bool includeBought = true}) =>
      (db.select(db.chandaItems)..where(
            (t) =>
                t.deleted.not() &
                (listId == null ? const Constant(true) : t.listId.equals(listId)) &
                (includeBought ? const Constant(true) : t.bought.not()),
          ))
          .get();

  Future<VaultItem?> item(String id) =>
      (db.select(db.chandaItems)..where((t) => t.id.equals(id) & t.deleted.not())).getSingleOrNull();

  /// An item already saved from the same product page, so saving twice
  /// updates rather than duplicates.
  Future<VaultItem?> findSaved(String shop, String url, String productKey) async {
    final all = await (db.select(db.chandaItems)..where((t) => t.deleted.not() & t.shop.equals(shop))).get();
    return all
        .where((i) => (productKey.isNotEmpty && i.productKey == productKey) || i.url == url)
        .firstOrNull;
  }

  /// Saves what Chanda read on a product page into [listId], keeping the
  /// first price as the start of its history. [variant] and [note] are the
  /// user's own; they win over what the page showed.
  Future<String> saveReading(
    Reading r, {
    required String listId,
    Map<String, String>? variant,
    String note = '',
    int? target,
    String tags = '',
  }) async {
    final url = cleanLink(Uri.parse(r.url));
    final shop = shopFor(url);
    final key = shop.keyOf(url);
    final existing = await findSaved(shop.id, '$url', key);
    final id = existing?.id ?? newId();
    final now = nowIso();
    final row = ChandaItemsCompanion(
      id: Value(id),
      listId: Value(listId),
      title: Value(r.title),
      brand: Value(r.brand),
      shop: Value(shop.id),
      url: Value('$url'),
      productKey: Value(key),
      variant: Value(jsonEncode(variant ?? r.variant)),
      note: Value(note),
      tags: Value(tags),
      images: Value(jsonEncode(r.images)),
      description: Value(r.description),
      seller: Value(r.seller),
      gtin: Value(r.gtin),
      mpn: Value(r.mpn),
      rating: Value(r.rating),
      reviews: Value(r.reviews),
      warranty: Value(r.warranty),
      currency: Value(r.currency),
      price: Value(r.price),
      was: Value(r.was),
      shipping: Value(r.shipping),
      inStock: Value(r.inStock),
      target: Value(target ?? existing?.target),
      added: Value(existing?.added ?? now),
      checked: Value(r.price == null ? null : now),
      status: const Value('ok'),
      failures: const Value(0),
      layer: Value(r.layer),
    );
    await store.save(db.chandaItems, row, id);
    if (r.price != null) await _addPoint(id, r, source: 'save');
    return id;
  }

  Future<void> updateItem(VaultItem i) => store.save(db.chandaItems, i, i.id);

  /// Removes an item, and what this device kept about it on the side (its
  /// frame size and size chart).
  Future<void> removeItem(String id) async {
    await store.remove(db.chandaItems, id);
    for (final key in [frameSetting(id), sizeChartSetting(id)]) {
      await db.customStatement('DELETE FROM local_settings WHERE key = ?', [key]);
    }
  }

  Future<void> moveItem(VaultItem i, String listId) => updateItem(i.copyWith(listId: listId));

  /// Sets the user's own price for an item they read off the page
  /// themselves (when nothing could be read).
  Future<void> setManualPrice(VaultItem i, int price) async {
    await updateItem(i.copyWith(price: Value(price), checked: Value(nowIso()), status: 'ok', layer: 'typed'));
    final id = newId();
    await store.save(
      db.chandaPrices,
      ChandaPricesCompanion.insert(
        id: id,
        itemId: i.id,
        price: price,
        currency: i.currency,
        seen: nowIso(),
        layer: const Value('typed'),
        source: const Value('manual'),
      ),
      id,
    );
  }

  // ---- prices ----

  /// An item's price history, oldest first.
  Future<List<PricePoint>> history(String itemId) =>
      (db.select(db.chandaPrices)
            ..where((t) => t.itemId.equals(itemId) & t.deleted.not())
            ..orderBy([(t) => OrderingTerm.asc(t.seen)]))
          .get();

  /// The price before the latest one for every item, for "down 12%" badges.
  Future<Map<String, int>> previousPrices() async {
    final rows = await db
        .customSelect(
          'SELECT item_id, price FROM ('
          ' SELECT item_id, price, ROW_NUMBER() OVER (PARTITION BY item_id ORDER BY seen DESC) AS n'
          ' FROM chanda_prices WHERE deleted = 0'
          ') WHERE n = 2',
          readsFrom: {db.chandaPrices},
        )
        .get();
    return {for (final r in rows) r.read<String>('item_id'): r.read<int>('price')};
  }

  Future<void> _addPoint(String itemId, Reading r, {required String source}) async {
    final id = newId();
    await store.save(
      db.chandaPrices,
      ChandaPricesCompanion.insert(
        id: id,
        itemId: itemId,
        price: r.price!,
        currency: r.currency,
        was: Value(r.was),
        shipping: Value(r.shipping),
        inStock: Value(r.inStock),
        seen: nowIso(),
        layer: Value(r.layer),
        source: Value(source),
      ),
      id,
    );
  }

  /// Records a confirmed check of [i]: the new price, a history point when
  /// something changed (or once a day so the chart has a line), and the
  /// alerts it raised. Returns the stored alerts.
  Future<List<AlertEvent>> recordCheck(VaultItem i, Reading r, List<Alert> alerts) async {
    final now = DateTime.now().toUtc();
    final last = (await history(i.id)).lastOrNull;
    final changed =
        last == null || last.price != r.price || last.inStock != r.inStock || last.currency != r.currency;
    final old = last == null ? null : DateTime.tryParse(last.seen);
    final daily = old == null || now.difference(old) >= const Duration(hours: 20);
    await updateItem(
      i.copyWith(
        price: Value(r.price),
        was: Value(r.was),
        shipping: Value(r.shipping ?? i.shipping),
        inStock: r.inStock,
        currency: r.currency,
        rating: Value(r.rating ?? i.rating),
        reviews: Value(r.reviews ?? i.reviews),
        seller: r.seller.isEmpty ? i.seller : r.seller,
        checked: Value(nowIso(now)),
        status: 'ok',
        failures: 0,
        layer: r.layer,
      ),
    );
    if (changed || daily) await _addPoint(i.id, r, source: 'check');
    final out = <AlertEvent>[];
    for (final a in alerts) {
      out.add(await addAlert(i.id, a));
    }
    return out;
  }

  /// Notes a check that could not read a price: [status] needs-you, gone or
  /// failed. A failure counts towards the back-off ([checkEvery]).
  Future<void> recordTrouble(VaultItem i, String status) => updateItem(
    i.copyWith(
      checked: Value(nowIso()),
      status: status,
      failures: status == 'failed' ? i.failures + 1 : i.failures,
    ),
  );

  // ---- alerts ----

  Future<AlertEvent> addAlert(String itemId, Alert a) async {
    final id = newId();
    final row = ChandaAlertsCompanion.insert(
      id: id,
      itemId: itemId,
      kind: a.kind,
      before: Value(a.before),
      after: Value(a.after),
      currency: Value(a.currency),
      at: nowIso(),
    );
    await store.save(db.chandaAlerts, row, id);
    return (await (db.select(db.chandaAlerts)..where((t) => t.id.equals(id))).getSingle());
  }

  Future<List<AlertEvent>> alerts() =>
      (db.select(db.chandaAlerts)
            ..where((t) => t.deleted.not())
            ..orderBy([(t) => OrderingTerm.desc(t.at)])
            ..limit(200))
          .get();

  Future<void> markAlertsSeen() async {
    for (final a in await alerts()) {
      if (!a.seen) await store.save(db.chandaAlerts, a.copyWith(seen: true), a.id);
    }
  }

  // ---- prefs ----

  Future<String?> pref(String key) async => (await (db.select(
    db.prefs,
  )..where((t) => t.id.equals(key) & t.deleted.not())).getSingleOrNull())?.value;

  Future<void> setPref(String key, String value) =>
      store.save(db.prefs, PrefsCompanion.insert(id: key, value: value), key);

  Future<String> homeCurrency() async => await pref(homeCurrencyPref) ?? 'GBP';

  Future<double> dropPercent() async => double.tryParse(await pref(dropPercentPref) ?? '') ?? 5;
}

/// The user's chosen options of an item.
Map<String, String> variantOf(VaultItem i) {
  try {
    return {for (final e in (jsonDecode(i.variant) as Map).entries) '${e.key}': '${e.value}'};
  } on Object {
    return const {};
  }
}

List<String> imagesOf(VaultItem i) {
  try {
    return [for (final s in jsonDecode(i.images) as List) '$s'];
  } on Object {
    return const [];
  }
}

List<String> tagsOf(VaultItem i) => [
  for (final t in i.tags.split(','))
    if (t.trim().isNotEmpty) t.trim(),
];

/// Sorts [items] for the vault, given each item's previous price.
List<VaultItem> sorted(List<VaultItem> items, VaultSort sort, Map<String, int> previous) {
  double drop(VaultItem i) {
    final p = previous[i.id], now = i.price;
    return p == null || now == null || p == 0 ? 0 : (p - now) / p;
  }

  final out = [...items];
  int byPrice(VaultItem a, VaultItem b) => (a.price ?? 1 << 40).compareTo(b.price ?? 1 << 40);
  out.sort(switch (sort) {
    VaultSort.added => (a, b) => b.added.compareTo(a.added),
    VaultSort.priceLow => byPrice,
    VaultSort.priceHigh => (a, b) => (b.price ?? -1).compareTo(a.price ?? -1),
    VaultSort.drop => (a, b) => drop(b).compareTo(drop(a)),
    VaultSort.title => (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
  });
  // Bought things sink to the bottom.
  return [...out.where((i) => !i.bought), ...out.where((i) => i.bought)];
}
