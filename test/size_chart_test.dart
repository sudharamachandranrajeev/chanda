import 'dart:convert';

import 'package:chanda/domain/garment_fit.dart';
import 'package:chanda/domain/html_evidence.dart';
import 'package:chanda/domain/people.dart';
import 'package:chanda/domain/reading.dart';
import 'package:chanda/domain/size_chart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Person person({double? chest, double? waist, double? hip}) =>
      Person(id: 'p', consent: DateTime(2026), chest: chest, waist: waist, hip: hip);

  test('reads a size chart from JSON-LD size specifications, in centimetres', () {
    final ld = jsonEncode({
      '@context': 'https://schema.org',
      '@type': 'ProductGroup',
      'name': 'Linen shirt',
      'hasVariant': [
        for (final (s, lo) in [('S', 34), ('M', 38), ('L', 42)])
          {
            '@type': 'Product',
            'size': {
              '@type': 'SizeSpecification',
              'name': s,
              'hasMeasurement': [
                {
                  '@type': 'QuantitativeValue',
                  'valueReference': 'https://schema.org/WearableMeasurementChestOrBust',
                  'minValue': lo,
                  'maxValue': lo + 2,
                  'unitCode': 'INH',
                },
                // A garment measurement, not the body's: left out.
                {'@type': 'QuantitativeValue', 'name': 'Sleeve', 'value': 60, 'unitCode': 'CMT'},
              ],
            },
          },
      ],
    });
    final chart = findSizeChart(Evidence(url: 'https://www.shop.example/p/1', ld: [ld]))!;
    expect(chart.source, ChartSource.data);
    expect(chart.host, 'shop.example');
    expect(chart.rows.map((r) => r.size), ['S', 'M', 'L']);
    expect(chart.rows[1].ranges[Measure.chest]!.$1, closeTo(38 * 2.54, 1e-9));
    expect(chart.rows[1].ranges.keys, [Measure.chest]);
    // Kept and read back.
    final back = SizeChart.fromJson(chart.toJson())!;
    expect(back.rows[2].ranges[Measure.chest], chart.rows[2].ranges[Measure.chest]);
  });

  test('reads tables a row per size and a column per size, in either unit', () {
    final byRow = chartFromTable([
      ['Size', 'Chest (cm)', 'Waist (cm)', 'Hip (cm)'],
      ['XS', '78-82', '62-66', '86-90'],
      ['S', '82 – 86', '66 – 70', '90 – 94'],
      ['M', '86/90', '70/74', '94/98'],
    ]);
    expect(byRow.map((r) => r.size), ['XS', 'S', 'M']);
    expect(byRow[1].ranges[Measure.waist], (66.0, 70.0));
    expect(byRow[2].ranges[Measure.hip], (94.0, 98.0));

    // Sizes across, measurements down; no unit given but figures too small
    // for centimetres, so inches.
    final byColumn = chartFromTable([
      ['', '8', '10', '12'],
      ['Bust', '32', '34', '36'],
      ['Waist', '25', '27', '29'],
      ['Length', '38', '38.5', '39'],
    ]);
    expect(byColumn.map((r) => r.size), ['8', '10', '12']);
    expect(byColumn[0].ranges[Measure.chest]!.$1, closeTo(32 * 2.54, 1e-9));
    expect(byColumn[0].ranges.keys, [Measure.chest, Measure.waist]);

    // Both units: the centimetre columns win.
    final both = chartFromTable([
      ['Size', 'Chest (in)', 'Chest (cm)'],
      ['M', '37-39', '94-99'],
    ]);
    expect(both.single.ranges[Measure.chest], (94.0, 99.0));

    // A table of garment measurements only is no chart.
    expect(
      chartFromTable([
        ['Size', 'Length', 'Sleeve'],
        ['M', '70', '62'],
      ]),
      isEmpty,
    );
  });

  test('plain HTML keeps size-chart tables, and the chart is found from them', () {
    final e = htmlEvidence('''<html><body><h1>Tee</h1>
<table><tr><td>Delivery</td><td>2 days</td></tr></table>
<div hidden><table><tr><th>Size</th><th>Chest cm</th></tr><tr><td>S</td><td>86-90</td></tr>
<tr><td>M</td><td>94-98</td></tr></table></div></body></html>''', 'https://shop.example/tee');
    expect(e.tables, hasLength(1));
    final chart = findSizeChart(e)!;
    expect(chart.source, ChartSource.table);
    expect(chart.rows.map((r) => r.size), ['S', 'M']);
    expect(findSizeChart(const Evidence(url: 'https://shop.example/x')), isNull);
  });

  test('says where each measurement falls, never which size to buy', () {
    final chart = SizeChart(
      [
        const SizeRow('S', {Measure.chest: (86, 90), Measure.waist: (70, 74)}),
        const SizeRow('M', {Measure.chest: (94, 98), Measure.waist: (78, 82)}),
        const SizeRow('L', {Measure.chest: (102, 106), Measure.waist: (86, 90)}),
      ],
      ChartSource.table,
      'shop.example',
    );
    final within = sizeNote(chart, person(chest: 96, waist: 80), GarmentKind.top);
    expect(within.summary, "Within the chart's range");
    expect(within.lines.first.text, "Chest 96 cm: within the chart's range for M (94–98 cm).");
    expect(within.source, 'From the size table on shop.example.');

    final between = sizeNote(chart, person(chest: 92, waist: 80), GarmentKind.top);
    expect(between.summary, 'Between sizes');
    expect(between.lines.first.fit, SizeFit.between);
    expect(between.lines.first.text, "Chest 92 cm: between the chart's S (up to 90 cm) and M (from 94 cm).");

    final outside = sizeNote(chart, person(chest: 120), GarmentKind.top);
    expect(outside.summary, 'Outside the chart');
    expect(outside.lines.single.text, "Chest 120 cm: above the chart's largest size, L (up to 106 cm).");
    expect(outside.missing, [Measure.waist]);
    expect(sizeNote(chart, person(chest: 80), GarmentKind.top).lines.single.fit, SizeFit.below);

    // A skirt looks at the waist (and hip, which this chart does not give).
    final skirt = sizeNote(chart, person(chest: 96, waist: 72, hip: 99), GarmentKind.skirt);
    expect(skirt.lines.map((l) => l.measure), [Measure.waist]);
    expect(skirt.missing, isEmpty);

    // In inches.
    expect(
      sizeNote(chart, person(chest: 96), GarmentKind.top, inches: true).lines.first.text,
      "Chest 37.8 in: within the chart's range for M (37.0–38.6 in).",
    );

    final none = sizeNote(null, person(chest: 96), GarmentKind.top);
    expect((none.noChart, none.summary), (true, 'No size chart found'));
    for (final n in [within, between, outside, none]) {
      for (final l in n.lines) {
        expect(l.text, isNot(contains('your size')));
      }
    }
  });
}
