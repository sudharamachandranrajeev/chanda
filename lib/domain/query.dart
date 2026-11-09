import 'package:brahma_core/brahma_core.dart' show currencyInfo;

import 'money.dart';
import 'shops.dart';

/// One thing a search asks for besides its words, shown as a chip the user
/// can tap off: a budget, a size, a colour, a material or a shop.
class Facet {
  const Facet(this.kind, this.value, this.label);

  /// budget | size | colour | material | shop
  final String kind;

  /// budget: "min-max" in minor units ('' for an open end); shop: its id;
  /// otherwise the lower-case word.
  final String value;
  final String label;

  @override
  bool operator ==(Object other) => other is Facet && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);
}

/// A search, read: the words to look for and the facets around them.
class Query {
  const Query(this.raw, this.words, this.facets, {this.currency = 'GBP'});

  final String raw;

  /// The words left once the facets are taken out.
  final String words;
  final List<Facet> facets;

  /// The currency a budget is in.
  final String currency;

  Query without(Facet f) => Query(raw, words, [...facets.where((x) => x != f)], currency: currency);

  Iterable<String> of(String kind) => facets.where((f) => f.kind == kind).map((f) => f.value);

  int? get minPrice => _budget(0);
  int? get maxPrice => _budget(1);

  int? _budget(int end) {
    final b = of('budget').firstOrNull;
    if (b == null) return null;
    final v = b.split('-')[end];
    return v.isEmpty ? null : int.parse(v);
  }

  /// Too little to search well: one word or none and nothing else. The
  /// search page then asks about a budget or a size.
  bool get vague => words.split(' ').where((w) => w.length > 1).length <= 1 && facets.isEmpty;

  bool get isEmpty => words.trim().isEmpty && facets.isEmpty;
}

const colours = {
  'black', 'white', 'grey', 'gray', 'silver', 'gold', 'brass', 'red', 'burgundy', 'pink', 'rose',
  'orange', 'yellow', 'mustard', 'beige', 'cream', 'ivory', 'khaki', 'brown', 'camel', 'tan', 'green',
  'olive', 'sage', 'mint', 'teal', 'turquoise', 'blue', 'navy', 'purple', 'lilac', 'lavender',
  'multicolour', 'clear', 'transparent',
};

const materials = {
  'cotton', 'linen', 'wool', 'cashmere', 'silk', 'satin', 'denim', 'leather', 'suede', 'polyester',
  'nylon', 'velvet', 'fleece', 'wood', 'wooden', 'bamboo', 'metal', 'steel', 'aluminium', 'glass',
  'ceramic', 'porcelain', 'plastic', 'acrylic', 'marble', 'rattan',
};

final _amount = r'(?:([£$€])\s?)?(\d+(?:[.,]\d{1,2})?)';
final _budgets = <(RegExp, String)>[
  (RegExp('(?:between\\s+)?$_amount\\s*(?:-|–|to|and)\\s*$_amount', caseSensitive: false), 'range'),
  (RegExp('(?:under|below|less than|up to|max(?:imum)?|cheaper than|<)\\s*$_amount', caseSensitive: false), 'max'),
  (RegExp('$_amount\\s*(?:or less|or under|max)', caseSensitive: false), 'max'),
  (RegExp('(?:over|above|more than|at least|min(?:imum)?|>)\\s*$_amount', caseSensitive: false), 'min'),
];

final _sizes = <RegExp>[
  RegExp(r'\b(?:size\s+)?(uk|eu|us)\s?(\d{1,2}(?:\.5)?)\b', caseSensitive: false),
  RegExp(r'\bw?(\d{2})\s?w\s+l?(\d{2})\s?l?\b', caseSensitive: false),
  RegExp(r'\bsize\s+(xxs|xs|s|m|l|xl|xxl|xxxl|[2-5]xl|\d{1,2})\b', caseSensitive: false),
  RegExp(r'\b(xxs|xs|xl|xxl|xxxl|[2-5]xl)\b', caseSensitive: false),
];

/// Reads [text] into words and facets: "black linen shirt size M under £30
/// on Amazon" is "shirt" with colour black, material linen, size M, at most
/// £30, at Amazon UK. Amounts are in [currency] (the user's home currency).
Query readQuery(String text, {String currency = 'GBP'}) {
  var rest = ' ${text.replaceAll(RegExp(r'\s+'), ' ').trim()} ';
  final facets = <Facet>[];
  final scale = currencyInfo(currency).scale;
  int? money(String? n) => n == null ? null : parseAmount(n.replaceAll(',', '.'), scale: scale);

  for (final (re, kind) in _budgets) {
    final m = re.firstMatch(rest);
    if (m == null) continue;
    final a = money(m[2]), b = kind == 'range' ? money(m[4]) : null;
    if (a == null) continue;
    final (lo, hi) = switch (kind) {
      'range' => (a, b),
      'max' => (null, a),
      _ => (a, null),
    };
    final label = switch ((lo, hi)) {
      (null, final int h) => 'Under ${showPrice(h, currency)}',
      (final int l, null) => 'Over ${showPrice(l, currency)}',
      (final int l, final int h) => '${showPrice(l, currency)}–${showPrice(h, currency)}',
      _ => '',
    };
    facets.add(Facet('budget', '${lo ?? ''}-${hi ?? ''}', label));
    rest = rest.replaceRange(m.start, m.end, ' ');
    break;
  }

  for (final re in _sizes) {
    for (final m in re.allMatches(rest).toList().reversed) {
      final v = switch (m.groupCount) {
        2 when re == _sizes[0] => '${m[1]!.toUpperCase()} ${m[2]}',
        2 => 'W${m[1]} L${m[2]}',
        _ => m[1]!.toUpperCase(),
      };
      facets.add(Facet('size', v.toLowerCase(), 'Size $v'));
      rest = rest.replaceRange(m.start, m.end, ' ');
    }
  }

  // Shops: "on Amazon", "from temu", or the name alone.
  for (final s in shops) {
    final name = s.name.split(' ').first.toLowerCase();
    final m = RegExp('\\b(?:on |from |at )?${RegExp.escape(name)}(?: uk)?\\b', caseSensitive: false).firstMatch(rest);
    if (m == null) continue;
    facets.add(Facet('shop', s.id, s.name));
    rest = rest.replaceRange(m.start, m.end, ' ');
  }

  final words = <String>[];
  for (final w in rest.trim().split(' ')) {
    final l = w.toLowerCase();
    if (colours.contains(l)) {
      facets.add(Facet('colour', l == 'gray' ? 'grey' : l, _cap(l)));
    } else if (materials.contains(l)) {
      facets.add(Facet('material', l, _cap(l)));
    } else if (w.isNotEmpty) {
      words.add(w);
    }
  }
  return Query(text.trim(), words.join(' '), facets, currency: currency);
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Whether [title] (with [extra] such as the chosen options) fits [q]'s
/// colour, material and size facets. Budget and shop are checked on the
/// offer itself.
bool fitsFacets(Query q, String title, {String extra = ''}) {
  final t = ' ${'$title $extra'.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')} ';
  for (final kind in ['colour', 'material']) {
    final want = q.of(kind).toList();
    if (want.isNotEmpty && !want.any((w) => t.contains(' $w ') || (w == 'grey' && t.contains(' gray ')))) {
      return false;
    }
  }
  return true;
}
