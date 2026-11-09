import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'reading.dart';

/// Collects [Evidence] from a page's HTML without a web view: for background
/// price checks, where no page is drawn. Prices drawn by script are not
/// seen, so this trusts the page's structured data and falls back to price
/// texts after the title.
Evidence htmlEvidence(String body, String url) {
  final doc = html.parse(body);
  final meta = <String, String>{};
  for (final m in doc.querySelectorAll('meta[content]')) {
    final k = (m.attributes['property'] ?? m.attributes['name'] ?? m.attributes['itemprop'] ?? '').toLowerCase();
    if (k.isNotEmpty) meta.putIfAbsent(k, () => (m.attributes['content'] ?? '').trim());
  }
  final micro = <String, String>{};
  for (final el in doc.querySelectorAll('[itemprop]')) {
    final k = el.attributes['itemprop']!.toLowerCase();
    final v = el.attributes['content'] ?? el.attributes['href'] ?? el.attributes['src'] ?? el.text;
    if (v.trim().isNotEmpty) micro.putIfAbsent(k, () => v.replaceAll(RegExp(r'\s+'), ' ').trim());
  }
  final ld = [for (final s in doc.querySelectorAll('script[type="application/ld+json"]')) s.text];
  final embedded = [
    for (final s in doc.querySelectorAll('script#__NEXT_DATA__, script[type="application/json"]'))
      if (s.text.contains('price')) s.text,
    for (final s in doc.querySelectorAll('script:not([src])')) ..._assigned(s.text),
  ];
  for (final bad in doc.querySelectorAll('script, style, noscript, template')) {
    bad.remove();
  }
  final h1 = doc.querySelector('h1')?.text.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
  final text = _text(doc.body);
  return Evidence(
    url: url,
    canonical: doc.querySelector('link[rel="canonical"]')?.attributes['href'] ?? '',
    docTitle: doc.querySelector('title')?.text.trim() ?? '',
    h1: h1,
    ld: ld,
    meta: meta,
    micro: micro,
    embedded: embedded,
    prices: _pricesAfter(text, h1),
    text: text.length > 8000 ? text.substring(0, 8000) : text,
    check: RegExp(
      r'security checks?|verify (that )?you are (a )?human|are you a robot|captcha|access denied|unusual traffic|'
      r'pardon our interruption|robot check',
      caseSensitive: false,
    ).hasMatch('${doc.querySelector('title')?.text ?? ''} ${text.length > 2000 ? text.substring(0, 2000) : text}'),
  );
}

/// Loads [url] the plain way, as Chanda (no pretending to be a browser),
/// and collects its evidence. Throws on a network error or HTTP failure.
Future<Evidence> fetchEvidence(Uri url, {http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    final r = await c
        .get(url, headers: {'user-agent': 'Chanda/0.1 (price check for one shopper)', 'accept': 'text/html'})
        .timeout(const Duration(seconds: 30));
    if (r.statusCode == 403 || r.statusCode == 429 || r.statusCode == 503) {
      return Evidence(url: '$url', check: true);
    }
    if (r.statusCode == 404 || r.statusCode == 410) throw const PageGone();
    if (r.statusCode != 200) throw http.ClientException('HTTP ${r.statusCode}', url);
    return htmlEvidence(r.body, '$url');
  } finally {
    if (client == null) c.close();
  }
}

/// The product page no longer exists.
class PageGone implements Exception {
  const PageGone();
  @override
  String toString() => 'The product page is gone';
}

/// JSON a script assigns to a window global: `window.__INIT_DATA__ = {...}`.
Iterable<String> _assigned(String script) sync* {
  for (final m in RegExp(
    r'(?:window\.)?(__INIT_DATA__|__NUXT__|__APOLLO_STATE__|__PRELOADED_STATE__|__INITIAL_STATE__|__rawData__|runParams|rawData|gbRawData|goodsDetailData|productIntroData)\s*=\s*',
  ).allMatches(script)) {
    final start = m.end;
    if (start >= script.length || (script[start] != '{' && script[start] != '[')) continue;
    final end = _matchingBrace(script, start);
    if (end != null && end - start < 3000000) yield script.substring(start, end + 1);
  }
}

int? _matchingBrace(String s, int start) {
  var depth = 0;
  var inString = false;
  String? quote;
  for (var i = start; i < s.length; i++) {
    final c = s[i];
    if (inString) {
      if (c == '\\') {
        i++;
      } else if (c == quote) {
        inString = false;
      }
    } else if (c == '"' || c == "'") {
      inString = true;
      quote = c;
    } else if (c == '{' || c == '[') {
      depth++;
    } else if (c == '}' || c == ']') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return null;
}

String _text(Element? body) {
  if (body == null) return '';
  final out = StringBuffer();
  void walk(Node n) {
    if (n is Text) {
      final t = n.text.replaceAll(RegExp(r'\s+'), ' ');
      if (t.trim().isNotEmpty) out.write(t);
    } else if (n is Element) {
      final block = const {
        'p',
        'div',
        'li',
        'tr',
        'br',
        'h1',
        'h2',
        'h3',
        'h4',
        'section',
        'article',
        'header',
        'footer',
        'td',
        'dd',
        'dt',
        'span',
      }.contains(n.localName);
      if (block && n.localName != 'span') out.write('\n');
      for (final c in n.nodes) {
        walk(c);
      }
      if (block && n.localName != 'span') out.write('\n');
    }
  }

  walk(body);
  return out.toString().replaceAll(RegExp(r'\n\s*\n+'), '\n').trim();
}

/// Price texts in the page text after the title, first seen first.
List<PriceSeen> _pricesAfter(String text, String h1) {
  var from = h1.isEmpty ? 0 : text.indexOf(h1);
  if (from < 0) from = 0;
  final window = text.substring(from, (from + 3000).clamp(0, text.length));
  final out = <PriceSeen>[];
  final re = RegExp(r'(?:[£€$¥₹₩₺₽₫₱฿₪￡￥＄]|US\s?\$|[A-Z]{2}\$|R\$)\s?\d[\d.,]*|\d[\d.,]*\s?(?:€|zł|Kč)');
  for (final (i, m) in re.allMatches(window).take(12).indexed) {
    final before = window.substring((m.start - 16).clamp(0, window.length), m.start).toLowerCase();
    out.add(
      PriceSeen(
        m[0]!.trim(),
        struck: RegExp(r'\b(was|rrp|list price|typical price)\b').hasMatch(before),
        score: 10.0 - i,
      ),
    );
  }
  return out;
}
