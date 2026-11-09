import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nithya/nithya.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/money.dart';
import '../domain/vault.dart';
import '../domain/watch.dart';
import 'look.dart';

/// An item's picture [index]: the copy kept on this device, else the
/// shop's own, else a quiet placeholder.
class ItemImage extends ConsumerWidget {
  const ItemImage(this.item, {super.key, this.index = 0, this.fit = BoxFit.cover});
  final VaultItem item;
  final int index;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kept = ref.watch(keptImageProvider((item.id, index))).value;
    final urls = imagesOf(item);
    final placeholder = ColoredBox(
      color: NithyaPalette.of(context).controls,
      child: Center(child: Icon(Icons.shopping_bag_outlined, size: 36, color: muted(context))),
    );
    Widget fade(Widget child, int? frame) => AnimatedOpacity(
      opacity: frame == null ? 0 : 1,
      duration: NithyaMotion.slow,
      curve: Curves.easeOut,
      child: child,
    );
    if (kept != null) {
      return Image.file(
        kept,
        fit: fit,
        frameBuilder: (_, child, frame, sync) => sync ? child : fade(child, frame),
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    if (index < urls.length) {
      return Image.network(
        urls[index],
        fit: fit,
        headers: const {'user-agent': 'Chanda/0.1'},
        frameBuilder: (_, child, frame, sync) => sync ? child : fade(child, frame),
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    return placeholder;
  }
}

/// How much [now] is below [before], as a whole per cent; null if not.
int? dropPercent(int? before, int? now) {
  if (before == null || now == null || before <= 0 || now >= before) return null;
  return ((before - now) * 100 / before).round();
}

/// The tag that says how fresh an item's price is, or what is wrong.
Widget freshnessTag(VaultItem i, {DateTime? now}) {
  final t = now ?? DateTime.now().toUtc();
  return switch (i.status) {
    'needs-you' => const Tag('Open the shop to check', icon: Icons.touch_app_outlined, color: attention),
    'gone' => const Tag('Listing gone', icon: Icons.link_off, color: NithyaAccent.danger),
    'failed' => Tag('Could not read · ${ago(i.checked, t)}', icon: Icons.error_outline, color: attention),
    _ when !i.inStock => const Tag(
      'Out of stock',
      icon: Icons.remove_shopping_cart_outlined,
      color: attention,
    ),
    _ => switch (freshness(i.checked, t)) {
      Freshness.fresh => Tag('Checked ${ago(i.checked, t)}', icon: Icons.check),
      Freshness.stale => Tag('Checked ${ago(i.checked, t)}', icon: Icons.schedule),
      Freshness.never => const Tag('Not checked yet', icon: Icons.schedule),
    },
  };
}

/// The price as the shop shows it, with the struck "was" beside it.
class PriceLine extends StatelessWidget {
  const PriceLine(this.item, {super.key, this.big = false});
  final VaultItem item;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final p = NithyaPalette.of(context);
    final price = item.price;
    final style = (big ? NithyaType.title : NithyaType.heading).toStyle(color: p.foreground);
    if (price == null) return Text('No price yet', style: NithyaType.body.toStyle(color: p.muted));
    final now = showPrice(price, item.currency);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 8,
      children: [
        if (big)
          GlowText(now, style: style, color: p.foreground)
        else
          Text(now, style: style.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        if (item.was != null && item.was! > price)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              showPrice(item.was!, item.currency),
              style: NithyaType.caption
                  .toStyle(color: p.muted)
                  .copyWith(decoration: TextDecoration.lineThrough),
            ),
          ),
      ],
    );
  }
}
