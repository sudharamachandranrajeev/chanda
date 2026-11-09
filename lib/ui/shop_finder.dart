import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/links.dart';
import '../domain/shops.dart';
import '../domain/similar_shops.dart';
import 'browser_page.dart';
import 'common.dart';
import 'look.dart';

/// Adds a shop to Chanda's search. A shop that declares its search address
/// (in the list, or on its home page) is added at once; otherwise the user
/// pastes one results address and the words they searched there. With no
/// [shop], any shop can be added that way.
Future<void> addToSearch(BuildContext context, WidgetRef ref, {SeedShop? shop}) async {
  var add = shop;
  if (shop != null && shop.search == null) {
    showMessage(context, 'Looking up how to search ${shop.name}…');
    try {
      final f = await ref.read(shopFactsProvider(shop.home).future);
      if (f.search case final t?) add = _withSearch(shop, t);
    } on Object {
      // Asked for below.
    }
  }
  if (add?.search == null) {
    if (!context.mounted) return;
    add = await _askForSearch(context, ref, shop);
  }
  if (add == null) return;
  await MyShops(ref.read(sessionProvider).vault).add(add);
  ref.read(revisionProvider.notifier).bump();
  ref.read(syncProvider.notifier).soon();
  if (context.mounted) showMessage(context, 'Chanda now searches ${add.name} too.');
}

SeedShop _withSearch(SeedShop s, String search) => SeedShop(
  domain: s.domain,
  name: s.name,
  home: s.home,
  groups: s.groups,
  band: s.band,
  country: s.country,
  currency: s.currency,
  search: search,
);

Future<SeedShop?> _askForSearch(BuildContext context, WidgetRef ref, SeedShop? shop) async {
  final address = TextEditingController(), words = TextEditingController();
  final currency = await ref.read(homeCurrencyProvider.future).catchError((_) => 'GBP');
  SeedShop? out;
  if (!context.mounted) return null;
  await showFormDialog(
    context,
    title: shop == null ? 'Add a shop to search' : 'Add ${shop.name} to search',
    action: 'Add',
    fields: (_) => [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          '${shop == null ? 'In the shop' : '${shop.name} does not say how to search it. In the shop'}, search for '
          'something, then copy the address of the results page and paste it here with the words you searched.',
        ),
      ),
      if (shop != null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: Text('Open ${shop.name}'),
            onPressed: () => openInApp(context, Uri.parse(shop.home)),
          ),
        ),
      Field(
        address,
        'Results page address',
        hint: 'https://shop.example/search?q=desk+lamp',
        autofocus: true,
      ),
      Field(words, 'The words you searched', hint: 'desk lamp'),
    ],
    onSave: () async {
      final url = linkIn(address.text.trim());
      if (url == null || !url.isScheme('https')) return 'Paste the full address, starting https://';
      final domain = registrableDomain(bareHost(url));
      if (shop != null && domain != shop.domain) return 'That address is not on ${shop.domain}.';
      if (shop == null) {
        for (final s in shops) {
          if (s.domains.contains(domain)) return 'Chanda already searches ${s.name}.';
        }
      }
      final t = searchFromExample(url, words.text);
      if (t == null) return 'Those words are not in that address. Check both, or search again in the shop.';
      out = shop != null
          ? _withSearch(shop, t)
          : SeedShop(
              domain: domain,
              name: _nameOf(domain),
              home: url.replace(path: '/', query: '').toString().replaceFirst(RegExp(r'\?$'), ''),
              groups: const [],
              band: 'mid',
              currency: currency,
              search: t,
            );
      return null;
    },
  );
  return out;
}

/// "example.co.uk" → "Example".
String _nameOf(String domain) {
  final first = domain.split('.').first;
  return first.isEmpty ? domain : first[0].toUpperCase() + first.substring(1);
}

/// Shops like the ones the user saves from, with why, to check and add.
class SimilarShopsCard extends ConsumerWidget {
  const SimilarShopsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final similar = ref.watch(similarShopsProvider).value ?? const [];
    if (similar.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return SectionCard(
      title: 'Shops like yours',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Picked from a list kept with Chanda, by what you save and what you pay. No shop pays to be here.',
              style: text.bodySmall?.copyWith(color: muted(context)),
            ),
          ),
          for (final s in similar.take(6))
            ListTile(
              key: ValueKey('similar-${s.shop.domain}'),
              contentPadding: EdgeInsets.zero,
              title: Text(s.shop.name),
              subtitle: Text('${s.shop.domain} · ${s.why.join('. ')}'),
              onTap: () => openInApp(context, Uri.parse(s.shop.home)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Check this shop',
                    icon: const Icon(Icons.fact_check_outlined),
                    onPressed: () => showShopFacts(context, s.shop),
                  ),
                  IconButton(
                    tooltip: 'Add to my search',
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => addToSearch(context, ref, shop: s.shop),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// What the shop and its domain registry publish about it, to judge for
/// oneself.
Future<void> showShopFacts(BuildContext context, SeedShop shop) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(shop.name),
    scrollable: true,
    content: SizedBox(width: 440, child: _Facts(shop)),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
  ),
);

class _Facts extends ConsumerWidget {
  const _Facts(this.shop);
  final SeedShop shop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facts = ref.watch(shopFactsProvider(shop.home));
    final text = Theme.of(context).textTheme;
    return facts.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text(describeError(e)),
      data: (f) {
        Widget row(IconData icon, String label, String value) => ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: Icon(icon),
          title: Text(label),
          subtitle: Text(value),
        );
        Widget link(IconData icon, String label, Uri url) => ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: Icon(icon),
          title: Text(label),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => openInApp(context, url),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            row(
              Icons.history,
              'Web address first registered',
              f.registered != null
                  ? '${f.registered}'
                  : f.registryChecked
                  ? 'The registry did not say'
                  : 'Unknown: the registry could not be asked',
            ),
            row(
              f.secure ? Icons.lock_outline : Icons.lock_open,
              'Secure connection',
              f.secure ? 'Yes' : 'Not confirmed',
            ),
            if (f.company.isNotEmpty) row(Icons.business, 'Company', f.company),
            if (f.country.isNotEmpty) row(Icons.place_outlined, 'Country', f.country),
            if (f.email.isNotEmpty) row(Icons.mail_outline, 'Email', f.email),
            if (f.phone.isNotEmpty) row(Icons.call_outlined, 'Phone', f.phone),
            if (Uri.tryParse(f.returns) case final r? when r.isScheme('https'))
              link(Icons.assignment_return_outlined, 'Returns policy', r),
            link(Icons.reviews_outlined, 'Read what buyers say', f.reviews),
            const SizedBox(height: 8),
            if (!f.pageRead)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'The shop\'s page could not be read, so its own details are missing.',
                  style: text.bodySmall,
                ),
              ),
            Text(
              'These are facts the shop and its registry publish, not a verdict. An old address is a good sign, '
              'not a promise. Checked ${f.domain} within the last month.',
              style: text.bodySmall?.copyWith(color: muted(context)),
            ),
          ],
        );
      },
    );
  }
}
