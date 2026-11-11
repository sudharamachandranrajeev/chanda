import 'dart:convert';
import 'dart:math';

import 'money.dart';
import 'screen_text.dart';

// The last rung of reading a live shop panel: when a results page gives
// neither product data nor tiles Chanda can read (it is drawn as pictures,
// or the shop changes its layout), it reads the text off a screenshot of
// what the user sees and matches it to the page's own links. Prices read
// this way are shown, marked "read from screen", but never kept or alerted
// on until the product page itself has been read.

/// A link on the page that holds a picture (a product tile's photo), with
/// its place on the screen in screenshot pixels.
class ScreenBox {
  const ScreenBox(
    this.href, {
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
  final String href;
  final double left, top, width, height;

  double get right => left + width;
  double get bottom => top + height;
}

/// A product read off the screen. [href] is set when a picture link was
/// found for it; otherwise [probes] are points on the screen to look for
/// a link under (see [linkProbeScript]).
class ScreenTile {
  const ScreenTile({
    required this.title,
    required this.price,
    this.was = '',
    this.href = '',
    this.probes = const [],
  });
  final String title;
  final String price;
  final String was;
  final String href;
  final List<(double, double)> probes;

  ScreenTile withHref(String h) => ScreenTile(title: title, price: price, was: was, href: h, probes: probes);

  Map<String, Object?> toJson() => {'title': title, 'price': price, 'was': was, 'url': href, 'src': 'screen'};
}

final _priceWords = RegExp(
  r'\b(was|rrp|list|typical|delivery|shipping|postage|off|save|saving|coupon|per|each|from|reviews?|sold|'
  r'ratings?|stars?|free)\b|%',
  caseSensitive: false,
);
final _hasSign = RegExp(r'[£$€¥₹₩]|\b[A-Z]{3}\b|\d[.,]\d{2}\b');

/// Whether [l] is only a price ("£29.99", "29,99 €"), nothing like a
/// discount or a delivery line.
bool isPriceLine(ScreenLine l, String hint) {
  final t = l.text.trim();
  if (t.length > 22 || _priceWords.hasMatch(t) || !_hasSign.hasMatch(t)) return false;
  // Only digits and the marks of a price; a name with a number in it is not.
  if (RegExp(r'[A-Za-z]{4,}').hasMatch(t.replaceAll(RegExp(r'\b[A-Z]{3}\b'), ''))) return false;
  final p = parsePrice(t, hint: hint);
  return p != null && p.minor > 0;
}

bool _isTitleLine(ScreenLine l, String hint) {
  final t = l.text.trim();
  if (t.length < 4 || isPriceLine(l, hint) || _priceWords.hasMatch(t)) return false;
  // "4.5 (120)" and "★★★★" are ratings; they have almost no letters.
  return RegExp(r'\p{L}', unicode: true).allMatches(t).length >= 3;
}

({ScreenLine now, ScreenLine? was}) _prices(List<ScreenLine> prices, String hint) {
  // The current price is drawn biggest; a struck price is the larger sum.
  final sorted = [...prices]
    ..sort((a, b) => b.height != a.height ? b.height.compareTo(a.height) : a.top.compareTo(b.top));
  final now = sorted.first;
  final nowMinor = parsePrice(now.text, hint: hint)!.minor;
  final was = prices.where((p) => p != now && parsePrice(p.text, hint: hint)!.minor > nowMinor).firstOrNull;
  return (now: now, was: was);
}

String _title(List<ScreenLine> lines, String hint) {
  final words = [
    for (final l in lines)
      if (_isTitleLine(l, hint)) l.text.trim(),
  ];
  // A name wraps over lines; two or three together are the whole name.
  return words.take(3).join(' ');
}

/// Products read off a screenshot. [boxes] are the page's picture links; a
/// tile is the box with the lines of text below (and over) it. Without
/// boxes the text alone is grouped into columns, each tile closing at its
/// price line. [hint] is the shop's currency, for prices without a mark.
List<ScreenTile> screenTiles(
  List<ScreenLine> lines,
  List<ScreenBox> boxes, {
  String hint = 'GBP',
  double? width,
}) {
  final ordered = [...lines]
    ..sort((a, b) => a.top != b.top ? a.top.compareTo(b.top) : a.left.compareTo(b.left));
  final out = <ScreenTile>[];
  if (boxes.isNotEmpty) {
    final byBox = <ScreenBox, List<ScreenLine>>{for (final b in boxes) b: []};
    for (final l in ordered) {
      ScreenBox? home;
      for (final b in boxes) {
        final slack = b.width * 0.1;
        final inColumn = l.centreX >= b.left - slack && l.centreX <= b.right + slack;
        // Under the picture, or over it, but not above where it starts.
        final below = l.centreY >= b.top && l.top - b.bottom <= b.height * 1.6;
        if (inColumn && below && (home == null || b.top > home.top)) home = b;
      }
      if (home != null) byBox[home]!.add(l);
    }
    for (final MapEntry(key: b, value: ls) in byBox.entries) {
      final prices = ls.where((l) => isPriceLine(l, hint)).toList();
      if (prices.isEmpty) continue;
      final (:now, :was) = _prices(prices, hint);
      final title = _title(ls, hint);
      if (title.length < 6) continue;
      out.add(ScreenTile(title: title, price: now.text.trim(), was: was?.text.trim() ?? '', href: b.href));
    }
    return out;
  }

  // No picture links: columns by where their text starts. A price beside
  // another on the same row ("£12.99  £18.00") belongs to the first.
  final beside = <ScreenLine, List<ScreenLine>>{};
  final joined = <ScreenLine>{};
  final priced = ordered.where((l) => isPriceLine(l, hint)).toList();
  for (final a in priced) {
    for (final b in priced) {
      final sameRow = (a.centreY - b.centreY).abs() <= max(a.height, b.height) * 0.6;
      if (a != b &&
          !joined.contains(a) &&
          sameRow &&
          b.left > a.left &&
          b.left - (a.left + a.width) <= max(a.height, b.height) * 3) {
        (beside[a] ??= []).add(b);
        joined.add(b);
      }
    }
  }
  final tol = (width ?? 1000) * 0.04;
  final columns = <List<ScreenLine>>[];
  for (final l in [...ordered.where((l) => !joined.contains(l))]..sort((a, b) => a.left.compareTo(b.left))) {
    final col = columns.where((c) => (c.first.left - l.left).abs() <= tol).firstOrNull;
    if (col == null) {
      columns.add([l]);
    } else {
      col.add(l);
    }
  }
  for (final col in columns) {
    col.sort((a, b) => a.top.compareTo(b.top));
    var buffer = <ScreenLine>[];
    for (var i = 0; i < col.length; i++) {
      final l = col[i];
      if (!isPriceLine(l, hint)) {
        buffer.add(l);
        continue;
      }
      // A second price just under the first is the old or the new one.
      final group = [l, ...?beside[l]];
      while (i + 1 < col.length &&
          isPriceLine(col[i + 1], hint) &&
          col[i + 1].top - group.last.bottom <= group.last.height * 1.2) {
        group.add(col[++i]);
      }
      final (:now, :was) = _prices(group, hint);
      final title = _title(buffer, hint);
      final probes = <(double, double)>[
        for (final t in [...buffer.reversed.where((b) => _isTitleLine(b, hint)), now]) (t.centreX, t.centreY),
      ];
      buffer = [];
      if (title.length < 6) continue;
      out.add(ScreenTile(title: title, price: now.text.trim(), was: was?.text.trim() ?? '', probes: probes));
    }
  }
  return out;
}

/// JavaScript that lists the picture links on the screen: the page's size in
/// CSS pixels and, for each link around a picture, its place. It reads only.
const boxesScript = r'''
(() => {
  const ad = /sponsored-ads\.|\/sspa\/|[/.]aax-|\/gp\/slredirect|\/aclk\b|doubleclick\./i;
  const seen = new Map();
  for (const a of document.querySelectorAll('a[href]')) {
    if (a.closest('header, nav, footer') || !a.querySelector('img')) continue;
    let href = '';
    try { href = new URL(a.getAttribute('href'), document.baseURI).href; } catch (e) { continue; }
    if (!/^https?:/.test(href) || ad.test(href)) continue;
    const r = a.getBoundingClientRect();
    if (r.width < 40 || r.height < 40 || r.bottom < 0 || r.top > innerHeight || r.right < 0 || r.left > innerWidth) continue;
    const old = seen.get(href);
    if (!old || old.w * old.h < r.width * r.height) seen.set(href, {href, x: r.left, y: r.top, w: r.width, h: r.height});
  }
  return JSON.stringify({w: innerWidth, h: innerHeight, boxes: [...seen.values()]});
})()
''';

/// The page size and picture links [boxesScript] found, scaled by [scale]
/// (screenshot pixels per CSS pixel).
({double width, double height, List<ScreenBox> boxes}) readBoxes(Object? json, {required double scale}) {
  try {
    final j = json is String ? jsonDecode(json) : json;
    if (j is! Map) return (width: 0, height: 0, boxes: const []);
    return (
      width: (j['w'] as num).toDouble(),
      height: (j['h'] as num).toDouble(),
      boxes: [
        for (final b in (j['boxes'] as List).whereType<Map>())
          ScreenBox(
            '${b['href']}',
            left: (b['x'] as num) * scale,
            top: (b['y'] as num) * scale,
            width: (b['w'] as num) * scale,
            height: (b['h'] as num) * scale,
          ),
      ],
    );
  } on Object {
    return (width: 0, height: 0, boxes: const []);
  }
}

/// JavaScript that finds, for each point (CSS pixels, as JSON text), the
/// link under it, using `elementsFromPoint`; empty where there is none or it
/// is an advert. It reads only.
String linkProbeScript(List<(double, double)> points) =>
    '''
((pts) => {
  const ad = /sponsored-ads\\.|\\/sspa\\/|[/.]aax-|\\/gp\\/slredirect|\\/aclk\\b|doubleclick\\./i;
  return JSON.stringify(pts.map(([x, y]) => {
    for (const el of document.elementsFromPoint(x, y)) {
      const a = el.closest('a[href]');
      if (!a) continue;
      try {
        const href = new URL(a.getAttribute('href'), document.baseURI).href;
        if (/^https?:/.test(href) && !ad.test(href)) return href;
      } catch (e) {}
    }
    return '';
  }));
})(${jsonEncode([
      for (final (x, y) in points) [x, y],
    ])})
''';
