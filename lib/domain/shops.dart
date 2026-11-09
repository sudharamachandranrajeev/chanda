/// A shop Chanda knows by name. Any other site works too: it is known by
/// its domain ([shopFor]).
class Shop {
  const Shop({
    required this.id,
    required this.name,
    required this.domains,
    required this.home,
    required this.currency,
    this.country = 'GB',
    this.fromAbroad = false,
    this.userPresent = false,
    this.productKey,
    this.search,
  });

  final String id;
  final String name;

  /// Host names, without "www.", that belong to the shop.
  final List<String> domains;
  final String home;

  /// What the shop charges a UK shopper in.
  final String currency;
  final String country;

  /// The shop usually sends goods from outside the UK (landed cost adds
  /// import VAT and duty above the low-value limit).
  final bool fromAbroad;

  /// The shop turns away pages loaded without a person present, so its
  /// prices refresh only while the user has Chanda open (never in the
  /// background), and a check page is handed to the user.
  final bool userPresent;

  /// Finds the shop's own product id in a product page's URL.
  final RegExp? productKey;

  /// The shop's search page, with `{q}` for the words (URL-encoded) or
  /// `{q-}` for the words joined by hyphens. Null when unknown.
  final String? search;

  bool get known => !id.contains('.');

  /// The search page for [words], or null when the shop has none listed.
  Uri? searchFor(String words) {
    final t = search;
    final w = words.trim();
    if (t == null || w.isEmpty) return null;
    final hyphens = w.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '-');
    return Uri.parse(
      t
          .replaceAll('{q-}', Uri.encodeComponent(hyphens.replaceAll(RegExp(r'^-|-$'), '')))
          .replaceAll('{q}', Uri.encodeComponent(w)),
    );
  }

  /// Searched in the hidden web view. Shops that want a person present are
  /// searched in the visible browser instead, with the user there.
  bool get searchHidden => search != null && !userPresent;

  String keyOf(Uri url) => productKey?.firstMatch(url.path)?.group(1) ?? '';
}

/// The shops Chanda was first tested with. Hacoo and Temu are app-first and
/// strict about automated loads; Shein sends unknown visitors to a check.
final shops = <Shop>[
  Shop(
    id: 'amazon-uk',
    name: 'Amazon UK',
    domains: ['amazon.co.uk'],
    home: 'https://www.amazon.co.uk/',
    currency: 'GBP',
    productKey: RegExp(r'/(?:dp|gp/product|gp/aw/d)/([A-Z0-9]{10})'),
    search: 'https://www.amazon.co.uk/s?k={q}',
  ),
  Shop(
    id: 'shein',
    name: 'Shein',
    domains: ['shein.co.uk', 'shein.com', 'm.shein.com'],
    home: 'https://www.shein.co.uk/',
    currency: 'GBP',
    fromAbroad: true,
    userPresent: true,
    productKey: RegExp(r'-p-(\d+)'),
    search: 'https://www.shein.co.uk/pdsearch/{q}/',
  ),
  Shop(
    id: 'temu',
    name: 'Temu',
    domains: ['temu.com'],
    home: 'https://www.temu.com/uk',
    currency: 'GBP',
    fromAbroad: true,
    userPresent: true,
    productKey: RegExp(r'-g-(\d+)\.html'),
    search: 'https://www.temu.com/uk/search_result.html?search_key={q}',
  ),
  Shop(
    id: 'aliexpress',
    name: 'AliExpress',
    domains: ['aliexpress.com', 'aliexpress.co.uk', 'aliexpress.us', 'm.aliexpress.com'],
    home: 'https://www.aliexpress.com/',
    currency: 'GBP',
    fromAbroad: true,
    productKey: RegExp(r'/item/(\d+)\.html'),
    search: 'https://www.aliexpress.com/w/wholesale-{q-}.html',
  ),
  Shop(
    id: 'hacoo',
    name: 'Hacoo',
    domains: ['hacoo.com', 'hacoo.app'],
    home: 'https://www.hacoo.com/',
    currency: 'GBP',
    fromAbroad: true,
    userPresent: true,
    search: 'https://www.hacoo.com/search?keyword={q}',
  ),
];

Shop? shopById(String id) => shops.where((s) => s.id == id).firstOrNull;

/// The host without "www." (and "m." for mobile sites).
String bareHost(Uri url) => url.host.toLowerCase().replaceFirst(RegExp(r'^(www\d?|m)\.'), '');

/// The catalogue shop for [url], or a shop named after its domain. Currency
/// for an unknown shop is guessed from the domain's country.
Shop shopFor(Uri url) {
  final host = bareHost(url);
  for (final s in shops) {
    if (s.domains.any((d) => host == d || host.endsWith('.$d'))) return s;
  }
  final (country, currency) = _countryOf(host);
  return Shop(
    id: host,
    name: host,
    domains: [host],
    home: '${url.scheme}://${url.host}/',
    currency: currency,
    country: country,
    fromAbroad: country != 'GB',
  );
}

/// Shop by stored id: a catalogue shop, else one rebuilt from the domain.
Shop shopOf(String id) => shopById(id) ?? shopFor(Uri.parse('https://$id/'));

(String, String) _countryOf(String host) {
  for (final MapEntry(key: tld, value: cc) in _tlds.entries) {
    if (host.endsWith(tld)) return cc;
  }
  return ('', 'GBP');
}

const _tlds = <String, (String, String)>{
  '.co.uk': ('GB', 'GBP'),
  '.uk': ('GB', 'GBP'),
  '.ie': ('IE', 'EUR'),
  '.de': ('DE', 'EUR'),
  '.fr': ('FR', 'EUR'),
  '.es': ('ES', 'EUR'),
  '.it': ('IT', 'EUR'),
  '.nl': ('NL', 'EUR'),
  '.us': ('US', 'USD'),
  '.ca': ('CA', 'CAD'),
  '.com.au': ('AU', 'AUD'),
  '.co.in': ('IN', 'INR'),
  '.in': ('IN', 'INR'),
  '.co.jp': ('JP', 'JPY'),
  '.jp': ('JP', 'JPY'),
  '.cn': ('CN', 'CNY'),
};
