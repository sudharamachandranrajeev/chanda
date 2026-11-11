import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'offers.dart';
import 'query.dart';
import 'links.dart' show isPrivatePage;
import 'reading.dart' show checkScript, isWallAddress;
import 'shops.dart';
import 'web_reader.dart' show hasWebView;

/// How a shop is searched on this device.
enum SearchWay {
  /// Through the shop's own product search for apps: plain HTTP, no page.
  api,

  /// Its search page, loaded in a hidden web view.
  hidden,

  /// Only with the user there: the shop's live panel in Search.
  needsYou,
}

/// Searches one shop. Tests swap in a fake.
abstract class ShopSearcher {
  /// How [shop] can be searched here, or null when it cannot (it has no
  /// search page and no product search Chanda knows).
  SearchWay? wayFor(Shop shop);

  /// Gets ready to search [shops]: looks at which run on a platform that
  /// can be asked directly. Quick, and never fails a search.
  Future<void> prepare(Iterable<Shop> shops);

  /// Throws [ShopCheck] when the shop shows its check instead of results.
  Future<List<Offer>> search(Shop shop, Query q);
}

/// Which shops the user got past a check for in a live panel this session.
/// Such a shop is tried hidden on the next searches (the panel and the
/// hidden view share cookies), and goes back to its panel at the first
/// wall, for the rest of the session.
class ShopPasses {
  final _passed = <String>{};
  final _walled = <String>{};

  /// The user's panel showed results for [shop].
  void passed(String shop) {
    if (!_walled.contains(shop)) _passed.add(shop);
  }

  /// A hidden try after a pass met a wall again.
  void walled(String shop) {
    if (_passed.remove(shop)) _walled.add(shop);
  }

  /// Whether to try [shop] hidden although it wants a person present.
  bool tryHidden(String shop) => _passed.contains(shop);
}

/// When to stop reading a results page: once it lists tiles and their
/// count held for two reads in a row (the page has finished drawing them),
/// or after [reads] reads, whichever comes first.
class TileWatch {
  TileWatch({this.reads = 14});
  final int reads;
  var _n = 0, _last = -1, _same = 0;

  /// Records a read that found [count] tiles; true when reading can stop.
  bool add(int count) {
    _n++;
    _same = count == _last ? _same + 1 : 0;
    _last = count;
    return (count > 0 && _same >= 1) || _n >= reads;
  }
}

/// How many shop pages load hidden at once: each web view takes 600-750 MB,
/// so two on a computer and one on a phone.
int get hiddenAtOnce => switch (defaultTargetPlatform) {
  TargetPlatform.android || TargetPlatform.iOS => 1,
  _ => 2,
};

/// Reads shop search pages in a hidden web view that shares the in-app
/// browser's cookies, so a shop the user signed in to shows them their own
/// prices. It loads the page the way the browser does: no disguise, and a
/// shop that asks for a check gets the user, in its live panel.
class WebShopSearcher implements ShopSearcher {
  WebShopSearcher({ShopPasses? passes}) : passes = passes ?? ShopPasses();
  final ShopPasses passes;

  @override
  Future<void> prepare(Iterable<Shop> shops) async {}

  @override
  SearchWay? wayFor(Shop shop) {
    if (shop.search == null) return null;
    if (!hasWebView) return SearchWay.needsYou;
    return shop.searchHidden || passes.tryHidden(shop.id) ? SearchWay.hidden : SearchWay.needsYou;
  }

  @override
  Future<List<Offer>> search(Shop shop, Query q) async {
    final url = shop.searchFor(q.shopWords());
    if (url == null) return const [];
    final loaded = Completer<void>();
    final view = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri('$url')),
      initialSettings: InAppWebViewSettings(javaScriptEnabled: true),
      onLoadStop: (_, _) {
        if (!loaded.isCompleted) loaded.complete();
      },
      onReceivedError: (_, req, err) {
        // A load cut short by the shop's own redirect is not a failure.
        if (err.type == WebResourceErrorType.CANCELLED) return;
        if (req.isForMainFrame != false && !loaded.isCompleted) loaded.completeError(err.description);
      },
    );
    try {
      await view.run();
      await loaded.future.timeout(const Duration(seconds: 30));
      // Results are drawn by script after the page loads: read until the
      // number of tiles stops changing.
      final web = view.webViewController!;
      final watch = TileWatch();
      var checks = 0;
      while (true) {
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        // A check, sign-in or payment page is never read: the user gets
        // the shop's panel instead.
        final at = await web.getUrl();
        if (at != null && (isWallAddress(at) || isPrivatePage(at))) throw ShopCheck(shop.name);
        final offers = parseOffers(shop, '${await web.evaluateJavascript(source: offerScript)}');
        // Twice in a row, in case the check passes by itself.
        if (offers.isEmpty && await web.evaluateJavascript(source: checkScript) == true) {
          if (++checks >= 2) throw ShopCheck(shop.name);
        } else {
          checks = 0;
        }
        if (watch.add(offers.length)) return offers;
      }
    } on ShopCheck {
      passes.walled(shop.id);
      rethrow;
    } finally {
      // Dispose straight away: a web view holds hundreds of megabytes.
      await view.dispose();
    }
  }
}

/// Where a shop's search has got to. [check] and [needsYou] both mean the
/// shop's live panel: it hit a check, or it never loads without a person.
enum SearchState { waiting, searching, done, check, needsYou, failed }

class ShopResult {
  const ShopResult(this.shop, this.state, {this.offers = const [], this.error = ''});
  final Shop shop;
  final SearchState state;

  /// All the page listed; [rankOffers] picks those worth showing.
  final List<Offer> offers;
  final String error;

  bool get needsYou => state == SearchState.check || state == SearchState.needsYou;
}

/// Searches [among] for [q], reporting each shop's state as it changes.
/// Shops with a product search for apps are asked [apiAtOnce] at a time;
/// search pages load hidden [hidden] at a time. Shops that want the user
/// present report [SearchState.needsYou] for their live panel. Shops that
/// cannot be searched are left out.
Stream<ShopResult> searchShops(
  ShopSearcher searcher,
  Query q,
  Iterable<Shop> among, {
  int? hidden,
  int apiAtOnce = 4,
}) {
  final out = StreamController<ShopResult>();
  final wanted = q.of('shop').toSet();
  final queues = {SearchWay.api: Queue<Shop>(), SearchWay.hidden: Queue<Shop>()};
  final limits = {SearchWay.api: apiAtOnce, SearchWay.hidden: hidden ?? hiddenAtOnce};
  final running = {SearchWay.api: 0, SearchWay.hidden: 0};
  bool idle() => queues.values.every((q) => q.isEmpty) && running.values.every((n) => n == 0);
  void next() {
    for (final way in queues.keys) {
      final queue = queues[way]!;
      while (running[way]! < limits[way]! && queue.isNotEmpty) {
        final s = queue.removeFirst();
        running[way] = running[way]! + 1;
        out.add(ShopResult(s, SearchState.searching));
        searcher
            .search(s, q)
            .then(
              (offers) => out.add(ShopResult(s, SearchState.done, offers: offers)),
              onError: (Object e) => out.add(
                ShopResult(s, e is ShopCheck ? SearchState.check : SearchState.failed, error: '$e'),
              ),
            )
            .whenComplete(() {
              running[way] = running[way]! - 1;
              if (idle()) {
                out.close();
              } else {
                next();
              }
            });
      }
    }
  }

  Future<void> start() async {
    final list = [
      for (final s in among)
        if (wanted.isEmpty || wanted.contains(s.id)) s,
    ];
    try {
      await searcher.prepare(list);
    } on Object {
      // Shops that could not be looked at are searched the ordinary way.
    }
    for (final s in list) {
      switch (searcher.wayFor(s)) {
        case null:
          continue;
        case SearchWay.needsYou:
          out.add(ShopResult(s, SearchState.needsYou));
        case final way:
          queues[way]!.add(s);
          out.add(ShopResult(s, SearchState.waiting));
      }
    }
    if (idle()) {
      await out.close();
    } else {
      next();
    }
  }

  scheduleMicrotask(start);
  return out.stream;
}
