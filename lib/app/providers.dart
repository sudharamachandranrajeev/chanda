import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../db/database.dart';
import '../domain/ai_reader.dart';
import '../domain/checker.dart';
import '../domain/cloud_tryon.dart';
import '../domain/app_searcher.dart';
import '../domain/ebay_api.dart';
import '../domain/embeddings.dart';
import '../domain/images.dart';
import '../domain/local_search.dart';
import '../domain/money.dart';
import '../domain/notify.dart';
import '../domain/people.dart';
import '../domain/picture_index.dart';
import '../domain/pictures.dart';
import '../domain/shop_api.dart';
import '../domain/shop_search.dart';
import '../domain/shops.dart';
import '../domain/similar_shops.dart';
import '../domain/taste.dart';
import '../domain/taste_store.dart';
import '../domain/tryon.dart';
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

/// Loads the bytes of an item's picture (item id, index, web address);
/// tests swap in their own.
final itemPictureProvider = Provider<Future<Uint8List?> Function(String, int, String?)>((_) => itemPicture);

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

// ---- search ----

/// Shops the user got past a check for this session (see [ShopPasses]).
final shopPassesProvider = Provider<ShopPasses>((_) => ShopPasses());

/// The HTTP client for shops' own product searches and eBay; tests swap in a
/// fake service. Null means a real client.
final apiClientProvider = Provider<http.Client?>((_) => null);

/// Which shop runs on what, kept in the vault's local settings (this device
/// only), so a run does not ask every shop again.
class _DbPlatformCache implements PlatformCache {
  const _DbPlatformCache(this.db);
  final AppDatabase db;
  static const key = 'chanda.platforms';

  @override
  Future<Map<String, String>> load() async {
    try {
      final j = jsonDecode(await db.localSetting(key) ?? '{}');
      return {
        if (j is Map)
          for (final e in j.entries) '${e.key}': '${e.value}',
      };
    } on FormatException {
      return const {};
    }
  }

  @override
  Future<void> save(Map<String, String> known) => db.setLocalSetting(key, jsonEncode(known));
}

/// Shops' own product searches over plain HTTP.
final shopApisProvider = Provider<ShopApis>((ref) {
  final apis = ShopApis(
    client: ref.watch(apiClientProvider),
    cache: _DbPlatformCache(ref.watch(sessionProvider).db),
  );
  ref.onDispose(apis.close);
  return apis;
});

/// The user's own eBay application keys (this device only, never synced);
/// empty when not set. Invalidate after changing them.
final ebayKeysProvider = FutureProvider<({String id, String secret})>((ref) async {
  final db = ref.watch(sessionProvider).db;
  return (
    id: (await db.localSetting(ebayIdSetting) ?? '').trim(),
    secret: (await db.localSetting(ebaySecretSetting) ?? '').trim(),
  );
});

/// Searches shops every way there is (see [AppSearcher]); tests swap in a
/// fake.
final searcherProvider = Provider<ShopSearcher>((ref) {
  final keys = ref.watch(ebayKeysProvider).value;
  final client = ref.watch(apiClientProvider);
  return AppSearcher(
    web: WebShopSearcher(passes: ref.watch(shopPassesProvider)),
    apis: ref.watch(shopApisProvider),
    ebay: keys != null && keys.id.isNotEmpty && keys.secret.isNotEmpty
        ? EbayApi(id: keys.id, secret: keys.secret, client: client ?? http.Client())
        : null,
  );
});

/// Search over the vault and found offers, and the "same product?" answers.
final localSearchProvider = Provider<LocalSearch>(
  (ref) => LocalSearch(ref.watch(sessionProvider).store, embedder: ref.watch(embedderProvider).value),
);

/// Where a downloaded model is kept: one folder per pinned revision.
Future<Directory> modelFolder(String name) async =>
    Directory('${(await getApplicationSupportDirectory()).path}/models/$name');

/// A downloadable model: downloaded or not, on or off, and a download's
/// progress.
class ModelState {
  const ModelState({this.present = false, this.on = false, this.done, this.error});
  final bool present;
  final bool on;

  /// Bytes downloaded so far while a download runs.
  final int? done;
  final String? error;

  bool get downloading => done != null;
}

/// One optional model: its device setting, its files and its folder.
class DownloadedModel extends AsyncNotifier<ModelState> {
  DownloadedModel(this.setting, this.files, this.folder);
  final String setting;
  final List<ModelFile> files;
  final String folder;

  int get bytes => bytesOf(files);

  Future<Directory> dir() => modelFolder(folder);

  @override
  Future<ModelState> build() async {
    try {
      final present = modelPresent(await dir(), files);
      final on = await ref.read(sessionProvider).db.localSetting(setting) == 'on';
      return ModelState(present: present, on: on && present);
    } on Object catch (e) {
      debugPrint('Chanda: model $folder unavailable: $e');
      return const ModelState();
    }
  }

  Future<void> download() async {
    if (state.value?.downloading ?? false) return;
    state = const AsyncData(ModelState(done: 0));
    try {
      await downloadModel(
        await dir(),
        files: files,
        progress: (n) => state = AsyncData(ModelState(done: n)),
      );
      await ref.read(sessionProvider).db.setLocalSetting(setting, 'on');
      state = const AsyncData(ModelState(present: true, on: true));
    } on Object catch (e) {
      state = AsyncData(ModelState(error: describeError(e)));
    }
  }

  Future<void> setOn(bool on) async {
    await ref.read(sessionProvider).db.setLocalSetting(setting, on ? 'on' : 'off');
    state = AsyncData(ModelState(present: state.value?.present ?? false, on: on));
  }

  Future<void> remove() async {
    await ref.read(sessionProvider).db.setLocalSetting(setting, 'off');
    final d = await dir();
    if (d.existsSync()) await d.delete(recursive: true);
    state = const AsyncData(ModelState());
  }
}

/// "Smarter search": the meaning model.
final smartSearchProvider = AsyncNotifierProvider<DownloadedModel, ModelState>(
  () => DownloadedModel(smartSearchSetting, modelFiles, 'minilm-faf4aa4'),
);

/// "Picture search": the picture model.
final picturesProvider = AsyncNotifierProvider<DownloadedModel, ModelState>(
  () => DownloadedModel(pictureSetting, pictureFiles, 'fashion-siglip-c56244c'),
);

/// "Try-on": the face, body and cut-out models.
final tryOnProvider = AsyncNotifierProvider<DownloadedModel, ModelState>(
  () => DownloadedModel(tryOnSetting, tryOnFiles, 'tryon-v1'),
);

/// The try-on models, loaded while try-on is downloaded and on; tests swap
/// in fakes.
final tryOnModelsProvider = FutureProvider<TryOnModels?>((ref) async {
  final on = await ref.watch(tryOnProvider.selectAsync((s) => s.on));
  if (!on) return null;
  try {
    final m = await TryOnModels.load(await ref.read(tryOnProvider.notifier).dir());
    ref.onDispose(m.close);
    return m;
  } on Object catch (e) {
    debugPrint('Chanda: could not load the try-on models: $e');
    return null;
  }
});

// ---- people (try-on) ----

/// Bumped after any change to the saved people.
final peopleRevisionProvider = NotifierProvider<Revision, int>(Revision.new);

final peopleProvider = Provider<People>((ref) => People(ref.watch(sessionProvider).db));

/// The one saved person the app shows today, if any.
final personProvider = FutureProvider<Person?>((ref) {
  ref.watch(peopleRevisionProvider);
  return ref.watch(peopleProvider).first();
});

final personThumbsProvider = FutureProvider.family<Map<PhotoKind, Uint8List>, String>((ref, id) {
  ref.watch(peopleRevisionProvider);
  return ref.watch(peopleProvider).thumbs(id);
});

/// The meaning model, loaded while smarter search is on.
final embedderProvider = FutureProvider<Embedder?>((ref) async {
  final s = await ref.watch(smartSearchProvider.selectAsync((s) => s.on));
  if (!s) return null;
  try {
    final e = await OnnxEmbedder.load(await ref.read(smartSearchProvider.notifier).dir());
    ref.onDispose(e.close);
    return e;
  } on Object catch (e) {
    debugPrint('Chanda: could not load the search model: $e');
    return null;
  }
});

/// The picture model, loaded while picture search is on.
final pictureEmbedderProvider = FutureProvider<PictureEmbedder?>((ref) async {
  final on = await ref.watch(picturesProvider.selectAsync((s) => s.on));
  if (!on) return null;
  try {
    final e = await OnnxPictureEmbedder.load(await ref.read(picturesProvider.notifier).dir());
    ref.onDispose(e.close);
    return e;
  } on Object catch (e) {
    debugPrint('Chanda: could not load the picture model: $e');
    return null;
  }
});

/// The shipped picture labels (what a thing is, colours, patterns).
final pictureLabelsProvider = FutureProvider<List<PictureLabel>>((_) async {
  try {
    return await loadLabels();
  } on Object catch (e) {
    debugPrint('Chanda: picture labels not loaded: $e');
    return const [];
  }
});

/// Ratings and the taste model's inputs.
final tasteProvider = FutureProvider<TasteStore>(
  (ref) async =>
      TasteStore(ref.watch(sessionProvider).store, labels: await ref.watch(pictureLabelsProvider.future)),
);

final ratingsProvider = FutureProvider<Map<String, Rating>>((ref) async {
  ref.watch(revisionProvider);
  return {for (final r in await (await ref.watch(tasteProvider.future)).ratings()) r.url: r};
});

final tasteOnProvider = FutureProvider<bool>((ref) async {
  ref.watch(revisionProvider);
  return (await ref.watch(tasteProvider.future)).on();
});

final mutedProvider = FutureProvider<Set<String>>((ref) async {
  ref.watch(revisionProvider);
  return (await ref.watch(tasteProvider.future)).muted();
});

/// Puts the pictures of saved things and of offers found lately through
/// the picture model, a few dozen at a time, so looks count in suggestions
/// and photo search. Nothing happens while picture search is off.
Future<void> indexPictures(Ref ref, {int cap = 24}) async {
  final e = await ref.read(pictureEmbedderProvider.future);
  if (e == null) return;
  try {
    await PictureIndex(ref.read(sessionProvider).db)
        .fillFromVault(e, ref.read(sessionProvider).vault, cap: cap);
  } on Object catch (e) {
    debugPrint('Chanda: pictures not indexed: $e');
  }
}

/// "For you": suggestions from offers found before, best first.
final forYouProvider = FutureProvider<List<(ShopOffer, Suggestion)>>((ref) async {
  ref.watch(revisionProvider);
  ref.watch(pictureEmbedderProvider);
  await indexPictures(ref);
  return (await ref.watch(tasteProvider.future)).forYou();
});

/// Whether the "rate a few" card has shown in this session.
class RatePromptShown extends Notifier<bool> {
  @override
  bool build() => false;
  void shown() => state = true;
}

final ratePromptShownProvider = NotifierProvider<RatePromptShown, bool>(RatePromptShown.new);

// ---- shops ----

/// The curated shop list for "similar shops".
final seedShopsProvider = FutureProvider<List<SeedShop>>((_) async {
  try {
    return await loadSeedShops();
  } on Object catch (e) {
    debugPrint('Chanda: shop list not loaded: $e');
    return const [];
  }
});

/// The shops the user added to search, registered with the catalogue.
final myShopsProvider = FutureProvider<List<SeedShop>>((ref) {
  ref.watch(revisionProvider);
  return MyShops(ref.watch(sessionProvider).vault).load();
});

/// Shops like the ones the user buys from, that they do not use yet.
final similarShopsProvider = FutureProvider<List<SimilarShop>>((ref) async {
  final items = await ref.watch(allItemsProvider.future);
  final seeds = await ref.watch(seedShopsProvider.future);
  final labels = await ref.watch(pictureLabelsProvider.future);
  final mine = {for (final s in await ref.watch(myShopsProvider.future)) s.domain};
  final home = await ref.watch(homeCurrencyProvider.future);
  return similarShops([
    for (final s in seeds)
      if (!mine.contains(s.domain)) s,
  ], profileOf(items, seeds, labels, currency: home));
});

/// Facts about the shop at a home address, looked up when asked for (and
/// kept a month). Its page is read the plain way, or like a product page
/// when the plain way is turned away.
final shopFactsProvider = FutureProvider.family<ShopFacts, String>((ref, home) {
  final reader = ref.read(readerProvider);
  return ShopFactsStore(ref.read(sessionProvider).db)
      .facts(Uri.parse(home), readPage: (u) async => (await reader.read(u)).ld);
});

/// Offers found before that could be the item at other shops, with the
/// user's answers so far.
final candidatesProvider = FutureProvider.family<(List<ShopOffer>, Map<String, String>), String>((
  ref,
  id,
) async {
  ref.watch(revisionProvider);
  final item = await ref.watch(itemProvider(id).future);
  if (item == null) return (const <ShopOffer>[], const <String, String>{});
  final s = ref.watch(localSearchProvider);
  return (await s.candidatesFor(item), await s.matchesFor(id));
});

// ---- checks while the app is open ----

/// Reads product pages: a hidden web view (with the in-app browser's
/// cookies) where there is one, else plain HTML. Tests swap in a fake.
/// The user's own API key for optional AI reading; empty when not set.
/// Invalidate after changing it.
final aiKeyProvider = FutureProvider<String>(
  (ref) async => await ref.watch(sessionProvider).db.localSetting(aiKeySetting) ?? '',
);

/// The HTTP client for AI reading; tests swap in a fake service.
final aiClientProvider = Provider<http.Client?>((_) => null);

/// The user's own keys for AI try-on (kept on this device only, never
/// synced) and whether their Gemini key is on a paid plan. Invalidate after
/// changing them.
final cloudKeysProvider = FutureProvider<({Map<CloudProvider, String> keys, bool geminiPaid})>((ref) async {
  final db = ref.watch(sessionProvider).db;
  return (
    keys: {for (final p in CloudProvider.values) p: (await db.localSetting(cloudKeySetting(p)) ?? '').trim()},
    geminiPaid: await db.localSetting(geminiPaidSetting) == 'on',
  );
});

/// The HTTP client for AI try-on; tests swap in a fake service.
final cloudClientProvider = Provider<http.Client?>((_) => null);

final readerProvider = Provider<PageReader>(
  (_) => hasWebView ? const WebPageReader() : const HtmlPageReader(),
);

final notifierProvider = FutureProvider<AlertNotifier>((ref) async {
  ref.watch(revisionProvider);
  final s = ref.watch(sessionProvider);
  return AlertNotifier(
    ntfy: await s.vault.pref(ntfyPref),
    local: await s.db.localSetting(notifySetting) != 'off',
  );
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
