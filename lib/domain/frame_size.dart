import 'dart:convert';

import 'reading.dart';

// A glasses frame's size from its listing, in millimetres. Shops write it
// in a few ways, read in this order:
//
//   1. schema.org JSON-LD `additionalProperty` values named like frame width,
//      lens width, bridge width and temple (arm) length;
//   2. the JSON-LD `size`, written as the frame marking "46-19-140";
//   3. the marking in the title or on the page: "52□18 140", "52-18-140";
//   4. a measurements table on the page: "Lens width 52 mm".
//
// The marking is lens width, bridge, temple length. The total width is the
// listing's own frame width when it gives one; otherwise it is estimated as
// two lenses plus the bridge plus about 10 mm for the hinges, and marked so.

/// The extra width of a frame beyond two lenses and the bridge (hinges and
/// rims), used only when a listing gives no total width.
const frameExtraMm = 10.0;

/// Where a frame size came from.
enum FrameSource {
  /// The shop's product data for search engines.
  productData,

  /// The size marking in the listing's title.
  title,

  /// The size marking or a measurements table on the shop's page.
  page,

  /// Typed by the user.
  typed,
}

/// A frame's measurements in millimetres; any may be missing.
class FrameSize {
  const FrameSize({this.total, this.lens, this.bridge, this.temple, required this.source});
  final double? total, lens, bridge, temple;
  final FrameSource source;

  /// The listing gives the total width itself.
  bool get estimated => total == null;

  /// The frame's full width, the listing's or the estimate; null when not
  /// even lens and bridge are known.
  double? get width => total ?? (lens != null && bridge != null ? 2 * lens! + bridge! + frameExtraMm : null);

  /// The size marking, "52-18-140", when lens and bridge are known.
  String? get marking => lens == null || bridge == null
      ? null
      : [lens, bridge, ?temple].map((v) => v!.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)).join('-');

  String get sourceText => switch (source) {
    FrameSource.productData => "the shop's product data",
    FrameSource.title => 'the size marking in the title',
    FrameSource.page => "the shop's page",
    FrameSource.typed => 'what you typed',
  };

  /// One line for the user: the width, how it was found, and the marking.
  String get describe {
    final w = width;
    if (w == null) return 'Frame size unknown.';
    final mm = '${w.toStringAsFixed(0)} mm';
    final from = sourceText;
    final mark = marking == null ? '' : ' (size $marking)';
    return estimated
        ? 'Frame about $mm wide, estimated from the lens and bridge sizes in $from$mark.'
        : 'Frame $mm wide, from $from$mark.';
  }

  Map<String, Object?> toJson() => {
    'total': ?total,
    'lens': ?lens,
    'bridge': ?bridge,
    'temple': ?temple,
    'source': source.name,
  };

  static FrameSize? fromJson(Object? j) {
    if (j is! Map) return null;
    double? d(String k) => (j[k] as num?)?.toDouble();
    final source = FrameSource.values.asNameMap()['${j['source']}'];
    if (source == null) return null;
    return FrameSize(
      total: d('total'),
      lens: d('lens'),
      bridge: d('bridge'),
      temple: d('temple'),
      source: source,
    )._sane();
  }

  /// This size with values outside believable ranges dropped; null when
  /// nothing useful is left.
  FrameSize? _sane() {
    double? within(double? v, double lo, double hi) => v != null && v >= lo && v <= hi ? v : null;
    final s = FrameSize(
      total: within(total, 100, 175),
      lens: within(lens, 35, 70),
      bridge: within(bridge, 10, 28),
      temple: within(temple, 110, 165),
      source: source,
    );
    return s.width == null ? null : s;
  }
}

/// A size marking: two-digit lens and bridge, then an optional temple length
/// ("52□18 140", "46-19-140", "52 18 145", "52[]18-140").
final _marking = RegExp(
  r'(?<![\d.])([3-7]\d)\s*(?:□|\[\s*\]|-|–|\s|x|×)\s*([1-2]\d)(?:\s*(?:-|–|\s)\s*(1[1-6]\d))?(?![\d.])',
);

/// The frame size in a size marking within [text], or null. Without the
/// box sign (□), a temple length is required, so that "52 18" alone in
/// ordinary text is not taken for a size.
FrameSize? frameSizeInMarking(String text, FrameSource source) {
  for (final m in _marking.allMatches(text)) {
    final boxed = RegExp(r'□|\[\s*\]').hasMatch(m.group(0)!);
    if (m.group(3) == null && !boxed) continue;
    final s = FrameSize(
      lens: double.parse(m.group(1)!),
      bridge: double.parse(m.group(2)!),
      temple: m.group(3) == null ? null : double.parse(m.group(3)!),
      source: source,
    )._sane();
    if (s != null) return s;
  }
  return null;
}

/// Which measure a name like "Lens width", "bridgeWidth" or "Arm length"
/// is: total, lens, bridge or temple; null for others.
String? _measure(String name) {
  final n = name.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
  if (RegExp(r'^(frame|total|overall)(width|size)?$').hasMatch(n) || n == 'framewidthtotal') return 'total';
  if (RegExp(r'^(lens|eye)(width|size|diameter)?$').hasMatch(n)) return 'lens';
  if (RegExp(r'^(bridge|nosebridge)(width|size)?$').hasMatch(n)) return 'bridge';
  if (RegExp(r'^(temple|arm|templearm)(length|size)?$').hasMatch(n)) return 'temple';
  return null;
}

/// Millimetres in [value] (a number or "51 mm"), given [unit] (UN/CEFACT:
/// MMT millimetre, CMT centimetre); null when not a length.
double? _mm(Object? value, String? unit) {
  final m = RegExp(r'^\s*(\d+(?:[.,]\d+)?)\s*(mm|cm)?\s*$', caseSensitive: false).firstMatch('$value');
  if (m == null) return null;
  final n = double.parse(m.group(1)!.replaceAll(',', '.'));
  final u = (m.group(2) ?? unit ?? 'MMT').toUpperCase();
  return u == 'CM' || u == 'CMT' ? n * 10 : n;
}

/// The frame size in a page's JSON-LD [blocks]: the product's
/// `additionalProperty` measurements, else its `size` marking.
FrameSize? frameSizeInLd(List<String> blocks) {
  final found = <String, double>{};
  String? sizeText;
  void walk(Object? n, int depth) {
    if (depth > 12) return;
    if (n is List) {
      for (final x in n) {
        walk(x, depth + 1);
      }
    } else if (n is Map) {
      final props = n['additionalProperty'];
      for (final p in props is List ? props : [?props]) {
        if (p is! Map) continue;
        final what = _measure('${p['name'] ?? p['propertyID'] ?? ''}');
        final mm = _mm(p['value'], p['unitCode'] as String?);
        if (what != null && mm != null) found.putIfAbsent(what, () => mm);
      }
      final size = n['size'];
      if (size is String && sizeText == null) sizeText = size;
      for (final v in n.values) {
        if (v is Map || v is List) walk(v, depth + 1);
      }
    }
  }

  for (final b in blocks) {
    try {
      walk(jsonDecode(b), 0);
    } on FormatException {
      // Skip a block the shop wrote badly.
    }
  }
  if (found.isNotEmpty) {
    final s = FrameSize(
      total: found['total'],
      lens: found['lens'],
      bridge: found['bridge'],
      temple: found['temple'],
      source: FrameSource.productData,
    )._sane();
    if (s != null) return s;
  }
  return sizeText == null ? null : frameSizeInMarking(sizeText!, FrameSource.productData);
}

/// The frame size in a page's measurements table, read from its text:
/// "Lens width: 52 mm", "Bridge 18mm", "Frame width 140 mm".
FrameSize? frameSizeInTable(String text) {
  final found = <String, double>{};
  final row = RegExp(
    r'(frame width|total width|overall width|lens width|lens size|eye size|bridge width|bridge size|bridge|'
    r'temple length|arm length|temple)\s*[:\-–]?\s*(\d{2,3}(?:[.,]\d)?)\s*mm',
    caseSensitive: false,
  );
  for (final m in row.allMatches(text)) {
    final what = _measure(m.group(1)!);
    if (what != null) found.putIfAbsent(what, () => double.parse(m.group(2)!.replaceAll(',', '.')));
  }
  if (found.isEmpty) return null;
  return FrameSize(
    total: found['total'],
    lens: found['lens'],
    bridge: found['bridge'],
    temple: found['temple'],
    source: FrameSource.page,
  )._sane();
}

/// The frame size from a saved item's own words ([title], [description]),
/// with no page needed.
FrameSize? frameSizeInItem(String title, String description) =>
    frameSizeInMarking(title, FrameSource.title) ??
    frameSizeInMarking(description, FrameSource.page) ??
    frameSizeInTable(description);

/// The frame size on a product page, most trusted first.
FrameSize? frameSizeOnPage(Evidence e) =>
    frameSizeInLd(e.ld) ??
    frameSizeInMarking(e.h1.isNotEmpty ? e.h1 : e.docTitle, FrameSource.title) ??
    frameSizeInTable(e.text) ??
    frameSizeInMarking(e.text, FrameSource.page);

/// A size typed by the user: a total width, or a marking ("52-18-140"), or
/// both. Null when neither gives a width.
FrameSize? typedFrameSize({String total = '', String marking = ''}) {
  final t = double.tryParse(total.trim().replaceAll(',', '.').replaceAll(RegExp(r'\s*mm$'), ''));
  final m = marking.trim().isEmpty
      ? null
      : RegExp(r'^\s*([3-7]\d(?:\.\d)?)\s*\D+\s*([1-2]\d(?:\.\d)?)(?:\s*\D+\s*(1[1-6]\d))?\s*$')
            .firstMatch(marking);
  return FrameSize(
    total: t,
    lens: m == null ? null : double.parse(m.group(1)!),
    bridge: m == null ? null : double.parse(m.group(2)!),
    temple: m?.group(3) == null ? null : double.parse(m!.group(3)!),
    source: FrameSource.typed,
  )._sane();
}

/// Words that mark a saved thing as glasses (any language Chanda reads
/// titles in is fine to add to).
final _glassesWords = RegExp(
  r'\b(glasses|eyeglasses|spectacles|specs|sunglasses|eyewear|optical frames?|reading glasses|lunettes|brille|gafas)\b',
  caseSensitive: false,
);

/// Whether a saved thing is a pair of glasses: by its title, tags or list
/// name, or a frame size marking in its title.
bool isGlasses({required String title, String tags = '', String list = ''}) =>
    _glassesWords.hasMatch('$title $tags $list') || frameSizeInMarking(title, FrameSource.title) != null;
