import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/services.dart' show rootBundle;
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import '../db/database.dart';
import 'pictures.dart';
import 'shops.dart';
import 'taste_store.dart' show categoryOf;
import 'vault.dart';

// "Similar shops": shops the user does not use yet that sell the kinds of
// things they save, at their kind of prices, from a curated list
// (assets/shops/seed.json). Each can be checked (how long its domain has
// been registered, whether it has a secure connection, the company and
// returns details it publishes) and added to Chanda's search.
//
// Facts are only what the shop or the domain registry publish. Reviews are
// a link out: Chanda does not rate shops.

/// Synced: the shops the user added to their search, as a JSON list.
const myShopsPref = 'chanda.myShops';

/// A shop in the curated list.
class SeedShop {
  const SeedShop({
    required this.domain,
    required this.name,
    required this.home,
    required this.groups,
    required this.band,
    this.country = 'GB',
    this.currency = 'GBP',
    this.search,
  });

  factory SeedShop.fromJson(Map<String, Object?> j) => SeedShop(
    domain: '${j['domain']}',
    name: '${j['name']}',
    home: '${j['home']}',
    groups: [for (final g in (j['groups'] as List?) ?? const []) '$g'],
    band: '${j['band'] ?? 'mid'}',
    country: '${j['country'] ?? 'GB'}',
    currency: '${j['currency'] ?? 'GBP'}',
    search: j['search'] as String?,
  );

  final String domain;
  final String name;
  final String home;

  /// What it sells: clothes, shoes, tech, home… (see [groupOf]).
  final List<String> groups;

  /// budget | mid | premium
  final String band;
  final String country;
  final String currency;

  /// Its search page with `{q}`, as the shop declares it; null if it
  /// declares none.
  final String? search;

  Map<String, Object?> toJson() => {
    'domain': domain,
    'name': name,
    'home': home,
    'groups': groups,
    'band': band,
    'country': country,
    'currency': currency,
    'search': search,
  };

  Shop toShop() => Shop(
    id: domain,
    name: name,
    domains: [domain],
    home: home,
    currency: currency,
    country: country,
    fromAbroad: country != 'GB',
    search: search,
  );
}

List<SeedShop> seedShopsFrom(Map json) => [
  for (final s in (json['shops'] as List?) ?? const []) SeedShop.fromJson((s as Map).cast<String, Object?>()),
];

Future<List<SeedShop>> loadSeedShops() async =>
    seedShopsFrom(jsonDecode(await rootBundle.loadString('assets/shops/seed.json', cache: false)) as Map);

/// Picture label categories by the kind of shop that sells them.
const _groups = {
  'clothes':
      't-shirt|shirt|blouse|polo shirt|jumper|cardigan|hoodie|sweatshirt|jacket|coat|blazer|'
      'waistcoat|dress|skirt|jeans|trousers|shorts|leggings|joggers|suit|jumpsuit|pyjamas|'
      'swimsuit|bikini|underwear|bra|socks|tights',
  'shoes': 'trainers|boots|sandals|heels|flat shoes|loafers|slippers',
  'accessories':
      'handbag|backpack|tote bag|wallet|belt|hat|cap|scarf|gloves|tie|watch|necklace|earrings|'
      'ring|bracelet|hair clip|umbrella|suitcase|jewellery box',
  'glasses': 'glasses|sunglasses',
  'tech':
      'phone|phone case|laptop|tablet|headphones|earbuds|speaker|smartwatch|camera|television|'
      'computer monitor|keyboard|computer mouse|charger|cable|power bank|game console|'
      'game controller|printer',
  'home':
      'lamp|chair|sofa|table|desk|bed|pillow|duvet|rug|curtains|mirror|clock|vase|plant pot|'
      'candle|picture frame|shelf|storage box|mug|plate|bowl|glassware|cutlery|saucepan|'
      'frying pan|kettle|toaster|coffee machine|blender|vacuum cleaner|towel|bedding|light bulb',
  'toys': 'toy|doll|building blocks',
  'books': 'book|notebook|pen',
  'sport': 'bicycle|helmet|tent|yoga mat|dumbbells',
  'beauty': 'perfume|lipstick|skincare bottle|makeup brush|hair dryer|shaver',
  'pets': 'dog bed|pet toy',
  'garden': 'garden tool',
  'tools': 'drill|screwdriver',
};

final _groupOf = {
  for (final e in _groups.entries)
    for (final c in e.value.split('|')) c: e.key,
};

/// The kind of shop that sells picture label category [category].
String? groupOf(String category) => _groupOf[category];

/// budget under £25, premium from £100 (minor units).
String bandOf(int minor) => minor < 2500 ? 'budget' : (minor < 10000 ? 'mid' : 'premium');

/// What the user shops for: kinds of things (from their saved things'
/// titles and the shops they use), their price band, and the shops they
/// use already.
class ShopProfile {
  const ShopProfile({this.groups = const {}, this.band, this.domains = const {}, this.currency = 'GBP'});
  final Map<String, double> groups;
  final String? band;
  final Set<String> domains;
  final String currency;

  bool get isEmpty => groups.isEmpty && band == null;
}

ShopProfile profileOf(
  List<VaultItem> items,
  List<SeedShop> seeds,
  List<PictureLabel> labels, {
  String currency = 'GBP',
}) {
  final byDomain = {for (final s in seeds) s.domain: s};
  final groups = <String, double>{};
  final domains = <String>{};
  final prices = <int>[];
  for (final i in items) {
    final host = bareHost(Uri.parse(i.url));
    domains.add(host);
    if (groupOf(categoryOf(i.title, labels)) case final g?) groups[g] = (groups[g] ?? 0) + 1;
    final seed = byDomain[host] ?? byDomain[i.shop];
    for (final g in seed?.groups ?? const <String>[]) {
      groups[g] = (groups[g] ?? 0) + 0.5;
    }
    if (i.price case final p? when i.currency == currency) prices.add(p);
  }
  prices.sort();
  final total = groups.values.fold(0.0, (a, b) => a + b);
  return ShopProfile(
    groups: {for (final e in groups.entries) e.key: e.value / total},
    band: prices.isEmpty ? null : bandOf(prices[prices.length ~/ 2]),
    domains: domains,
    currency: currency,
  );
}

/// A suggested shop and why.
class SimilarShop {
  const SimilarShop(this.shop, this.score, this.why);
  final SeedShop shop;
  final double score;
  final List<String> why;
}

/// Shops from [seeds] the user does not use yet, best first: by how much of
/// what they save each sells, then a matching price band and currency.
List<SimilarShop> similarShops(List<SeedShop> seeds, ShopProfile p, {int limit = 12}) {
  if (p.isEmpty) return const [];
  final out = <SimilarShop>[];
  for (final s in seeds) {
    if (p.domains.any((d) => d == s.domain || d.endsWith('.${s.domain}'))) continue;
    final shared = [
      for (final g in s.groups)
        if ((p.groups[g] ?? 0) > 0) g,
    ]..sort((a, b) => p.groups[b]!.compareTo(p.groups[a]!));
    var score = shared.fold(0.0, (a, g) => a + p.groups[g]!);
    if (s.groups.contains('general')) score += 0.15;
    if (score == 0) continue;
    final why = <String>['Sells ${shared.isEmpty ? 'a bit of everything' : shared.take(2).join(' and ')}'];
    if (s.band == p.band) {
      score += 0.3;
      why.add('${_bandWords[s.band]} prices, like the things you save');
    }
    if (s.currency != p.currency) score *= 0.5;
    out.add(SimilarShop(s, score, why));
  }
  out.sort((a, b) => b.score.compareTo(a.score));
  return out.take(limit).toList();
}

const _bandWords = {'budget': 'Low', 'mid': 'Middling', 'premium': 'Higher'};

// ---- a shop's search address ----

/// The search address a page declares in its schema.org data
/// (WebSite → potentialAction → SearchAction), as a `{q}` template.
String? searchFromLd(List<String> ld) {
  for (final block in ld) {
    for (final m in RegExp(
      r'"(?:target|urlTemplate)"\s*:\s*"([^"]*\{search_term_string\}[^"]*)"',
    ).allMatches(block)) {
      final t = m.group(1)!.replaceAll(r'\/', '/').replaceAll('{search_term_string}', '{q}');
      if (_safeTemplate(t)) return t;
    }
  }
  return null;
}

/// The OpenSearch description a page links to.
Uri? openSearchLink(String page, Uri base) {
  final doc = html.parse(page);
  for (final l in doc.querySelectorAll('link[rel="search"]')) {
    if ((l.attributes['type'] ?? '').contains('opensearchdescription')) {
      final href = l.attributes['href'];
      if (href != null) return base.resolve(href);
    }
  }
  return null;
}

/// The results page template in an OpenSearch description, as `{q}`.
String? searchFromOpenSearch(String xml) {
  for (final m in RegExp(r'<Url\b[^>]*>', caseSensitive: false).allMatches(xml)) {
    final tag = m.group(0)!;
    if (!RegExp(r'''type\s*=\s*["']text/html["']''').hasMatch(tag)) continue;
    final t = RegExp(r'''template\s*=\s*["']([^"']+)["']''').firstMatch(tag)?.group(1);
    if (t == null) continue;
    final q = t
        .replaceAll('&amp;', '&')
        .replaceAll('{searchTerms}', '{q}')
        // Optional parameters ("{startPage?}") are dropped with their name.
        .replaceAll(RegExp(r'[?&][\w-]+=\{[\w:]+\?\}'), '');
    if (_safeTemplate(q)) return q;
  }
  return null;
}

/// A template from one results address the user pasted and the words they
/// searched there: "https://shop.example/s?k=desk+lamp" with "desk lamp"
/// gives "https://shop.example/s?k={q}". Null when the words are not in it.
String? searchFromExample(Uri results, String words) {
  final w = words.trim().toLowerCase();
  if (w.isEmpty || !results.isScheme('https')) return null;
  for (final MapEntry(:key, :value) in results.queryParameters.entries) {
    if (value.trim().toLowerCase() == w) {
      final q = {...results.queryParameters, key: '__Q__'};
      return results.replace(queryParameters: q).toString().replaceAll('__Q__', '{q}');
    }
  }
  final hyphens = w.replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '-');
  final segs = results.pathSegments;
  for (var i = 0; i < segs.length; i++) {
    final s = segs[i].toLowerCase();
    final mark = s == w ? '{q}' : (s == hyphens ? '{q-}' : null);
    if (mark == null) continue;
    final path = [...segs.take(i), '__Q__', ...segs.skip(i + 1)].join('/');
    final out = results.replace(path: '/$path').toString().replaceAll('__Q__', mark);
    return out.contains('?') && results.query.isEmpty ? out.replaceAll('?', '') : out;
  }
  return null;
}

/// Only an https address with exactly one place for the words.
bool _safeTemplate(String t) {
  final u = Uri.tryParse(t.replaceAll('{q}', 'x'));
  return u != null && u.isScheme('https') && u.host.isNotEmpty && '{q}'.allMatches(t).length == 1;
}

// ---- facts about a shop ----

/// What a shop and its domain registry publish about it.
class ShopFacts {
  const ShopFacts({
    required this.domain,
    this.registered,
    this.registryChecked = false,
    this.secure = false,
    this.pageRead = false,
    this.company = '',
    this.country = '',
    this.email = '',
    this.phone = '',
    this.returns = '',
    this.search,
  });

  factory ShopFacts.fromJson(Map<String, Object?> j) => ShopFacts(
    domain: '${j['domain']}',
    registered: j['registered'] as int?,
    registryChecked: j['registryChecked'] == true,
    secure: j['secure'] == true,
    pageRead: j['pageRead'] == true,
    company: '${j['company'] ?? ''}',
    country: '${j['country'] ?? ''}',
    email: '${j['email'] ?? ''}',
    phone: '${j['phone'] ?? ''}',
    returns: '${j['returns'] ?? ''}',
    search: j['search'] as String?,
  );

  final String domain;

  /// The year the domain was first registered; null when unknown.
  final int? registered;

  /// The registry answered (so a null [registered] means it did not say).
  final bool registryChecked;

  /// Its home page answered over a secure connection.
  final bool secure;

  /// Its home page could be read (some shops turn automated reads away).
  final bool pageRead;
  final String company;
  final String country;
  final String email;
  final String phone;

  /// Its returns policy page, when it publishes one.
  final String returns;

  /// A search address it declares.
  final String? search;

  /// A review site's page for the shop, to read for oneself.
  Uri get reviews => Uri.parse('https://www.trustpilot.com/review/$domain');

  Map<String, Object?> toJson() => {
    'domain': domain,
    'registered': registered,
    'registryChecked': registryChecked,
    'secure': secure,
    'pageRead': pageRead,
    'company': company,
    'country': country,
    'email': email,
    'phone': phone,
    'returns': returns,
    'search': search,
  };
}

/// Company, contact and returns details from a home page's schema.org data
/// (Organization, OnlineStore and the like), and a returns link from its
/// links when the data has none.
({String company, String country, String email, String phone, String returns}) detailsFromPage(
  List<String> ld, {
  String page = '',
  Uri? base,
}) {
  var company = '', country = '', email = '', phone = '', returns = '';
  void visit(Object? n) {
    if (n is List) {
      n.forEach(visit);
      return;
    }
    if (n is! Map) return;
    final type = '${n['@type']}';
    if (RegExp(r'Organization|Store|Corporation|LocalBusiness').hasMatch(type)) {
      if (company.isEmpty) company = '${n['legalName'] ?? n['name'] ?? ''}'.trim();
      if (email.isEmpty) email = '${n['email'] ?? ''}'.replaceFirst('mailto:', '').trim();
      if (phone.isEmpty) phone = '${n['telephone'] ?? ''}'.trim();
      if (country.isEmpty && n['address'] is Map) {
        final c = (n['address'] as Map)['addressCountry'];
        country = '${(c is Map ? c['name'] : c) ?? ''}'.trim();
      }
    }
    if (type.contains('MerchantReturnPolicy') && returns.isEmpty) {
      returns = '${n['merchantReturnLink'] ?? n['url'] ?? ''}';
    }
    for (final v in n.values) {
      if (v is Map || v is List) visit(v);
    }
  }

  for (final block in ld) {
    try {
      visit(jsonDecode(block));
    } on FormatException {
      continue;
    }
  }
  if (returns.isEmpty && page.isNotEmpty && base != null) {
    for (final a in html.parse(page).querySelectorAll('a[href]')) {
      final words = '${a.text} ${a.attributes['href']}'.toLowerCase();
      if (RegExp(r'\breturns?\b|refund').hasMatch(words)) {
        returns = '${base.resolve(a.attributes['href']!)}';
        break;
      }
    }
  }
  if (!returns.startsWith('https://')) returns = '';
  return (company: company, country: country, email: email, phone: phone, returns: returns);
}

/// The part of [host] a registry holds: "shop.example.co.uk" → "example.co.uk".
String registrableDomain(String host) {
  final parts = host.toLowerCase().split('.');
  if (parts.length <= 2) return host.toLowerCase();
  final second = parts[parts.length - 2];
  const shared = {'co', 'com', 'org', 'net', 'ac', 'gov', 'ltd', 'plc', 'me', 'edu'};
  final keep = shared.contains(second) && parts.last.length == 2 ? 3 : 2;
  return parts.sublist(parts.length - keep).join('.');
}

const _agent = {'user-agent': 'Chanda/0.1 (shop check for one shopper)'};

/// The registration year of [domain] from its registry's RDAP service
/// (found through IANA's list). Null when the registry has no RDAP service
/// or does not say. Throws on network errors.
Future<(bool, int?)> registeredYear(String domain, {http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    final boot = await c
        .get(Uri.parse('https://data.iana.org/rdap/dns.json'), headers: _agent)
        .timeout(const Duration(seconds: 15));
    if (boot.statusCode != 200) return (false, null);
    final tld = domain.split('.').last;
    String? base;
    for (final s in (jsonDecode(boot.body) as Map)['services'] as List) {
      final tlds = (s as List)[0] as List;
      if (tlds.contains(tld)) {
        base = [for (final u in s[1] as List) '$u'].where((u) => u.startsWith('https://')).firstOrNull;
        break;
      }
    }
    if (base == null) return (false, null);
    final r = await c
        .get(Uri.parse('${base.endsWith('/') ? base : '$base/'}domain/$domain'), headers: _agent)
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) return (false, null);
    for (final e in ((jsonDecode(r.body) as Map)['events'] as List?) ?? const []) {
      if (e is Map && e['eventAction'] == 'registration') {
        return (true, DateTime.tryParse('${e['eventDate']}')?.year);
      }
    }
    return (true, null);
  } finally {
    if (client == null) c.close();
  }
}

/// Looks up and keeps facts about shops (`chanda_shop_facts`, on this device
/// only), each at most once a month.
class ShopFactsStore {
  ShopFactsStore(this.db, {this.client});
  final AppDatabase db;
  final http.Client? client;

  Future<ShopFacts?> kept(String domain, {DateTime? now, Duration fresh = const Duration(days: 30)}) async {
    final row = await db
        .customSelect(
          'SELECT json, checked FROM chanda_shop_facts WHERE domain = ?',
          variables: [Variable(domain)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    final checked = DateTime.tryParse(row.read<String>('checked'));
    if (checked == null || (now ?? DateTime.now()).difference(checked) > fresh) return null;
    return ShopFacts.fromJson((jsonDecode(row.read<String>('json')) as Map).cast());
  }

  /// The facts about the shop at [home], looked up unless kept from the
  /// last month. [readPage] reads the home page another way (the web view)
  /// when the plain read is turned away.
  Future<ShopFacts> facts(Uri home, {Future<List<String>> Function(Uri)? readPage, DateTime? now}) async {
    final domain = registrableDomain(bareHost(home));
    if (await kept(domain, now: now) case final f?) return f;
    final c = client ?? http.Client();
    try {
      var secure = false, read = false;
      var ld = <String>[];
      var page = '';
      String? search;
      try {
        final r = await c
            .get(home.replace(scheme: 'https'), headers: {..._agent, 'accept': 'text/html'})
            .timeout(const Duration(seconds: 20));
        secure = true;
        if (r.statusCode == 200) {
          page = r.body;
          read = true;
          ld = [
            for (final s in html.parse(page).querySelectorAll('script[type="application/ld+json"]')) s.text,
          ];
          if (openSearchLink(page, home) case final osd?) {
            final x = await c.get(osd, headers: _agent).timeout(const Duration(seconds: 15));
            if (x.statusCode == 200) search = searchFromOpenSearch(x.body);
          }
        }
      } on Object {
        // Not answering over https, or turned away: see below.
      }
      if (!read && readPage != null) {
        try {
          ld = await readPage(home);
          read = true;
          secure = secure || home.isScheme('https');
        } on Object {
          // Left unread.
        }
      }
      search = searchFromLd(ld) ?? search;
      final d = detailsFromPage(ld, page: page, base: home);
      var (checked, year) = (false, null as int?);
      try {
        (checked, year) = await registeredYear(domain, client: c);
      } on Object {
        // The registry did not answer: unknown.
      }
      final f = ShopFacts(
        domain: domain,
        registered: year,
        registryChecked: checked,
        secure: secure,
        pageRead: read,
        company: d.company,
        country: d.country,
        email: d.email,
        phone: d.phone,
        returns: d.returns,
        search: search,
      );
      await db.customStatement(
        'INSERT OR REPLACE INTO chanda_shop_facts (domain, json, checked) VALUES (?, ?, ?)',
        [domain, jsonEncode(f.toJson()), nowIso(now)],
      );
      return f;
    } finally {
      if (client == null) c.close();
    }
  }
}

// ---- the user's own shops ----

/// The shops the user added to Chanda's search (synced), registered with
/// the shop catalogue so search and names use them.
class MyShops {
  MyShops(this.vault);
  final Vault vault;

  Future<List<SeedShop>> list() async {
    try {
      return [
        for (final s in jsonDecode(await vault.pref(myShopsPref) ?? '[]') as List)
          SeedShop.fromJson((s as Map).cast<String, Object?>()),
      ];
    } on Object {
      return const [];
    }
  }

  /// Adds or replaces [s] and registers the list.
  Future<void> add(SeedShop s) async {
    final all = [
      for (final o in await list())
        if (o.domain != s.domain) o,
      s,
    ];
    await _save(all);
  }

  Future<void> remove(String domain) async => _save([
    for (final o in await list())
      if (o.domain != domain) o,
  ]);

  Future<void> _save(List<SeedShop> all) async {
    await vault.setPref(myShopsPref, jsonEncode([for (final s in all) s.toJson()]));
    registerShops([for (final s in all) s.toShop()]);
  }

  /// Registers the stored list (at start and after a sync).
  Future<List<SeedShop>> load() async {
    final all = await list();
    registerShops([for (final s in all) s.toShop()]);
    return all;
  }
}
