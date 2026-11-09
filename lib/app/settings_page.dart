import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nithya/nithya.dart';

import '../domain/ai_reader.dart';
import '../domain/embeddings.dart';
import '../domain/money.dart';
import '../domain/notify.dart';
import '../domain/vault.dart';
import '../ui/common.dart';
import '../ui/look.dart';
import 'background.dart';
import 'providers.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => const PageScaffold(
    title: 'Settings',
    children: [
      _TrustCard(),
      _LookCard(),
      _MoneyCard(),
      _AlertsCard(),
      _BackgroundCard(),
      _SmartSearchCard(),
      _AiCard(),
      AppLockCard(),
      HintsCard(),
      SyncCard(),
      SecurityCard(
        network:
            'Chanda loads a shop\'s pages only to show them to you, read a product you save, and check saved '
            'prices. Background checks say they come from Chanda. It fetches exchange rates from the European '
            'Central Bank\'s reference feed (frankfurter.dev) and talks to your sync server only if you sign in. '
            'Smarter search downloads its model from Hugging Face once, if you ask for it. '
            'If you add your own AI key, a product page\'s text goes to Anthropic only when you press Read with AI. '
            'Shop logins stay in the shop\'s own pages: Chanda never sees or stores your passwords or card '
            'details, never reads payment pages and never checks out for you.',
      ),
      AboutCard(
        description:
            'Your shopping vault: save what you want from any shop, watch its price, and buy it in the shop\'s '
            'own page when the price is right.',
      ),
    ],
  );
}

/// What Chanda promises, in plain words.
class _TrustCard extends StatelessWidget {
  const _TrustCard();

  static const _points = [
    (
      Icons.link_off,
      'No affiliate tags',
      'Links you save and open are cleaned of tracking and referral codes. Chanda earns nothing when you buy.',
    ),
    (
      Icons.verified_outlined,
      'Prices read twice',
      'An alert fires only when two reads of the shop\'s page, seconds apart, agree.',
    ),
    (
      Icons.lock_outline,
      'Your data stays yours',
      'Your vault is encrypted on this device. Nothing is sold or shared; sync goes only to a server you choose.',
    ),
    (
      Icons.credit_card_off_outlined,
      'Payment pages are never read',
      'You pay on the shop\'s own page. Chanda does not read sign-in or payment pages and never stores card details.',
    ),
  ];

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Chanda works only for you',
    child: Column(
      children: [
        for (final (icon, title, text) in _points)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon, color: NithyaAccent.primary),
            title: Text(title),
            subtitle: Text(text),
          ),
      ],
    ),
  );
}

class _LookCard extends ConsumerWidget {
  const _LookCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(themeProvider);
    final platform = MediaQuery.platformBrightnessOf(context);
    return SectionCard(
      title: 'Look',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final c in themeChoices)
            _Swatch(
              label: themeLabel(c),
              palette: paletteFor(c, platform),
              selected: c == choice,
              onTap: () => ref.read(themeProvider.notifier).set(c),
            ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.label, required this.palette, required this.selected, required this.onTap});
  final String label;
  final NithyaPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 116,
    child: Extruded(
      selected: selected,
      onTap: onTap,
      radius: NithyaRadius.xl,
      depth: 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    if (palette.glow.isNotEmpty) palette.glow.first.color.withValues(alpha: 0.5),
                    palette.background,
                    palette.panel,
                    if (palette.glow.length > 1) palette.glow.last.color.withValues(alpha: 0.5),
                  ],
                ),
              ),
              child: Center(
                child: Container(
                  width: 34,
                  height: 14,
                  decoration: BoxDecoration(
                    color: NithyaAccent.primary,
                    borderRadius: BorderRadius.circular(NithyaRadius.pill),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelLarge),
          ),
        ],
      ),
    ),
  );
}

class _MoneyCard extends ConsumerWidget {
  const _MoneyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeCurrencyProvider).value ?? 'GBP';
    final rules = ref.watch(importRulesProvider).value ?? const UkImportRules();
    final fx = ref.watch(fxProvider);
    return SectionCard(
      title: 'Money',
      hint: 'action.landed',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Home currency'),
            subtitle: Text(
              fx.isLoading
                  ? 'Fetching exchange rates…'
                  : fx.value == null
                  ? 'Exchange rates not fetched yet: prices in other currencies are not converted.'
                  : 'Exchange rates of ${fx.value!.day}',
            ),
            trailing: DropdownButton<String>(
              value: ecbCurrencies.contains(home) ? home : null,
              underline: const SizedBox.shrink(),
              items: [for (final c in ecbCurrencies) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (c) {
                if (c != null) ref.mutate((v) => v.setPref(homeCurrencyPref, c));
              },
            ),
          ),
          if (home == 'GBP') ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Customs duty on goods over £135'),
              subtitle: const Text('Your estimate; it depends on the kind of goods. Clothing is often 12%.'),
              trailing: Text('${_n(rules.dutyPercent)}%'),
              onTap: () => _number(
                context,
                ref,
                title: 'Customs duty',
                label: 'Per cent of the price',
                initial: _n(rules.dutyPercent),
                save: (n) => ref.mutate((v) => v.setPref(dutyPref, '$n')),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Courier handling fee'),
              subtitle: const Text('Charged by some couriers when import VAT is due on delivery.'),
              trailing: Text(showPrice(rules.handlingFee, 'GBP')),
              onTap: () => _number(
                context,
                ref,
                title: 'Handling fee',
                label: 'Pounds',
                initial: (rules.handlingFee / 100).toStringAsFixed(2),
                save: (n) => ref.mutate((v) => v.setPref(handlingPref, '${(n * 100).round()}')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _n(num n) => n == n.roundToDouble() ? '${n.round()}' : '$n';

Future<void> _number(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String label,
  required String initial,
  required Future<void> Function(num n) save,
}) async {
  final c = TextEditingController(text: initial);
  await showFormDialog(
    context,
    title: title,
    fields: (_) => [Field(c, label, number: true, autofocus: true)],
    onSave: () async {
      final n = numberIn(c);
      if (n == null || n < 0) return 'Type a number, 0 or more.';
      await save(n);
      return null;
    },
  );
}

class _AlertsCard extends ConsumerStatefulWidget {
  const _AlertsCard();

  @override
  ConsumerState<_AlertsCard> createState() => _AlertsCardState();
}

class _AlertsCardState extends ConsumerState<_AlertsCard> {
  bool? _notify;

  @override
  void initState() {
    super.initState();
    ref.read(sessionProvider).db.localSetting(notifySetting).then((v) {
      if (mounted) setState(() => _notify = v != 'off');
    });
  }

  Future<void> _setNotify(bool on) async {
    if (on && !await AlertNotifier.askPermission()) {
      if (mounted) showMessage(context, 'Notifications are turned off for Chanda in the system settings.');
      return;
    }
    await ref.read(sessionProvider).db.setLocalSetting(notifySetting, on ? 'on' : 'off');
    setState(() => _notify = on);
    ref.invalidate(notifierProvider);
  }

  Future<void> _test() async {
    try {
      await (await ref.read(notifierProvider.future)).test();
      if (mounted) showMessage(context, 'Test alert sent.');
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _ntfy(String current) async {
    final c = TextEditingController(text: current);
    await showFormDialog(
      context,
      title: 'Alerts through ntfy',
      fields: (_) => [
        const Text(
          'Pick a topic name nobody would guess; anyone who knows it can read your alerts. Then subscribe to '
          'the same address in the ntfy app. Leave empty to stop.',
        ),
        const SizedBox(height: 12),
        Field(c, 'Topic address', hint: 'https://ntfy.sh/your-secret-topic', autofocus: true),
      ],
      onSave: () async {
        final url = c.text.trim();
        if (url.isNotEmpty) {
          final u = Uri.tryParse(url);
          if (u == null || u.scheme != 'https' || u.pathSegments.where((s) => s.isNotEmpty).isEmpty) {
            return 'Type the full address, starting https:// and ending with the topic.';
          }
        }
        await ref.mutate((v) => v.setPref(ntfyPref, url));
        ref.invalidate(notifierProvider);
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ntfy = ref.watch(_ntfyProvider).value ?? '';
    final percent = ref.watch(_dropProvider).value ?? 5;
    return SectionCard(
      title: 'Alerts',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Notifications on this device'),
            value: _notify ?? true,
            onChanged: _notify == null ? null : _setNotify,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Alert when a price drops by'),
            subtitle: const Text('Smaller changes are kept in the price history without an alert.'),
            trailing: Text('${_n(percent)}% or more'),
            onTap: () => _number(
              context,
              ref,
              title: 'Price drop alerts',
              label: 'Per cent',
              initial: _n(percent),
              save: (n) => ref.mutate((v) => v.setPref(dropPercentPref, '$n')),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Row(
              children: [
                const Text('Also send to ntfy'),
                const SizedBox(width: 6),
                Hint('action.ntfy', child: Icon(Icons.info_outline, size: 16, color: muted(context))),
              ],
            ),
            subtitle: Text(ntfy.isEmpty ? 'Off' : ntfy, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => _ntfy(ntfy),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Send a test alert'),
              onPressed: _test,
            ),
          ),
        ],
      ),
    );
  }
}

final _ntfyProvider = FutureProvider<String>((ref) async {
  ref.watch(revisionProvider);
  return await ref.watch(sessionProvider).vault.pref(ntfyPref) ?? '';
});

final _dropProvider = FutureProvider<double>((ref) {
  ref.watch(revisionProvider);
  return ref.watch(sessionProvider).vault.dropPercent();
});

class _BackgroundCard extends ConsumerStatefulWidget {
  const _BackgroundCard();

  @override
  ConsumerState<_BackgroundCard> createState() => _BackgroundCardState();
}

class _BackgroundCardState extends ConsumerState<_BackgroundCard> {
  bool? _on;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(sessionProvider).db.localSetting(backgroundSetting).then((v) {
      if (mounted) setState(() => _on = v == 'on');
    });
  }

  Future<void> _set(bool on) async {
    setState(() => _busy = true);
    try {
      await setBackgroundChecks(on);
      await ref.read(sessionProvider).db.setLocalSetting(backgroundSetting, on ? 'on' : 'off');
      if (mounted) setState(() => _on = on);
    } on Object catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final checking = ref.watch(liveChecksProvider);
    return SectionCard(
      title: 'Price checks',
      hint: 'action.background',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(checking ? Icons.sync : Icons.schedule, color: NithyaAccent.primary),
            title: const Text('While Chanda is open'),
            subtitle: const Text('Every quarter of an hour Chanda checks the items that are due.'),
            trailing: TextButton(
              onPressed: checking
                  ? null
                  : () async {
                      final r = await ref.read(liveChecksProvider.notifier).runDue();
                      if (context.mounted) {
                        showMessage(
                          context,
                          r == null || r.checked == 0
                              ? 'Nothing is due yet.'
                              : 'Checked ${r.checked}${r.alerted > 0 ? ', ${r.alerted} alerts' : ''}.',
                        );
                      }
                    },
              child: Text(checking ? 'Checking…' : 'Check due now'),
            ),
          ),
          if (canCheckInBackground)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('While Chanda is closed'),
              subtitle: const Text(
                'About once an hour this device wakes Chanda to check what is due, without opening a window.',
              ),
              value: _on ?? false,
              onChanged: _on == null || _busy ? null : _set,
            ),
        ],
      ),
    );
  }
}

/// Optional AI reading with the user's own key.
class _AiCard extends ConsumerWidget {
  const _AiCard();

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final c = TextEditingController();
    await showFormDialog(
      context,
      title: 'AI reading',
      fields: (_) => [
        const Text(
          'Paste an API key from your Anthropic account. It stays on this device, in the encrypted vault, and '
          'is never synced. Each reading is charged to your account, usually well under a penny. Leave empty '
          'to remove the key.',
        ),
        const SizedBox(height: 12),
        Field(c, 'API key', hint: 'sk-ant-…', autofocus: true),
      ],
      onSave: () async {
        final key = c.text.trim();
        if (key.isNotEmpty && !looksLikeKey(key)) return 'That does not look like an Anthropic API key.';
        await ref.read(sessionProvider).db.setLocalSetting(aiKeySetting, key);
        ref.invalidate(aiKeyProvider);
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = ref.watch(aiKeyProvider).value ?? '';
    return SectionCard(
      title: 'AI reading',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.auto_awesome_outlined, color: NithyaAccent.primary),
            title: Text(key.isEmpty ? 'Off' : 'On, with your key ending ${key.substring(key.length - 4)}'),
            subtitle: const Text(
              'When Chanda is unsure of a product\'s name or price, Read with AI sends the page\'s text to Claude '
              'and fills in what it finds for you to check. Sign-in and payment pages are never sent.',
            ),
            trailing: TextButton(
              onPressed: () => _edit(context, ref),
              child: Text(key.isEmpty ? 'Add key' : 'Change'),
            ),
          ),
        ],
      ),
    );
  }
}

/// The optional meaning model for search.
class _SmartSearchCard extends ConsumerWidget {
  const _SmartSearchCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(smartSearchProvider).value ?? const SmartSearch();
    final notifier = ref.read(smartSearchProvider.notifier);
    final mb = (modelBytes / 1e6).round();
    return SectionCard(
      title: 'Smarter search',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Search finds words by default. Smarter search also finds things by meaning: "specs" finds reading '
            'glasses, and a search in one language finds titles in another. It needs a $mb MB download, once, '
            'and then runs on this device: nothing you search for is sent anywhere.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          if (s.downloading) ...[
            LinearProgressIndicator(value: s.done! / modelBytes),
            const SizedBox(height: 6),
            Text('Downloading… ${(s.done! / 1e6).round()} of $mb MB'),
          ] else if (s.present) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Search by meaning'),
              value: s.on,
              onChanged: notifier.setOn,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: Text('Remove the download ($mb MB)'),
                onPressed: notifier.remove,
              ),
            ),
          ] else ...[
            if (s.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(s.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.download_outlined),
                label: Text('Download ($mb MB)'),
                onPressed: notifier.download,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
