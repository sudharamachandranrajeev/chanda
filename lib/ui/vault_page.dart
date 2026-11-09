import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nithya/nithya.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/images.dart';
import '../domain/links.dart';
import '../domain/shops.dart';
import '../domain/vault.dart';
import 'common.dart';
import 'item_bits.dart';
import 'item_page.dart';
import 'look.dart';
import 'save_flow.dart';

const _sortNames = {
  VaultSort.added: 'Newest first',
  VaultSort.priceLow: 'Price, low to high',
  VaultSort.priceHigh: 'Price, high to low',
  VaultSort.drop: 'Biggest drop',
  VaultSort.title: 'Name',
};

/// Everything the user wants to buy, from every shop.
class VaultPage extends ConsumerStatefulWidget {
  const VaultPage({super.key});

  @override
  ConsumerState<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends ConsumerState<VaultPage> {
  final _selected = <String>{};
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(String id) =>
      setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));

  Future<void> _add() async {
    final clip = linkIn(await clipboardText());
    if (mounted) await askForLink(context, initial: clip == null ? '' : '$clip');
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(vaultViewProvider);
    final items = ref.watch(shownItemsProvider);
    final checking = ref.watch(liveChecksProvider);
    return PageScaffold(
      title: 'Vault',
      actions: [
        if (checking)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Tooltip(
              message: 'Checking prices',
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
        PopupMenuButton<VaultSort>(
          tooltip: 'Sort',
          icon: const Icon(Icons.sort),
          initialValue: view.sort,
          onSelected: (s) => ref.read(vaultViewProvider.notifier).set(view.copyWith(sort: s)),
          itemBuilder: (_) => [
            for (final e in _sortNames.entries) PopupMenuItem(value: e.key, child: Text(e.value)),
          ],
        ),
      ],
      fab: _selected.isEmpty
          ? FloatingActionButton.extended(
              heroTag: 'vault-add',
              icon: const Icon(Icons.add_link),
              label: const Text('Add from link'),
              onPressed: _add,
            )
          : null,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Readable(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const HintBanner('page.vault'),
                          TextField(
                            controller: _search,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              hintText: 'Search your vault',
                              suffixIcon: view.query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear',
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        _search.clear();
                                        ref.read(vaultViewProvider.notifier).set(view.copyWith(query: ''));
                                      },
                                    ),
                            ),
                            onChanged: (q) =>
                                ref.read(vaultViewProvider.notifier).set(view.copyWith(query: q)),
                          ),
                          const SizedBox(height: 12),
                          _ListChips(view: view),
                          _TagChips(view: view),
                        ],
                      ),
                    ),
                  ),
                ),
                ...switch (items) {
                  AsyncData(:final value) when value.isEmpty => [
                    SliverToBoxAdapter(
                      child: _Empty(filtered: view.query.isNotEmpty || view.tag != null, onAdd: _add),
                    ),
                  ],
                  AsyncData(:final value) => [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 120 + MediaQuery.paddingOf(context).bottom),
                      sliver: SliverLayoutBuilder(
                        builder: (context, c) {
                          // Keep the grid to a readable width on wide windows.
                          final side = c.crossAxisExtent > 1200 ? (c.crossAxisExtent - 1200) / 2 : 0.0;
                          return SliverPadding(
                            padding: EdgeInsets.symmetric(horizontal: side),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 270,
                                mainAxisExtent: 336,
                                crossAxisSpacing: 18,
                                mainAxisSpacing: 20,
                              ),
                              delegate: SliverChildBuilderDelegate(childCount: value.length, (context, n) {
                                final i = value[n];
                                return FadeIn(
                                  delay: Duration(milliseconds: 30 * n.clamp(0, 10)),
                                  child: ItemCard(
                                    i,
                                    selected: _selected.contains(i.id),
                                    onTap: _selected.isNotEmpty
                                        ? () => _toggle(i.id)
                                        : () => Navigator.of(context)
                                              .push(MaterialPageRoute<void>(builder: (_) => ItemPage(i.id))),
                                    onLongPress: () => _toggle(i.id),
                                  ),
                                );
                              }),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  AsyncError(:final error) => [SliverToBoxAdapter(child: ErrorPanel(describeError(error)))],
                  _ => [
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  ],
                },
              ],
            ),
          ),
          AnimatedSize(
            duration: NithyaMotion.slow,
            curve: Motion.curve,
            child: _selected.isEmpty ? const SizedBox(width: double.infinity) : _selectionBar(context),
          ),
        ],
      ),
    );
  }

  Widget _selectionBar(BuildContext context) {
    Future<void> each(Future<void> Function(Vault v, VaultItem i) f) async {
      final all = ref.read(allItemsProvider).value ?? const <VaultItem>[];
      await ref.mutate((v) async {
        for (final i in all.where((i) => _selected.contains(i.id))) {
          await f(v, i);
        }
      });
      setState(_selected.clear);
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        child: Readable(
          child: Extruded(
            glow: NithyaAccent.primary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('${_selected.length} chosen', style: Theme.of(context).textTheme.labelLarge),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.drive_file_move_outline),
                  label: const Text('Move'),
                  onPressed: () async {
                    final listId = await _pickList(context, ref);
                    if (listId != null) await each((v, i) => v.moveItem(i, listId));
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.sell_outlined),
                  label: const Text('Tag'),
                  onPressed: () async {
                    final c = TextEditingController();
                    final ok = await showFormDialog(
                      context,
                      title: 'Add a tag',
                      action: 'Add',
                      fields: (_) => [Field(c, 'Tag', autofocus: true)],
                      onSave: () async => c.text.trim().isEmpty ? 'Type a tag.' : null,
                    );
                    final tag = c.text.trim().replaceAll(',', ' ');
                    if (ok) {
                      await each((v, i) => v.updateItem(i.copyWith(tags: {...tagsOf(i), tag}.join(','))));
                    }
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Bought'),
                  onPressed: () => each((v, i) => v.updateItem(i.copyWith(bought: !i.bought))),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                  onPressed: () async {
                    final n = _selected.length;
                    if (await askSure(context, 'Delete $n?', 'Their price history goes too.')) {
                      final ids = {..._selected};
                      await each((v, i) => v.removeItem(i.id));
                      for (final id in ids) {
                        await forgetImages(id);
                      }
                    }
                  },
                ),
                IconButton(
                  tooltip: 'Cancel',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(_selected.clear),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks which list; null when cancelled.
Future<String?> _pickList(BuildContext context, WidgetRef ref) async {
  final lists = await ref.read(listsProvider.future);
  if (!context.mounted) return null;
  return showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('Move to')),
          for (final l in lists)
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: Text(l.name),
              onTap: () => Navigator.pop(context, l.id),
            ),
        ],
      ),
    ),
  );
}

class _ListChips extends ConsumerWidget {
  const _ListChips({required this.view});
  final VaultView view;

  Future<void> _newList(BuildContext context, WidgetRef ref) async {
    final c = TextEditingController();
    String? id;
    await showFormDialog(
      context,
      title: 'New list',
      action: 'Add',
      fields: (_) => [Field(c, 'Name', hint: 'Birthday, Kitchen, Winter clothes', autofocus: true)],
      onSave: () async {
        if (c.text.trim().isEmpty) return 'Give it a name.';
        id = await ref.mutate((v) => v.addList(c.text));
        return null;
      },
    );
    if (id != null) ref.read(vaultViewProvider.notifier).set(view.copyWith(listId: () => id));
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, VaultList l) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(l.name)),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete list and its items'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'rename') {
      final c = TextEditingController(text: l.name);
      await showFormDialog(
        context,
        title: 'Rename list',
        fields: (_) => [Field(c, 'Name', autofocus: true)],
        onSave: () async {
          if (c.text.trim().isEmpty) return 'Give it a name.';
          await ref.mutate((v) => v.renameList(l, c.text));
          return null;
        },
      );
    } else if (action == 'delete' &&
        await askSure(context, 'Delete ${l.name}?', 'Every item in it and their price history go too.')) {
      await ref.mutate((v) => v.removeList(l.id));
      ref.read(vaultViewProvider.notifier).set(view.copyWith(listId: () => null));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(listsProvider).value ?? const <VaultList>[];
    final set = ref.read(vaultViewProvider.notifier).set;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Everything'),
            selected: view.listId == null,
            onSelected: (_) => set(view.copyWith(listId: () => null)),
          ),
          for (final l in lists)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onLongPress: () => _edit(context, ref, l),
                onSecondaryTap: () => _edit(context, ref, l),
                child: ChoiceChip(
                  label: Text(l.name),
                  selected: view.listId == l.id,
                  onSelected: (_) => set(view.copyWith(listId: () => l.id)),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('New list'),
              onPressed: () => _newList(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChips extends ConsumerWidget {
  const _TagChips({required this.view});
  final VaultView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagsProvider);
    if (tags.isEmpty) return const SizedBox.shrink();
    final set = ref.read(vaultViewProvider.notifier).set;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final t in tags.take(30))
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text('#$t'),
                  visualDensity: VisualDensity.compact,
                  selected: view.tag == t,
                  onSelected: (on) => set(view.copyWith(tag: () => on ? t : null)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.filtered, required this.onAdd});
  final bool filtered;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => filtered
      ? const EmptyState(icon: Icons.search_off, title: 'Nothing matches')
      : EmptyState(
          icon: Icons.favorite_border,
          title: 'Your vault is empty',
          message:
              'Open a shop on the Shops page and press Save on anything you like, share a product to Chanda from '
              'another app, or paste a link.',
          actions: [
            FilledButton.icon(
              icon: const Icon(Icons.add_link),
              label: const Text('Paste a link'),
              onPressed: onAdd,
            ),
          ],
        );
}

/// One saved product: picture, shop, name, price and how fresh it is,
/// glowing when its price has dropped.
class ItemCard extends ConsumerWidget {
  const ItemCard(this.item, {super.key, this.onTap, this.onLongPress, this.selected = false});
  final VaultItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = NithyaPalette.of(context);
    final text = Theme.of(context).textTheme;
    final previous = ref.watch(previousPricesProvider).value?[item.id];
    final down = dropPercent(previous, item.price);
    final atTarget = item.target != null && item.price != null && item.price! <= item.target!;
    return Opacity(
      opacity: item.bought ? 0.55 : 1,
      child: Extruded(
        onTap: onTap,
        onLongPress: onLongPress,
        selected: selected,
        glow: atTarget || down != null ? drop : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 178,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(tag: 'item-${item.id}', child: ItemImage(item)),
                  // Shade so the badges read on any picture.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment(0, -0.2),
                        colors: [Color(0x55000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: Row(
                      children: [
                        if (atTarget)
                          const Flexible(
                            child: GlowBadge(label: 'At your price', color: drop, icon: Icons.flag),
                          )
                        else if (down != null)
                          Flexible(
                            child: GlowBadge(label: '−$down%', color: drop, icon: Icons.south),
                          ),
                        const Spacer(),
                        if (selected) const Icon(Icons.check_circle, color: NithyaAccent.primary),
                        if (item.bought && !selected) const Tag('Bought', icon: Icons.check),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shopOf(item.shop).name.toUpperCase(),
                      style: text.labelSmall?.copyWith(color: p.muted),
                    ),
                    const SizedBox(height: 3),
                    Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                    const Spacer(),
                    PriceLine(item),
                    const SizedBox(height: 6),
                    freshnessTag(item),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
