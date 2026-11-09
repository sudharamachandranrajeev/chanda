import 'dart:convert';
import 'dart:math';

import 'package:brahma_core/brahma_core.dart';
import 'package:http/http.dart' as http;

/// A price as read from a page: minor units of [currency].
typedef ReadPrice = ({int minor, String currency});

/// Symbols and words that name a currency in price text, longest first so
/// "US $" wins over "$". A bare "$", "¥" or "kr" is ambiguous; the page's own
/// currency (or the shop's) decides it.
const _marks = <(String, String)>[
  ('US \$', 'USD'),
  ('US\$', 'USD'),
  ('C\$', 'CAD'),
  ('CA\$', 'CAD'),
  ('A\$', 'AUD'),
  ('AU\$', 'AUD'),
  ('NZ\$', 'NZD'),
  ('HK\$', 'HKD'),
  ('S\$', 'SGD'),
  ('R\$', 'BRL'),
  ('MX\$', 'MXN'),
  ('£', 'GBP'),
  ('€', 'EUR'),
  ('₹', 'INR'),
  ('₩', 'KRW'),
  ('₺', 'TRY'),
  ('₽', 'RUB'),
  ('₫', 'VND'),
  ('₱', 'PHP'),
  ('฿', 'THB'),
  ('₪', 'ILS'),
  ('zł', 'PLN'),
  ('Kč', 'CZK'),
  ('Ft', 'HUF'),
  ('lei', 'RON'),
  ('руб', 'RUB'),
  ('元', 'CNY'),
  ('円', 'JPY'),
  ('Rs.', 'INR'),
  ('Rs', 'INR'),
];

const _ambiguous = <String, List<String>>{
  r'$': ['USD', 'CAD', 'AUD', 'NZD', 'HKD', 'SGD', 'MXN'],
  '¥': ['JPY', 'CNY'],
  '￥': ['JPY', 'CNY'],
  'kr': ['SEK', 'NOK', 'DKK', 'ISK'],
};

final _code = RegExp(r'\b([A-Z]{3})\b');
final _number = RegExp(r"\d{1,3}(?:[.,\s  ']\d{3})+(?:[.,]\d{1,2})?(?!\d)|\d+(?:[.,]\d{1,2})?(?!\d)");

/// The currency [text] names, if any. [hint] (the page's or shop's currency)
/// settles ambiguous marks such as "$" and "¥".
String? currencyIn(String text, {String? hint}) {
  for (final (mark, code) in _marks) {
    if (text.contains(mark)) return code;
  }
  for (final m in _code.allMatches(text)) {
    final c = m[1]!;
    if (currencies.containsKey(c)) return c;
  }
  for (final MapEntry(key: mark, value: options) in _ambiguous.entries) {
    if (text.contains(mark)) return options.contains(hint) ? hint : options.first;
  }
  return null;
}

/// Reads a price written any common way: "£1,234.56", "1.234,56 €",
/// "US \$12.99", "₹1,299", "12,99 zł", "¥1,280", "CHF 12.50". Returns null
/// when [text] holds no number. Without a currency mark it takes [hint].
ReadPrice? parsePrice(String text, {String? hint}) {
  // Prices drawn in parts ("£8 . 42", "12 ,99 €") read as one number.
  final t = text
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAllMapped(RegExp(r'(\d) ?([.,]) ?(\d)'), (m) => '${m[1]}${m[2]}${m[3]}')
      .trim();
  final code = currencyIn(t, hint: hint) ?? hint;
  if (code == null) return null;
  final m = _number.firstMatch(t);
  if (m == null) return null;
  final value = parseAmount(m[0]!, scale: currencyInfo(code).scale);
  if (value == null) return null;
  return (minor: value, currency: code);
}

/// Turns "1.234,56", "1,234.56", "1 234,5", "12.99" or "1,280" into minor
/// units with [scale] decimals. The last separator is the decimal point when
/// one or two digits follow it; three digits after a lone separator mean
/// thousands ("1,280" is one thousand two hundred and eighty).
int? parseAmount(String raw, {int scale = 2}) {
  var s = raw.replaceAll(RegExp(r"[\s  ']"), '');
  final lastDot = s.lastIndexOf('.');
  final lastComma = s.lastIndexOf(',');
  final last = max(lastDot, lastComma);
  String whole, fraction = '';
  if (last == -1) {
    whole = s;
  } else {
    final after = s.length - last - 1;
    final sep = s[last];
    final sepCount = sep.allMatches(s).length;
    final both = lastDot != -1 && lastComma != -1;
    if (both || (after <= 2 && sepCount == 1)) {
      whole = s.substring(0, last).replaceAll(RegExp(r'[.,]'), '');
      fraction = s.substring(last + 1);
    } else {
      whole = s.replaceAll(RegExp(r'[.,]'), '');
    }
  }
  if (whole.isEmpty) whole = '0';
  if (!RegExp(r'^\d+$').hasMatch(whole) || !RegExp(r'^\d*$').hasMatch(fraction)) return null;
  // A fraction finer than the currency's minor unit is rounded, not cut
  // ("¥1,280.5" is ¥1,281).
  final f = fraction.padRight(scale + 1, '0');
  final minor = int.parse(whole) * pow(10, scale).toInt() + (scale == 0 ? 0 : int.parse(f.substring(0, scale)));
  return f.codeUnitAt(scale) >= 0x35 ? minor + 1 : minor;
}

/// "£12.99", "¥1,280", "€9.50" for [minor] units of [code].
String showPrice(int minor, String code) {
  final c = currencyInfo(code);
  return formatMinor(minor, c.scale, symbol: c.symbol);
}

/// Daily reference rates (European Central Bank, through the free Frankfurter
/// API), as units of each currency per one unit of [base].
class FxRates {
  const FxRates(this.base, this.day, this.rates);
  final String base;

  /// The banks' publication day, yyyy-MM-dd.
  final String day;
  final Map<String, double> rates;

  static const endpoint = 'https://api.frankfurter.dev/v1/latest';

  /// Converts [minor] units of [from] into [base], or null for a currency the
  /// ECB does not publish.
  int? toBase(int minor, String from) {
    if (from == base) return minor;
    final r = rates[from];
    if (r == null || r <= 0) return null;
    final fromScale = currencyInfo(from).scale, toScale = currencyInfo(base).scale;
    final major = minor / pow(10, fromScale) / r;
    return (major * pow(10, toScale)).round();
  }

  Map<String, Object> toJson() => {'base': base, 'date': day, 'rates': rates};

  static FxRates? fromJson(Object? json) {
    final j = json is String ? jsonDecode(json) : json;
    if (j is! Map || j['base'] is! String || j['rates'] is! Map) return null;
    return FxRates(j['base'] as String, '${j['date'] ?? ''}', {
      for (final e in (j['rates'] as Map).entries) '${e.key}': (e.value as num).toDouble(),
    });
  }

  static Future<FxRates> fetch(String base, {http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final r = await c
          .get(Uri.parse('$endpoint?base=$base'), headers: {'user-agent': 'Chanda/0.1'})
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) throw StateError('Exchange rates: HTTP ${r.statusCode}');
      return fromJson(r.body) ?? (throw const FormatException('Exchange rates: unexpected reply'));
    } finally {
      if (client == null) c.close();
    }
  }
}

/// UK import rules Chanda estimates landed cost with. Dated, because they
/// change: the £135 low-value threshold is due to go by October 2028.
class UkImportRules {
  const UkImportRules({this.dutyPercent = 0, this.handlingFee = 0});

  static const version = 'UK 2026-11-09';
  static const vatPercent = 20;

  /// Goods worth up to this (pence) are "low value": the seller or
  /// marketplace charges UK VAT at checkout, and there is no customs duty.
  static const lowValueLimit = 13500;

  /// The user's estimate of customs duty for this kind of goods (it depends
  /// on the product's commodity code), and a courier's handling fee in pence.
  final double dutyPercent;
  final int handlingFee;
}

/// What an item costs delivered, in the user's own currency.
class Landed {
  const Landed({required this.total, required this.parts, required this.estimate, required this.note});

  /// Minor units of the home currency.
  final int total;

  /// What makes up [total]: ('Price', 1299), ('Delivery', 299), ('Import VAT', ...).
  final List<(String, int)> parts;

  /// True when any part is Chanda's estimate rather than the shop's figure.
  final bool estimate;
  final String note;
}

/// Landed cost of buying at [price] (+ [shipping]) in [currency] for a
/// UK shopper whose home currency is [home]. [fromAbroad]: the goods are
/// sent from outside the UK. Prices shown to UK shoppers in pounds are
/// taken as VAT-inclusive (UK law requires it of shops selling to
/// consumers, and of marketplaces for low-value imports).
Landed? landedCost({
  required int price,
  int? shipping,
  required String currency,
  required String home,
  required bool fromAbroad,
  required FxRates? fx,
  UkImportRules rules = const UkImportRules(),
}) {
  int? conv(int m) => fx == null ? (currency == home ? m : null) : fx.toBase(m, currency);
  final goods = conv(price);
  final ship = shipping == null ? 0 : conv(shipping);
  if (goods == null || ship == null) return null;
  final parts = <(String, int)>[('Price', goods), if (shipping != null && ship > 0) ('Delivery', ship)];
  var estimate = currency != home;
  var note = currency != home ? 'Converted at the ECB reference rate${fx == null ? '' : ' of ${fx.day}'}.' : '';
  if (fromAbroad && home == 'GBP') {
    final inPounds = currency == 'GBP';
    if (goods > UkImportRules.lowValueLimit) {
      // Over £135: the price shown should not include import VAT; duty and
      // VAT are paid on arrival, on goods + delivery + duty.
      final duty = (goods * rules.dutyPercent / 100).round();
      final vat = ((goods + ship + duty) * UkImportRules.vatPercent / 100).round();
      if (duty > 0) parts.add(('Customs duty', duty));
      parts.add(('Import VAT', vat));
      if (rules.handlingFee > 0) parts.add(('Handling fee', rules.handlingFee));
      estimate = true;
      note = '$note Over £135: import VAT${duty > 0 ? ' and duty' : ''} due on delivery (${UkImportRules.version}).'
          .trim();
    } else if (!inPounds) {
      // Low value but priced abroad: the seller may not have charged UK VAT.
      final vat = ((goods + ship) * UkImportRules.vatPercent / 100).round();
      parts.add(('UK VAT (if not charged)', vat));
      estimate = true;
      note = '$note A seller outside the UK should charge UK VAT; Chanda adds it in case it has not.'.trim();
    }
  }
  return Landed(total: parts.fold(0, (s, p) => s + p.$2), parts: parts, estimate: estimate, note: note);
}
