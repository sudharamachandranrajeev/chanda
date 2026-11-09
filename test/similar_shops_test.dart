import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chanda/domain/pictures.dart';
import 'package:chanda/domain/shops.dart';
import 'package:chanda/domain/similar_shops.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support.dart';

final _labels = [
  for (final c in ['dress', 'trainers', 'lamp', 'laptop']) PictureLabel('category', c, Float32List(4)),
];

List<SeedShop> _seeds() =>
    seedShopsFrom(jsonDecode(File('assets/shops/seed.json').readAsStringSync()) as Map);

const _rdapBoot = {
  'services': [
    [
      ['uk'],
      ['https://rdap.nominet.uk/uk/'],
    ],
    [
      ['zz'],
      ['http://rdap.example/'],
    ],
  ],
};

void main() {
  test('the curated list: unique domains, known kinds, safe search addresses', () {
    final seeds = _seeds();
    expect(seeds.length, greaterThanOrEqualTo(50));
    expect(seeds.map((s) => s.domain).toSet(), hasLength(seeds.length));
    const kinds = {
      'general', 'clothes', 'shoes', 'accessories', 'glasses', 'tech', 'home', 'toys', 'books', 'sport', //
      'beauty', 'pets', 'garden', 'tools', 'gifts',
    };
    for (final s in seeds) {
      expect(kinds.containsAll(s.groups), isTrue, reason: s.domain);
      expect(['budget', 'mid', 'premium'], contains(s.band));
      expect(Uri.parse(s.home).isScheme('https'), isTrue, reason: s.domain);
      if (s.search case final t?) {
        expect(t.startsWith('https://'), isTrue, reason: s.domain);
        expect('{q}'.allMatches(t), hasLength(1), reason: s.domain);
      }
    }
  });

  test('similar shops: what the user saves and their price band, not shops they use', () async {
    final v = await memoryVault();
    await saved(v, reading(url: 'https://www.asos.com/p/1', title: 'Black slip dress', price: 2800));
    await saved(v, reading(url: 'https://www.asos.com/p/2', title: 'White trainers', price: 4500));
    await saved(v, reading(url: 'https://www.amazon.co.uk/dp/B000000001', title: 'Desk lamp', price: 3000));
    final seeds = _seeds();
    final p = profileOf(await v.items(), seeds, _labels);
    expect(p.band, 'mid');
    expect(p.groups['clothes']! > p.groups['home']!, isTrue);
    final out = similarShops(seeds, p);
    expect(out.map((s) => s.shop.domain), isNot(contains('asos.com')));
    expect(out.first.shop.groups, contains('clothes'));
    expect(out.first.why.first, startsWith('Sells clothes'));
    expect(similarShops(seeds, const ShopProfile()), isEmpty);
  });

  test('search addresses: declared, from OpenSearch, or from one pasted example', () {
    expect(
      searchFromLd([
        '{"@type":"WebSite","potentialAction":{"@type":"SearchAction",'
            r'"target":"https:\/\/shop.example\/search?q={search_term_string}","query-input":"required"}}',
      ]),
      'https://shop.example/search?q={q}',
    );
    expect(searchFromLd(['{"target":"http://shop.example/s?q={search_term_string}"}']), isNull);
    expect(
      openSearchLink(
        '<link rel="search" type="application/opensearchdescription+xml" href="/osd.xml">',
        Uri.parse('https://shop.example/'),
      ),
      Uri.parse('https://shop.example/osd.xml'),
    );
    expect(
      searchFromOpenSearch(
        '<OpenSearchDescription><Url type="application/x-suggestions+json" template="https://x/s?q={searchTerms}"/>'
        '<Url type="text/html" template="https://shop.example/search?q={searchTerms}&amp;page={startPage?}"/>'
        '</OpenSearchDescription>',
      ),
      'https://shop.example/search?q={q}',
    );
    expect(
      searchFromExample(Uri.parse('https://shop.example/s?k=desk+lamp&ref=nav'), 'Desk lamp'),
      'https://shop.example/s?k={q}&ref=nav',
    );
    expect(
      searchFromExample(Uri.parse('https://shop.example/search/desk-lamp/'), 'desk lamp'),
      'https://shop.example/search/{q-}/',
    );
    expect(
      Shop(
        id: 'x',
        name: 'x',
        domains: const ['x'],
        home: '',
        currency: 'GBP',
        search: 'https://shop.example/search/{q-}/',
      ).searchFor('desk lamp'),
      Uri.parse('https://shop.example/search/desk-lamp/'),
    );
    expect(searchFromExample(Uri.parse('https://shop.example/s?k=chair'), 'desk lamp'), isNull);
  });

  test('company, contact and returns details from a home page', () {
    final d = detailsFromPage(
      [
        '{"@context":"https://schema.org","@graph":[{"@type":"Organization","name":"Example",'
            '"legalName":"Example Retail Ltd","email":"mailto:help@shop.example","telephone":"+44 20 0000 0000",'
            '"address":{"@type":"PostalAddress","addressCountry":"GB"}}]}',
        'not json',
      ],
      page: '<a href="/help/returns-policy">Returns</a>',
      base: Uri.parse('https://shop.example/'),
    );
    expect(d.company, 'Example Retail Ltd');
    expect(d.email, 'help@shop.example');
    expect(d.phone, '+44 20 0000 0000');
    expect(d.country, 'GB');
    expect(d.returns, 'https://shop.example/help/returns-policy');
  });

  test('registrable domains', () {
    expect(registrableDomain('shop.example.co.uk'), 'example.co.uk');
    expect(registrableDomain('www2.hm.com'), 'hm.com');
    expect(registrableDomain('example.com'), 'example.com');
  });

  test('facts: registry year, secure page, kept a month', () async {
    var calls = 0;
    final client = MockClient((r) async {
      calls++;
      expect(r.headers['user-agent'], startsWith('Chanda/'));
      return switch ('${r.url}') {
        'https://data.iana.org/rdap/dns.json' => http.Response(jsonEncode(_rdapBoot), 200),
        'https://rdap.nominet.uk/uk/domain/example.co.uk' => http.Response(
          jsonEncode({
            'events': [
              {'eventAction': 'registration', 'eventDate': '1999-04-01T00:00:00Z'},
            ],
          }),
          200,
        ),
        'https://www.example.co.uk/' => http.Response(
          '<script type="application/ld+json">{"@type":"WebSite","potentialAction":{"target":'
          '"https://www.example.co.uk/search?q={search_term_string}"}}</script>',
          200,
        ),
        _ => http.Response('', 404),
      };
    });
    final v = await memoryVault();
    final store = ShopFactsStore(v.db, client: client);
    final now = DateTime.utc(2026, 11, 9);
    final f = await store.facts(Uri.parse('https://www.example.co.uk/'), now: now);
    expect((f.registered, f.registryChecked, f.secure, f.pageRead), (1999, true, true, true));
    expect(f.search, 'https://www.example.co.uk/search?q={q}');
    final n = calls;
    await store.facts(Uri.parse('https://www.example.co.uk/'), now: now.add(const Duration(days: 29)));
    expect(calls, n, reason: 'kept');
    await store.facts(Uri.parse('https://www.example.co.uk/'), now: now.add(const Duration(days: 31)));
    expect(calls, greaterThan(n), reason: 'looked up again after a month');

    final none = await ShopFactsStore(v.db, client: client).facts(Uri.parse('https://shop.zz/'));
    expect((none.registered, none.registryChecked, none.pageRead), (null, false, false));
  });

  test('added shops join the search and never replace a built-in one', () async {
    final v = await memoryVault();
    final mine = MyShops(v);
    await mine.add(_seeds().firstWhere((s) => s.domain == 'johnlewis.com'));
    await mine.add(
      const SeedShop(
        domain: 'amazon.co.uk',
        name: 'Fake',
        home: 'https://amazon.co.uk/',
        groups: [],
        band: 'mid',
      ),
    );
    expect(
      shops.where((s) => s.id == 'johnlewis.com').single.searchFor('lamp'),
      Uri.parse('https://www.johnlewis.com/search?search-term=lamp'),
    );
    expect(shops.where((s) => s.name == 'Fake'), isEmpty);
    expect(shopFor(Uri.parse('https://www.johnlewis.com/p/1')).name, 'John Lewis');
    await mine.remove('johnlewis.com');
    await mine.remove('amazon.co.uk');
    expect(shops.where((s) => s.id == 'johnlewis.com'), isEmpty);
  });
}
