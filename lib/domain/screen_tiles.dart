import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

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

/// Shop furniture around a tile's name: "Sponsored", "+6 other colours",
/// "Add to basket", "100+ bought in past month", "Best Seller".
final _tileNoise = RegExp(
  r'^(sponsored|\+\s?\d+\s+(other|more)\b|add to (basket|cart|bag|trolley)|\d+[\d,.]*k?\+?\s+bought\b|'
  r'best\s?seller|amazon.s choice|limited time deal|options?:|more (buying )?(choices|options))',
  caseSensitive: false,
);

bool _isTitleLine(ScreenLine l, String hint) {
  final t = l.text.trim();
  if (t.length < 4 || isPriceLine(l, hint) || _priceWords.hasMatch(t) || _tileNoise.hasMatch(t)) return false;
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
      // The name is over the price; under it are delivery and basket lines.
      final title = _title([
        for (final l in ls)
          if (l.bottom <= now.top + now.height * 0.3) l,
      ], hint);
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

/// The height in pixels of the PNG picture [png] (from its header), or 0.
double pngHeight(Uint8List png) {
  const sign = [0x89, 0x50, 0x4E, 0x47];
  if (png.length < 24 || [for (var i = 0; i < 4; i++) png[i]].join() != sign.join()) return 0;
  return ByteData.sublistView(png, 20, 24).getUint32(0).toDouble();
}

/// One screenful of a page, as [viewScript] saw it, in screenshot pixels:
/// the band not hidden by bars pinned to the top or bottom of the view (a
/// sticky header, a cookie notice), the picture links in it ([boxes]) and
/// every link in it ([links]), and how far the page was scrolled.
class ScreenView {
  const ScreenView({
    required this.width,
    required this.height,
    required this.top,
    required this.bottom,
    required this.scrollY,
    this.next,
    this.boxes = const [],
    this.links = const [],
  });
  static const none = ScreenView(width: 0, height: 0, top: 0, bottom: 0, scrollY: 0);

  /// The view's size in CSS pixels.
  final double width, height;

  /// The clear band, in screenshot pixels.
  final double top, bottom;

  /// How far the page was scrolled, in CSS pixels.
  final double scrollY;

  /// Where the first picture link at or below the band's top starts (it may
  /// be below the view), scaled like the band; null when the page has none.
  final double? next;
  final List<ScreenBox> boxes;
  final List<ScreenBox> links;

  bool get isEmpty => height <= 0;
}

/// The view [viewScript] answered with [json], scaled by [scale]
/// (screenshot pixels per CSS pixel).
ScreenView readView(Object? json, {required double scale}) {
  List<ScreenBox> rects(Object? list) => [
    if (list is List)
      for (final b in list.whereType<Map>())
        ScreenBox(
          '${b['href']}',
          left: (b['x'] as num) * scale,
          top: (b['y'] as num) * scale,
          width: (b['w'] as num) * scale,
          height: (b['h'] as num) * scale,
        ),
  ];
  try {
    final j = json is String ? jsonDecode(json) : json;
    if (j is! Map) return ScreenView.none;
    final h = (j['h'] as num).toDouble();
    return ScreenView(
      width: (j['w'] as num).toDouble(),
      height: h,
      top: ((j['top'] as num?) ?? 0) * scale,
      bottom: ((j['bottom'] as num?) ?? h) * scale,
      scrollY: ((j['sy'] as num?) ?? 0).toDouble(),
      next: switch (j['next']) {
        final num n => n * scale,
        _ => null,
      },
      boxes: rects(j['boxes']),
      links: rects(j['links']),
    );
  } on Object {
    return ScreenView.none;
  }
}

/// The link under the first of [probes] that has one: the smallest of
/// [links] holding the point. Empty when none does.
String linkAt(List<(double, double)> probes, List<ScreenBox> links) {
  for (final (x, y) in probes) {
    ScreenBox? best;
    for (final l in links) {
      if (x < l.left || x > l.right || y < l.top || y > l.bottom) continue;
      if (best == null || l.width * l.height < best.width * best.height) best = l;
    }
    if (best != null) return best.href;
  }
  return '';
}

/// The products read off one screenful: [lines] matched to the view's
/// picture links, and a tile without one given the link under its text.
List<ScreenTile> viewTiles(List<ScreenLine> lines, ScreenView view, {required String hint}) => [
  for (final t in screenTiles(lines, view.boxes, hint: hint, width: view.width))
    t.href.isNotEmpty ? t : t.withHref(linkAt(t.probes, view.links)),
];

/// The tiles of several screenfuls, each product once: by its link, or by
/// its name and price where it has none. Where one screenful cut a name
/// short at its edge, the longest reading of the name is kept.
List<ScreenTile> mergeTiles(Iterable<List<ScreenTile>> views) {
  final out = <String, ScreenTile>{};
  for (final view in views) {
    for (final t in view) {
      final key = t.href.isNotEmpty ? t.href : '${t.title}|${t.price}';
      final old = out[key];
      if (old == null || t.title.length > old.title.length) out[key] = t;
    }
  }
  return [...out.values];
}

/// [items] without prices far out of line with the rest: a misread digit
/// or two lines read as one ("£80.28" and "100 sold" as "£8028100") gives a
/// sum ten times the others or more. Needs three or more to compare.
List<T> plausiblePrices<T>(List<T> items, int Function(T) minor) {
  if (items.length < 3) return items;
  final sorted = [for (final i in items) minor(i)]..sort();
  final median = sorted[sorted.length ~/ 2];
  return [
    for (final i in items)
      if (minor(i) <= median * 10 && minor(i) * 10 >= median) i,
  ];
}

/// How many screenfuls a read from the screen reads at most.
const screenViews = 6;

/// How far to scroll from [view] (CSS pixels) for the next screenful: past
/// the shop's header and banners to the first picture link when there is
/// none in reach yet, otherwise on by part of the clear band, so that a
/// tile's text cut at the band's edge is whole in the next one.
double screenStep(ScreenView view) {
  final band = view.bottom - view.top;
  final next = view.next;
  if (view.boxes.isEmpty && next != null && next > view.top + band * 0.5) return next - view.top - 8;
  return max(band * 0.5, band - 260);
}

/// Whether [view] is worth reading: it has a picture link in reach, or the
/// page has none at all (then its text alone is grouped into tiles).
bool worthReading(ScreenView view) => view.boxes.isNotEmpty || view.next == null;

/// JavaScript that describes what is on the screen: the view's size and
/// scroll, the band not covered by bars pinned to its top or bottom, and the
/// links in that band (with the picture links among them), all in CSS
/// pixels. It reads only.
const viewScript = r'''
(() => {
  const ad = /sponsored-ads\.|\/sspa\/|[/.]aax-|\/gp\/slredirect|\/aclk\b|doubleclick\./i;
  const W = innerWidth, H = innerHeight;
  const pinned = (el) => {
    for (let e = el; e && e !== document.body && e !== document.documentElement; e = e.parentElement) {
      const p = getComputedStyle(e).position;
      if (p === 'fixed' || p === 'sticky') return e;
    }
    return null;
  };
  let top = 0, bottom = H;
  for (const f of [0.1, 0.5, 0.9]) {
    const a = pinned(document.elementFromPoint(W * f, 2));
    if (a) { const r = a.getBoundingClientRect(); if (r.top <= 2 && r.bottom < H * 0.5) top = Math.max(top, r.bottom); }
    const b = pinned(document.elementFromPoint(W * f, H - 2));
    if (b) { const r = b.getBoundingClientRect(); if (r.bottom >= H - 2 && r.top > H * 0.25) bottom = Math.min(bottom, r.top); }
  }
  // Links in the band; picture links in it or just over it (a tile's
  // picture may sit above the band while its text is in it); and where the
  // first picture link at or below the band's top starts.
  const boxes = new Map(), links = [];
  let next = null;
  for (const a of document.querySelectorAll('a[href]')) {
    if (a.closest('header, nav, footer')) continue;
    let href = '';
    try { href = new URL(a.getAttribute('href'), document.baseURI).href; } catch (e) { continue; }
    if (!/^https?:/.test(href) || ad.test(href)) continue;
    const r = a.getBoundingClientRect();
    if (r.width < 4 || r.height < 4 || r.right < 0 || r.left > W) continue;
    if (r.bottom >= top && r.top <= bottom && links.length < 800) links.push({href, x: r.left, y: r.top, w: r.width, h: r.height});
    if (r.width < 40 || r.height < 40 || !a.querySelector('img')) continue;
    if (r.top >= top && (next === null || r.top < next)) next = r.top;
    if (r.top > bottom || r.bottom < top - r.height * 1.6) continue;
    const old = boxes.get(href);
    if (!old || old.w * old.h < r.width * r.height) boxes.set(href, {href, x: r.left, y: r.top, w: r.width, h: r.height});
  }
  const s = document.scrollingElement || document.documentElement;
  return JSON.stringify({w: W, h: H, top, bottom, sy: s.scrollTop, next, boxes: [...boxes.values()], links});
})()
''';

/// The element the page scrolls: the document, or where the document does
/// not scroll, the biggest scrolling box in the middle of the view.
const _scroller = r'''
const scroller = () => {
  const doc = document.scrollingElement || document.documentElement;
  if (doc.scrollHeight > innerHeight + 4) return doc;
  for (let e = document.elementFromPoint(innerWidth / 2, innerHeight / 2); e; e = e.parentElement) {
    const o = getComputedStyle(e).overflowY;
    if ((o === 'auto' || o === 'scroll') && e.scrollHeight > e.clientHeight + 4) return e;
  }
  return doc;
};
''';

/// JavaScript that scrolls the page down by [dy] CSS pixels at once and
/// says how far it moved (a negative [dy] scrolls back up). Only the view
/// moves: nothing is clicked.
String scrollByScript(double dy) =>
    '''
(() => {
  $_scroller
  const s = scroller(), before = s.scrollTop;
  s.scrollTo({top: before + ${dy.round()}, behavior: 'instant'});
  return s.scrollTop - before;
})()
''';
