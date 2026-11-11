import 'dart:convert';
import 'dart:io';

import 'package:chanda/domain/app_searcher.dart';
import 'package:chanda/domain/attributes.dart';
import 'package:chanda/domain/ebay_api.dart';
import 'package:chanda/domain/offers.dart';
import 'package:chanda/domain/query.dart';
import 'package:chanda/domain/shop_api.dart';
import 'package:chanda/domain/shop_search.dart';
import 'package:chanda/domain/shops.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Shop product searches over plain HTTP. Every test uses a fake HTTP client:
// nothing here reaches a real shop or eBay.

Shop shop(String host, {String currency = 'GBP'}) =>
    Shop(id: host, name: host, domains: [host], home: 'https://$host/', currency: currency);

const shopifyReply = {
  'resources': {
    'results': {
      'products': [
        {
          'title': 'Trail slip-on shoe',
          'url': '/products/trail-slip-on?_pos=1&_sid=abc&_ss=r',
          'price': '59.00',
          'compare_at_price_max': '79.00',
          'featured_image': {'url': '//cdn.example/shoe.jpg'},
          'available': true,
        },
        {'title': 'Sold out boot', 'url': '/products/boot', 'price': '40.00', 'available': false},
        {'title': 'No price', 'url': '/products/none', 'price': ''},
      ],
    },
  },
};

final wooReply = [
  {
    'name': 'Walking boot &amp; sock set',
    'permalink': 'https://woo.example/product/boot-set/?utm_source=x',
    'prices': {'price': '4999', 'regular_price': '5999', 'currency_code': 'GBP', 'currency_minor_unit': 2},
    'images': [
      {'src': 'https://woo.example/boot.jpg'},
    ],
    'is_in_stock': true,
    'average_rating': '4.50',
    'review_count': 12,
  },
  {
    'name': 'Yen thing',
    'permalink': 'https://woo.example/product/yen/',
    'prices': {'price': '1280', 'regular_price': '1280', 'currency_code': 'JPY', 'currency_minor_unit': 0},
    'is_in_stock': false,
  },
];

http.Response json(Object body, [int code = 200, Map<String, String> headers = const {}]) =>
    http.Response(jsonEncode(body), code, headers: {'content-type': 'application/json', ...headers});

class MemoryCache implements PlatformCache {
  Map<String, String> saved = {};
  @override
  Future<Map<String, String>> load() async => saved;
  @override
  Future<void> save(Map<String, String> known) async => saved = known;
}

void main() {
  // The attribute list as shipped; searches use the one in force.
  lexicon = Lexicon.fromJson(jsonDecode(File(lexiconAsset).readAsStringSync()) as Map);
  final q = readQuery('walking shoes for all terrains, easy slip in');

  group('which shops can be asked', () {
    test('Shopify and WooCommerce are told apart from plain shops, with an honest agent', () async {
      final seen = <http.Request>[];
      final client = MockClient((r) async {
        seen.add(r);
        return switch ((r.url.host, r.url.path)) {
          ('shopify.example', '/search/suggest.json') => json(shopifyReply),
          ('woo.example', '/wp-json/wc/store/v1/products') => json(wooReply),
          _ => http.Response('not found', 404),
        };
      });
      final cache = MemoryCache();
      final apis = ShopApis(client: client, cache: cache);
      final shops = [shop('shopify.example'), shop('woo.example'), shop('plain.example')];
      await apis.detect(shops);
      expect(apis.platformOf(shops[0]), Platform.shopify);
      expect(apis.platformOf(shops[1]), Platform.woocommerce);
      expect(apis.platformOf(shops[2]), isNull);
      expect(apis.checked(shops[2]), isTrue);
      expect(seen.every((r) => r.headers['user-agent']!.startsWith('Chanda/')), isTrue);
      expect(seen.every((r) => !r.headers.containsKey('cookie')), isTrue);
      expect(cache.saved, {'shopify.example': 'shopify', 'woo.example': 'woocommerce', 'plain.example': ''});

      // A later run knows them without asking again.
      seen.clear();
      final again = ShopApis(client: client, cache: cache);
      await again.detect(shops);
      expect(again.platformOf(shops[0]), Platform.shopify);
      expect(again.platformOf(shops[2]), isNull);
      expect(seen, isEmpty);
    });

    test('a shop that is offline is looked at again next time', () async {
      final apis = ShopApis(client: MockClient((_) async => throw http.ClientException('offline')));
      final s = shop('down.example');
      await apis.detect([s]);
      expect(apis.checked(s), isFalse);
    });
  });

  group('Shopify', () {
    test('asks the suggest endpoint with the shop words and reads the products', () async {
      late Uri asked;
      final apis = ShopApis(
        client: MockClient((r) async {
          asked = r.url;
          return json(shopifyReply);
        }),
      );
      final s = shop('shopify.example');
      await apis.detect([s]);
      final offers = await apis.search(s, q);
      expect(asked.path, '/search/suggest.json');
      expect(asked.queryParameters['q'], 'all terrain slip on walking shoes');
      expect(asked.queryParameters['resources[type]'], 'product');
      expect(offers.map((o) => (o.title, o.price, o.was, o.inStock)), [
        ('Trail slip-on shoe', 5900, 7900, true),
        ('Sold out boot', 4000, null, false),
      ]);
      expect(offers.first.url, 'https://shopify.example/products/trail-slip-on');
      expect(offers.first.image, 'https://cdn.example/shoe.jpg');
      expect(offers.every((o) => o.source == OfferSource.api), isTrue);
    });
  });

  group('WooCommerce', () {
    test('reads minor-unit prices in the shop currency\'s own scale', () async {
      late Uri asked;
      final apis = ShopApis(
        client: MockClient((r) async {
          if (r.url.path.contains('suggest')) return http.Response('', 404);
          asked = r.url;
          return json(wooReply);
        }),
      );
      final s = shop('woo.example');
      await apis.detect([s]);
      final offers = await apis.search(s, q);
      expect(asked.queryParameters['search'], 'all terrain slip on walking shoes');
      expect(offers[0].title, 'Walking boot & sock set');
      expect((offers[0].price, offers[0].was, offers[0].rating, offers[0].reviews), (4999, 5999, 4.5, 12));
      expect(offers[0].url, 'https://woo.example/product/boot-set/', reason: 'tracking removed');
      expect((offers[1].price, offers[1].currency, offers[1].inStock), (1280, 'JPY', false));
    });
  });

  group('slowing down', () {
    final s = shop('shopify.example');
    test('a short Retry-After is waited out once', () async {
      var calls = 0;
      final pauses = <Duration>[];
      final apis = ShopApis(
        client: MockClient(
          (r) async =>
              ++calls == 1 ? http.Response('slow', 429, headers: {'retry-after': '2'}) : json(shopifyReply),
        ),
        pause: (d) async => pauses.add(d),
        cache: MemoryCache()..saved = {'shopify.example': 'shopify'},
      );
      await apis.detect([s]);
      final offers = await apis.search(s, q);
      expect(offers, hasLength(2));
      expect(pauses, [const Duration(seconds: 2)]);
    });

    test('a long one skips the shop until it is over, without asking again', () async {
      var calls = 0;
      var now = DateTime.utc(2026, 11, 11, 12);
      final pauses = <Duration>[];
      final cache = MemoryCache()..saved = {'shopify.example': 'shopify'};
      final apis = ShopApis(
        client: MockClient((r) async {
          calls++;
          return http.Response('slow', 429, headers: {'retry-after': '120'});
        }),
        clock: () => now,
        pause: (d) async => pauses.add(d),
        cache: cache,
      );
      await apis.detect([s]);
      await expectLater(apis.search(s, q), throwsA(isA<ShopBusy>()));
      expect(calls, 1);
      await expectLater(apis.search(s, q), throwsA(isA<ShopBusy>()));
      expect(calls, 1, reason: 'no ask while the pause lasts');
      expect(pauses, isEmpty);
      now = now.add(const Duration(seconds: 121));
      await expectLater(apis.search(s, q), throwsA(isA<ShopBusy>()));
      expect(calls, 2, reason: 'asked again after the pause');
    });

    test('Retry-After as seconds or as a date', () {
      final now = DateTime.utc(2026, 10, 21, 7, 28);
      expect(retryAfter('7', now), const Duration(seconds: 7));
      expect(retryAfter('Wed, 21 Oct 2026 07:29:00 GMT', now), const Duration(seconds: 60));
      expect(retryAfter('Wed, 21 Oct 2026 07:00:00 GMT', now), Duration.zero);
      expect(retryAfter('soon', now), isNull);
      expect(retryAfter(null, now), isNull);
    });
  });

  group('eBay with the user\'s own keys', () {
    const reply = {
      'itemSummaries': [
        {
          'itemId': 'v1|123456789012|0',
          'legacyItemId': '123456789012',
          'title': 'Walking shoes slip on',
          'price': {'value': '34.99', 'currency': 'GBP'},
          'image': {'imageUrl': 'https://i.ebayimg.com/a.jpg'},
          'itemWebUrl': 'https://www.ebay.co.uk/itm/123456789012?hash=item1&amdata=enc%3AX&mkcid=1',
        },
        {
          'itemId': 'v1|1|0',
          'title': 'Broken',
          'price': {'value': 'x', 'currency': 'GBP'},
        },
      ],
    };

    test(
      'gets a token with the keys, then searches EBAY_GB without any affiliate or end-user header',
      () async {
        final seen = <http.Request>[];
        final client = MockClient((r) async {
          seen.add(r);
          if (r.url.host == 'api.ebay.com' && r.url.path == '/identity/v1/oauth2/token') {
            return json({'access_token': 'tok', 'expires_in': 7200});
          }
          return json(reply);
        });
        final api = EbayApi(id: 'my-id', secret: 'my-secret', client: client);
        final offers = await api.search(q);
        await api.search(q);
        expect(seen.where((r) => r.url.path.endsWith('/token')), hasLength(1), reason: 'the token is kept');
        final token = seen.first;
        expect(token.headers['authorization'], 'Basic ${base64.encode(utf8.encode('my-id:my-secret'))}');
        expect(token.body, contains('grant_type=client_credentials'));
        final search = seen[1];
        expect(search.url.path, '/buy/browse/v1/item_summary/search');
        expect(search.url.queryParameters['q'], 'all terrain slip on walking shoes');
        expect(search.headers['authorization'], 'Bearer tok');
        expect(search.headers['x-ebay-c-marketplace-id'], 'EBAY_GB');
        final names = search.headers.keys.map((k) => k.toLowerCase()).toList();
        expect(names, isNot(contains('x-ebay-c-enduserctx')), reason: 'no affiliate header');
        expect(search.url.toString(), isNot(contains('campid')));
        expect(offers, hasLength(1));
        expect(offers.single.url, 'https://www.ebay.co.uk/itm/123456789012', reason: 'plain item page');
        expect(
          (offers.single.price, offers.single.currency, offers.single.source),
          (3499, 'GBP', OfferSource.api),
        );
      },
    );

    test('keys that eBay refuses say so; a pause is kept', () async {
      final refuse = EbayApi(
        id: 'a',
        secret: 'b',
        client: MockClient((_) async => json({'error': 'invalid_client'}, 401)),
      );
      await expectLater(refuse.search(q), throwsA(isA<StateError>()));
      var calls = 0;
      final busy = EbayApi(
        id: 'a',
        secret: 'b',
        client: MockClient((r) async {
          calls++;
          if (r.url.path.endsWith('/token')) return json({'access_token': 't', 'expires_in': 7200});
          return http.Response('', 429, headers: {'retry-after': '90'});
        }),
      );
      await expectLater(busy.search(q), throwsA(isA<ShopBusy>()));
      final before = calls;
      await expectLater(busy.search(q), throwsA(isA<ShopBusy>()));
      expect(calls, before, reason: 'not asked during the pause');
    });
  });

  group('the ways in order', () {
    test('eBay with a key, then a platform search, then the page', () async {
      final client = MockClient(
        (r) async => r.url.host == 'shopify.example' ? json(shopifyReply) : http.Response('', 404),
      );
      final apis = ShopApis(client: client);
      final ebay = EbayApi(id: 'a', secret: 'b', client: client);
      final searcher = AppSearcher(web: WebShopSearcher(), apis: apis, ebay: ebay);
      final plain = Shop(
        id: 'plain.example',
        name: 'Plain',
        domains: const ['plain.example'],
        home: 'https://plain.example/',
        currency: 'GBP',
        search: 'https://plain.example/s?q={q}',
      );
      final walled = Shop(
        id: 'walled.example',
        name: 'Walled',
        domains: const ['walled.example'],
        home: 'https://walled.example/',
        currency: 'GBP',
        userPresent: true,
        search: 'https://walled.example/s?q={q}',
      );
      final seed = shop('shopify.example');
      final ebayShop = shop(ebayShopId);
      await searcher.prepare([seed, plain, walled, ebayShop]);
      expect(searcher.wayFor(ebayShop), SearchWay.api);
      expect(searcher.wayFor(seed), SearchWay.api, reason: 'no web view needed');
      expect(searcher.wayFor(plain), isIn([SearchWay.hidden, SearchWay.needsYou]));
      expect(searcher.wayFor(walled), SearchWay.needsYou);
      expect(searcher.wayFor(shop('unknown.example')), isNull, reason: 'no search page, no platform');
      expect((await searcher.search(seed, q)).length, 2);
    });
  });
}
