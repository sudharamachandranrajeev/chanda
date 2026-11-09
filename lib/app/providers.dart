import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../db/database.dart';
import '../domain/checker.dart';
import '../domain/images.dart';
import '../domain/money.dart';
import '../domain/notify.dart';
import '../domain/shops.dart';
import '../domain/vault.dart';
import '../domain/web_reader.dart';
import '../ui/hints.dart';
import '../ui/look.dart';
import 'session.dart';

/// The open session; main() overrides this before the first frame.
final sessionProvider = Provider<AppSession>((ref) => throw StateError('No session'));

/// What main() and the tests override: the session, under both its Chanda
/// and its shared type, the app's identity and hints, and the theme read
/// at start-up (so the first frame is already in it).
List<Override> chandaOverrides(AppSession session, {String theme = defaultTheme}) => [
  sessionProvider.overrideWithValue(session),
  coreSessionProvider.overrideWithValue(session),
  appIdentityProvider.overrideWithValue(chandaIdentity),
  hintTextsProvider.overrideWithValue({...coreHints, ...chandaHints}),
  sentinelChecksProvider.overrideWithValue([...coreChecks, lockCheck]),
  initialThemeProvider.overrideWithValue(theme),
];

extension Mutate on WidgetRef {
  /// Runs a write, refreshes the screens and queues a sync.
  Future<T> mutate<T>(Future<T> Function(Vault v) write) async {
    final result = await write(read(sessionProvider).vault);
    changed();
    return result;
  }
}

// ---- look ----

final initialThemeProvider = Provider<String>((_) => defaultTheme);

/// The theme on this device (not synced: each screen suits its own).
class ThemeChoice extends Notifier<String> {
  @override
  String build() => ref.watch(initialThemeProvider);

  Future<void> set(String choice) async {
    state = choice;
    await ref.read(sessionProvider).db.setLocalSetting(themeSetting, choice);
  }
}

final themeProvider = NotifierProvider<ThemeChoice, String>(ThemeChoice.new);

// ---- the vault ----

final listsProvider = FutureProvider<List<VaultList>>((ref) {
  ref.watch(revisionProvider);
  return ref.watch(sessionProvider).vault.lists();
});

final allItemsProvider = FutureProvider<List<VaultItem>>((ref) {
  ref.watch(revisionProvider);
  return ref.watch(sessionProvider).vault.items();
});

final itemProvider = FutureProvider.family<VaultItem?, String>((ref, id) {
  ref.watch(revisionProvider);
  return ref.watch(sessionProvider).vault.item(id);
});

final historyProvider = FutureProvider.family<List<PricePoint>, String>((ref, id) {
  ref.watch(revisionProvider);
  return ref.watch(sessionProvider).vault.history(id);
});

final previousPricesProvider = FutureProvider<Map<String, int>>((ref) {
  ref.watch(revisionProvider);
  return ref.watch(sessionProvider).vault.previousPrices();
});

final alertsProvider = FutureProvider<List<AlertEvent>>((ref) {
  ref.watch(revisionProvider);
  return ref.watch(sessionProvider).vault.alerts();
});

final unseenAlertsProvider = Provider<int>(
  (ref) => (ref.watch(alertsProvider).value ?? const []).where((a) => !a.seen).length,
);

/// The kept copy of an item's picture, if there is one.
final keptImageProvider = FutureProvider.family<File?, (String, int)>((ref, k) => keptImage(k.$1, k.$2));

/// What the vault shows: one list (null = all), the order, a tag and
/// the words typed in its search box.
class VaultView {
  const VaultView({this.listId, this.sort = VaultSort.added, this.tag, this.query = ''});
  final String? listId;
  final VaultSort sort;
  final String? tag;
  final String query;

  VaultView copyWith({String? Function()? listId, VaultSort? sort, String? Function()? tag, String? query}) =>
      VaultView(
        listId: listId == null ? this.listId : listId(),
        sort: sort ?? this.sort,
        tag: tag == null ? this.tag : tag(),
        query: query ?? this.query,
      );
}

class VaultViewState extends Notifier<VaultView> {
  @override
  VaultView build() => const VaultView();
  void set(VaultView v) => state = v;
}

final vaultViewProvider = NotifierProvider<VaultViewState, VaultView>(VaultViewState.new);

/// The items on the vault screen, filtered and sorted.
final shownItemsProvider = FutureProvider<List<VaultItem>>((ref) async {
  final all = await ref.watch(allItemsProvider.future);
  final previous = await ref.watch(previousPricesProvider.future);
  final v = ref.watch(vaultViewProvider);
  final words = v.query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  bool matches(VaultItem i) {
    if (v.listId != null && i.listId != v.listId) return false;
    if (v.tag != null && !tagsOf(i).contains(v.tag)) return false;
    final hay = '${i.title} ${i.brand} ${i.shop} ${i.tags} ${i.note}'.toLowerCase();
    return words.every(hay.contains);
  }

  return sorted(all.where(matches).toList(), v.sort, previous);
});

/// Every tag in use, most used first.
final tagsProvider = Provider<List<String>>((ref) {
  final counts = <String, int>{};
  for (final i in ref.watch(allItemsProvider).value ?? const <VaultItem>[]) {
    for (final t in tagsOf(i)) {
      counts[t] = (counts[t] ?? 0) + 1;
    }
  }
  return counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
});

// ---- money ----

final homeCurrencyProvider = FutureProvider<String>((ref) {
  ref.watch(revisionProvider);
  return ref.watch(sessionProvider).vault.homeCurrency();
});

final importRulesProvider = FutureProvider<UkImportRules>((ref) async {
  ref.watch(revisionProvider);
  final v = ref.watch(sessionProvider).vault;
  return UkImportRules(
    dutyPercent: double.tryParse(await v.pref(dutyPref) ?? '') ?? 0,
    handlingFee: int.tryParse(await v.pref(handlingPref) ?? '') ?? 0,
  );
});

/// Exchange rates into the home currency: the copy kept on this device,
/// refreshed once a day. Without a network the kept copy stands (its date
/// is shown wherever it is used).
final fxProvider = FutureProvider<FxRates?>((ref) async {
  final home = await ref.watch(homeCurrencyProvider.future);
  final db = ref.watch(sessionProvider).db;
  final kept = FxRates.fromJson(await db.localSetting(fxSetting));
  final today = DateTime.now().toUtc();
  final old = kept == null ? null : DateTime.tryParse(kept.day);
  if (kept != null && kept.base == home && old != null && today.difference(old) < const Duration(hours: 36)) {
    return kept;
  }
  try {
    final fresh = await FxRates.fetch(home);
    await db.setLocalSetting(fxSetting, jsonEncode(fresh.toJson()));
    return fresh;
  } on Object catch (e) {
    debugPrint('Chanda: exchange rates not refreshed: $e');
    return kept?.base == home ? kept : null;
  }
});

/// What [i] costs delivered, in the home currency.
Landed? landedFor(WidgetRef ref, VaultItem i) {
  final price = i.price;
  final home = ref.watch(homeCurrencyProvider).value;
  final rules = ref.watch(importRulesProvider).value;
  if (price == null || home == null || rules == null) return null;
  return landedCost(
    price: price,
    shipping: i.shipping,
    currency: i.currency,
    home: home,
    fromAbroad: shopOf(i.shop).fromAbroad,
    fx: ref.watch(fxProvider).value,
    rules: rules,
  );
}

// ---- checks while the app is open ----

/// Reads product pages: a hidden web view (with the in-app browser's
/// cookies) where there is one, else plain HTML. Tests swap in a fake.
final readerProvider = Provider<PageReader>((_) => hasWebView ? const WebPageReader() : const HtmlPageReader());

final notifierProvider = FutureProvider<AlertNotifier>((ref) async {
  ref.watch(revisionProvider);
  final s = ref.watch(sessionProvider);
  return AlertNotifier(ntfy: await s.vault.pref(ntfyPref), local: await s.db.localSetting(notifySetting) != 'off');
});

/// Checks the vault while the app is open, every quarter hour (each item
/// only when it is due), and on demand. State: whether a run is going.
class LiveChecks extends Notifier<bool> {
  Timer? _timer;
  Checker? _checker;

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    return false;
  }

  /// Starts the quarter-hourly checks, the first a little after start-up.
  void start({Duration first = const Duration(seconds: 30)}) {
    _timer?.cancel();
    _timer = Timer(first, () {
      runDue();
      _timer = Timer.periodic(const Duration(minutes: 15), (_) => runDue());
    });
  }

  Future<Checker> _make() async => _checker ??= Checker(
    ref.read(sessionProvider).vault,
    reader: ref.read(readerProvider),
    notifier: await ref.read(notifierProvider.future),
    present: true,
  );

  /// Checks every item that is due.
  Future<CheckReport?> runDue() async {
    if (state) return null;
    state = true;
    try {
      _checker = null;
      final report = await (await _make()).run();
      if (report.checked > 0) _refresh();
      return report;
    } on Object catch (e) {
      debugPrint('Chanda: checks stopped: $e');
      return null;
    } finally {
      state = false;
    }
  }

  /// Checks one item now, whether due or not.
  Future<CheckResult> checkNow(VaultItem item) async {
    try {
      return await (await _make()).check(item);
    } finally {
      _refresh();
    }
  }

  void _refresh() {
    ref.read(revisionProvider.notifier).bump();
    ref.read(syncProvider.notifier).soon();
  }
}

final liveChecksProvider = NotifierProvider<LiveChecks, bool>(LiveChecks.new);
