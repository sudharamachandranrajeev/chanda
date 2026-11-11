import 'dart:io';

import 'package:brahma_core/brahma_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nithya/nithya.dart';

import '../domain/ai_reader.dart';
import '../domain/cloud_tryon.dart';
import '../domain/money.dart';
import '../domain/notify.dart';
import '../domain/taste.dart';
import '../domain/taste_store.dart';
import '../domain/vault.dart';
import '../ui/common.dart';
import '../ui/look.dart';
import '../ui/person_page.dart';
import 'background.dart';
import 'providers.dart';

String _smartAbout(int mb) =>
    'Search finds words by default. Smarter search also finds things by meaning: "specs" finds reading '
    'glasses, and a search in one language finds titles in another. It needs a $mb MB download, once, and then '
    'runs on this device: nothing you search for is sent anywhere.';

String _picturesAbout(int mb) =>
    'Search with a photo, find saved things and offers that look alike, and let looks count in your '
    'suggestions. It needs a $mb MB download, once, and then runs on this device: your photos are not sent '
    'anywhere.';

String tryOnAbout(int mb) =>
    'See glasses from your vault on a photo of your face, at their real size, and clothes on a photo of your '
    'whole body, never made slimmer. It needs a $mb MB download, once, and then runs on this device: your '
    'photos and sizes stay on it and are never synced or sent anywhere, unless you turn on AI try-on below.';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => PageScaffold(
    title: 'Settings',
    children: [
      const _TrustCard(),
      _LookCard(),
      _MoneyCard(),
      _AlertsCard(),
      _BackgroundCard(),
      ModelCard(
        provider: smartSearchProvider,
        title: 'Smarter search',
        switchLabel: 'Search by meaning',
        about: _smartAbout,
      ),
      ModelCard(
        provider: picturesProvider,
        title: 'Picture search',
        switchLabel: 'Use pictures',
        about: _picturesAbout,
      ),
      ModelCard(
        provider: tryOnProvider,
        title: 'Try-on',
        switchLabel: 'Try things on',
        about: tryOnAbout,
        extra: _PersonTile(),
      ),
      _TasteCard(),
      _AiCard(),
      _CloudTryOnCard(),
      AppLockCard(),
      HintsCard(),
      SyncCard(),
      SecurityCard(
        network:
            'Chanda loads a shop\'s pages only to show them to you, read a product you save, and check saved '
            'prices. Background checks say they come from Chanda. It fetches exchange rates from the European '
            'Central Bank\'s reference feed (frankfurter.dev) and talks to your sync server only if you sign in. '
            'Smarter search, picture search and try-on download their models from Hugging Face once, if you '
            'ask for them. With picture search on, Chanda fetches the pictures of things you saved or found to compare '
            'their looks, saying it is Chanda. '
            'When you check a shop, Chanda reads its home page and asks the registry for its web address, '
            'found through IANA\'s public list, when the address was first registered. '
            'If you add your own AI key, a product page\'s text goes to Anthropic only when you press Read with AI. '
            'If you add a key for AI try-on and agree to that service\'s terms, your body photo and the '
            'garment\'s picture go to that service (FASHN, fal or Gemini) only when you press Try with AI. '
            'To find a size chart, Chanda reads the product\'s page again. '
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

/// AI try-on: the user's own keys for the cloud services, in the order
/// Chanda uses them.
class _CloudTryOnCard extends ConsumerWidget {
  const _CloudTryOnCard();

  Future<void> _edit(BuildContext context, WidgetRef ref, CloudProvider p) async {
    final c = TextEditingController();
    final terms = providerTerms(p);
    await showFormDialog(
      context,
      title: '${providerName(p)} key',
      fields: (_) => [
        Text(
          'Paste an API key from your ${providerName(p)} account (${providerKeyPage(p)}). It stays on this '
          'device, in the encrypted vault, and is never synced. ${terms.price} Leave empty to remove the key.',
        ),
        if (p == CloudProvider.gemini) ...[const SizedBox(height: 8), const Text(geminiFreeWarning)],
        const SizedBox(height: 12),
        Field(c, 'API key', autofocus: true),
      ],
      onSave: () async {
        final key = c.text.trim();
        if (key.isNotEmpty && (key.length < 16 || key.contains(RegExp(r'\s')))) {
          return 'That does not look like an API key.';
        }
        await ref.read(sessionProvider).db.setLocalSetting(cloudKeySetting(p), key);
        ref.invalidate(cloudKeysProvider);
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cloudKeysProvider).value;
    final keys = state?.keys ?? const {};
    final paid = state?.geminiPaid ?? false;
    final using = pickProvider(keys, geminiPaid: paid);
    return SectionCard(
      title: 'AI try-on',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            using == null
                ? 'Off. Clothes are drawn on your body photo on this device. With your own key for one of these '
                      'services, Try with AI also asks it for a more lifelike picture. Before the first one, '
                      'Chanda shows what is sent, how long it is kept and what it costs, and asks you.'
                : 'Try with AI uses ${providerName(using)}. Only the clothes are taken from its picture: your '
                      'shape, face, hair and hands stay as on your photo, and a picture that makes you narrower '
                      'is not shown.',
          ),
          for (final p in CloudProvider.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.checkroom_outlined, color: NithyaAccent.primary),
              title: Text(providerName(p)),
              subtitle: Text(
                (keys[p] ?? '').isEmpty
                    ? 'No key'
                    : 'Your key ending ${keys[p]!.substring(keys[p]!.length - 4)}'
                          '${p == CloudProvider.gemini && !paid ? ' (not used: not marked as paid)' : ''}',
              ),
              trailing: TextButton(
                onPressed: () => _edit(context, ref, p),
                child: Text((keys[p] ?? '').isEmpty ? 'Add key' : 'Change'),
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('My Gemini key is on a paid plan'),
            subtitle: const Text(geminiFreeWarning),
            value: paid,
            onChanged: (on) async {
              await ref.read(sessionProvider).db.setLocalSetting(geminiPaidSetting, on ? 'on' : 'off');
              ref.invalidate(cloudKeysProvider);
            },
          ),
        ],
      ),
    );
  }
}

/// An optional downloaded model: what it does, its download and its switch.
class ModelCard extends ConsumerWidget {
  const ModelCard({
    super.key,
    required this.provider,
    required this.title,
    required this.about,
    required this.switchLabel,
    this.extra,
  });
  final AsyncNotifierProvider<DownloadedModel, ModelState> provider;
  final String title;
  final String Function(int mb) about;
  final String switchLabel;

  /// Shown under the download, whether or not it is there.
  final Widget? extra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(provider).value ?? const ModelState();
    final notifier = ref.read(provider.notifier);
    final bytes = notifier.bytes;
    final mb = (bytes / 1e6).round();
    return SectionCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(about(mb), style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          if (s.downloading) ...[
            LinearProgressIndicator(value: s.done! / bytes),
            const SizedBox(height: 6),
            Text('Downloading… ${(s.done! / 1e6).round()} of $mb MB'),
          ] else if (s.present) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(switchLabel),
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
          ?extra,
        ],
      ),
    );
  }
}

/// The person kept for try-on: their photos and sizes.
class _PersonTile extends ConsumerWidget {
  const _PersonTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(personProvider).value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.face_outlined),
      title: const Text('Your photos and sizes'),
      subtitle: Text(p == null ? 'None kept' : 'Kept on this device only'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const PersonPage())),
    );
  }
}

/// Suggestions from the user's ratings: on or off, muted attributes,
/// export, import and reset.
class _TasteCard extends ConsumerWidget {
  const _TasteCard();

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final json = await (await ref.read(tasteProvider.future)).export();
    if (Platform.isAndroid) {
      await copyText(json);
      if (context.mounted) {
        showMessage(context, 'Your ratings are copied. Paste them into a note or a file to keep.');
      }
      return;
    }
    final where = await getSaveLocation(
      suggestedName: 'chanda-taste.json',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
    );
    if (where == null) return;
    await File(where.path).writeAsString(json);
    if (context.mounted) showMessage(context, 'Saved to ${where.path}');
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'JSON', extensions: ['json'], mimeTypes: ['application/json']),
      ],
    );
    if (file == null) return;
    try {
      if (await file.length() > 5 << 20) {
        throw const FormatException('That file is too big to be a taste export.');
      }
      final n = await (await ref.read(tasteProvider.future)).import(await file.readAsString());
      ref.read(revisionProvider.notifier).bump();
      ref.read(syncProvider.notifier).soon();
      if (context.mounted) showMessage(context, n == 1 ? '1 rating added.' : '$n ratings added.');
    } on FormatException catch (e) {
      if (context.mounted) showMessage(context, e.message);
    }
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final ok = await confirm(
      context,
      title: 'Forget your ratings?',
      message: 'Every star rating and muted word is deleted on all your devices. Saved things stay.',
      action: 'Forget',
      destructive: true,
    );
    if (!ok) return;
    await (await ref.read(tasteProvider.future)).reset();
    ref.read(revisionProvider.notifier).bump();
    ref.read(syncProvider.notifier).soon();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(tasteOnProvider).value ?? true;
    final n = ref.watch(ratingsProvider).value?.length ?? 0;
    final muted = ref.watch(mutedProvider).value ?? const <String>{};
    Future<void> write(Future<void> Function(TasteStore t) f) async {
      await f(await ref.read(tasteProvider.future));
      ref.read(revisionProvider.notifier).bump();
      ref.read(syncProvider.notifier).soon();
    }

    return SectionCard(
      title: 'Your taste',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Chanda learns what you like from your star ratings and what you save, on this device. It uses '
            'only those: never your age, gender or anything else about you. Suggestions only reorder what you '
            'searched for; they never add things you did not ask for.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Suggest and sort by my taste'),
            subtitle: Text(n == 1 ? '1 rating so far' : '$n ratings so far'),
            value: on,
            onChanged: (v) => write((t) => t.setOn(v)),
          ),
          if (muted.isNotEmpty) ...[
            Text('Not counted (tap to count again)', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final a in muted.toList()..sort())
                  InputChip(label: Text(attributeWords(a)), onDeleted: () => write((t) => t.unmute(a))),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.upload_outlined),
                label: const Text('Export'),
                onPressed: () => _export(context, ref),
              ),
              TextButton.icon(
                icon: const Icon(Icons.download_outlined),
                label: const Text('Import'),
                onPressed: () => _import(context, ref),
              ),
              TextButton.icon(
                icon: const Icon(Icons.restart_alt),
                label: const Text('Forget ratings'),
                onPressed: n == 0 && muted.isEmpty ? null : () => _reset(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
