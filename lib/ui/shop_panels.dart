import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nithya/nithya.dart';

import '../domain/links.dart';
import '../domain/offers.dart';
import '../domain/panel_script.dart';
import '../domain/query.dart';
import '../domain/reading.dart' show isWallAddress;
import '../domain/screen_ocr.dart';
import '../domain/screen_tiles.dart';
import '../domain/shop_search.dart';
import '../domain/shops.dart';
import '../domain/web_reader.dart' show hasWebView;
import 'browser_page.dart';
import 'common.dart';
import 'look.dart';
import 'search_page.dart' show ResultHeading;

/// What a live panel needs to know: the shop, the search page to show, and
/// where to send the products it reads.
class PanelRequest {
  const PanelRequest({required this.shop, required this.url, required this.onOffers});
  final Shop shop;
  final Uri url;

  /// Products read off the panel's page so far (all of them each time).
  final void Function(List<Offer> offers) onOffers;
}

typedef PanelBuilder = Widget Function(BuildContext context, PanelRequest request);

/// Builds a shop's live panel; widget tests swap in a fake.
final panelBuilderProvider = Provider<PanelBuilder>(
  (_) =>
      (context, request) => LiveShopPanel(request),
);

/// How long a panel stays loaded after the user moves to another one.
const panelKeepAlive = Duration(seconds: 60);

/// The shops that need the user, as tabs inside Search. Each tab is the
/// shop's own search page, live: the user passes its check or signs in
/// there, and Chanda reads the products as they appear into the results
/// above. One panel is on show; the one before it stays loaded for a
/// minute, then goes (a web view takes hundreds of megabytes).
class ShopPanels extends ConsumerStatefulWidget {
  const ShopPanels({
    super.key,
    required this.shops,
    required this.query,
    required this.results,
    required this.onOffers,
  });
  final List<Shop> shops;
  final Query query;
  final Map<String, ShopResult> results;
  final void Function(Shop shop, List<Offer> offers) onOffers;

  @override
  ConsumerState<ShopPanels> createState() => _ShopPanelsState();
}

class _ShopPanelsState extends ConsumerState<ShopPanels> {
  String? _selected;
  final _shownAt = <String, DateTime>{};
  Timer? _sweep;

  @override
  void initState() {
    super.initState();
    _sweep = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sweep?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(ShopPanels old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) _shownAt.removeWhere((id, _) => id != _selected);
  }

  Shop? get _current {
    if (widget.shops.isEmpty) return null;
    return widget.shops.where((s) => s.id == _selected).firstOrNull ?? widget.shops.first;
  }

  bool _alive(Shop s) {
    if (s.id == _current?.id) return true;
    final at = _shownAt[s.id];
    return at != null && DateTime.now().difference(at) < panelKeepAlive;
  }

  void _select(Shop s) => setState(() {
    final before = _current;
    if (before != null) _shownAt[before.id] = DateTime.now();
    _selected = s.id;
    _shownAt.remove(s.id);
  });

  String _label(Shop s) {
    final r = widget.results[s.id];
    return switch (r?.state) {
      SearchState.done when r!.offers.isNotEmpty => '${s.name} · ${r.offers.length}',
      SearchState.failed => '${s.name} · try here',
      _ => s.name,
    };
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    if (current == null) return const SizedBox.shrink();
    final build = ref.watch(panelBuilderProvider);
    final p = NithyaPalette.of(context);
    final style = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResultHeading('Shops that need you', '${widget.shops.length}'),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'These shops show results only to a person. Pass their check or sign in below, and Chanda adds '
            'what it sees to the results. Sign-in and payment pages are never read.',
            style: style.bodySmall?.copyWith(color: p.muted),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in widget.shops)
              ChoiceChip(
                avatar: widget.results[s.id]?.needsYou ?? true
                    ? const Icon(Icons.person_outline, size: 16)
                    : const Icon(Icons.check, size: 16, color: drop),
                label: Text(_label(s)),
                selected: s.id == current.id,
                tooltip: widget.results[s.id]?.needsYou ?? true ? '${s.name} needs you' : null,
                onSelected: (_) => _select(s),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 560,
          child: IndexedStack(
            index: widget.shops.indexOf(current),
            children: [
              for (final s in widget.shops)
                if (_alive(s))
                  KeyedSubtree(
                    key: ValueKey('${s.id}|${widget.query.raw}'),
                    child: build(
                      context,
                      PanelRequest(
                        shop: s,
                        url: s.searchFor(widget.query.shopWords()) ?? Uri.parse(s.home),
                        onOffers: (offers) => widget.onOffers(s, offers),
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );
  }
}

/// One shop's search page, live inside Search. It reads the products as the
/// page draws them: the page's product data and tiles by a script that
/// watches the page change; if those give nothing, the text on the screen.
/// It reads nothing on a sign-in or payment page, or on a shop's check page,
/// and it never clicks or types: the user does that.
class LiveShopPanel extends ConsumerStatefulWidget {
  const LiveShopPanel(this.request, {super.key});
  final PanelRequest request;

  @override
  ConsumerState<LiveShopPanel> createState() => _LiveShopPanelState();
}

class _LiveShopPanelState extends ConsumerState<LiveShopPanel> {
  InAppWebViewController? _web;
  late Uri _url = widget.request.url;
  var _progress = 0.0;
  var _count = 0;
  var _fromScreen = false;
  var _reading = false;
  Timer? _later;
  final _screenTried = <String>{};

  Shop get _shop => widget.request.shop;
  bool get _private => isPrivatePage(_url);
  bool get _wall => isWallAddress(_url);

  @override
  void dispose() {
    _later?.cancel();
    super.dispose();
  }

  /// Products the page script reported for the page at [href].
  void _got(Object? json, Object? href) {
    final at = Uri.tryParse('$href');
    if (!mounted || at == null || isPrivatePage(at) || isWallAddress(at)) return;
    final offers = parseOffers(_shop, '$json');
    if (offers.isEmpty) return;
    setState(() {
      _count = offers.length;
      _fromScreen = false;
    });
    widget.request.onOffers(offers);
  }

  /// Reads the products off the page as drawn. The panel shows only part of
  /// the page, and the top of a results page is mostly the shop's header,
  /// its own adverts and a cookie notice, so it looks at up to
  /// [screenViews] screenfuls: it scrolls down a step at a time, keeps a
  /// screenshot of each, puts the page back where it was, and only then
  /// reads the text off them. A background try ([asked] false) scrolls only
  /// while the page is still at its top, so it never moves a page the user
  /// is reading. When the user [asked] and nothing could be read, says so.
  Future<void> _readScreen({bool asked = false}) async {
    final web = _web;
    if (web == null || _reading || _private || _wall) return;
    setState(() => _reading = true);
    final at = _url;
    final watch = Stopwatch()..start();
    void nothing(String why) {
      debugPrint('Chanda: nothing read from the screen of ${_shop.id}: $why');
      if (asked && mounted) {
        showMessage(context, 'Nothing readable on the screen yet. Scroll to the results and try again.');
      }
    }

    try {
      final shots = <(ScreenView, Uint8List)>[];
      var moved = 0.0, covered = false;
      try {
        Uint8List? previous;
        // A few more steps than screenfuls: skipping the header costs one.
        for (var i = 0; i < screenViews + 2 && shots.length < screenViews; i++) {
          final png = await _settledShot(web, previous);
          if (png == null) break;
          previous = png;
          // The layout as drawn: read after the screenshot, since a page may
          // show a bar of its own once it scrolls.
          final json = await web.evaluateJavascript(source: viewScript);
          final css = readView(json, scale: 1);
          if (css.isEmpty) break;
          final band = css.bottom - css.top;
          if (band < css.height * 0.15) {
            covered = true;
            break;
          }
          if (worthReading(css)) shots.add((readView(json, scale: pngHeight(png) / css.height), png));
          // A page the user has scrolled is not moved by a background try.
          if ((!asked && i == 0 && css.scrollY > 0) || !mounted || _url != at) break;
          final step = await web.evaluateJavascript(source: scrollByScript(screenStep(css)));
          if (step is! num || step <= 0) break;
          moved += step;
        }
      } finally {
        if (moved > 0) await web.evaluateJavascript(source: scrollByScript(-moved));
      }
      if (!mounted || _private || _wall || _url != at) return;
      if (covered && shots.isEmpty) {
        debugPrint('Chanda: nothing read from the screen of ${_shop.id}: something covers the page');
        if (asked) {
          showMessage(
            context,
            'Something on the page covers the results, like a cookie notice. Close it, then try again.',
          );
        }
        return;
      }
      if (shots.isEmpty) return nothing('no screenshot or no page layout');
      final views = <List<ScreenTile>>[];
      var lineCount = 0;
      for (final (view, png) in shots) {
        final (lines, _) = await readScreen(png, top: view.top, bottom: view.bottom);
        lineCount += lines.length;
        views.add(viewTiles(lines, view, hint: _shop.currency));
      }
      final tiles = mergeTiles(views);
      final offers = plausiblePrices(
        parseOffers(_shop, [for (final t in tiles) t.toJson()], source: OfferSource.screen),
        (o) => o.price,
      );
      debugPrint(
        'Chanda: read ${offers.length} products from ${shots.length} screens of ${_shop.id} '
        '(${tiles.length} tiles, $lineCount lines) in ${watch.elapsedMilliseconds} ms',
      );
      if (!mounted) return;
      if (offers.isEmpty) {
        return nothing(
          '$lineCount text lines, ${tiles.length} tiles on ${shots.length} screens, no products',
        );
      }
      setState(() {
        _count = offers.length;
        _fromScreen = true;
      });
      widget.request.onOffers(offers);
    } on Object catch (e) {
      debugPrint('Chanda: reading the screen of ${_shop.id} failed: $e');
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  /// A screenshot of the page once it shows something new: after a scroll
  /// the web engine draws the page again a moment later, and until then a
  /// screenshot is the screen before ([before]).
  Future<Uint8List?> _settledShot(InAppWebViewController web, Uint8List? before) async {
    if (before == null) return web.takeScreenshot();
    Uint8List? png;
    for (var i = 0; i < 15; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      png = await web.takeScreenshot();
      if (png != null && !listEquals(png, before)) break;
    }
    // Let the newly shown part finish drawing (late pictures, text).
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return await web.takeScreenshot() ?? png;
  }

  /// A while after the page loads with nothing read, try the screen once.
  void _maybeReadScreen() {
    _later?.cancel();
    _later = Timer(const Duration(seconds: 9), () {
      final key = '$_url';
      if (!mounted || _count > 0 || _private || _wall || !_screenTried.add(key)) return;
      _readScreen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = NithyaPalette.of(context);
    final style = Theme.of(context).textTheme;
    if (!hasWebView) {
      return Extruded(
        depth: 0.4,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${_shop.name} needs Chanda\'s web engine, which this build does not have. Search other shops '
              'here, or open ${_shop.name} yourself in your own browser.',
              style: style.bodyMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open in browser'),
              onPressed: () => openLink(context, '$_url'),
            ),
          ],
        ),
      );
    }
    return Extruded(
      depth: 0.4,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 4, 0),
            child: Row(
              children: [
                Icon(_private ? Icons.lock : Icons.public, size: 16, color: _private ? drop : p.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _private
                        ? 'Sign-in or payment page: Chanda is not reading it.'
                        : _count > 0
                        ? '$_count products read${_fromScreen ? ' from the screen' : ''}'
                        : _wall
                        ? 'Pass the check below: Chanda reads the results once they show.'
                        : 'Waiting for results…',
                    style: style.bodySmall,
                  ),
                ),
                if (_reading)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                  onPressed: () => _web?.goBack(),
                ),
                IconButton(
                  tooltip: 'Reload',
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: () => _web?.reload(),
                ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  onSelected: (v) => switch (v) {
                    'screen' => _readScreen(asked: true),
                    'browser' => openLink(context, '${cleanLink(_url)}'),
                    _ => null,
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'screen',
                      enabled: !_private && !_wall,
                      child: const Text('Read the results from the screen'),
                    ),
                    const PopupMenuItem(value: 'browser', child: Text('Open in browser')),
                  ],
                ),
              ],
            ),
          ),
          if (_progress < 1) LinearProgressIndicator(value: _progress, minHeight: 2),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri('${widget.request.url}')),
              initialUserScripts: UnmodifiableListView([
                UserScript(source: panelScript, injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END),
              ]),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                useShouldOverrideUrlLoading: true,
                mediaPlaybackRequiresUserGesture: true,
              ),
              onWebViewCreated: (c) {
                _web = c;
                c.addJavaScriptHandler(
                  handlerName: tilesHandler,
                  callback: (args) {
                    if (args.length >= 2) _got(args[0], args[1]);
                    return null;
                  },
                );
              },
              shouldOverrideUrlLoading: (_, action) => routeNavigation(context, action),
              onUpdateVisitedHistory: (_, url, _) {
                if (url != null && mounted) setState(() => _url = Uri.parse('$url'));
              },
              onProgressChanged: (_, n) {
                if (mounted) setState(() => _progress = n / 100);
              },
              onLoadStop: (c, url) async {
                // Where the script was not injected, inject it now (it runs once).
                final at = url == null ? null : Uri.tryParse('$url');
                if (at != null && !isPrivatePage(at) && !isWallAddress(at)) {
                  await c.evaluateJavascript(source: panelScript);
                }
                _maybeReadScreen();
              },
            ),
          ),
        ],
      ),
    );
  }
}
