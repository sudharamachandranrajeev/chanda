import 'dart:async';
import 'dart:collection';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'offers.dart';
import 'query.dart';
import 'reading.dart' show checkScript;
import 'shops.dart';
import 'web_reader.dart' show hasWebView;

/// Searches one shop's search page. Tests swap in a fake.
abstract class ShopSearcher {
  /// Whether this device can read shop pages itself (it needs a web view).
  bool get available;

  /// Throws [ShopCheck] when the shop shows its check instead of results.
  Future<List<Offer>> search(Shop shop, Query q);
}

/// Reads shop search pages in a hidden web view that shares the in-app
/// browser's cookies, so a shop the user signed in to shows them their own
/// prices. It loads the page the way the browser does: no disguise, and a
/// shop that asks for a check gets the user, in the visible browser.
class WebShopSearcher implements ShopSearcher {
  const WebShopSearcher();

  @override
  bool get available => hasWebView;

  @override
  Future<List<Offer>> search(Shop shop, Query q) async {
    final url = shop.searchFor(q.words);
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
      // Results are drawn by script after the page loads: read until
      // products for the search appear and two reads agree.
      final web = view.webViewController!;
      var offers = const <Offer>[];
      String? last;
      var same = 0, checks = 0;
      for (var i = 0; i < 14; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        final json = '${await web.evaluateJavascript(source: offerScript)}';
        same = json == last ? same + 1 : 0;
        last = json;
        offers = parseOffers(shop, json);
        final found = rankOffers(q, offers).isNotEmpty;
        if (same >= 1 && found) break;
        // Twice in a row, in case the check passes by itself.
        if (!found && await web.evaluateJavascript(source: checkScript) == true) {
          if (++checks >= 2) throw ShopCheck(shop.name);
        } else {
          checks = 0;
        }
      }
      return offers;
    } finally {
      await view.dispose();
    }
  }
}

/// Where a shop's search has got to.
enum SearchState { waiting, searching, done, check, inBrowser, failed }

class ShopResult {
  const ShopResult(this.shop, this.state, {this.offers = const [], this.error = ''});
  final Shop shop;
  final SearchState state;

  /// All the page listed; [rankOffers] picks those worth showing.
  final List<Offer> offers;
  final String error;
}

/// Searches [among] for [q], three shops at a time, reporting each shop's
/// state as it changes. Shops that want the user present are not loaded
/// hidden: they report [SearchState.inBrowser], for the user to open.
/// Shops without a search page are left out.
Stream<ShopResult> searchShops(ShopSearcher searcher, Query q, Iterable<Shop> among, {int atOnce = 3}) {
  final out = StreamController<ShopResult>();
  final wanted = q.of('shop').toSet();
  final list = [
    for (final s in among)
      if (s.search != null && (wanted.isEmpty || wanted.contains(s.id))) s,
  ];
  final queue = Queue<Shop>();
  for (final s in list) {
    if (s.searchHidden && searcher.available) {
      queue.add(s);
      out.add(ShopResult(s, SearchState.waiting));
    } else {
      out.add(ShopResult(s, SearchState.inBrowser));
    }
  }
  var running = 0;
  void next() {
    while (running < atOnce && queue.isNotEmpty) {
      final s = queue.removeFirst();
      running++;
      out.add(ShopResult(s, SearchState.searching));
      searcher
          .search(s, q)
          .then(
            (offers) => out.add(ShopResult(s, SearchState.done, offers: offers)),
            onError: (Object e) =>
                out.add(ShopResult(s, e is ShopCheck ? SearchState.check : SearchState.failed, error: '$e')),
          )
          .whenComplete(() {
            running--;
            if (queue.isEmpty && running == 0) {
              out.close();
            } else {
              next();
            }
          });
    }
  }

  if (queue.isEmpty) {
    scheduleMicrotask(out.close);
  } else {
    scheduleMicrotask(next);
  }
  return out.stream;
}
