import 'dart:async';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nithya/nithya.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/local_search.dart';
import '../domain/money.dart';
import '../domain/offers.dart';
import '../domain/query.dart';
import '../domain/shop_search.dart';
import '../domain/shops.dart';
import 'browser_page.dart';
import 'item_page.dart';
import 'look.dart';
import 'vault_page.dart' show ItemCard;

/// One search over the vault and the shops. The words are read into chips
/// (budget, size, colour, material, shop) the user can tap off; the shops
/// that allow it are read in the background, three at a time, and the
/// others open in the browser for the user to add their results.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _box = TextEditingController();
  Query? _q;
  var _vault = const <VaultItem>[];
  final _results = <String, ShopResult>{};

  /// Offers found before for these words, shown until the shops answer.
  var _before = const <Offer>[];
  StreamSubscription<ShopResult>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    _box.dispose();
    super.dispose();
  }

  Future<void> _submit(String text) async {
    final home = await ref.read(homeCurrencyProvider.future);
    final q = readQuery(text, currency: home);
    if (q.isEmpty) return;
    await _search(q);
  }

  Future<void> _search(Query q) async {
    await _sub?.cancel();
    setState(() {
      _q = q;
      _results.clear();
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
    _sub = searchShops(ref.read(searcherProvider), q, shops).listen((r) async {
      if (r.state == SearchState.done) await local.keepOffers(r.offers, q.raw);
      if (mounted && _q == q) setState(() => _results[r.shop.id] = r);
    });
  }

  /// Opens a shop's search in the browser; what the user adds joins the
  /// results.
  Future<void> _open(Shop shop) async {
    final q = _q;
    if (q == null) return;
    final offers = await openSearchInApp(context, shop, q.words);
    if (offers == null || !mounted) return;
    await ref.read(localSearchProvider).keepOffers(offers, q.raw);
    if (mounted && _q == q) {
      setState(() => _results[shop.id] = ShopResult(shop, SearchState.done, offers: offers));
    }
  }

  void _add(String words) {
    _box.text = '${_box.text.trim()} $words';
    _submit(_box.text);
  }

  @override
  Widget build(BuildContext context) {
    final q = _q;
    final found = {
      for (final o in _before) o.id: o,
      for (final r in _results.values)
        for (final o in r.offers) o.id: o,
    };
    final offers = q == null ? const <Offer>[] : rankOffers(q, found.values);
    return PageScaffold(
      title: 'Search',
      banner: 'page.search',
      children: [
        _SearchBox(controller: _box, onSubmit: _submit),
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
          _ShopStates(results: _results, onOpen: _open),
          if (_vault.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Heading('In your vault', '${_vault.length}'),
            _Grid(
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
          _Heading('At the shops', offers.isEmpty ? '' : '${offers.length}'),
          if (offers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _results.values.any((r) => r.state == SearchState.searching || r.state == SearchState.waiting)
                    ? 'Searching…'
                    : 'Nothing found yet. Open a shop above to search it yourself.',
                style: TextStyle(color: muted(context)),
              ),
            )
          else
            _Grid(children: [for (final o in offers) SizedBox(height: 300, child: OfferCard(o))]),
        ],
      ],
    );
  }
}

IconData _facetIcon(String kind) => switch (kind) {
  'budget' => Icons.payments_outlined,
  'size' => Icons.straighten,
  'colour' => Icons.palette_outlined,
  'material' => Icons.texture,
  _ => Icons.storefront_outlined,
};

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller, required this.onSubmit});
  final TextEditingController controller;
  final ValueChanged<String> onSubmit;

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

/// Each shop's search: going, done (how many), or waiting for the user.
class _ShopStates extends StatelessWidget {
  const _ShopStates({required this.results, required this.onOpen});
  final Map<String, ShopResult> results;
  final ValueChanged<Shop> onOpen;

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
          SearchState.done => ActionChip(
            avatar: const Icon(Icons.check, size: 16, color: drop),
            label: Text('${r.shop.name} · ${r.offers.length}'),
            tooltip: 'Open the search at ${r.shop.name}',
            onPressed: () => onOpen(r.shop),
          ),
          SearchState.check => ActionChip(
            avatar: const Icon(Icons.verified_user_outlined, size: 16),
            label: Text('${r.shop.name}: open to pass its check'),
            onPressed: () => onOpen(r.shop),
          ),
          SearchState.inBrowser => ActionChip(
            avatar: const Icon(Icons.open_in_new, size: 16),
            label: Text('Search ${r.shop.name}'),
            tooltip: '${r.shop.name} shows results only to a visitor in person',
            onPressed: () => onOpen(r.shop),
          ),
          SearchState.failed => ActionChip(
            avatar: const Icon(Icons.error_outline, size: 16),
            label: Text('${r.shop.name}: try in browser'),
            tooltip: r.error,
            onPressed: () => onOpen(r.shop),
          ),
        },
    ],
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.count);
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

class _Grid extends StatelessWidget {
  const _Grid({required this.children});
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
  const OfferCard(this.offer, {super.key, this.footer});
  final Offer offer;

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
                        ].join(' '),
                        style: text.bodySmall?.copyWith(color: p.muted),
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
