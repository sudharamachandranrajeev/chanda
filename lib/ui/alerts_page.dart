import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nithya/nithya.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/money.dart';
import '../domain/watch.dart';
import 'item_page.dart';
import 'look.dart';

/// Every alert Chanda raised, newest first. Opening the page marks them
/// seen; the unseen ones keep their glow until the user leaves.
class AlertsPage extends ConsumerStatefulWidget {
  const AlertsPage({super.key});

  @override
  ConsumerState<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends ConsumerState<AlertsPage> {
  Set<String>? _fresh;

  @override
  Widget build(BuildContext context) {
    final alerts = ref.watch(alertsProvider);
    final items = {for (final i in ref.watch(allItemsProvider).value ?? const <VaultItem>[]) i.id: i};
    // Note which were unseen on arrival, then mark them seen.
    if (_fresh == null && alerts.hasValue) {
      _fresh = {
        for (final a in alerts.value!)
          if (!a.seen) a.id,
      };
      if (_fresh!.isNotEmpty) Future.microtask(() => ref.mutate((v) => v.markAlertsSeen()));
    }
    return PageScaffold(
      title: 'Alerts',
      body: AsyncView(
        alerts,
        builder: (list) {
          final shown = [
            for (final a in list)
              if (items.containsKey(a.itemId)) a,
          ];
          return ListView(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 110 + MediaQuery.paddingOf(context).bottom),
            children: [
              const Readable(child: HintBanner('page.alerts')),
              if (shown.isEmpty)
                const EmptyState(
                  icon: Icons.notifications_none,
                  title: 'No alerts yet',
                  message: 'Price drops, your target prices and things back in stock show up here and on this device.',
                ),
              for (final (n, a) in shown.indexed)
                Readable(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FadeIn(
                      delay: Duration(milliseconds: 30 * n.clamp(0, 10)),
                      child: _AlertTile(a, items[a.itemId]!, fresh: _fresh?.contains(a.id) ?? false),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile(this.a, this.item, {required this.fresh});
  final AlertEvent a;
  final VaultItem item;
  final bool fresh;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (icon, colour, title) = switch (a.kind) {
      'target' => (Icons.flag, drop, 'At your price'),
      'drop' => (Icons.south, drop, 'Price drop'),
      'stock' => (Icons.inventory_2_outlined, NithyaAccent.primary, 'Back in stock'),
      _ => (Icons.notifications_outlined, muted(context), 'Test'),
    };
    final change = [
      if (a.before != null) showPrice(a.before!, a.currency),
      if (a.after != null) showPrice(a.after!, a.currency),
    ].join('  →  ');
    return Extruded(
      glow: fresh ? colour : null,
      depth: 0.6,
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ItemPage(item.id))),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colour.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(NithyaRadius.lg),
            ),
            child: Icon(icon, color: colour),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: text.titleSmall?.copyWith(color: colour)),
                    const SizedBox(width: 8),
                    Text(ago(a.at, DateTime.now().toUtc()), style: text.bodySmall),
                  ],
                ),
                const SizedBox(height: 2),
                Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
                if (change.isNotEmpty) Text(change, style: text.labelLarge?.merge(tabular)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
