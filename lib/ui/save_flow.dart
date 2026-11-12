import 'dart:async';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nithya/nithya.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/ai_reader.dart';
import '../domain/garment_fit.dart' show garmentTag;
import '../domain/html_evidence.dart';
import '../domain/images.dart';
import '../domain/links.dart';
import '../domain/money.dart';
import '../domain/reading.dart';
import '../domain/shops.dart';
import '../domain/web_reader.dart';
import 'browser_page.dart';
import 'common.dart';
import 'look.dart';

/// Saves the product at the first link in [text] (shared or pasted).
Future<void> saveFromText(BuildContext context, String text) async {
  final url = linkIn(text);
  if (url == null) return showMessage(context, 'There is no web address in that.');
  await saveFromLink(context, url);
}

/// Opens [url] to save it: in the in-app browser, which reads the page
/// once it has drawn, or (without a web view) by reading its plain HTML.
Future<void> saveFromLink(BuildContext context, Uri url) async {
  final clean = cleanLink(url);
  if (isPrivatePage(clean)) {
    return showMessage(context, 'That is a sign-in or payment page: Chanda does not read those.');
  }
  if (hasWebView) {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => BrowserPage(url: clean, saveOnLoad: true)));
    return;
  }
  final Reading r;
  try {
    r = readProduct(await fetchEvidence(clean), hint: shopFor(clean).currency);
  } on Object catch (e) {
    if (context.mounted) showError(context, e);
    return;
  }
  if (context.mounted) await showSaveSheet(context, r);
}

/// Asks for a link (offering the one on the clipboard) and saves it.
Future<void> askForLink(BuildContext context, {String initial = ''}) async {
  final c = TextEditingController(text: initial);
  Uri? url;
  final ok = await showFormDialog(
    context,
    title: 'Save from a link',
    action: 'Open',
    fields: (_) => [
      const Text('Paste a product\'s address from any shop.'),
      const SizedBox(height: 12),
      Field(c, 'Link', hint: 'https://…', autofocus: true),
    ],
    onSave: () async {
      url = linkIn(c.text.trim()) ?? linkIn('https://${c.text.trim()}');
      return url == null || !url!.host.contains('.') ? 'That does not look like a web address.' : null;
    },
  );
  if (ok && url != null && context.mounted) await saveFromLink(context, url!);
}

/// Shows what was read from a product page for the user to check and
/// save. Returns the saved item's id.
Future<String?> showSaveSheet(BuildContext context, Reading r) =>
    showModalBottomSheet<String>(context: context, isScrollControlled: true, builder: (_) => SaveSheet(r));

class SaveSheet extends ConsumerStatefulWidget {
  const SaveSheet(this.reading, {super.key});
  final Reading reading;

  @override
  ConsumerState<SaveSheet> createState() => _SaveSheetState();
}

class _SaveSheetState extends ConsumerState<SaveSheet> {
  late Reading r = widget.reading;
  var _reading = false;
  late final _title = TextEditingController(text: r.title);
  late final _price = TextEditingController(text: r.price == null ? '' : _decimal(r.price!, r.currency));
  final _target = TextEditingController();
  // A garment the title does not name but the shop's category does gets
  // that word as a tag, so it can be tried on; the user can remove it.
  late final _tags = TextEditingController(
    text: garmentTag(title: r.title, category: r.category),
  );
  final _note = TextEditingController();
  String? _listId;
  var _alertDrop = true, _alertStock = true, _watchClose = false;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _price, _target, _tags, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _amount(TextEditingController c) => c.text.trim().isEmpty
      ? null
      : parsePrice(c.text, hint: r.currency)?.minor ??
            parseAmount(c.text.trim(), scale: currencyInfo(r.currency).scale);

  Future<void> _save() async {
    final title = _title.text.trim();
    final price = _amount(_price);
    final target = _amount(_target);
    if (title.isEmpty) return setState(() => _error = 'Give it a name.');
    if (_price.text.trim().isNotEmpty && price == null) {
      return setState(() => _error = 'The price is not a number.');
    }
    if (_target.text.trim().isNotEmpty && target == null) {
      return setState(() => _error = 'The target is not a number.');
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await ref.mutate((v) async {
        final listId = _listId ?? await v.defaultList();
        final id = await v.saveReading(
          r,
          listId: listId,
          note: _note.text.trim(),
          target: target,
          tags: _tagText(),
        );
        final saved = (await v.item(id))!;
        await v.updateItem(
          saved.copyWith(
            title: title,
            alertDrop: _alertDrop,
            alertStock: _alertStock,
            watchClose: _watchClose,
          ),
        );
        // The user read the price themselves where Chanda could not, or
        // corrected it.
        if (price != null && price != r.price) await v.setManualPrice((await v.item(id))!, price);
        return id;
      });
      unawaited(keepImages(id, r.images).then((_) => ref.invalidate(keptImageProvider)));
      if (mounted) {
        Navigator.pop(context, id);
        showMessage(context, 'Saved to your vault.');
      }
    } on Object catch (e) {
      setState(() {
        _busy = false;
        _error = describeError(e);
      });
    }
  }

  /// Asks the AI to read the page and puts what it found in the fields.
  Future<void> _readWithAi(String key) async {
    setState(() {
      _reading = true;
      _error = null;
    });
    try {
      final read = await readWithAi(r, key, client: ref.read(aiClientProvider));
      setState(() {
        r = read;
        _title.text = read.title;
        _price.text = read.price == null ? '' : _decimal(read.price!, read.currency);
      });
    } on Object catch (e) {
      setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  String _tagText() => _tags.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).join(',');

  @override
  Widget build(BuildContext context) {
    final p = NithyaPalette.of(context);
    final text = Theme.of(context).textTheme;
    final lists = ref.watch(listsProvider).value ?? const <VaultList>[];
    final shop = shopFor(Uri.parse(r.url));
    final aiKey = ref.watch(aiKeyProvider).value ?? '';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Extruded(
                        radius: NithyaRadius.xl,
                        depth: 0.6,
                        child: SizedBox(
                          width: 88,
                          height: 88,
                          child: r.images.isEmpty
                              ? Icon(Icons.shopping_bag_outlined, color: p.muted)
                              : Image.network(
                                  r.images.first,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      Icon(Icons.shopping_bag_outlined, color: p.muted),
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Save from ${shop.name}', style: text.labelSmall),
                            const SizedBox(height: 4),
                            if (r.price != null)
                              GlowText(showPrice(r.price!, r.currency), style: NithyaType.title.toStyle())
                            else
                              Text('No price found', style: text.titleMedium),
                            if (r.check)
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Tag(
                                  'The shop is showing a check page',
                                  icon: Icons.shield_outlined,
                                  color: attention,
                                ),
                              ),
                            for (final w in r.warnings)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(w, style: text.bodySmall?.copyWith(color: attention)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (r.check)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Finish the shop\'s check on its page, then press Save again. You can also type the price '
                        'you see below.',
                        style: text.bodyMedium,
                      ),
                    ),
                  if (aiKey.isNotEmpty &&
                      r.layer != 'ai' &&
                      r.confidence != 'high' &&
                      r.text.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          icon: _reading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.auto_awesome_outlined),
                          label: const Text('Read with AI'),
                          onPressed: _reading ? null : () => _readWithAi(aiKey),
                        ),
                      ),
                    ),
                  Field(_title, 'Name'),
                  Row(
                    children: [
                      Expanded(child: Field(_price, 'Price (${r.currency})', number: true)),
                      const SizedBox(width: 12),
                      Expanded(child: Field(_target, 'Alert me at', number: true, hint: 'Your target price')),
                    ],
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _listId,
                    decoration: const InputDecoration(labelText: 'List'),
                    hint: Text(lists.isEmpty ? 'Wishlist' : lists.first.name),
                    items: [for (final l in lists) DropdownMenuItem(value: l.id, child: Text(l.name))],
                    onChanged: (id) => setState(() => _listId = id),
                  ),
                  const SizedBox(height: 12),
                  Field(_tags, 'Tags', hint: 'gift, summer, desk'),
                  Field(_note, 'Note', lines: 2, hint: 'Size, colour, who it is for'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Alert when the price drops'),
                    value: _alertDrop,
                    onChanged: (v) => setState(() => _alertDrop = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Alert when back in stock'),
                    value: _alertStock,
                    onChanged: (v) => setState(() => _alertStock = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Watch closely'),
                    subtitle: const Text('Check every 6 hours instead of daily.'),
                    value: _watchClose,
                    onChanged: (v) => setState(() => _watchClose = v),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.favorite),
                    label: const Text('Save to vault'),
                    onPressed: _busy ? null : _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [minor] as a plain decimal for a text field: 1299 GBP is "12.99".
String _decimal(int minor, String currency) {
  final scale = currencyInfo(currency).scale;
  if (scale == 0) return '$minor';
  final s = minor.abs().toString().padLeft(scale + 1, '0');
  return '${minor < 0 ? '-' : ''}${s.substring(0, s.length - scale)}.${s.substring(s.length - scale)}';
}
