import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:brahma_core/brahma_core.dart';
import 'package:chanda/domain/money.dart';
import 'package:flutter_test/flutter_test.dart';

/// Price texts gathered from many shops' pages by the price-parser project
/// (BSD-3-Clause, (c) Scrapinghub; test/fixtures/price_parser_cases.json
/// says which revision). Each is read with the currency the page named, or
/// with the shop's own (pounds here) where the text names none.
void main() {
  final doc = jsonDecode(File('test/fixtures/price_parser_cases.json').readAsStringSync()) as Map;
  final cases = doc['cases'] as List;

  test('the borrowed cases are there and credited', () {
    expect(cases.length, greaterThan(800));
    expect(doc['about'], contains('BSD-3-Clause'));
  });

  test('every price-parser case reads to its amount', () {
    final wrong = <String>[];
    for (final c in cases.cast<List>()) {
      final [text as String, code as String?, amount as String] = c;
      final currency = code ?? 'GBP';
      final want = (double.parse(amount) * pow(10, currencyInfo(currency).scale)).round();
      final got = parsePrice(text, hint: currency);
      if (got?.minor != want || got?.currency != currency) {
        wrong.add('"$text": want $want $currency, got $got');
      }
    }
    expect(wrong, isEmpty);
  });

  test('cases the port added', () {
    expect(parsePrice('34.992001', hint: 'GBP')?.minor, 3499, reason: 'four or more decimals are decimals');
    expect(parsePrice('1.234', hint: 'EUR')?.minor, 123400, reason: 'three after a point stay thousands');
    expect(parsePrice(r'$.75', hint: 'USD')?.minor, 75);
    expect(parsePrice('35€ 99')?.minor, 3599, reason: 'the euro sign as the decimal point');
    expect(parsePrice('5€ 16,50 €')?.minor, 500);
  });
}
