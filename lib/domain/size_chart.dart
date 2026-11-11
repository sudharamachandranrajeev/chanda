import 'dart:convert';

import 'garment_fit.dart';
import 'people.dart';
import 'reading.dart';

// A shop's size chart, read from its product page, set against the
// measurements saved for a person. Chanda says where each measurement falls
// on the chart (within a size's range, between two sizes, below or above
// the chart) and where the chart came from. It never picks a size: cuts
// differ, and a chart is the shop's own guide.
//
// The chart comes from, most trusted first:
//   1. schema.org JSON-LD: SizeSpecification with its measurements;
//   2. tables on the page that name sizes and body measurements, either a
//      row per size or a column per size.

/// The body measurements a chart can give.
enum Measure { chest, waist, hip, insideLeg }

/// The plain name of [m], for "Chest 96 cm".
String measureName(Measure m) => switch (m) {
  Measure.chest => 'Chest',
  Measure.waist => 'Waist',
  Measure.hip => 'Hip',
  Measure.insideLeg => 'Inside leg',
};

/// [m] as saved for [p], in centimetres.
double? personMeasure(Person p, Measure m) => switch (m) {
  Measure.chest => p.chest,
  Measure.waist => p.waist,
  Measure.hip => p.hip,
  Measure.insideLeg => p.insideLeg,
};

/// The measurements that matter for a garment of kind [k], most telling
/// first.
List<Measure> measuresFor(GarmentKind k) => switch (k) {
  GarmentKind.top => const [Measure.chest, Measure.waist],
  GarmentKind.dress => const [Measure.chest, Measure.waist, Measure.hip],
  GarmentKind.skirt => const [Measure.waist, Measure.hip],
  GarmentKind.trousers => const [Measure.waist, Measure.hip, Measure.insideLeg],
};

/// One size's row: its label and, per measurement, the range it is for
/// (centimetres; low equals high for a single number).
class SizeRow {
  const SizeRow(this.size, this.ranges);
  final String size;
  final Map<Measure, (double, double)> ranges;

  Map<String, Object?> toJson() => {
    'size': size,
    for (final e in ranges.entries) e.key.name: [e.value.$1, e.value.$2],
  };

  static SizeRow fromJson(Map j) => SizeRow('${j['size']}', {
    for (final m in Measure.values)
      if (j[m.name] is List)
        m: (((j[m.name] as List)[0] as num).toDouble(), ((j[m.name] as List)[1] as num).toDouble()),
  });
}

/// Where a chart came from.
enum ChartSource {
  /// The shop's structured product data.
  data,

  /// A table on the product page.
  table,
}

/// A size chart and where it was read.
class SizeChart {
  const SizeChart(this.rows, this.source, this.host);
  final List<SizeRow> rows;
  final ChartSource source;

  /// The shop's web address, for the source line.
  final String host;

  String toJson() => jsonEncode({
    'source': source.name,
    'host': host,
    'rows': [for (final r in rows) r.toJson()],
  });

  static SizeChart? fromJson(String? s) {
    if (s == null) return null;
    try {
      final j = jsonDecode(s) as Map;
      return SizeChart(
        [for (final r in j['rows'] as List) SizeRow.fromJson(r as Map)],
        ChartSource.values.byName('${j['source']}'),
        '${j['host']}',
      );
    } on Object {
      return null;
    }
  }
}

/// The local setting that keeps the chart read for item [itemId] (or
/// "none" when the page had none), so the page is read once.
String sizeChartSetting(String itemId) => 'chanda.sizechart.$itemId';

/// The size chart on a product page's evidence, or null when there is none
/// Chanda can read.
SizeChart? findSizeChart(Evidence e) {
  final host = Uri.tryParse(e.url)?.host.replaceFirst(RegExp(r'^www\.'), '') ?? '';
  final fromData = chartFromLd(e.ld);
  if (fromData.isNotEmpty) return SizeChart(fromData, ChartSource.data, host);
  for (final t in e.tables) {
    final rows = chartFromTable(t);
    if (rows.length >= 2) return SizeChart(rows, ChartSource.table, host);
  }
  return null;
}

// ---- JSON-LD ----

/// The sizes with measurements in JSON-LD [blocks]: every SizeSpecification
/// (a product's size, its variants' sizes) whose hasMeasurement names a
/// body measurement.
List<SizeRow> chartFromLd(List<String> blocks) {
  final out = <String, SizeRow>{};
  void walk(Object? n) {
    if (n is List) {
      for (final x in n) {
        walk(x);
      }
    } else if (n is Map) {
      final type = n['@type'];
      if ((type is String
              ? [type]
              : type is List
              ? type
              : const [])
          .contains('SizeSpecification')) {
        final row = _ldSize(n);
        if (row != null) out.putIfAbsent(row.size, () => row);
      }
      for (final v in n.values) {
        walk(v);
      }
    }
  }

  for (final b in blocks) {
    try {
      walk(jsonDecode(b));
    } on FormatException {
      continue;
    }
  }
  return out.values.toList();
}

SizeRow? _ldSize(Map n) {
  final name = '${n['name'] ?? n['size'] ?? ''}'.trim();
  if (name.isEmpty) return null;
  final ranges = <Measure, (double, double)>{};
  final ms = n['hasMeasurement'];
  for (final q in ms is List ? ms : [ms]) {
    if (q is! Map) continue;
    final what = _measure('${q['valueReference'] ?? ''} ${q['propertyID'] ?? ''} ${q['name'] ?? ''}');
    if (what == null) continue;
    double? num_(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
    var lo = num_(q['minValue']) ?? num_(q['value']);
    var hi = num_(q['maxValue']) ?? num_(q['value']) ?? lo;
    lo ??= hi;
    if (lo == null || hi == null) continue;
    final unit = '${q['unitCode'] ?? q['unitText'] ?? ''}'.toUpperCase();
    final k = unit == 'INH' || unit.startsWith('IN') ? 2.54 : (unit == 'MMT' || unit == 'MM' ? 0.1 : 1.0);
    final r = (lo * k, hi * k);
    if (_plausible(what, r)) ranges[what] = r;
  }
  return ranges.isEmpty ? null : SizeRow(name, ranges);
}

/// The measurement a label names, or null.
Measure? _measure(String label) {
  final l = label.toLowerCase();
  if (RegExp(r'chest|bust').hasMatch(l)) return Measure.chest;
  if (RegExp(r'waist').hasMatch(l)) return Measure.waist;
  if (RegExp(r'hip').hasMatch(l)) return Measure.hip;
  if (RegExp(r'inside ?leg|inseam|inner ?leg').hasMatch(l)) return Measure.insideLeg;
  return null;
}

/// Body measurements in centimetres fall in these ranges; anything else is
/// a garment measurement or a misread.
bool _plausible(Measure m, (double, double) r) {
  final (lo, hi) = switch (m) {
    Measure.insideLeg => (40.0, 110.0),
    _ => (40.0, 200.0),
  };
  return r.$1 >= lo && r.$2 <= hi && r.$1 <= r.$2;
}

// ---- tables ----

final _number = RegExp(r'\d+(?:[.,]\d+)?');

/// A cell's range: "86-90", "86 – 90", "86/90", "86 to 90", "86". Null when
/// the cell holds no number.
(double, double)? _cellRange(String cell) {
  final ns = [for (final m in _number.allMatches(cell)) double.parse(m[0]!.replaceAll(',', '.'))];
  if (ns.isEmpty) return null;
  if (ns.length == 1) return (ns[0], ns[0]);
  return ns[0] <= ns[1] ? (ns[0], ns[1]) : null;
}

/// Inches when [label] says so, centimetres when it says so, else null.
bool? _inchLabel(String label) {
  final l = label.toLowerCase();
  if (RegExp(r'\bcm\b|centimet').hasMatch(l)) return false;
  if (RegExp(r'\bin\b|inch|"|”|\(in\)').hasMatch(l)) return true;
  return null;
}

/// The size rows in [table] (rows of cell texts): a row per size with the
/// measurements as column headings, or a column per size with the
/// measurements down the first column. Inches are turned into centimetres;
/// a chart that does not say is taken as inches when its chest or hip
/// figures are too small for centimetres.
List<SizeRow> chartFromTable(List<List<String>> table) {
  if (table.length < 2) return const [];
  final tableInches = _inchLabel(table.expand((r) => r).join(' '));
  final head = table.first;
  final byRow = head.skip(1).any((c) => _measure(c) != null);
  // Collect (size, measurement, range, inches?) whichever way round.
  final cells = <(String, Measure, (double, double), bool?)>[];
  if (byRow) {
    for (final row in table.skip(1)) {
      if (row.isEmpty) continue;
      for (var c = 1; c < row.length && c < head.length; c++) {
        final m = _measure(head[c]);
        final r = _cellRange(row[c]);
        if (m != null && r != null) cells.add((row[0], m, r, _inchLabel(head[c])));
      }
    }
  } else {
    final sizes = table.first;
    for (final row in table.skip(1)) {
      if (row.isEmpty) continue;
      final m = _measure(row[0]);
      if (m == null) continue;
      for (var c = 1; c < row.length && c < sizes.length; c++) {
        final r = _cellRange(row[c]);
        if (r != null) cells.add((sizes[c], m, r, _inchLabel(row[0])));
      }
    }
  }
  if (cells.isEmpty) return const [];
  // A table that gives both units has cm and inch columns for the same
  // measurement; keep the centimetre ones.
  final hasCm = {
    for (final c in cells)
      if (c.$4 == false) c.$2,
  };
  final guessInches = () {
    final big = [
      for (final c in cells)
        if (c.$4 == null && (c.$2 == Measure.chest || c.$2 == Measure.hip)) c.$3.$2,
    ];
    if (big.isEmpty) return tableInches ?? false;
    big.sort();
    return tableInches ?? big[big.length ~/ 2] < 60;
  }();
  final out = <String, Map<Measure, (double, double)>>{};
  final order = <String>[];
  for (final (size, m, r, inchLabel) in cells) {
    final inches = inchLabel ?? guessInches;
    if (inches && hasCm.contains(m)) continue;
    final k = inches ? 2.54 : 1.0;
    final cm = (r.$1 * k, r.$2 * k);
    final label = size.trim();
    if (label.isEmpty || !_plausible(m, cm)) continue;
    if (!out.containsKey(label)) order.add(label);
    (out[label] ??= {}).putIfAbsent(m, () => cm);
  }
  return [for (final s in order) SizeRow(s, out[s]!)];
}

// ---- the note ----

/// Where one measurement falls on a chart.
enum SizeFit {
  /// Within one size's range (or more than one, where ranges overlap).
  within,

  /// Between two sizes.
  between,

  /// Smaller than the smallest size.
  below,

  /// Larger than the largest size.
  above,
}

/// One measurement against the chart.
class SizeLine {
  const SizeLine(this.measure, this.cm, this.fit, this.text);
  final Measure measure;
  final double cm;
  final SizeFit fit;
  final String text;
}

/// What Chanda says about a chart and a person.
class SizeNote {
  const SizeNote(this.lines, this.source, {this.missing = const []});

  /// No chart on the page.
  const SizeNote.noChart() : lines = const [], source = '', missing = const [];

  final List<SizeLine> lines;

  /// "From the size table on shop.example."
  final String source;

  /// Measurements the chart gives that are not saved for the person.
  final List<Measure> missing;

  bool get noChart => source.isEmpty;

  /// The short heading: "Within the chart's range", "Between sizes",
  /// "Outside the chart", "No size chart found" or "Add your measurements".
  String get summary {
    if (noChart) return 'No size chart found';
    if (lines.isEmpty) return 'Add your measurements';
    if (lines.every((l) => l.fit == SizeFit.within)) return "Within the chart's range";
    if (lines.any((l) => l.fit == SizeFit.below || l.fit == SizeFit.above)) return 'Outside the chart';
    return 'Between sizes';
  }
}

/// Sets [chart] against [person]'s measurements for a garment of kind
/// [kind]. Measurements show in inches when [inches].
SizeNote sizeNote(SizeChart? chart, Person person, GarmentKind kind, {bool inches = false}) {
  if (chart == null || chart.rows.isEmpty) return const SizeNote.noChart();
  final source = switch (chart.source) {
    ChartSource.data => "From the shop's product data on ${chart.host}.",
    ChartSource.table => 'From the size table on ${chart.host}.',
  };
  final lines = <SizeLine>[];
  final missing = <Measure>[];
  for (final m in measuresFor(kind)) {
    final rows = [
      for (final r in chart.rows)
        if (r.ranges.containsKey(m)) (r.size, r.ranges[m]!),
    ];
    if (rows.isEmpty) continue;
    final v = personMeasure(person, m);
    if (v == null) {
      missing.add(m);
      continue;
    }
    lines.add(placeOnChart(m, v, rows, inches: inches));
  }
  return SizeNote(lines, source, missing: missing);
}

/// Where [cm] of measurement [m] falls among [rows] (size, range).
SizeLine placeOnChart(Measure m, double cm, List<(String, (double, double))> rows, {bool inches = false}) {
  String len(double v) => showLength(v, inches: inches);
  String range((double, double) r) => r.$1 == r.$2 ? len(r.$1) : '${len(r.$1).split(' ').first}–${len(r.$2)}';
  final who = '${measureName(m)} ${len(cm)}';
  // Half a centimetre either side: charts round to whole numbers.
  const slack = 0.5;
  final inside = [
    for (final (s, r) in rows)
      if (cm >= r.$1 - slack && cm <= r.$2 + slack) (s, r),
  ];
  if (inside.isNotEmpty) {
    final sizes = inside.map((x) => '${x.$1} (${range(x.$2)})').join(' and ');
    return SizeLine(m, cm, SizeFit.within, "$who: within the chart's range for $sizes.");
  }
  final sorted = [...rows]..sort((a, b) => a.$2.$1.compareTo(b.$2.$1));
  final first = sorted.first, last = sorted.last;
  if (cm < first.$2.$1) {
    return SizeLine(
      m,
      cm,
      SizeFit.below,
      "$who: below the chart's smallest size, ${first.$1} (from ${len(first.$2.$1)}).",
    );
  }
  if (cm > last.$2.$2) {
    return SizeLine(
      m,
      cm,
      SizeFit.above,
      "$who: above the chart's largest size, ${last.$1} (up to ${len(last.$2.$2)}).",
    );
  }
  var below = sorted.first, above = sorted.last;
  for (final x in sorted) {
    if (x.$2.$2 < cm) below = x;
  }
  for (final x in sorted.reversed) {
    if (x.$2.$1 > cm) above = x;
  }
  return SizeLine(
    m,
    cm,
    SizeFit.between,
    "$who: between the chart's ${below.$1} (up to ${len(below.$2.$2)}) and ${above.$1} "
    '(from ${len(above.$2.$1)}).',
  );
}
