import 'dart:async';
import 'dart:convert';

import 'package:brahma_core/brahma_core.dart' show currencyInfo;
import 'package:http/http.dart' as http;

import 'links.dart';
import 'money.dart';
import 'offers.dart';
import 'query.dart';
import 'shops.dart';

// Shops that sell on Shopify or WooCommerce answer a product search over
// plain HTTP, as their own storefront does for its search box. Chanda asks
// the way an app should: its own name in the user agent, at most a few asks
// at once, and a pause when a shop says "slow down" (429 with Retry-After).
// No web view, no page, so it works on every build and in the background.

/// How Chanda says who is asking.
const apiAgent = 'Chanda/0.5 (shop search for one shopper; https://github.com/sudharamachandranrajeev/chanda-shopping-assistant)';

/// A shop asked Chanda to slow down; the next try is after [until].
class ShopBusy implements Exception {
  const ShopBusy(this.shop, this.until);
  final String shop;
  final DateTime until;

  @override
  String toString() => '$shop asked for a pause';
}

/// What a shop's site is built on, when Chanda can search it directly.
enum Platform { shopify, woocommerce }

/// Searches shops over plain HTTP, and remembers which shop is which kind.
class ShopApis {
  ShopApis({
    this.client,
    DateTime Function()? clock,
    Future<void> Function(Duration)? pause,
    this.cache,
    this.maxWait = const Duration(seconds: 5),
  }) : _now = clock ?? DateTime.now,
       _pause = pause ?? Future<void>.delayed;

  final http.Client? client;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _pause;

  /// Longest pause asked for that Chanda waits out within one search; a
  /// longer one skips the shop until it is over.
  final Duration maxWait;

  /// Where what was found about each shop is kept between runs.
  final PlatformCache? cache;

  /// Host to platform; a host that is neither is kept as `null`.
  final _known = <String, Platform?>{};
  final _blocked = <String, DateTime>{};
  var _loaded = false;

  http.Client get _http => client ?? (_own ??= http.Client());
  http.Client? _own;

  /// The platform of [shop]'s site when known (and so searchable here).
  Platform? platformOf(Shop shop) => _known[_host(shop)];

  /// Whether [shop] has been looked at already.
  bool checked(Shop shop) => _known.containsKey(_host(shop));

  static String _host(Shop shop) =>
      Uri.parse(shop.home).host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');

  /// Looks at each of [among] not seen before, [atOnce] at a time, within
  /// [within], and remembers what they run on. A shop that does not answer
  /// in time is left for the next search.
  Future<void> detect(
    Iterable<Shop> among, {
    int atOnce = 6,
    Duration within = const Duration(seconds: 6),
  }) async {
    await _load();
    final todo = [
      for (final s in among)
        if (!checked(s)) s,
    ];
    if (todo.isEmpty) return;
    final deadline = _now().add(within);
    var next = 0;
    Future<void> worker() async {
      while (next < todo.length && _now().isBefore(deadline)) {
        final s = todo[next++];
        try {
          _known[_host(s)] = await _probe(s).timeout(within);
        } on Object {
          // Offline or slow: look again next time.
        }
      }
    }

    await Future.wait([for (var i = 0; i < atOnce; i++) worker()]).timeout(within, onTimeout: () => const []);
    await cache?.save({
      for (final e in _known.entries)
        if (e.key.isNotEmpty) e.key: e.value?.name ?? '',
    });
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    final saved = await cache?.load() ?? const {};
    for (final e in saved.entries) {
      _known[e.key] = Platform.values.where((p) => p.name == e.value).firstOrNull;
    }
  }

  Future<Platform?> _probe(Shop shop) async {
    final root = Uri.parse(shop.home);
    final shopify = await _get(
      root.replace(
        path: '/search/suggest.json',
        queryParameters: {'q': 'a', 'resources[type]': 'product', 'resources[limit]': '1'},
      ),
      shop,
    );
    final sj = shopify == null ? null : _json(shopify);
    if (sj is Map && sj['resources'] is Map) return Platform.shopify;
    final woo = await _get(
      root.replace(path: '/wp-json/wc/store/v1/products', queryParameters: {'per_page': '1'}),
      shop,
    );
    final wj = woo == null ? null : _json(woo);
    if (wj is List && (wj.isEmpty || (wj.first is Map && (wj.first as Map).containsKey('prices')))) {
      return Platform.woocommerce;
    }
    return null;
  }

  static Object? _json(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  /// The body of a 200 answer, or null for any other; throws [ShopBusy]
  /// when the shop asked for a pause longer than [maxWait].
  Future<String?> _get(Uri url, Shop shop) async {
    final host = url.host;
    final blocked = _blocked[host];
    if (blocked != null && _now().isBefore(blocked)) throw ShopBusy(shop.name, blocked);
    for (var attempt = 0; attempt < 2; attempt++) {
      final r = await _http
          .get(url, headers: {'user-agent': apiAgent, 'accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 429 || r.statusCode == 503) {
        final wait = retryAfter(r.headers['retry-after'], _now()) ?? const Duration(seconds: 30);
        if (attempt == 0 && wait <= maxWait) {
          await _pause(wait);
          continue;
        }
        final until = _now().add(wait);
        _blocked[host] = until;
        throw ShopBusy(shop.name, until);
      }
      return r.statusCode == 200 ? r.body : null;
    }
    return null;
  }

  /// Searches [shop] for [q]. Throws [StateError] when the shop is not known
  /// to run on a platform searched here.
  Future<List<Offer>> search(Shop shop, Query q) async {
    final words = q.shopWords();
    final root = Uri.parse(shop.home);
    switch (platformOf(shop)) {
      case Platform.shopify:
        final body = await _get(
          root.replace(
            path: '/search/suggest.json',
            queryParameters: {'q': words, 'resources[type]': 'product', 'resources[limit]': '10'},
          ),
          shop,
        );
        return body == null ? const [] : shopifyOffers(shop, body);
      case Platform.woocommerce:
        final body = await _get(
          root.replace(
            path: '/wp-json/wc/store/v1/products',
            queryParameters: {'search': words, 'per_page': '20'},
          ),
          shop,
        );
        return body == null ? const [] : wooOffers(shop, body);
      case null:
        throw StateError('${shop.name} has no product search Chanda can ask');
    }
  }

  void close() => _own?.close();
}

/// How long to wait for a `Retry-After` header: seconds, or a date.
Duration? retryAfter(String? header, DateTime now) {
  final h = header?.trim();
  if (h == null || h.isEmpty) return null;
  final seconds = int.tryParse(h);
  if (seconds != null) return Duration(seconds: seconds.clamp(0, 86400));
  try {
    final at = _httpDate(h);
    final d = at.difference(now.toUtc());
    return d.isNegative ? Duration.zero : d;
  } on Object {
    return null;
  }
}

/// A date in the HTTP format shops send ("Wed, 21 Oct 2026 07:28:00 GMT").
DateTime _httpDate(String s) {
  final m = RegExp(
    r'(\d{1,2}) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) (\d{4}) (\d\d):(\d\d):(\d\d)',
  ).firstMatch(s);
  if (m == null) throw FormatException('Not an HTTP date: $s');
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return DateTime.utc(
    int.parse(m[3]!),
    months.indexOf(m[2]!) + 1,
    int.parse(m[1]!),
    int.parse(m[4]!),
    int.parse(m[5]!),
    int.parse(m[6]!),
  );
}

/// Keeps which shop runs on what, between runs.
abstract class PlatformCache {
  Future<Map<String, String>> load();
  Future<void> save(Map<String, String> known);
}

/// Offers from Shopify's predictive search (`/search/suggest.json`).
List<Offer> shopifyOffers(Shop shop, String body) {
  final json = ApiJson.parse(body);
  final products = json.at(['resources', 'results', 'products']);
  final out = <Offer>[];
  for (final p in products is List ? products : const []) {
    if (p is! Map) continue;
    final link = Uri.tryParse(shop.home)?.resolve('${p['url'] ?? ''}');
    final price = parsePrice('${p['price'] ?? ''}', hint: shop.currency);
    final title = '${p['title'] ?? ''}'.trim();
    if (link == null || price == null || price.minor <= 0 || title.length < 3) continue;
    final compare = parsePrice(
      '${p['compare_at_price_max'] ?? p['compare_at_price'] ?? ''}',
      hint: price.currency,
    );
    final image = p['featured_image'] is Map
        ? '${(p['featured_image'] as Map)['url'] ?? ''}'
        : '${p['image'] ?? ''}';
    out.add(
      Offer(
        shop: shop.id,
        // Keep the product's own path; the suggestion's query is tracking.
        url: '${Uri(scheme: link.scheme, host: link.host, path: link.path)}',
        title: title,
        image: image.startsWith('//') ? 'https:$image' : image,
        price: price.minor,
        currency: price.currency,
        was: compare != null && compare.minor > price.minor ? compare.minor : null,
        inStock: p['available'] != false,
        source: OfferSource.api,
      ),
    );
  }
  return out;
}

/// Offers from WooCommerce's Store API (`/wp-json/wc/store/v1/products`),
/// whose prices are whole minor units in text ("2999" with two decimals).
List<Offer> wooOffers(Shop shop, String body) {
  final json = ApiJson.parse(body).value;
  final out = <Offer>[];
  for (final p in json is List ? json : const []) {
    if (p is! Map || p['prices'] is! Map) continue;
    final prices = p['prices'] as Map;
    final code = '${prices['currency_code'] ?? shop.currency}'.toUpperCase();
    final scale = int.tryParse('${prices['currency_minor_unit'] ?? 2}') ?? 2;
    final ours = currencyInfo(code).scale;
    int? minor(Object? v) => switch (int.tryParse('${v ?? ''}')) {
      final n? when n > 0 => (n * _pow10(ours) / _pow10(scale)).round(),
      _ => null,
    };
    final now = minor(prices['price']);
    final title = _plain('${p['name'] ?? ''}');
    final link = Uri.tryParse('${p['permalink'] ?? ''}');
    if (now == null || link == null || !link.hasScheme || title.length < 3) continue;
    final was = minor(prices['regular_price']);
    final images = p['images'];
    out.add(
      Offer(
        shop: shop.id,
        url: '${cleanLink(link)}',
        title: title,
        image: images is List && images.isNotEmpty && images.first is Map
            ? '${(images.first as Map)['src'] ?? ''}'
            : '',
        price: now,
        currency: code,
        was: was != null && was > now ? was : null,
        rating: switch (double.tryParse('${p['average_rating'] ?? ''}')) {
          final r? when r > 0 && r <= 5 => r,
          _ => null,
        },
        reviews: int.tryParse('${p['review_count'] ?? ''}'),
        inStock: p['is_in_stock'] != false,
        source: OfferSource.api,
      ),
    );
  }
  return out;
}

int _pow10(int n) => n <= 0 ? 1 : 10 * _pow10(n - 1);

/// A product name from a shop's data: HTML entities made plain.
String _plain(String s) => s
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&amp;', '&')
    .replaceAll('&#038;', '&')
    .replaceAll('&#8211;', '-')
    .replaceAll('&#8217;', "'")
    .replaceAll('&quot;', '"')
    .replaceAll('&#039;', "'")
    .trim();

/// JSON from a shop, read without throwing: a page that is not JSON is
/// just nothing.
class ApiJson {
  const ApiJson(this.value);
  factory ApiJson.parse(String body) {
    try {
      return ApiJson(jsonDecode(body));
    } on FormatException {
      return const ApiJson(null);
    }
  }
  final Object? value;

  Object? at(List<String> path) {
    Object? v = value;
    for (final k in path) {
      if (v is! Map) return null;
      v = v[k];
    }
    return v;
  }
}
