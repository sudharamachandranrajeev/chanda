import 'dart:async';

import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nithya/nithya.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/links.dart';
import '../domain/money.dart';
import '../domain/offers.dart';
import '../domain/reading.dart';
import '../domain/screen_ocr.dart';
import '../domain/screen_text.dart';
import '../domain/shops.dart';
import '../domain/web_reader.dart';
import 'common.dart';
import 'look.dart';
import 'save_flow.dart';

/// Opens [url] inside Chanda, or in the system browser where this build
/// has no web view. With [item], the page is that item's: the user can
/// update its price from what they see, or mark it bought.
Future<void> openInApp(BuildContext context, Uri url, {VaultItem? item}) async {
  if (!hasWebView) return openLink(context, '${cleanLink(url)}');
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BrowserPage(url: url, item: item),
    ),
  );
}

/// Opens [shop]'s search for [words] inside Chanda, for a shop that wants
/// the user present. The user gets past any check, then presses Add these
/// results; the offers on the page come back. Null when they just close it
/// (or the build has no web view and the search opened in the browser).
Future<List<Offer>?> openSearchInApp(BuildContext context, Shop shop, String words) async {
  final url = shop.searchFor(words);
  if (url == null) return null;
  if (!hasWebView) {
    await openLink(context, '$url');
    return null;
  }
  return Navigator.of(context).push<List<Offer>>(
    MaterialPageRoute(builder: (_) => BrowserPage(url: url, gathers: true)),
  );
}

/// A shop's own website inside Chanda. The user signs in, chooses and
/// pays on the shop's own pages; Chanda keeps the cookies (in the web
/// view's store, as any browser does), and reads a page only when asked
/// to save or update a product. Sign-in and payment pages are never read.
class BrowserPage extends ConsumerStatefulWidget {
  const BrowserPage({super.key, required this.url, this.saveOnLoad = false, this.item, this.gathers = false});
  final Uri url;

  /// Opened for a search: the bar offers Add these results, which reads
  /// the products listed on the page and returns them.
  final bool gathers;

  /// Reads the product as soon as the page has drawn and offers to save it.
  final bool saveOnLoad;
  final VaultItem? item;

  @override
  ConsumerState<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends ConsumerState<BrowserPage> {
  InAppWebViewController? _web;
  var _progress = 0.0;
  late Uri _url = cleanLink(widget.url);
  var _reading = false;
  var _autoDone = false;
  var _canBack = false;

  bool get _private => isPrivatePage(_url);
  Shop get _shop => shopFor(_url);

  Future<Reading?> _read() async {
    final web = _web;
    if (web == null || _private) return null;
    setState(() => _reading = true);
    try {
      final e = await settle(web, tries: 8);
      final r = readProduct(e, hint: shopFor(_url).currency);
      if (r.price != null || r.check || !canReadScreen) return r;
      // No price as data: read it off what the user sees.
      final png = await web.takeScreenshot();
      if (png == null || _private) return r;
      final (lines, height) = await readScreen(png);
      return withScreenText(r, lines, screenHeight: height);
    } on Object catch (e) {
      if (mounted) showError(context, e);
      return null;
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _save() async {
    final r = await _read();
    if (r == null || !mounted) return;
    if (r.title.isEmpty && r.price == null && !r.check) {
      return showMessage(context, 'This does not look like a product page. Open the product itself, then Save.');
    }
    await showSaveSheet(context, r);
  }

  /// Reads the products listed on the page and hands them back.
  Future<void> _gather() async {
    final web = _web;
    if (web == null || _private) return;
    setState(() => _reading = true);
    try {
      final offers = parseOffers(_shop, '${await web.evaluateJavascript(source: offerScript)}');
      if (!mounted) return;
      if (offers.isEmpty) {
        return showMessage(context, 'No products with prices found here yet. Let the results load, then try again.');
      }
      Navigator.pop(context, offers);
    } on Object catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  /// Updates the item's price from the page the user is looking at.
  Future<void> _update() async {
    final item = widget.item!;
    final r = await _read();
    if (r == null || !mounted) return;
    if (!r.usable) {
      return showMessage(
        context,
        r.check ? 'Finish the shop\'s check on the page first.' : 'No price found on this page.',
      );
    }
    await ref.mutate((v) => v.recordCheck(item, r, const []));
    if (mounted) showMessage(context, 'Price updated: ${showPrice(r.price!, r.currency)}.');
  }

  Future<void> _bought() async {
    final item = widget.item!;
    await ref.mutate((v) => v.updateItem(item.copyWith(bought: true, checked: Value(item.checked))));
    if (mounted) {
      Navigator.pop(context);
      showMessage(context, 'Marked as bought. It stays in your vault, at the bottom.');
    }
  }

  Future<NavigationActionPolicy> _route(NavigationAction action) async {
    final url = action.request.url;
    if (url == null) return NavigationActionPolicy.ALLOW;
    final uri = Uri.parse('$url');
    if (isGoogleSignIn(uri)) {
      // Google refuses sign-in inside apps' web views.
      await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
      if (mounted) {
        showMessage(
          context,
          'Google sign-in opened in your browser. Here, sign in to the shop with your email and password instead.',
        );
      }
      return NavigationActionPolicy.CANCEL;
    }
    if (uri.scheme != 'http' &&
        uri.scheme != 'https' &&
        uri.scheme != 'about' &&
        uri.scheme != 'blob' &&
        uri.scheme != 'data') {
      // Shop apps, mail and phone links go to the system.
      await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
      return NavigationActionPolicy.CANCEL;
    }
    return NavigationActionPolicy.ALLOW;
  }

  Future<bool> _popup(CreateWindowAction action) async {
    // Sign-in windows, a shop's "open in new tab": shown over the page.
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _PopupPage(action: action, route: _route),
      ),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final p = NithyaPalette.of(context);
    return PopScope(
      canPop: !_canBack,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) _web?.goBack();
      },
      child: Scaffold(
        backgroundColor: p.background,
        appBar: AppBar(
          backgroundColor: p.panel,
          titleSpacing: 0,
          title: Row(
            children: [
              Icon(_private ? Icons.lock : Icons.public, size: 16, color: _private ? drop : p.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _url.host.replaceFirst(RegExp(r'^www\.'), ''),
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              onPressed: _canBack ? () => _web?.goBack() : null,
            ),
            IconButton(tooltip: 'Reload', icon: const Icon(Icons.refresh), onPressed: () => _web?.reload()),
            PopupMenuButton<String>(
              onSelected: (v) => switch (v) {
                'system' => openLink(context, '${cleanLink(_url)}'),
                'copy' => _copy(),
                _ => null,
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'system', child: Text('Open in browser')),
                PopupMenuItem(value: 'copy', child: Text('Copy clean link')),
              ],
            ),
          ],
          bottom: _progress < 1
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(value: _progress, minHeight: 2),
                )
              : null,
        ),
        body: Column(
          children: [
            AnimatedSize(
              duration: NithyaMotion.slow,
              curve: Motion.curve,
              child: _private
                  ? MaterialBanner(
                      backgroundColor: drop.withValues(alpha: 0.12),
                      leading: const Icon(Icons.lock_outline, color: drop),
                      content: const Text(
                        'Sign-in or payment page: Chanda is not reading it. What you type goes only to the shop.',
                      ),
                      actions: const [SizedBox.shrink()],
                    )
                  : const SizedBox(width: double.infinity),
            ),
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri('$_url')),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  supportMultipleWindows: true,
                  javaScriptCanOpenWindowsAutomatically: true,
                  useShouldOverrideUrlLoading: true,
                  mediaPlaybackRequiresUserGesture: true,
                ),
                onWebViewCreated: (c) => _web = c,
                shouldOverrideUrlLoading: (_, action) => _route(action),
                onCreateWindow: (_, action) => _popup(action),
                onUpdateVisitedHistory: (c, url, _) async {
                  final back = await c.canGoBack();
                  if (!mounted) return;
                  setState(() {
                    if (url != null) _url = Uri.parse('$url');
                    _canBack = back;
                  });
                },
                onProgressChanged: (_, n) => setState(() => _progress = n / 100),
                onLoadStop: (_, _) {
                  if (widget.saveOnLoad && !_autoDone) {
                    _autoDone = true;
                    _save();
                  }
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: _bar(context, item),
      ),
    );
  }

  Future<void> _copy() async {
    await copyText('${cleanLink(_url)}');
    if (mounted) showMessage(context, 'Link copied, without tracking codes.');
  }

  Widget _bar(BuildContext context, VaultItem? item) {
    final text = Theme.of(context).textTheme;
    final busy = _reading
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Extruded(
          padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
          depth: 0.8,
          child: Row(
            children: [
              Expanded(
                child: item == null
                    ? Text(
                        _private
                            ? 'Paying or signing in: Chanda stays out.'
                            : widget.gathers
                            ? 'Results at ${_shop.name}'
                            : 'Found something at ${_shop.name}?',
                        style: text.bodyMedium,
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelLarge),
                          Text(
                            item.price == null ? 'No price kept' : 'Kept at ${showPrice(item.price!, item.currency)}',
                            style: text.bodySmall,
                          ),
                        ],
                      ),
              ),
              if (item == null && widget.gathers) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.favorite_border),
                  label: const Text('Save'),
                  onPressed: _private || _reading ? null : _save,
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: busy ?? const Icon(Icons.playlist_add),
                  label: const Text('Add these results'),
                  onPressed: _private || _reading ? null : _gather,
                ),
              ] else if (item == null)
                FilledButton.icon(
                  icon: busy ?? const Icon(Icons.favorite_border),
                  label: const Text('Save'),
                  onPressed: _private || _reading ? null : _save,
                )
              else ...[
                Hint(
                  'action.check',
                  child: OutlinedButton.icon(
                    icon: busy ?? const Icon(Icons.price_check),
                    label: const Text('Update price'),
                    onPressed: _private || _reading ? null : _update,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(icon: const Icon(Icons.check), label: const Text('Bought it'), onPressed: _bought),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A window the page opened (often a sign-in), over the page that
/// opened it, sharing its cookies.
class _PopupPage extends StatefulWidget {
  const _PopupPage({required this.action, required this.route});
  final CreateWindowAction action;
  final Future<NavigationActionPolicy> Function(NavigationAction) route;

  @override
  State<_PopupPage> createState() => _PopupPageState();
}

class _PopupPageState extends State<_PopupPage> {
  String _host = '';

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: NithyaPalette.of(context).background,
    appBar: AppBar(
      backgroundColor: NithyaPalette.of(context).panel,
      title: Text(_host, style: Theme.of(context).textTheme.titleMedium),
      leading: IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
    ),
    body: InAppWebView(
      windowId: widget.action.windowId,
      initialSettings: InAppWebViewSettings(javaScriptEnabled: true, useShouldOverrideUrlLoading: true),
      shouldOverrideUrlLoading: (_, a) => widget.route(a),
      onUpdateVisitedHistory: (_, url, _) => setState(() => _host = url?.host ?? ''),
      onCloseWindow: (_) {
        if (mounted) Navigator.pop(context);
      },
    ),
  );
}
