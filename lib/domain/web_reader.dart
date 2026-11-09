import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'html_evidence.dart';
import 'links.dart';
import 'reading.dart';

/// Whether this build has an embedded web view. Linux has one (WPE WebKit)
/// when built with it; a build without (packages/no_linux_webview) opens
/// shops in the system browser and reads plain HTML.
bool get hasWebView =>
    !kIsWeb &&
    (Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isWindows ||
        Platform.isMacOS ||
        (Platform.isLinux && InAppWebViewPlatform.instance != null));

/// Gathers a product page's evidence. Tests swap in a fake.
abstract class PageReader {
  Future<Evidence> read(Uri url);
}

/// Reads with a hidden web view that shares the in-app browser's cookies,
/// so a shop the user signed in to shows them their own prices. Used only
/// while the app is open.
class WebPageReader implements PageReader {
  const WebPageReader();

  @override
  Future<Evidence> read(Uri url) async {
    if (isPrivatePage(url)) throw ArgumentError('Chanda does not read sign-in or payment pages');
    final loaded = Completer<void>();
    final view = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri('$url')),
      initialSettings: InAppWebViewSettings(javaScriptEnabled: true),
      onLoadStop: (_, _) {
        if (!loaded.isCompleted) loaded.complete();
      },
      onReceivedError: (_, req, err) {
        if (err.type == WebResourceErrorType.CANCELLED) return;
        if (req.isForMainFrame != false && !loaded.isCompleted) loaded.completeError(err.description);
      },
      onReceivedHttpError: (_, req, res) {
        if (req.isForMainFrame != false && (res.statusCode == 404 || res.statusCode == 410) && !loaded.isCompleted) {
          loaded.completeError(const PageGone());
        }
      },
    );
    try {
      await view.run();
      await loaded.future.timeout(const Duration(seconds: 40));
      return await settle(view.webViewController!);
    } finally {
      await view.dispose();
    }
  }
}

/// Reads [web]'s page a few times while its script draws it, until a
/// product reads the same twice (or the page is a check twice in a row).
Future<Evidence> settle(InAppWebViewController web, {int tries = 12}) async {
  Evidence? last;
  String? lastKey;
  var checks = 0;
  for (var i = 0; i < tries; i++) {
    await Future<void>.delayed(Duration(milliseconds: i == 0 ? 800 : 1500));
    final raw = await web.evaluateJavascript(source: evidenceScript);
    if (raw == null) continue;
    final e = Evidence.fromJson(raw is String ? raw : jsonEncode(raw));
    final r = readProduct(e, hint: 'GBP');
    final key = '${r.title}|${r.price}|${r.currency}|${r.inStock}';
    if (e.check && r.price == null) {
      if (++checks >= 2) return e;
    } else {
      checks = 0;
    }
    if (r.price != null && key == lastKey) return e;
    last = e;
    lastKey = key;
  }
  return last ?? Evidence(url: '${await web.getUrl() ?? ''}');
}

/// Reads plain HTML, as Chanda (background checks, and builds without a
/// web view).
class HtmlPageReader implements PageReader {
  const HtmlPageReader();

  @override
  Future<Evidence> read(Uri url) {
    if (isPrivatePage(url)) throw ArgumentError('Chanda does not read sign-in or payment pages');
    return fetchEvidence(url);
  }
}
