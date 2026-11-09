import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nithya/nithya.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/links.dart';
import '../domain/shops.dart';
import '../domain/similar_shops.dart';
import 'browser_page.dart';
import 'common.dart';
import 'item_bits.dart';
import 'look.dart';
import 'shop_finder.dart';

const _hues = [
  NithyaHues.amber,
  NithyaHues.rose,
  NithyaHues.red,
  NithyaHues.sky,
  NithyaHues.violet,
  NithyaHues.teal,
];

/// The shops: open one inside Chanda to browse, sign in and save. Items
/// whose shop turned Chanda's check away are listed first, to open.
class ShopsPage extends ConsumerWidget {
  const ShopsPage({super.key});

  Future<void> _other(BuildContext context) async {
    final c = TextEditingController();
    Uri? url;
    final ok = await showFormDialog(
      context,
      title: 'Open another shop',
      action: 'Open',
      fields: (_) => [Field(c, 'Shop address', hint: 'shop.example.com', autofocus: true)],
      onSave: () async {
        final t = c.text.trim();
        url = linkIn(t) ?? linkIn('https://$t');
        return url == null || !url!.host.contains('.') ? 'That does not look like a web address.' : null;
      },
    );
    if (ok && url != null && context.mounted) await openInApp(context, url!);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final items = ref.watch(allItemsProvider).value ?? const <VaultItem>[];
    final needYou = [
      for (final i in items)
        if (i.status == 'needs-you' && !i.bought) i,
    ];
    final counts = <String, int>{};
    for (final i in items) {
      counts[i.shop] = (counts[i.shop] ?? 0) + 1;
    }
    final mine = {for (final s in ref.watch(myShopsProvider).value ?? const <SeedShop>[]) s.domain};
    final others = [
      for (final id in counts.keys)
        if (shopById(id) == null) shopOf(id),
    ];
    return PageScaffold(
      title: 'Shops',
      banner: 'page.shops',
      children: [
        if (needYou.isNotEmpty)
          SectionCard(
            title: 'Waiting for you',
            hint: 'action.check',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'These shops show prices only to a visitor in person. Open each one, finish any check the shop '
                    'shows, and press Update price.',
                    style: text.bodyMedium,
                  ),
                ),
                for (final i in needYou)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(NithyaRadius.md),
                      child: SizedBox(width: 44, height: 44, child: ItemImage(i)),
                    ),
                    title: Text(i.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(shopOf(i.shop).name),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => openInApp(context, Uri.parse(i.url), item: i),
                  ),
              ],
            ),
          ),
        const SimilarShopsCard(),
        LayoutBuilder(
          builder: (context, c) {
            final cols = columnsFor(c.maxWidth, min: 260);
            final w = (c.maxWidth - (cols - 1) * 16) / cols;
            final all = [...shops, ...others];
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final (n, s) in all.indexed)
                  SizedBox(
                    width: w,
                    child: _ShopTile(
                      shop: s,
                      hue: _hues[n % _hues.length],
                      saved: counts[s.id] ?? 0,
                      onRemove: mine.contains(s.id)
                          ? () async {
                              await MyShops(ref.read(sessionProvider).vault).remove(s.id);
                              ref.read(revisionProvider.notifier).bump();
                              ref.read(syncProvider.notifier).soon();
                            }
                          : null,
                    ),
                  ),
                SizedBox(
                  width: w,
                  child: _ActionTile(
                    icon: Icons.add,
                    title: 'Any other shop',
                    subtitle: 'Type its address',
                    onTap: () => _other(context),
                  ),
                ),
                SizedBox(
                  width: w,
                  child: _ActionTile(
                    icon: Icons.manage_search,
                    title: 'Add a shop to search',
                    subtitle: 'Paste one of its results pages',
                    onTap: () => addToSearch(context, ref),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Extruded(
      onTap: onTap,
      depth: 0.5,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          NithyaIconTile(icon: icon, hue: NithyaHues.slate),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                Text(subtitle, style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopTile extends StatelessWidget {
  const _ShopTile({required this.shop, required this.hue, required this.saved, this.onRemove});
  final Shop shop;
  final Color hue;
  final int saved;

  /// Set for a shop the user added to search.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Extruded(
      onTap: () => openInApp(context, Uri.parse(shop.home)),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NithyaIconTile(icon: Icons.storefront_outlined, hue: hue),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shop.name, style: text.titleMedium),
                    Text(bareHost(Uri.parse(shop.home)), style: text.bodySmall),
                  ],
                ),
              ),
              if (onRemove != null)
                IconButton(
                  tooltip: 'Stop searching ${shop.name}',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: onRemove,
                )
              else
                const Icon(Icons.chevron_right),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (saved > 0) Tag('$saved saved', icon: Icons.favorite),
              if (onRemove != null) const Tag('You added it', icon: Icons.manage_search),
              if (shop.fromAbroad) const Tag('Ships from abroad', icon: Icons.flight_land),
              if (shop.userPresent)
                const Tag('Checked while Chanda is open', icon: Icons.visibility_outlined)
              else
                const Tag('Checked in the background', icon: Icons.schedule),
            ],
          ),
        ],
      ),
    );
  }
}
