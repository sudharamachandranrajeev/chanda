import 'dart:async';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nithya/nithya.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/attributes.dart';
import '../domain/local_search.dart';
import '../domain/money.dart';
import '../domain/offers.dart';
import '../domain/query.dart';
import '../domain/reranker.dart';
import '../domain/shop_search.dart';
import '../domain/shops.dart';
import '../domain/similar_shops.dart';
import '../domain/taste.dart';
import '../domain/taste_store.dart';
import 'browser_page.dart';
import 'item_page.dart';
import 'look.dart';
import 'photo_search.dart';
import 'shop_panels.dart';
import 'vault_page.dart' show ItemCard;

/// One search over the vault and the shops, all inside Chanda. The words
/// are read into chips (budget, size, colour, material, shop, and what the
/// product should be like) the user can tap off. Shops with a product
/// search are asked directly, shops whose pages load by themselves are read
/// in the background, and shops that need a person show up as live panels
/// below, read as the user uses them. Results stream into one grid.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, this.initial});

  /// Words to search for straight away (from a photo's labels).
  final String? initial;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _box = TextEditingController();
  Query? _q;
  var _vault = const <VaultItem>[];
  final _results = <String, ShopResult>{};

  /// Shops shown as live panels: those that need the user, in the order
  /// they turned up.
  final _panelShops = <String, Shop>{};

  /// Offers the user's panels read, by shop.
  final _fromPanels = <String, Map<String, Offer>>{};

  /// How close each offer's title is to the search in meaning (Smarter
  /// search on).
  var _meaning = const <String, double>{};

  /// The ranking model's score for each offer it read (Sharper ranking on).
  var _sharper = const <String, double>{};
  var _sharpening = false;

  /// Offers found before for these words, shown until the shops answer.
  var _before = const <Offer>[];
  StreamSubscription<ShopResult>? _sub;
  var _sort = ResultSort.best;

  /// The offers in taste order, for the offers they were worked out for.
  (String, List<Offer>)? _tasteOrder;

  @override
  void initState() {
    super.initState();
    unawaited(loadLexicon());
    if (widget.initial case final w?) {
      _box.text = w;
      WidgetsBinding.instance.addPostFrameCallback((_) => _submit(w));
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _box.dispose();
    super.dispose();
  }

  Future<void> _submit(String text) async {
    final home = await ref.read(homeCurrencyProvider.future);
    await loadLexicon();
    final q = readQuery(text, currency: home);
    if (q.isEmpty) return;
    await _search(q);
  }

  Future<void> _search(Query q) async {
    await _sub?.cancel();
    setState(() {
      _q = q;
      _results.clear();
      _panelShops.clear();
      _fromPanels.clear();
      _meaning = const {};
      _sharper = const {};
    });
    final local = ref.read(localSearchProvider);
    final hits = await local.search(q);
    if (!mounted || _q != q) return;
    setState(() {
      _vault = [for (final h in hits) ?h.item];
      _before = [
        for (final h in hits)
          if (h.offer case final o?) offerOf(o),
      ];
    });
    if (q.words.trim().isEmpty) return;
    await ref.read(myShopsProvider.future).catchError((_) => const <SeedShop>[]);
    if (!mounted || _q != q) return;
    _sub = searchShops(ref.read(searcherProvider), q, shops).listen((r) async {
      if (r.state == SearchState.done) await local.keepOffers(r.offers, q.raw);
      if (!mounted || _q != q) return;
      setState(() {
        _results[r.shop.id] = r;
        if (r.needsYou || r.state == SearchState.failed) _panelShops.putIfAbsent(r.shop.id, () => r.shop);
      });
      if (r.state == SearchState.done) unawaited(_updateMeaning(q));
    });
  }

  /// What a shop's panel read: shown at once with the rest, and kept (unless
  /// it was read off the screen). The user got past the shop's check, so the
  /// shop is tried hidden next time (see [ShopPasses]).
  Future<void> _fromPanel(Shop shop, List<Offer> offers) async {
    final q = _q;
    if (q == null || !mounted) return;
    final mine = _fromPanels.putIfAbsent(shop.id, () => {});
    for (final o in offers) {
      mine[o.id] = o;
    }
    ref.read(shopPassesProvider).passed(shop.id);
    setState(() => _results[shop.id] = ShopResult(shop, SearchState.done, offers: mine.values.toList()));
    await ref.read(localSearchProvider).keepOffers(offers, q.raw);
    unawaited(_updateMeaning(q));
  }

  /// With Smarter search on, scores every offer found by meaning.
  Future<void> _updateMeaning(Query q) async {
    final local = ref.read(localSearchProvider);
    if (local.embedder == null) return _sharpen(q);
    final all = {
      for (final r in _results.values)
        for (final o in r.offers) o.id: o,
    };
    try {
      final m = await local.meaningOf(q, all.values);
      if (mounted && _q == q) setState(() => _meaning = m);
    } on Object {
      // Without the meaning score, words and attributes still rank.
    }
    await _sharpen(q);
  }

  /// The offers found so far, ranked by attributes, words and meaning.
  List<RankedOffer> _ranked(Query q) {
    final found = {
      for (final o in _before) o.id: o,
      for (final r in _results.values)
        for (final o in r.offers) o.id: o,
    };
    return rankScored(q, found.values, meaning: _meaning.isEmpty ? null : _meaning);
  }

  /// With Sharper ranking on, scores the best matches it has not read yet.
  /// One run at a time; a run that finds new offers at the top goes again.
  Future<void> _sharpen(Query q) async {
    if (_sharpening) return;
    // Taken before the first wait, so a second call cannot start a run too.
    _sharpening = true;
    try {
      final model = await ref.read(rerankerProvider.future).catchError((_) => null);
      while (model != null && mounted && _q == q) {
        final todo = [
          for (final r in _ranked(q).take(rerankTop))
            if (!_sharper.containsKey(r.offer.id)) r.offer,
        ];
        if (todo.isEmpty) break;
        final scores = await model.score(rerankQuery(q.shopWords(), q.words), [
          for (final o in todo) o.title,
        ]);
        if (!mounted || _q != q) break;
        setState(() => _sharper = {..._sharper, for (var i = 0; i < todo.length; i++) todo[i].id: scores[i]});
      }
    } on Object catch (e) {
      // Without the model, the usual ranking stands.
      debugPrint('Chanda: sharper ranking failed: $e');
    } finally {
      _sharpening = false;
    }
  }

  /// [offers] in the chosen order. Taste only reorders: the same offers,
  /// worked out in the background and shown when ready.
  List<Offer> _ordered(List<Offer> offers) {
    switch (_sort) {
      case ResultSort.best:
        return offers;
      case ResultSort.price:
        return [...offers]..sort((a, b) => a.price.compareTo(b.price));
      case ResultSort.forYou:
        final key = offers.map((o) => o.id).join('|');
        if (_tasteOrder case (final k, final order) when k == key) return order;
        ref.read(tasteProvider.future).then((t) => t.reorder(offers, Thing.ofFound)).then((order) {
          if (mounted) setState(() => _tasteOrder = (key, order));
        });
        return offers;
    }
  }

  Future<void> _byPhoto() async {
    final bytes = await pickPhoto(context);
    if (bytes == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PhotoSearchPage(bytes)));
  }

  void _add(String words) {
    _box.text = '${_box.text.trim()} $words';
    _submit(_box.text);
  }

  @override
  Widget build(BuildContext context) {
    final q = _q;
    final ranked = q == null ? const <RankedOffer>[] : rerank(_ranked(q), _sharper);
    final why = {for (final r in ranked) r.offer.id: r.why};
    final offers = _ordered([for (final r in ranked) r.offer]);
    final tasteOn = ref.watch(tasteOnProvider).value ?? false;
    return PageScaffold(
      title: 'Search',
      banner: 'page.search',
      children: [
        _SearchBox(controller: _box, onSubmit: _submit, onPhoto: _byPhoto),
        if (q == null) const _ForYou(),
        if (q != null && q.facets.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in q.facets)
                  InputChip(
                    label: Text(f.label),
                    avatar: Icon(_facetIcon(f.kind), size: 16),
                    onDeleted: () => _search(q.without(f)),
                    deleteButtonTooltipMessage: 'Remove',
                  ),
              ],
            ),
          ),
        if (q != null && q.vague) _Vague(currency: q.currency, onAdd: _add),
        if (q != null) ...[
          const SizedBox(height: 16),
          _ShopStates(results: _results),
          if (_vault.isNotEmpty) ...[
            const SizedBox(height: 16),
            ResultHeading('In your vault', '${_vault.length}'),
            ResultGrid(
              children: [
                for (final i in _vault)
                  SizedBox(
                    height: 300,
                    child: ItemCard(
                      i,
                      onTap: () =>
                          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ItemPage(i.id))),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          ResultHeading('At the shops', offers.isEmpty ? '' : '${offers.length}'),
          if (offers.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SegmentedButton<ResultSort>(
                showSelectedIcon: false,
                segments: [
                  const ButtonSegment(value: ResultSort.best, label: Text('Best match')),
                  if (tasteOn) const ButtonSegment(value: ResultSort.forYou, label: Text('For you')),
                  const ButtonSegment(value: ResultSort.price, label: Text('Price')),
                ],
                selected: {_sort == ResultSort.forYou && !tasteOn ? ResultSort.best : _sort},
                onSelectionChanged: (v) => setState(() => _sort = v.single),
              ),
            ),
          if (offers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _results.values.any((r) => r.state == SearchState.searching || r.state == SearchState.waiting)
                    ? 'Searching…'
                    : _panelShops.isNotEmpty
                    ? 'Nothing found yet. The shops below need you: pass their check there and the results join here.'
                    : 'Nothing found. Try fewer words, or take a chip off.',
                style: TextStyle(color: muted(context)),
              ),
            )
          else
            ResultGrid(
              children: [for (final o in offers) SizedBox(height: 330, child: OfferCard(o, why: why[o.id]))],
            ),
          if (_panelShops.isNotEmpty) ...[
            const SizedBox(height: 20),
            ShopPanels(shops: _panelShops.values.toList(), query: q, results: _results, onOffers: _fromPanel),
          ],
        ],
      ],
    );
  }
}

/// "For you": offers found in earlier searches that suit the user's
/// ratings, each saying why, with "Not for me" and a way to stop a word
/// counting. Shown before a search; hidden until there is something to show.
class _ForYou extends ConsumerWidget {
  const _ForYou();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(forYouProvider).value ?? const [];
    if (all.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        const ResultHeading('For you', ''),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'From what you rated and saved, among things your searches found.',
            style: TextStyle(color: muted(context)),
          ),
        ),
        ResultGrid(
          children: [
            for (final (o, why) in all)
              SizedBox(height: 320, child: OfferCard(offerOf(o), footer: _Why(o, why))),
          ],
        ),
      ],
    );
  }
}

class _Why extends ConsumerWidget {
  const _Why(this.offer, this.why);
  final ShopOffer offer;
  final Suggestion why;

  String get _reason {
    if (why.explore) return 'Something different';
    if (why.because case final b?) return 'Like ${b.title}';
    if (why.liked case final a?) return 'You like ${attributeWords(a)}';
    return 'Close to what you like';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> write(Future<void> Function(TasteStore t) f) async {
      await f(await ref.read(tasteProvider.future));
      ref.read(revisionProvider.notifier).bump();
      ref.read(syncProvider.notifier).soon();
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            _reason,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted(context)),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Why this, and less like it',
          icon: const Icon(Icons.more_horiz, size: 18),
          onSelected: (v) =>
              write((t) => v == 'no' ? t.rateOffer(offer, 1, source: 'not-for-me') : t.mute(why.liked!)),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'no', child: Text('Not for me')),
            if (why.liked case final a?)
              PopupMenuItem(value: 'mute', child: Text('Stop counting "${attributeWords(a)}"')),
          ],
        ),
      ],
    );
  }
}

/// How shop results are ordered. Taste only reorders what matched.
enum ResultSort { best, forYou, price }

IconData _facetIcon(String kind) => switch (kind) {
  'budget' => Icons.payments_outlined,
  'size' => Icons.straighten,
  'colour' => Icons.palette_outlined,
  'material' => Icons.texture,
  'attribute' => Icons.tune,
  _ => Icons.storefront_outlined,
};

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller, required this.onSubmit, required this.onPhoto});
  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final VoidCallback onPhoto;

  @override
  Widget build(BuildContext context) => Extruded(
    depth: 0.8,
    padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
    child: Row(
      children: [
        Icon(Icons.search, color: muted(context)),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: onSubmit,
            decoration: const InputDecoration(
              hintText: 'black linen shirt size M under £30',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Search with a photo',
          icon: const Icon(Icons.photo_camera_outlined),
          onPressed: onPhoto,
        ),
        FilledButton(onPressed: () => onSubmit(controller.text), child: const Text('Search')),
      ],
    ),
  );
}

/// One word alone finds too much: offer a budget to narrow it.
class _Vague extends StatelessWidget {
  const _Vague({required this.currency, required this.onAdd});
  final String currency;
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    final sign = showPrice(0, currency).replaceAll(RegExp(r'[\d.,\s]'), '');
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Extruded(
        depth: 0.4,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Narrow it down? A budget or a size helps.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final n in [20, 50, 100])
                  ActionChip(label: Text('Under $sign$n'), onPressed: () => onAdd('under $sign$n')),
                ActionChip(label: Text('Over ${sign}100'), onPressed: () => onAdd('over ${sign}100')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Each shop's search: going, done (how many), or failed. Shops that need
/// the user have their panel below instead.
class _ShopStates extends StatelessWidget {
  const _ShopStates({required this.results});
  final Map<String, ShopResult> results;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final r in results.values)
        switch (r.state) {
          SearchState.waiting || SearchState.searching => Chip(
            avatar: const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            label: Text(r.shop.name),
          ),
          SearchState.done => Chip(
            avatar: const Icon(Icons.check, size: 16, color: drop),
            label: Text('${r.shop.name} · ${r.offers.length}'),
          ),
          SearchState.check || SearchState.needsYou => Chip(
            avatar: const Icon(Icons.person_outline, size: 16),
            label: Text('${r.shop.name}: needs you'),
          ),
          SearchState.failed => Tooltip(
            message: r.error,
            child: Chip(
              avatar: const Icon(Icons.error_outline, size: 16),
              label: Text('${r.shop.name}: not this time'),
            ),
          ),
        },
    ],
  );
}

/// A results heading with a count.
class ResultHeading extends StatelessWidget {
  const ResultHeading(this.title, this.count, {super.key});
  final String title;
  final String count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (count.isNotEmpty) ...[const SizedBox(width: 8), Tag(count)],
      ],
    ),
  );
}

/// Cards in as many columns as fit.
class ResultGrid extends StatelessWidget {
  const ResultGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final cols = columnsFor(c.maxWidth, min: 220);
      final w = (c.maxWidth - (cols - 1) * 14) / cols;
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [for (final child in children) SizedBox(width: w, child: child)],
      );
    },
  );
}

/// A product a shop listed: picture, shop, name, price, rating, and Save
/// (which opens the product and reads it, as saving from a shop does).
class OfferCard extends StatelessWidget {
  const OfferCard(this.offer, {super.key, this.footer, this.why});
  final Offer offer;

  /// What matched the search (attributes, then words): "why this matched".
  final List<String>? why;

  /// Under the price, in place of the rating (the compare view's buttons).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final p = NithyaPalette.of(context);
    final text = Theme.of(context).textTheme;
    final o = offer;
    final placeholder = ColoredBox(
      color: p.controls,
      child: Center(child: Icon(Icons.shopping_bag_outlined, size: 32, color: p.muted)),
    );
    return Extruded(
      onTap: () => openInApp(context, Uri.parse(o.url)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 140,
            child: o.image.startsWith('http')
                ? Image.network(
                    o.image,
                    fit: BoxFit.cover,
                    headers: const {'user-agent': 'Chanda/0.1'},
                    errorBuilder: (_, _, _) => placeholder,
                  )
                : placeholder,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shopOf(o.shop).name.toUpperCase(), style: text.labelSmall?.copyWith(color: p.muted)),
                  const SizedBox(height: 2),
                  Text(o.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        showPrice(o.price, o.currency),
                        style: NithyaType.heading.toStyle(color: p.foreground),
                      ),
                      if (o.was != null) ...[
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            showPrice(o.was!, o.currency),
                            style: NithyaType.caption
                                .toStyle(color: p.muted)
                                .copyWith(decoration: TextDecoration.lineThrough),
                          ),
                        ),
                      ],
                      const Spacer(),
                      IconButton(
                        tooltip: 'Save',
                        icon: const Icon(Icons.favorite_border),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BrowserPage(url: Uri.parse(o.url), saveOnLoad: true),
                          ),
                        ),
                      ),
                    ],
                  ),
                  footer ??
                      Text(
                        [
                          if (o.rating != null) '★ ${o.rating!.toStringAsFixed(1)}',
                          if (o.reviews != null) '(${o.reviews})',
                          if (!o.inStock) 'Out of stock',
                          if (o.source == OfferSource.screen) 'Read from screen: check the price',
                        ].join(' '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(color: p.muted),
                      ),
                  if (why != null && why!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Matches: ${why!.join(', ')}',
                        key: const ValueKey('why'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(color: NithyaAccent.primary),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
