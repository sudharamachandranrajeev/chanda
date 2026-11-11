import 'dart:math' as math;

import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nithya/nithya.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/checker.dart';
import '../domain/frame_size.dart';
import '../domain/garment_fit.dart';
import '../domain/images.dart';
import '../domain/money.dart';
import '../domain/shops.dart';
import '../domain/vault.dart';
import '../domain/watch.dart';
import 'browser_page.dart';
import 'clothes_page.dart';
import 'common.dart';
import 'compare_card.dart';
import 'glasses_page.dart';
import 'item_bits.dart';
import 'look.dart';

/// One saved product: its pictures, price and history, what it costs
/// delivered, its alerts, and the way to buy it.
class ItemPage extends ConsumerWidget {
  const ItemPage(this.id, {super.key});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(itemProvider(id));
    return Scaffold(
      body: AsyncView(
        item,
        builder: (i) => i == null ? const Center(child: Text('This item was deleted.')) : _Body(i),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body(this.item);
  final VaultItem item;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  var _checking = false;
  VaultItem get i => widget.item;

  Future<void> _checkNow() async {
    setState(() => _checking = true);
    try {
      final r = await ref.read(liveChecksProvider.notifier).checkNow(i);
      if (!mounted) return;
      showMessage(context, switch (r) {
        CheckResult.ok => 'Checked: the price is as shown.',
        CheckResult.alerted => 'Checked: the price changed, see Alerts.',
        CheckResult.needsYou => 'The shop wants you there: open it, then press Update price.',
        CheckResult.gone => 'The shop says this listing is gone.',
        CheckResult.failed => 'Could not read the price this time.',
        CheckResult.skipped => 'Skipped.',
      });
    } on Object catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _typePrice() async {
    final c = TextEditingController();
    await showFormDialog(
      context,
      title: 'Price you see',
      fields: (_) => [
        Text('Type the price ${shopOf(i.shop).name} shows you, in ${i.currency}.'),
        const SizedBox(height: 12),
        Field(c, 'Price', number: true, autofocus: true),
      ],
      onSave: () async {
        final n =
            parsePrice(c.text, hint: i.currency)?.minor ??
            parseAmount(c.text.trim(), scale: currencyInfo(i.currency).scale);
        if (n == null || n <= 0) return 'Type a price.';
        await ref.mutate((v) => v.setManualPrice(i, n));
        return null;
      },
    );
  }

  Future<void> _target() async {
    final c = TextEditingController(
      text: i.target == null ? '' : (i.target! / math.pow(10, currencyInfo(i.currency).scale)).toString(),
    );
    await showFormDialog(
      context,
      title: 'Alert me at',
      fields: (_) => [
        const Text('Chanda alerts you when the price reaches this or less. Leave empty for none.'),
        const SizedBox(height: 12),
        Field(c, 'Target price (${i.currency})', number: true, autofocus: true),
      ],
      onSave: () async {
        final t = c.text.trim();
        final n = t.isEmpty
            ? null
            : parsePrice(t, hint: i.currency)?.minor ?? parseAmount(t, scale: currencyInfo(i.currency).scale);
        if (t.isNotEmpty && n == null) return 'Type a price.';
        await ref.mutate((v) => v.updateItem(i.copyWith(target: Value(n))));
        return null;
      },
    );
  }

  Future<void> _notes() async {
    final note = TextEditingController(text: i.note);
    final tags = TextEditingController(text: tagsOf(i).join(', '));
    final title = TextEditingController(text: i.title);
    await showFormDialog(
      context,
      title: 'Edit',
      fields: (_) => [
        Field(title, 'Name'),
        Field(tags, 'Tags', hint: 'gift, summer, desk'),
        Field(note, 'Note', lines: 3),
      ],
      onSave: () async {
        if (title.text.trim().isEmpty) return 'Give it a name.';
        final t = tags.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).join(',');
        await ref.mutate(
          (v) => v.updateItem(i.copyWith(title: title.text.trim(), note: note.text.trim(), tags: t)),
        );
        return null;
      },
    );
  }

  Future<void> _delete() async {
    if (!await askSure(context, 'Delete ${i.title}?', 'Its price history goes too.')) return;
    await ref.mutate((v) => v.removeItem(i.id));
    await forgetImages(i.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = NithyaPalette.of(context);
    final text = Theme.of(context).textTheme;
    final shop = shopOf(i.shop);
    final images = imagesOf(i);
    final history = ref.watch(historyProvider(i.id)).value ?? const <PricePoint>[];
    final landed = landedFor(ref, i);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final listName = ref.watch(listsProvider).value?.where((l) => l.id == i.listId).firstOrNull?.name ?? '';

    final gallery = Extruded(
      child: AspectRatio(
        aspectRatio: 1,
        child: PageView.builder(
          itemCount: math.max(1, math.min(images.length, 5)),
          itemBuilder: (_, n) => n == 0
              ? Hero(
                  tag: 'item-${i.id}',
                  child: ItemImage(i, fit: BoxFit.contain),
                )
              : ItemImage(i, index: n, fit: BoxFit.contain),
        ),
      ),
    );

    final head = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Tag(shop.name, icon: Icons.storefront_outlined),
            if (i.brand.isNotEmpty) Tag(i.brand),
            freshnessTag(i),
            for (final t in tagsOf(i)) Tag('#$t'),
          ],
        ),
        const SizedBox(height: 12),
        Text(i.title, style: text.headlineSmall),
        const SizedBox(height: 12),
        PriceLine(i, big: true),
        if (landed != null &&
            (landed.parts.length > 1 || i.currency != (ref.watch(homeCurrencyProvider).value ?? i.currency)))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${landed.estimate ? 'About ' : ''}${showPrice(landed.total, ref.watch(homeCurrencyProvider).value ?? i.currency)} delivered',
              style: text.bodyMedium?.copyWith(color: p.muted),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('Your rating', style: text.bodyMedium?.copyWith(color: p.muted)),
            const SizedBox(width: 6),
            Stars(
              value: ref.watch(ratingsProvider).value?[i.url]?.stars,
              onChanged: (n) async {
                final t = await ref.read(tasteProvider.future);
                await (n == null ? t.unrate(i.url) : t.rateItem(i, n));
                ref.read(revisionProvider.notifier).bump();
                ref.read(syncProvider.notifier).soon();
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.shopping_cart_checkout),
              label: Text('Buy at ${shop.name}'),
              onPressed: () => openInApp(context, Uri.parse(i.url), item: i),
            ),
            Hint(
              'action.check',
              child: OutlinedButton.icon(
                icon: _checking
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                label: const Text('Check now'),
                onPressed: _checking ? null : _checkNow,
              ),
            ),
            if (isGlasses(title: i.title, tags: i.tags, list: listName))
              OutlinedButton.icon(
                icon: const Icon(Icons.face_retouching_natural_outlined),
                label: const Text('Try on'),
                onPressed: () =>
                    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => GlassesPage(i))),
              )
            else if (garmentKind(title: i.title, tags: i.tags, list: listName) case final kind?)
              OutlinedButton.icon(
                icon: const Icon(Icons.checkroom_outlined),
                label: const Text('Try on'),
                onPressed: () =>
                    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ClothesPage(i, kind))),
              ),
          ],
        ),
        if (i.status == 'needs-you' || i.status == 'failed' || i.price == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Type the price yourself'),
              onPressed: _typePrice,
            ),
          ),
      ],
    );

    final cards = [
      SectionCard(
        title: 'Price history',
        child: history.length < 2
            ? Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  history.isEmpty
                      ? 'No prices yet.'
                      : 'One price so far. Chanda adds a point each day it checks.',
                  style: text.bodyMedium?.copyWith(color: p.muted),
                ),
              )
            : PriceChart(history, currency: i.currency, target: i.target),
      ),
      // Only when there is more to it than the price itself.
      if (landed != null && (landed.parts.length > 1 || landed.estimate))
        SectionCard(
          title: 'Delivered to you',
          hint: 'action.landed',
          child: _LandedView(landed, home: ref.watch(homeCurrencyProvider).value ?? i.currency),
        ),
      SectionCard(
        title: 'Alerts',
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Alert me at'),
              trailing: Text(i.target == null ? 'Set a price' : showPrice(i.target!, i.currency)),
              onTap: _target,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.south),
              title: const Text('When the price drops'),
              value: i.alertDrop,
              onChanged: (v) => ref.mutate((x) => x.updateItem(i.copyWith(alertDrop: v))),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.inventory_2_outlined),
              title: const Text('When back in stock'),
              value: i.alertStock,
              onChanged: (v) => ref.mutate((x) => x.updateItem(i.copyWith(alertStock: v))),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.visibility_outlined),
              title: const Text('Watch closely'),
              subtitle: Text('Checked every ${checkEvery(i.copyWith(failures: 0)).inHours} hours.'),
              value: i.watchClose,
              onChanged: (v) => ref.mutate((x) => x.updateItem(i.copyWith(watchClose: v))),
            ),
          ],
        ),
      ),
      SectionCard(
        title: 'Details',
        trailing: IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined), onPressed: _notes),
        child: _Details(i),
      ),
      Wrap(
        spacing: 8,
        children: [
          TextButton.icon(
            icon: Icon(i.bought ? Icons.undo : Icons.check),
            label: Text(i.bought ? 'Not bought yet' : 'Mark as bought'),
            onPressed: () => ref.mutate((v) => v.updateItem(i.copyWith(bought: !i.bought))),
          ),
          TextButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open in browser'),
            onPressed: () => openLink(context, i.url),
          ),
          TextButton.icon(
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: NithyaAccent.danger),
            onPressed: _delete,
          ),
        ],
      ),
    ];

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: p.background.withValues(alpha: 0.85),
          title: Text(shop.name),
        ),
        SliverToBoxAdapter(
          child: Readable(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + MediaQuery.paddingOf(context).bottom),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(children: [gallery, const SizedBox(height: 20), ...cards.take(2)]),
                        ),
                        const SizedBox(width: 28),
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FadeIn(child: head),
                              const SizedBox(height: 24),
                              FadeIn(child: CompareCard(i)),
                              for (final (n, c) in cards.skip(2).indexed)
                                FadeIn(
                                  delay: Duration(milliseconds: 60 * n),
                                  child: c,
                                ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: gallery,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FadeIn(child: head),
                        const SizedBox(height: 20),
                        FadeIn(child: CompareCard(i)),
                        for (final (n, c) in cards.indexed)
                          FadeIn(
                            delay: Duration(milliseconds: 50 * n),
                            child: c,
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LandedView extends StatelessWidget {
  const _LandedView(this.landed, {required this.home});
  final Landed landed;
  final String home;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget row(String label, int v, {bool total = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: total ? text.titleSmall : text.bodyMedium)),
          Text(showPrice(v, home), style: (total ? text.titleSmall : text.bodyMedium)?.merge(tabular)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (label, v) in landed.parts) row(label, v),
        const Divider(height: 16),
        row(landed.estimate ? 'About' : 'Total', landed.total, total: true),
        if (landed.note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(landed.note, style: text.bodySmall),
          ),
      ],
    );
  }
}

class _Details extends StatelessWidget {
  const _Details(this.i);
  final VaultItem i;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final variant = variantOf(i);
    final rows = <(String, String)>[
      if (i.seller.isNotEmpty) ('Sold by', i.seller),
      if (i.rating != null)
        (
          'Rating',
          '${i.rating!.toStringAsFixed(1)} of 5${i.reviews == null ? '' : ' from ${i.reviews} reviews'}',
        ),
      if (i.warranty.isNotEmpty) ('Warranty', i.warranty),
      for (final e in variant.entries) (e.key, e.value),
      if (i.gtin.isNotEmpty) ('Barcode', i.gtin),
      if (i.mpn.isNotEmpty) ('Model', i.mpn),
      if (i.note.isNotEmpty) ('Note', i.note),
      (
        'Price read from',
        switch (i.layer) {
          'json-ld' || 'microdata' => 'the shop\'s product data',
          'meta' => 'the page\'s summary',
          'embedded' => 'the page\'s own data',
          'page' => 'the price shown on the page',
          'typed' => 'you',
          _ => 'not read yet',
        },
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 130,
                  child: Text(k, style: text.bodyMedium?.copyWith(color: muted(context))),
                ),
                Expanded(child: SelectableText(v, style: text.bodyMedium)),
              ],
            ),
          ),
        if (i.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(i.description, maxLines: 6, overflow: TextOverflow.ellipsis, style: text.bodySmall),
          ),
      ],
    );
  }
}

/// An item's price over time: a stepped line (a price holds until it
/// changes), lowest and highest marked, the target as a dashed line.
class PriceChart extends StatelessWidget {
  const PriceChart(this.points, {super.key, required this.currency, this.target});
  final List<PricePoint> points;
  final String currency;
  final int? target;

  @override
  Widget build(BuildContext context) {
    final p = NithyaPalette.of(context);
    final same = points.where((x) => x.currency == currency).toList();
    final prices = same.map((x) => x.price);
    final low = prices.reduce(math.min), high = prices.reduce(math.max);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: 'Price history: lowest ${showPrice(low, currency)}, highest ${showPrice(high, currency)}',
          child: SizedBox(
            height: 180,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Motion.reduced(context) ? Duration.zero : const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, t, _) => CustomPaint(
                painter: _ChartPainter(
                  same,
                  target: target,
                  line: NithyaAccent.primary,
                  grid: p.divider,
                  targetColour: drop,
                  label: NithyaType.caption.toStyle(color: p.muted),
                  currency: currency,
                  reveal: t,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          children: [
            Text('Lowest ${showPrice(low, currency)}', style: text.bodySmall),
            Text('Highest ${showPrice(high, currency)}', style: text.bodySmall),
            Text('Since ${dayLabel(same.first.seen)}', style: text.bodySmall),
          ],
        ),
      ],
    );
  }
}

String dayLabel(String iso) {
  final t = DateTime.tryParse(iso)?.toLocal();
  if (t == null) return '';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${t.day} ${months[t.month - 1]}';
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(
    this.points, {
    required this.target,
    required this.line,
    required this.grid,
    required this.targetColour,
    required this.label,
    required this.currency,
    required this.reveal,
  });

  final List<PricePoint> points;
  final int? target;
  final Color line, grid, targetColour;
  final TextStyle label;
  final String currency;
  final double reveal;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final times = [for (final x in points) DateTime.parse(x.seen).millisecondsSinceEpoch.toDouble()];
    final now = DateTime.now().millisecondsSinceEpoch.toDouble();
    final t0 = times.first, t1 = math.max(now, times.last + 1);
    var lo = points.map((x) => x.price).reduce(math.min).toDouble();
    var hi = points.map((x) => x.price).reduce(math.max).toDouble();
    if (target != null) {
      lo = math.min(lo, target!.toDouble());
      hi = math.max(hi, target!.toDouble());
    }
    final pad = math.max((hi - lo) * 0.15, hi * 0.02 + 1);
    lo -= pad;
    hi += pad;
    const left = 0.0, right = 64.0, top = 8.0, bottom = 8.0;
    final w = size.width - left - right, h = size.height - top - bottom;
    double x(double t) => left + (t - t0) / (t1 - t0) * w;
    double y(num v) => top + (1 - (v - lo) / (hi - lo)) * h;

    // Three faint guide lines, priced on the right.
    for (final f in [0.0, 0.5, 1.0]) {
      final v = lo + pad + (hi - lo - 2 * pad) * f;
      final yy = y(v);
      canvas.drawLine(
        Offset(left, yy),
        Offset(left + w, yy),
        Paint()
          ..color = grid
          ..strokeWidth = 1,
      );
      final tp = TextPainter(
        text: TextSpan(text: showPrice(v.round(), currency), style: label),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: right - 6);
      tp.paint(canvas, Offset(left + w + 6, yy - tp.height / 2));
    }

    final path = Path()..moveTo(x(times.first), y(points.first.price));
    for (var n = 1; n < points.length; n++) {
      path
        ..lineTo(x(times[n]), y(points[n - 1].price))
        ..lineTo(x(times[n]), y(points[n].price));
    }
    path.lineTo(x(t1), y(points.last.price));

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, left + w * reveal, size.height));
    final fill = Path.from(path)
      ..lineTo(x(t1), top + h)
      ..lineTo(x(times.first), top + h)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [line.withValues(alpha: 0.28), line.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, top, size.width, h)),
    );
    // A soft glow under the line, then the line.
    canvas.drawPath(
      path,
      Paint()
        ..color = line.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();

    if (target != null) {
      final yy = y(target!);
      final dash = Paint()
        ..color = targetColour
        ..strokeWidth = 1.4;
      for (var xx = left; xx < left + w; xx += 9) {
        canvas.drawLine(Offset(xx, yy), Offset(math.min(xx + 5, left + w), yy), dash);
      }
    }
    // The latest price as a dot.
    canvas.drawCircle(Offset(x(t1), y(points.last.price)), 4, Paint()..color = line);
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.points != points || old.reveal != reveal || old.target != target || old.line != line;
}
