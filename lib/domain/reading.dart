import 'dart:convert';
import 'dart:math';

import 'money.dart';

// How Chanda reads a product page, whatever the shop.
//
// A collector gathers evidence from the page: the script below inside a
// web view (it sees the page as drawn, so it knows which price is big, near
// the title and not struck through), or lib/domain/html_evidence.dart over
// plain HTML for background checks. [readProduct] then works through the
// layers, most trusted first:
//
//   1. schema.org JSON-LD (what shops publish for search engines)
//   2. microdata and OpenGraph product tags
//   3. JSON the page embeds for its own scripts (__NEXT_DATA__ and the like)
//   4. prices as drawn on the page
//
// Structured data can be stale, so it is checked against the prices drawn
// on the page: when they disagree, the drawn price wins and is flagged.

/// What a collector found on a page.
class Evidence {
  const Evidence({
    required this.url,
    this.canonical = '',
    this.docTitle = '',
    this.h1 = '',
    this.ld = const [],
    this.meta = const {},
    this.micro = const {},
    this.embedded = const [],
    this.prices = const [],
    this.images = const [],
    this.variant = const {},
    this.text = '',
    this.tables = const [],
    this.check = false,
    this.drawn = false,
  });

  final String url;
  final String canonical;
  final String docTitle;
  final String h1;

  /// Raw JSON-LD blocks.
  final List<String> ld;

  /// meta tags by lower-case property or name.
  final Map<String, String> meta;

  /// itemprop values in the page body.
  final Map<String, String> micro;

  /// JSON texts the page embeds for its own scripts.
  final List<String> embedded;

  /// Price texts on the page, likeliest first.
  final List<PriceSeen> prices;
  final List<String> images;

  /// Chosen options the page shows ("Colour" -> "Navy").
  final Map<String, String> variant;

  /// The page's main text, cut short.
  final String text;

  /// Tables that look like size charts (they name sizes and a body
  /// measurement), as rows of cell texts; hidden ones too, since shops keep
  /// their size chart in a pop-up.
  final List<List<List<String>>> tables;

  /// The page is a bot check or "access denied" page.
  final bool check;

  /// Collected from the page as drawn (a web view), so [prices] are ranked
  /// by what the shopper sees; false for plain HTML.
  final bool drawn;

  static Evidence fromJson(Object? json) {
    final j = (json is String ? jsonDecode(json) : json) as Map;
    Map<String, String> strings(Object? m) => {
      if (m is Map)
        for (final e in m.entries)
          if (e.value != null && '${e.value}'.trim().isNotEmpty) '${e.key}': '${e.value}'.trim(),
    };
    List<String> list(Object? l) => [
      if (l is List)
        for (final s in l) '$s',
    ];
    return Evidence(
      url: '${j['url'] ?? ''}',
      canonical: '${j['canonical'] ?? ''}',
      docTitle: '${j['docTitle'] ?? ''}',
      h1: '${j['h1'] ?? ''}',
      ld: list(j['ld']),
      meta: strings(j['meta']),
      micro: strings(j['micro']),
      embedded: list(j['embedded']),
      prices: [
        if (j['prices'] is List)
          for (final p in j['prices'] as List)
            if (p is Map) PriceSeen.fromJson(p),
      ],
      images: list(j['images']),
      variant: strings(j['variant']),
      text: '${j['text'] ?? ''}',
      tables: [
        if (j['tables'] is List)
          for (final t in j['tables'] as List)
            if (t is List)
              [
                for (final r in t)
                  if (r is List) [for (final c in r) '$c'],
              ],
      ],
      check: j['check'] == true,
      drawn: j['drawn'] == true,
    );
  }
}

/// A price text seen on the page.
class PriceSeen {
  const PriceSeen(this.text, {this.size = 0, this.struck = false, this.score = 0});
  final String text;

  /// Font size in pixels (0 when not drawn).
  final double size;

  /// Struck through, or labelled "was" or "RRP".
  final bool struck;
  final double score;

  static PriceSeen fromJson(Map j) => PriceSeen(
    '${j['text'] ?? ''}',
    size: (j['size'] as num?)?.toDouble() ?? 0,
    struck: j['struck'] == true,
    score: (j['score'] as num?)?.toDouble() ?? 0,
  );
}

/// What Chanda read about one product.
class Reading {
  const Reading({
    required this.url,
    required this.title,
    this.brand = '',
    this.description = '',
    this.images = const [],
    this.price,
    required this.currency,
    this.was,
    this.shipping,
    this.inStock = true,
    this.seller = '',
    this.gtin = '',
    this.mpn = '',
    this.sku = '',
    this.rating,
    this.reviews,
    this.warranty = '',
    this.variant = const {},
    this.layer = '',
    this.confidence = 'low',
    this.warnings = const [],
    this.check = false,
    this.text = '',
  });

  final String url;
  final String title;
  final String brand;
  final String description;
  final List<String> images;

  /// Minor units of [currency]; null when no price could be read.
  final int? price;
  final String currency;
  final int? was;
  final int? shipping;
  final bool inStock;
  final String seller;
  final String gtin;
  final String mpn;
  final String sku;
  final double? rating;
  final int? reviews;
  final String warranty;
  final Map<String, String> variant;

  /// Where the price came from: json-ld | microdata | meta | embedded | page.
  final String layer;

  /// high: two layers agree; medium: one trusted layer; low: a guess.
  final String confidence;
  final List<String> warnings;

  /// The page was a bot check: only the user can get past it.
  final bool check;

  /// The page's main text, kept only while the save sheet is open so the
  /// user can ask an AI to read it. Never saved.
  final String text;

  bool get usable => price != null && title.isNotEmpty && !check;

  /// This reading with the main facts read another way (the screen, or AI).
  /// [price] null keeps the old price; [clearWas] drops a "was" price that
  /// belonged to it.
  Reading withFacts({
    String? title,
    int? price,
    String? currency,
    bool clearWas = false,
    bool? inStock,
    required String layer,
    required String warning,
  }) => Reading(
    url: url,
    title: title ?? this.title,
    brand: brand,
    description: description,
    images: images,
    price: price ?? this.price,
    currency: price != null ? currency ?? this.currency : this.currency,
    was: clearWas ? null : was,
    shipping: shipping,
    inStock: inStock ?? this.inStock,
    seller: seller,
    gtin: gtin,
    mpn: mpn,
    sku: sku,
    rating: rating,
    reviews: reviews,
    warranty: warranty,
    variant: variant,
    layer: layer,
    confidence: 'low',
    warnings: [warning],
    check: check && price == null,
    text: text,
  );
}

/// Reads [e] into a product. [hint] is the shop's currency, used when the
/// page does not say.
Reading readProduct(Evidence e, {required String hint}) {
  final ld = _ldProduct(e.ld, e.h1.isNotEmpty ? e.h1 : e.meta['og:title'] ?? '');
  final m = e.meta, mi = e.micro;
  final pageCurrency =
      _s(ld?['currency']) ??
      mi['pricecurrency'] ??
      m['product:price:currency'] ??
      m['og:price:currency'] ??
      currencyIn(e.prices.firstOrNull?.text ?? '', hint: hint) ??
      hint;
  // A heading unlike the page's own title is a section heading, not the
  // product's name.
  final og = m['og:title'] ?? mi['name'];
  final h1 = e.h1.length > 4 && (og == null || similarity(e.h1, og) >= 0.3) ? e.h1 : null;
  // The shop's part comes off the page title before the longest part is
  // picked, or "Lamp | Example Shop" would read as the shop.
  final title = _withoutShop(
    _clean(_s(ld?['name']) ?? h1 ?? og ?? _docTitle(_withoutShop(e.docTitle, e.url))),
    e.url,
  );
  final warnings = <String>[];

  // Every price drawn on the page, as numbers.
  final drawn = <(PriceSeen, ReadPrice)>[
    for (final p in e.prices)
      if (parsePrice(p.text, hint: pageCurrency) case final r?)
        if (r.minor > 0) (p, r),
  ];
  final current = drawn.where((d) => !d.$1.struck).toList();
  bool shown(int minor) => current.take(10).any((d) => d.$2.minor == minor && d.$2.currency == pageCurrency);

  int? price;
  var layer = '', confidence = 'low';
  final structured = <(String, String?)>[
    ('json-ld', _s(ld?['price'])),
    ('microdata', mi['price']),
    ('meta', m['product:price:amount'] ?? m['og:price:amount']),
  ];
  for (final (name, raw) in structured) {
    if (raw == null) continue;
    final v = _amount(raw, pageCurrency);
    if (v == null || v <= 0) continue;
    if (current.isEmpty || shown(v)) {
      price = v;
      layer = name;
      confidence = current.isEmpty ? (name == 'json-ld' ? 'medium' : 'low') : 'high';
    } else {
      warnings.add(
        'The page\'s data says ${showPrice(v, pageCurrency)} but it shows '
        '${showPrice(current.first.$2.minor, current.first.$2.currency)}; Chanda took the price shown.',
      );
    }
    break;
  }
  if (price == null) {
    final embedded = _embeddedPrice(e.embedded, title, pageCurrency);
    if (embedded != null && (current.isEmpty || shown(embedded))) {
      price = embedded;
      layer = 'embedded';
      confidence = current.isEmpty ? 'low' : 'high';
    }
  }
  if (price == null && current.isNotEmpty) {
    price = current.first.$2.minor;
    layer = 'page';
    // Drawn on the page, big and near the title, is a good read; from plain
    // HTML, a price in the text is only a guess.
    confidence = e.drawn && current.first.$1.score >= 20 ? 'medium' : 'low';
  }

  // A struck-through price above the current one is the "was" price.
  final was =
      (price == null
          ? null
          : drawn
                .where((d) => d.$1.struck && d.$2.minor > price! && d.$2.currency == pageCurrency)
                .map((d) => d.$2.minor)
                .fold<int?>(null, (a, b) => a == null ? b : min(a, b))) ??
      _amount(_s(ld?['was']) ?? '', pageCurrency);

  final text = e.text;
  final ldStock = _s(ld?['availability']);
  final inStock = ldStock != null
      ? !RegExp(r'OutOfStock|SoldOut|Discontinued', caseSensitive: false).hasMatch(ldStock)
      : !RegExp(
          r'currently unavailable|out of stock|sold out|no longer available|not available',
          caseSensitive: false,
        ).hasMatch(text.substring(0, min(text.length, 3000)));

  final images = <String>{
    ..._list(ld?['image']),
    ?m['og:image'],
    ...e.images,
  }.map((i) => _absolute(i, e.url)).whereType<String>().take(6).toList();

  return Reading(
    url: e.canonical.isNotEmpty ? _absolute(e.canonical, e.url) ?? e.url : e.url,
    title: title,
    brand: _clean(_s(ld?['brand']) ?? m['product:brand'] ?? m['og:brand'] ?? mi['brand'] ?? _brandIn(text)),
    description: _clean(_s(ld?['description']) ?? m['og:description'] ?? m['description'] ?? ''),
    images: images,
    price: price,
    currency: pageCurrency,
    was: was,
    shipping: _amount(_s(ld?['shipping']) ?? '', pageCurrency) ?? _shippingIn(text, pageCurrency),
    inStock: inStock,
    seller: _clean(_s(ld?['seller']) ?? _sellerIn(text)),
    gtin: _s(ld?['gtin']) ?? mi['gtin13'] ?? mi['gtin'] ?? '',
    mpn: _s(ld?['mpn']) ?? mi['mpn'] ?? '',
    sku: _s(ld?['sku']) ?? mi['sku'] ?? '',
    rating: double.tryParse(_s(ld?['rating']) ?? mi['ratingvalue'] ?? '') ?? _ratingIn(text),
    reviews:
        int.tryParse((_s(ld?['reviews']) ?? mi['reviewcount'] ?? '').replaceAll(',', '')) ?? _reviewsIn(text),
    warranty: _warrantyIn(text),
    variant: e.variant,
    layer: layer,
    confidence: confidence,
    warnings: warnings,
    check: e.check && price == null,
    text: e.text,
  );
}

// ---- JSON-LD ----

/// The product in the page's JSON-LD that best matches [heading], flattened
/// to the fields Chanda uses.
Map<String, Object?>? _ldProduct(List<String> blocks, String heading) {
  final products = <Map>[];
  void walk(Object? n, int depth) {
    if (depth > 12) return;
    if (n is List) {
      for (final x in n) {
        walk(x, depth + 1);
      }
    } else if (n is Map) {
      final types = [n['@type']].expand((t) => t is List ? t : [t]).map((t) => '$t').toList();
      if (types.any((t) => t == 'Product' || t == 'ProductGroup' || t == 'IndividualProduct') &&
          n['name'] != null) {
        products.add(n);
      }
      for (final v in n.values) {
        walk(v, depth + 1);
      }
    }
  }

  for (final b in blocks) {
    try {
      walk(jsonDecode(b), 0);
    } on FormatException {
      // Shops sometimes write invalid JSON-LD; skip that block.
    }
  }
  if (products.isEmpty) return null;
  products.sort((a, b) => similarity('${b['name']}', heading).compareTo(similarity('${a['name']}', heading)));
  final p = products.first;
  // A product group's own offers, else its first variant's.
  var offers = _offers(p['offers']);
  if (offers.isEmpty && p['hasVariant'] is List) {
    for (final v in p['hasVariant'] as List) {
      if (v is Map) offers = _offers(v['offers']);
      if (offers.isNotEmpty) break;
    }
  }
  final inStock = offers
      .where((o) => !RegExp('OutOfStock|SoldOut').hasMatch('${o['availability']}'))
      .toList();
  final o = (inStock.isNotEmpty ? inStock : offers).firstOrNull ?? const {};
  final spec = o['priceSpecification'];
  final specs = spec is List ? spec : [?spec];
  String? was;
  String? specPrice;
  for (final s in specs.whereType<Map>()) {
    if ('${s['priceType']}'.contains('Strikethrough') || '${s['priceType']}'.contains('ListPrice')) {
      was = _s(s['price']);
    } else {
      specPrice ??= _s(s['price']);
    }
  }
  final rating = p['aggregateRating'];
  final shippingRate = _first(_first(o['shippingDetails'])?['shippingRate']);
  return {
    'name': p['name'],
    'brand': _name(p['brand']),
    'description': p['description'],
    'image': p['image'] is Map ? (p['image'] as Map)['url'] : p['image'],
    'price': _s(o['price']) ?? _s(o['lowPrice']) ?? specPrice,
    'currency': _s(o['priceCurrency']) ?? _s(_first(specs)?['priceCurrency']),
    'was': was,
    'availability': _s(o['availability']),
    'seller': _name(o['seller']),
    'shipping': _s(shippingRate?['value']),
    'gtin': _s(p['gtin13']) ?? _s(p['gtin']) ?? _s(p['gtin12']) ?? _s(p['gtin14']) ?? _s(p['gtin8']),
    'mpn': _s(p['mpn']),
    'sku': _s(p['sku']) ?? _s(o['sku']),
    'rating': rating is Map ? _s(rating['ratingValue']) : null,
    'reviews': rating is Map ? _s(rating['reviewCount']) ?? _s(rating['ratingCount']) : null,
  };
}

List<Map> _offers(Object? o) {
  if (o is List) return o.whereType<Map>().expand((x) => _offers(x)).toList();
  if (o is Map) {
    if ('${o['@type']}' == 'AggregateOffer' && o['offers'] != null) {
      final inner = _offers(o['offers']);
      if (inner.isNotEmpty) return inner;
    }
    return [o];
  }
  return const [];
}

Map? _first(Object? x) => x is List ? x.whereType<Map>().firstOrNull : (x is Map ? x : null);

String? _name(Object? x) => x is Map ? _s(x['name']) : _s(x);

String? _s(Object? x) {
  if (x == null || x is Map || x is List) return null;
  final s = '$x'.trim();
  return s.isEmpty ? null : s;
}

List<String> _list(Object? x) => [
  if (x is String) x,
  if (x is List)
    for (final i in x)
      if (i is String) i else if (i is Map && i['url'] is String) i['url'] as String,
];

/// A structured price: "12.99" is in major units; text may carry a symbol.
int? _amount(String raw, String currency) {
  if (raw.isEmpty) return null;
  final r = parsePrice(raw, hint: currency);
  return r?.currency == currency ? r!.minor : null;
}

// ---- JSON the page embeds ----

const _titleKeys = {
  'name',
  'title',
  'productname',
  'goodsname',
  'goods_name',
  'subject',
  'producttitle',
  'displayname',
};
const _priceKeys = {
  'price',
  'saleprice',
  'sale_price',
  'currentprice',
  'finalprice',
  'minprice',
  'pricevalue',
  'priceamount',
  'formattedprice',
  'displayprice',
  'activityprice',
  'retailprice',
  'salepricestr',
  'pricestr',
  'amountwithsymbol',
  'formatedamount',
  'formattedamount',
  'minactivityamount',
  'minamount',
  'amount',
  'value',
  'pricetext',
};

/// The price of the embedded product whose title is most like [title].
int? _embeddedPrice(List<String> blocks, String title, String currency) {
  if (title.isEmpty) return null;
  (double, int)? best;
  var seen = 0;
  void walk(Object? n, int depth) {
    if (depth > 30 || ++seen > 300000) return;
    if (n is List) {
      for (final x in n) {
        walk(x, depth + 1);
      }
      return;
    }
    if (n is! Map) return;
    String? name;
    for (final e in n.entries) {
      if (_titleKeys.contains('${e.key}'.toLowerCase()) &&
          e.value is String &&
          (e.value as String).length > 5) {
        name = e.value as String;
        break;
      }
    }
    if (name != null) {
      final s = similarity(name, title);
      if (s >= 0.6 && (best == null || s > best!.$1)) {
        final p = _priceOf(n, currency, 0);
        if (p != null) best = (s, p);
      }
    }
    for (final v in n.values) {
      walk(v, depth + 1);
    }
  }

  for (final b in blocks) {
    try {
      walk(jsonDecode(b), 0);
    } on FormatException {
      continue;
    }
  }
  return best?.$2;
}

/// A price in an embedded object: a text with a currency mark is trusted
/// over a bare number.
int? _priceOf(Map n, String currency, int depth) {
  if (depth > 3) return null;
  int? number;
  for (final e in n.entries) {
    final k = '${e.key}'.toLowerCase();
    if (!_priceKeys.contains(k) && !(k.contains('price') && !k.contains('unit'))) continue;
    final v = e.value;
    if (v is String && currencyIn(v) != null) {
      final r = parsePrice(v, hint: currency);
      if (r != null && r.currency == currency && r.minor > 0) return r.minor;
    } else if (v is Map) {
      final inner = _priceOf(v, currency, depth + 1);
      if (inner != null) return inner;
    } else if (number == null && (v is num || (v is String && RegExp(r'^\d+(\.\d+)?$').hasMatch(v)))) {
      number = _amount('$v', currency);
    }
  }
  return number;
}

// ---- text ----

/// How alike two titles are: the share of the shorter one's words in the
/// other (0-1).
double similarity(String a, String b) {
  final wa = _words(a), wb = _words(b);
  if (wa.isEmpty || wb.isEmpty) return 0;
  final (small, big) = wa.length <= wb.length ? (wa, wb) : (wb, wa);
  return small.where(big.contains).length / small.length;
}

Set<String> _words(String s) =>
    s.toLowerCase().split(RegExp(r'[^\p{L}\p{N}]+', unicode: true)).where((w) => w.length > 1).toSet();

String _clean(String s) {
  final t = s
      .replaceAll(RegExp(r'&amp;'), '&')
      .replaceAll(RegExp(r'&quot;'), '"')
      .replaceAll(RegExp(r'&#39;'), "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return t.length > 2000 ? t.substring(0, 2000) : t;
}

/// "Shirt - AliExpress 200000343" loses the shop's name at the end.
String _withoutShop(String title, String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  final labels = host
      .split('.')
      .where((l) => l.length > 2 && !const {'www', 'com', 'shop', 'store'}.contains(l));
  if (labels.isEmpty) return title;
  final parts = title.split(RegExp(r'\s+[|:–—-]\s+'));
  while (parts.length > 1 && labels.any((l) => parts.last.toLowerCase().contains(l))) {
    parts.removeLast();
  }
  return parts.length == 1
      ? parts.first
      : title.substring(0, title.lastIndexOf(parts.last) + parts.last.length);
}

/// "Thing : Amazon.co.uk: Fashion" and "Thing | Shop" lose the shop's part.
String _docTitle(String t) {
  final parts = t.split(RegExp(r'\s+[|:–—-]\s+'));
  return parts.isEmpty ? t : parts.reduce((a, b) => a.length >= b.length ? a : b);
}

String? _absolute(String url, String base) {
  if (url.isEmpty) return null;
  try {
    final u = Uri.parse(base).resolve(url.startsWith('//') ? 'https:$url' : url);
    return u.hasScheme && u.scheme.startsWith('http') ? u.toString() : null;
  } on FormatException {
    return null;
  }
}

String _brandIn(String text) =>
    RegExp(r'(?:^|\n)\s*(?:Brand|Visit the)\s*:?\s*([^\n]{2,40}?)(?:\s+Store)?\s*(?:\n|$)')
        .firstMatch(text)?[1] ??
    '';

String _sellerIn(String text) =>
    RegExp(
      r'(?:Sold by|Dispatched from and sold by|Seller|Store|Sold and shipped by)\s*:?\s*([^\n]{2,60}?)\s*(?:\n|$)',
    ).firstMatch(text)?[1] ??
    '';

int? _shippingIn(String text, String currency) {
  if (RegExp(r'free (?:uk )?(?:delivery|shipping)', caseSensitive: false).hasMatch(text)) return 0;
  final m = RegExp(
    r'(?:delivery|shipping|postage)\s*(?:fee|cost|charge)?\s*:?\s*((?:[£€$¥₹￡￥＄]|[A-Z]{3}\s?)\s?\d[\d.,]*)',
    caseSensitive: false,
  ).firstMatch(text);
  if (m == null) return null;
  final r = parsePrice(m[1]!, hint: currency);
  return r?.currency == currency ? r!.minor : null;
}

double? _ratingIn(String text) {
  final m = RegExp(r'(\d(?:[.,]\d)?)\s*out of\s*5', caseSensitive: false).firstMatch(text);
  final v = m == null ? null : double.tryParse(m[1]!.replaceAll(',', '.'));
  return v != null && v <= 5 ? v : null;
}

int? _reviewsIn(String text) {
  final m = RegExp(r'([\d,.]+)\s*(?:global\s+)?(?:ratings|reviews)\b', caseSensitive: false).firstMatch(text);
  return m == null ? null : int.tryParse(m[1]!.replaceAll(RegExp(r'[,.]'), ''));
}

/// Up to two short passages about warranty, guarantee or returns.
String _warrantyIn(String text) {
  final out = <String>[];
  for (final m in RegExp(
    r'[^\n.]{0,80}\b(?:warranty|guarantee|guaranteed|returns?|refund)\b[^\n.]{0,80}',
    caseSensitive: false,
  ).allMatches(text)) {
    final s = m[0]!.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.length > 12 && RegExp(r'\d|free|year|month|day|lifetime', caseSensitive: false).hasMatch(s)) {
      out.add(s);
    }
    if (out.length == 2) break;
  }
  return out.join(' · ');
}

/// Addresses shops send a visitor to when they want a check or a sign-in
/// first: Shein's `/risk/challenge`, Temu's `bgn_verification.html` and
/// `login.html`, and the usual captcha and challenge pages.
final wallAddress = RegExp(
  r'/risk/challenge|bgn_verification|captcha|/punish|_____tmd_____|cf_chl|/challenge(?:[/?#.]|$)|'
  r'/(?:login|signin|sign-in|sign_in)(?:\.html?)?(?:[/?#]|$)',
  caseSensitive: false,
);

/// Words on a shop's check page.
const _wallWords =
    r'security checks?|security verification|verify (that )?you are (a )?human|are you a robot|captcha|'
    r'access denied|unusual traffic|pardon our interruption|slide to verify|robot check';

/// Whether [url] is a shop's check or sign-in wall rather than its results.
bool isWallAddress(Uri url) => wallAddress.hasMatch('${url.path}?${url.query}');

/// True on a shop's bot-check, sign-in wall or access-denied page: by its
/// address (some check pages are empty) or its words.
final checkScript =
    '''
(() => /${wallAddress.pattern.replaceAll('/', r'\/')}/i.test(location.pathname + location.search) ||
  /$_wallWords/i.test(document.title + ' ' + (document.body ? document.body.innerText.slice(0, 2000) : '')))()
''';

/// Collects [Evidence] from the page in a web view, as JSON text. It reads
/// only; it never clicks, types or changes the page.
const evidenceScript = r'''
(() => {
  const clip = (s, n) => (s || '').replace(/\s+/g, ' ').trim().slice(0, n);
  const out = {url: location.href, drawn: true, docTitle: document.title || '', meta: {}, micro: {}, ld: [], embedded: [], prices: [], images: [], variant: {}};
  const canon = document.querySelector('link[rel="canonical"]');
  out.canonical = canon ? canon.href : '';
  // The product's title: the biggest visible h1 (pages also use h1 for
  // headings only screen readers see).
  let h1 = null, h1Size = 0;
  for (const h of document.querySelectorAll('h1')) {
    const r = h.getBoundingClientRect();
    const size = parseFloat(getComputedStyle(h).fontSize) || 0;
    if (r.width > 1 && r.height > 1 && r.left > -500 && clip(h.innerText, 400).length > 4 && size > h1Size) { h1 = h; h1Size = size; }
  }
  out.h1 = h1 ? clip(h1.innerText, 400) : '';
  for (const m of document.querySelectorAll('meta[content]')) {
    const k = (m.getAttribute('property') || m.getAttribute('name') || m.getAttribute('itemprop') || '').toLowerCase();
    if (k && !(k in out.meta)) out.meta[k] = clip(m.getAttribute('content'), 2000);
  }
  for (const el of document.querySelectorAll('[itemprop]')) {
    const k = el.getAttribute('itemprop').toLowerCase();
    if (k in out.micro) continue;
    const v = el.getAttribute('content') || el.getAttribute('href') || el.getAttribute('src') || el.innerText || '';
    if (v.trim()) out.micro[k] = clip(v, 600);
  }
  for (const s of document.querySelectorAll('script[type="application/ld+json"]')) {
    if (s.textContent.length < 400000) out.ld.push(s.textContent);
  }
  for (const s of document.querySelectorAll('script#__NEXT_DATA__, script[type="application/json"]')) {
    if (s.textContent.length < 3000000 && /price/i.test(s.textContent)) out.embedded.push(s.textContent);
  }
  for (const name of ['__INIT_DATA__', '__NUXT__', '__APOLLO_STATE__', '__PRELOADED_STATE__', '__INITIAL_STATE__', '__rawData__', 'runParams', '_dida_config_', 'rawData', 'gbRawData', 'goodsDetailData', 'productIntroData']) {
    try {
      const v = window[name];
      if (v && typeof v === 'object') {
        const t = JSON.stringify(v);
        if (t && t.length < 3000000 && /price/i.test(t)) out.embedded.push(t);
      }
    } catch (e) {}
  }

  // Prices as drawn: big, near the title or the buy button, not in a
  // carousel of other products, not struck through.
  const priceRe = /^(?:(?:[£€$¥￥￡＄₹₩₺₽₫₱฿₪]|US\s?\$|[A-Z]{2}\$|R\$|[A-Z]{3}\s?)\s?\d[\d.,\s  ]*|\d[\d.,\s  ]*\s?(?:€|zł|Kč|kr|Ft|lei|円|元|[A-Z]{3}))$/;
  const awayRe = /carousel|recommend|sponsor|similar|also[-_ ]?(bought|viewed|like)|related|bundle|frequently|compare|swiper|slider|upsell|cross-?sell|recently/i;
  const buyRe = /add to (cart|basket|bag|trolley)|buy now|add to bag/i;
  const top = (h1 ? h1.getBoundingClientRect().top + scrollY : 0);
  let buy = null;
  for (const b of document.querySelectorAll('button, input[type="submit"], [role="button"], a')) {
    const t = (b.innerText || b.value || b.getAttribute('aria-label') || '').trim();
    if (t.length < 40 && buyRe.test(t) && b.getBoundingClientRect().height > 0) { buy = b; break; }
  }
  const buyTop = buy ? buy.getBoundingClientRect().top + scrollY : null;
  const away = (el) => {
    for (let e = el, i = 0; e && e !== document.body && i < 14; e = e.parentElement, i++) {
      if (/^(HEADER|NAV|FOOTER)$/.test(e.tagName)) return true;
      const tag = (e.id || '') + ' ' + (typeof e.className === 'string' ? e.className : '') + ' ' + (e.getAttribute('aria-roledescription') || '');
      if (awayRe.test(tag)) return true;
    }
    return false;
  };
  const struck = (el) => {
    for (let e = el, i = 0; e && i < 4; e = e.parentElement, i++) {
      if (/^(DEL|S|STRIKE)$/.test(e.tagName)) return true;
      if (getComputedStyle(e).textDecorationLine.includes('line-through')) return true;
      if (e.getAttribute('data-a-strike') === 'true') return true;
      const tag = typeof e.className === 'string' ? e.className : '';
      if (/strike|was-?price|old-?price|original-?price|list-?price|basisprice|rrp/i.test(tag)) return true;
    }
    const before = (el.parentElement ? el.parentElement.innerText : '').toLowerCase();
    return /\b(was|rrp|list price|typical price)\b[^0-9]{0,12}$/.test(before.split(el.innerText.trim())[0] || '');
  };
  const seen = [];
  const all = document.body ? document.body.querySelectorAll('*') : [];
  for (let i = 0; i < all.length && i < 30000; i++) {
    const el = all[i];
    if (/^(SCRIPT|STYLE|NOSCRIPT|OPTION|SELECT)$/.test(el.tagName)) continue;
    const t = clip(el.innerText, 40);
    if (t.length < 2 || !priceRe.test(t) || !/\d/.test(t)) continue;
    if ([...el.children].some((c) => priceRe.test(clip(c.innerText, 40)))) continue;
    const r = el.getBoundingClientRect();
    if (r.width < 1 || r.height < 1 || r.left < -500) continue;
    const cs = getComputedStyle(el);
    if (cs.visibility === 'hidden' || cs.display === 'none' || parseFloat(cs.opacity) === 0) continue;
    if (away(el)) continue;
    let size = parseFloat(cs.fontSize) || 0;
    for (const c of el.querySelectorAll('*')) size = Math.max(size, parseFloat(getComputedStyle(c).fontSize) || 0);
    const y = r.top + scrollY;
    const unit = /\/|per\b/i.test((el.parentElement ? el.parentElement.innerText : '').slice(0, 80)) && size < 14;
    let score = size * 1.5 - Math.max(0, y - top) / 120;
    if (h1 && Math.abs(y - top) < 700) score += 12;
    if (buyTop !== null && Math.abs(y - buyTop) < 500) score += 10;
    if (unit) score -= 25;
    seen.push({text: t, size, struck: struck(el), score: Math.round(score * 10) / 10});
  }
  seen.sort((a, b) => b.score - a.score);
  out.prices = seen.slice(0, 16);

  // Product pictures: large, roughly square images near the top, the
  // biggest and those beside the title first. Banners and sprites (very
  // wide or tall, or named so) are left out.
  const titleTop = h1 ? h1.getBoundingClientRect().top : 0;
  const imgs = [...document.querySelectorAll('img')]
    .map((im) => ({im, r: im.getBoundingClientRect(), src: im.currentSrc || im.src}))
    .filter(({im, r, src}) => im.naturalWidth >= 300 && r.width >= 120 && r.height >= 120 &&
      r.width / r.height < 2.5 && r.height / r.width < 2.5 && r.top + scrollY < 2000 && !away(im) &&
      src && /^https?:/.test(src) && !/sprite/i.test(src))
    .map(({r, src}) => ({src, score: r.width * r.height / 1000 - Math.abs(r.top - titleTop) / 10}))
    .sort((a, b) => b.score - a.score);
  out.images = [...new Set(imgs.map((x) => x.src))].slice(0, 8);

  // Chosen options: "Colour: Navy" lines, selected <select> options and
  // checked chips in a labelled group.
  const optRe = /^(colou?r|size|style|pattern|capacity|material|length|width|fit|model|pack size|lens|frame size)\s*:\s*(.{1,40})$/i;
  const text = document.body ? document.body.innerText : '';
  for (const line of text.split('\n').slice(0, 1500)) {
    const m = line.trim().match(optRe);
    if (m && !(m[1] in out.variant)) out.variant[m[1][0].toUpperCase() + m[1].slice(1).toLowerCase()] = m[2].trim();
  }
  for (const s of document.querySelectorAll('select')) {
    const label = (s.labels && s.labels[0] ? s.labels[0].innerText : s.getAttribute('aria-label') || s.name || '').trim();
    const o = s.selectedOptions && s.selectedOptions[0];
    if (/colou?r|size|style|length|fit/i.test(label) && o && o.index > 0) out.variant[clip(label, 30)] = clip(o.innerText, 40);
  }
  for (const g of document.querySelectorAll('[role="radiogroup"][aria-label]')) {
    const c = g.querySelector('[aria-checked="true"], [aria-selected="true"]');
    const label = clip(g.getAttribute('aria-label'), 30);
    if (c && /colou?r|size|style|length|fit/i.test(label)) out.variant[label] = clip(c.innerText || c.getAttribute('aria-label') || c.getAttribute('title'), 40);
  }
  // Size charts: tables naming sizes and a body measurement, hidden ones
  // too (shops keep them in a pop-up).
  out.tables = [];
  for (const t of document.querySelectorAll('table')) {
    const all = clip(t.textContent, 4000);
    if (!/size/i.test(all) || !/chest|bust|waist|hip/i.test(all)) continue;
    const rows = [...t.rows].slice(0, 40).map((r) => [...r.cells].slice(0, 16).map((c) => clip(c.textContent, 40)));
    if (rows.length > 1) out.tables.push(rows);
    if (out.tables.length >= 6) break;
  }
  const main = document.querySelector('main, #dp, [role="main"]') || document.body;
  out.text = main ? main.innerText.slice(0, 8000) : '';
  out.check = /security checks?|security verification|verify (that )?you are (a )?human|are you a robot|captcha|access denied|unusual traffic|pardon our interruption|slide to verify|robot check/i.test(document.title + ' ' + text.slice(0, 2000));
  return JSON.stringify(out);
})()
''';
