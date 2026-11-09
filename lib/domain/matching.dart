import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'reading.dart' show similarity;

/// What Chanda knows about one listing, for telling whether two listings
/// sell the same thing.
class Listing {
  const Listing({
    required this.title,
    this.brand = '',
    this.gtin = '',
    this.mpn = '',
    this.variant = const {},
    this.dhash = '',
  });

  final String title;
  final String brand;
  final String gtin;
  final String mpn;

  /// The chosen options: {"Size": "M", "Colour": "Navy"}.
  final Map<String, String> variant;

  /// The picture's difference hash, 16 hex digits ('' when unknown).
  final String dhash;

  /// From a vault item's variant column (JSON).
  static Map<String, String> variantOf(String json) {
    try {
      final v = jsonDecode(json);
      return v is Map ? {for (final e in v.entries) '${e.key}': '${e.value}'} : const {};
    } on FormatException {
      return const {};
    }
  }
}

/// same: certainly one product (barcode, or brand and model number).
/// likely: probably, by picture or words; the user is asked once.
/// different: not the same, or a different size, colour or capacity.
enum Verdict { same, likely, different }

/// A barcode (EAN-13, UPC-A, EAN-8, GTIN-14) as 14 digits, or '' when
/// [raw] is not one with a correct check digit.
String gtin14(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  if (![8, 12, 13, 14].contains(d.length)) return '';
  final g = d.padLeft(14, '0');
  var sum = 0;
  for (var i = 0; i < 13; i++) {
    sum += int.parse(g[i]) * (i.isEven ? 3 : 1);
  }
  return (10 - sum % 10) % 10 == int.parse(g[13]) ? g : '';
}

/// Model numbers in [text]: words of 4 or more letters and digits mixed
/// ("WH-1000XM5", "B01KW9ZHU6", "A2342"), upper case without dashes.
Set<String> modelsIn(String text) => {
  for (final m in RegExp(r'\b[A-Za-z0-9][A-Za-z0-9-]{2,}[A-Za-z0-9]\b').allMatches(text))
    if (RegExp(r'\d').hasMatch(m[0]!) &&
        RegExp(r'[A-Za-z]').hasMatch(m[0]!) &&
        !_measure.hasMatch(m[0]!) &&
        !RegExp(r'^\d+(pcs|pc|pack|x)$', caseSensitive: false).hasMatch(m[0]!))
      m[0]!.toUpperCase().replaceAll('-', ''),
};

final _measure = RegExp(
  r'^\d+(?:\.\d+)?(mm|cm|m|ml|l|g|kg|gb|tb|mb|w|v|mah|hz|in|inch|oz|lb|ft|k|p)$',
  caseSensitive: false,
);

/// The sizes and amounts a listing names: capacities ("256GB", "500ml",
/// "2L"), lens strengths ("+2.0"), clothing sizes from the chosen options,
/// and pack counts ("2 pack", "3 pcs"). Two listings that both name a kind
/// of size, but different ones, sell different variants.
Map<String, String> sizesOf(Listing l) {
  final out = <String, String>{};
  final t = l.title.toLowerCase();
  for (final m in RegExp(r'(\d+(?:\.\d+)?)\s?(gb|tb|ml|l|kg|g|mah|w|inch|in|")(?![a-z])').allMatches(t)) {
    final unit = switch (m[2]!) {
      'inch' || 'in' || '"' => 'in',
      final u => u,
    };
    out.putIfAbsent(unit, () => _num(m[1]!));
  }
  final pack =
      RegExp(r'(\d+)\s?(?:-?pack|pcs|pieces|pairs?|pc)\b').firstMatch(t) ??
      RegExp(r'\bpack of (\d+)\b').firstMatch(t);
  if (pack != null) out['pack'] = pack[1]!;
  for (final e in l.variant.entries) {
    final k = e.key.toLowerCase();
    if (RegExp(r'size|capacity|strength|power|length|colou?r').hasMatch(k)) {
      out[k.contains('colo') ? 'colour' : k] = e.value.toLowerCase().trim();
    }
  }
  return out;
}

String _num(String s) => s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;

/// Whether [a] and [b] sell the same thing. Different variants never match,
/// even of one product: the price of a size 8 says nothing of a size 12.
Verdict match(Listing a, Listing b) {
  final ga = gtin14(a.gtin), gb = gtin14(b.gtin);
  if (ga.isNotEmpty && gb.isNotEmpty) return ga == gb ? Verdict.same : Verdict.different;

  final sa = sizesOf(a), sb = sizesOf(b);
  for (final k in sa.keys) {
    if (sb.containsKey(k) && sb[k] != sa[k]) return Verdict.different;
  }

  final ma = {...modelsIn(a.title), if (a.mpn.isNotEmpty) a.mpn.toUpperCase().replaceAll('-', '')};
  final mb = {...modelsIn(b.title), if (b.mpn.isNotEmpty) b.mpn.toUpperCase().replaceAll('-', '')};
  final sameBrand = _brandsAgree(a, b);
  if (sameBrand && ma.intersection(mb).any((m) => m.length >= 4)) return Verdict.same;

  if (a.dhash.isNotEmpty && b.dhash.isNotEmpty && hamming(a.dhash, b.dhash) <= 8) return Verdict.likely;
  if (similarity(a.title, b.title) >= 0.6 && sameBrand) return Verdict.likely;
  return Verdict.different;
}

/// Brands agree when both are known and equal, or one names the other in
/// its title, or neither is known.
bool _brandsAgree(Listing a, Listing b) {
  final ba = a.brand.toLowerCase().trim(), bb = b.brand.toLowerCase().trim();
  if (ba.isEmpty && bb.isEmpty) return true;
  if (ba.isNotEmpty && bb.isNotEmpty) return ba == bb;
  final (brand, other) = ba.isNotEmpty ? (ba, b.title) : (bb, a.title);
  return other.toLowerCase().contains(brand);
}

/// Bits that differ between two 64-bit hashes written as hex.
int hamming(String a, String b) {
  final x = BigInt.parse(a, radix: 16) ^ BigInt.parse(b, radix: 16);
  return x.toRadixString(2).replaceAll('0', '').length;
}

/// The difference hash of a picture: shrink to 9 by 8 in grey, then one bit
/// per pixel for whether it is brighter than its right-hand neighbour.
/// Resized, recompressed or lightly retouched copies of a picture keep
/// nearly the same hash. Null when [bytes] is not a picture.
String? dhashOf(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final small = img.grayscale(
    img.copyResize(decoded, width: 9, height: 8, interpolation: img.Interpolation.average),
  );
  var bits = BigInt.zero;
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      bits = bits << 1;
      if (small.getPixel(x, y).luminance > small.getPixel(x + 1, y).luminance) bits |= BigInt.one;
    }
  }
  return bits.toRadixString(16).padLeft(16, '0');
}
