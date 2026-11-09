import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nithya/nithya.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/compare.dart';
import '../domain/images.dart';
import '../domain/local_search.dart';
import '../domain/matching.dart';
import '../domain/money.dart';
import '../domain/query.dart';
import '../domain/shop_search.dart';
import '../domain/shops.dart';
import '../domain/vault.dart' show imagesOf;
import '../domain/watch.dart';
import 'browser_page.dart';
import 'look.dart';

/// The item at other shops: find it, confirm what is the same product, and
/// see the best deal with the reason for it.
class CompareCard extends ConsumerStatefulWidget {
  const CompareCard(this.item, {super.key});
  final VaultItem item;

  @override
  ConsumerState<CompareCard> createState() => _CompareCardState();
}

class _CompareCardState extends ConsumerState<CompareCard> {
  var _finding = false;
  final _walled = <Shop>{};
  String _itemHash = '';

  VaultItem get i => widget.item;

  /// The item's words for a shop's search box: its title, without the
  /// shop's clutter, at most eight words.
  String get _words => i.title.split(RegExp(r'\s+')).take(8).join(' ');

  Future<void> _find() async {
    setState(() {
      _finding = true;
      _walled.clear();
    });
    final local = ref.read(localSearchProvider);
    final q = readQuery(_words, currency: i.currency);
    try {
      await for (final r in searchShops(ref.read(searcherProvider), q, shops.where((s) => s.id != i.shop))) {
        if (r.state == SearchState.done) await local.keepOffers(r.offers, q.raw);
        if (r.state == SearchState.inBrowser ||
            r.state == SearchState.check ||
            r.state == SearchState.failed) {
          _walled.add(r.shop);
        }
      }
      await _hashPictures();
    } finally {
      ref.read(revisionProvider.notifier).bump();
      if (mounted) setState(() => _finding = false);
    }
  }

  Future<void> _openWalled(Shop s) async {
    final offers = await openSearchInApp(context, s, _words);
    if (offers == null) return;
    await ref.read(localSearchProvider).keepOffers(offers, _words);
    await _hashPictures();
    ref.read(revisionProvider.notifier).bump();
    if (mounted) setState(() => _walled.remove(s));
  }

  /// Picture fingerprints for the item and for up to a dozen candidates
  /// that lack one: like pictures make a "same product?" question.
  Future<void> _hashPictures() async {
    try {
      final local = ref.read(localSearchProvider);
      if (_itemHash.isEmpty) {
        final bytes = await firstPicture(i.id, imagesOf(i).firstOrNull);
        if (bytes != null) _itemHash = await compute(dhashOf, bytes) ?? '';
      }
      if (_itemHash.isEmpty) return;
      final cands = await local.candidatesFor(i);
      for (final o in cands.where((o) => o.dhash.isEmpty && o.image.startsWith('http')).take(12)) {
        final bytes = await fetchImage(o.image);
        final h = bytes == null ? null : await compute(dhashOf, bytes);
        if (h != null) await local.setHash(o.id, h);
      }
    } on Object catch (e) {
      debugPrint('Chanda: picture fingerprints skipped: $e');
    }
  }

  Future<void> _answer(ShopOffer o, bool same) async {
    await ref.read(localSearchProvider).answer(i.id, o.url, same: same);
    ref.read(revisionProvider.notifier).bump();
    ref.read(syncProvider.notifier).soon();
  }

  @override
  Widget build(BuildContext context) {
    final p = NithyaPalette.of(context);
    final text = Theme.of(context).textTheme;
    final (cands, answers) =
        ref.watch(candidatesProvider(i.id)).value ?? (const <ShopOffer>[], const <String, String>{});
    final home = ref.watch(homeCurrencyProvider).value ?? 'GBP';
    final fx = ref.watch(fxProvider).value;
    final mine = listingOf(i, dhash: _itemHash);
    final same = <ShopOffer>[];
    final ask = <ShopOffer>[];
    for (final o in cands) {
      final answered = answers[o.url];
      if (answered == 'same') {
        same.add(o);
        continue;
      }
      if (answered == 'different') continue;
      switch (match(mine, Listing(title: o.title, dhash: o.dhash))) {
        case Verdict.same:
          same.add(o);
        case Verdict.likely:
          ask.add(o);
        case Verdict.different:
          break;
      }
    }
    final deals = [
      if (i.price != null)
        Deal(
          shop: shopOf(i.shop),
          url: i.url,
          title: i.title,
          price: i.price!,
          currency: i.currency,
          seen: i.checked ?? i.added,
          shipping: i.shipping,
          rating: i.rating,
          reviews: i.reviews,
          seller: i.seller,
          warranty: i.warranty,
          inStock: i.inStock,
          saved: true,
        ),
      for (final o in same)
        if (o.price != null)
          Deal(
            shop: shopOf(o.shop),
            url: o.url,
            title: o.title,
            price: o.price!,
            currency: o.currency,
            seen: o.seen,
            rating: o.rating,
            reviews: o.reviews,
            inStock: o.inStock,
          ),
    ];
    final (costed, best) = compareDeals(deals, home: home, fx: fx);
    final now = DateTime.now().toUtc();

    return SectionCard(
      title: 'Other shops',
      hint: 'action.compare',
      trailing: _finding
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : TextButton.icon(
              icon: const Icon(Icons.travel_explore),
              label: const Text('Find'),
              onPressed: _find,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (best != null && costed.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Extruded(
                depth: 0.5,
                glow: drop,
                padding: const EdgeInsets.all(12),
                onTap: best.deal.deal.saved ? null : () => openInApp(context, Uri.parse(best.deal.deal.url)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const GlowBadge(label: 'Best deal', color: drop, icon: Icons.verified),
                        const SizedBox(width: 8),
                        Expanded(child: Text(best.deal.deal.shop.name, style: text.titleSmall)),
                        Text(
                          '${best.deal.landed!.estimate ? '≈ ' : ''}${showPrice(best.deal.landed!.total, home)}',
                          style: NithyaType.heading.toStyle(color: p.foreground),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(best.reason, style: text.bodySmall?.copyWith(color: p.muted)),
                  ],
                ),
              ),
            ),
          for (final c in costed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(c.deal.saved ? Icons.favorite : Icons.storefront_outlined, size: 20),
              title: Text('${c.deal.shop.name}${c.deal.saved ? ' (saved)' : ''}', style: text.bodyMedium),
              subtitle: Text(
                [
                  showPrice(c.deal.price, c.deal.currency),
                  if (c.deal.rating != null) '★ ${c.deal.rating!.toStringAsFixed(1)}',
                  if (!c.deal.inStock) 'out of stock',
                  ago(c.deal.seen, now),
                ].join(' · '),
                style: text.bodySmall?.copyWith(
                  color: freshness(c.deal.seen, now) == Freshness.fresh ? p.muted : NithyaAccent.warning,
                ),
              ),
              trailing: Text(
                c.landed == null
                    ? 'no rate'
                    : '${c.landed!.estimate ? '≈ ' : ''}${showPrice(c.landed!.total, home)}',
                style: text.titleSmall,
              ),
              onTap: c.deal.saved ? null : () => openInApp(context, Uri.parse(c.deal.url)),
            ),
          for (final o in ask.take(5))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Extruded(
                depth: 0.3,
                padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                child: Row(
                  children: [
                    if (o.image.startsWith('http'))
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(NithyaRadius.sm),
                          child: Image.network(
                            o.image,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(width: 44, height: 44),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Same product? ${shopOf(o.shop).name}', style: text.labelMedium),
                          Text(o.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodySmall),
                          if (o.price != null) Text(showPrice(o.price!, o.currency), style: text.labelLarge),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Look',
                      icon: const Icon(Icons.open_in_new, size: 18),
                      onPressed: () => openInApp(context, Uri.parse(o.url)),
                    ),
                    TextButton(onPressed: () => _answer(o, false), child: const Text('No')),
                    FilledButton.tonal(onPressed: () => _answer(o, true), child: const Text('Yes')),
                  ],
                ),
              ),
            ),
          if (_walled.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in _walled)
                    ActionChip(
                      avatar: const Icon(Icons.open_in_new, size: 16),
                      label: Text('Search ${s.name}'),
                      onPressed: () => _openWalled(s),
                    ),
                ],
              ),
            ),
          if (costed.length <= 1 && ask.isEmpty && !_finding)
            Text(
              'Press Find to look for this at the other shops. Chanda compares only the same product, in the same '
              'size and colour.',
              style: text.bodySmall?.copyWith(color: p.muted),
            ),
        ],
      ),
    );
  }
}
