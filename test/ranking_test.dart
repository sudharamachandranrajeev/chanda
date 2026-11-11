import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:chanda/domain/attributes.dart';
import 'package:chanda/domain/offers.dart';
import 'package:chanda/domain/query.dart';
import 'package:chanda/domain/reading.dart';
import 'package:chanda/domain/shops.dart';
import 'package:flutter_test/flutter_test.dart';

/// The attribute list as shipped.
final lex = Lexicon.fromJson(jsonDecode(File(lexiconAsset).readAsStringSync()) as Map);

/// What Amazon UK and AliExpress listed for the user's own search
/// (test/fixtures/walking_shoes_offers.json), read as the app reads tiles.
List<(Offer, bool)> walkingShoes() {
  final doc = jsonDecode(File('test/fixtures/walking_shoes_offers.json').readAsStringSync()) as Map;
  return [
    for (final o in doc['offers'] as List)
      (parseOffers(shopById('${o['shop']}')!, [o]).single, o['sponsored'] == true),
  ];
}

/// The research's rule-made labels: an outdoor word and a slip-on word is
/// 2, either is 1, and sandals, clogs, chef shoes and the like are 0.
int grade(String title) {
  final s = title.toLowerCase();
  if (RegExp(
    r'chef|clog|sandal|slipper|rain boot|weightlift|combat|oxford|water shoe|wading|beach|steel toe|safety|'
    r'snow boot|loafer',
  ).hasMatch(s)) {
    return 0;
  }
  final out = RegExp(r'walk|hik|trail|trek|outdoor|all[- ]terrain|rugged').hasMatch(s);
  final slip = RegExp(r'slip[- ]?on|slip[- ]?ins?\b|hands?[- ]free|easy on|bungee|elastic').hasMatch(s);
  return out && slip ? 2 : (out || slip ? 1 : 0);
}

double ndcg(List<int> ranked, List<int> all, {int k = 10}) {
  double dcg(List<int> g) =>
      [for (var i = 0; i < min(k, g.length); i++) (pow(2, g[i]) - 1) / (log(i + 2) / ln2)]
          .fold(0.0, (a, b) => a + b);
  return dcg(ranked) / dcg([...all]..sort((a, b) => b.compareTo(a)));
}

void main() {
  group('reading what a search asks for', () {
    test('the user\'s walking shoes: two attributes, two words, no small words', () {
      final q = readQuery('walking shoes for all terrains, easy slip in', attributes: lex);
      expect(q.words, 'walking shoes');
      expect(q.facets.map((f) => (f.kind, f.value)), [
        ('attribute', 'all-terrain'),
        ('attribute', 'slip-on'),
      ]);
      expect(q.facets.map((f) => f.label), ['All-terrain', 'Slip-on']);
      expect(q.shopWords(lex), 'all terrain slip on walking shoes');
    });

    test('other ways of asking', () {
      Query read(String s) => readQuery(s, attributes: lex);
      expect(read('wireless earbuds with long battery for running').of('attribute'), [
        'wireless',
        'long-battery',
        'for-sport',
      ]);
      expect(read('wireless earbuds with long battery for running').words, 'earbuds');
      expect(read('something to keep my tea hot all day at work').of('attribute'), ['keeps-hot']);
      expect(read('comfy office chair for back pain under 150').words, 'office chair');
      expect(read('comfy office chair for back pain under 150').of('attribute'), [
        'comfortable',
        'back-support',
      ]);
      expect(read('earbuds not apple').words, 'earbuds', reason: 'what follows "not" is not looked for');
      expect(read('slip-on trainers').of('attribute'), ['slip-on']);
      expect(read('desk light').words, 'desk light', reason: 'common words are not attributes');
      expect(read('reading glasses').facets, isEmpty);
    });

    test('words are compared singular and without invisible characters', () {
      expect(stem('terrains'), 'terrain');
      expect(stem('batteries'), 'battery');
      expect(stem('glasses'), 'glass');
      expect(stem('dress'), 'dress');
      expect(wordsOf('Slip​on Shoes'), ['slipon', 'shoe']);
      expect(wordsOf('Slip-On Shoes'), ['slip', 'on', 'shoe']);
      expect(withoutInvisible('£1​2.99﻿'), '£12.99');
    });

    test('the shipped list is small and credits its source', () {
      final raw = File(lexiconAsset).readAsStringSync();
      expect(raw.length, lessThan(200000));
      expect(raw, contains('Shopify Standard Product Taxonomy (MIT'));
      expect(lex.attributes.length, greaterThan(100));
      expect(lex.attributes.map((a) => a.id).toSet().length, lex.attributes.length);
    });
  });

  group('reading tiles', () {
    final unknown = shopFor(Uri.parse('https://shop.example/'));
    Map<String, Object?> tile(String title, String sig, {String src = 'dom', String url = ''}) => {
      'title': title,
      'price': '£1\u200b2.50',
      'url': url.isEmpty ? 'https://shop.example/p/${title.hashCode.abs()}' : url,
      'src': src,
      'sig': sig,
    };

    test('a shop with unknown product links needs three tiles alike', () {
      final two = parseOffers(unknown, [tile('Lamp one', 'LI.card'), tile('Lamp two', 'LI.card')]);
      expect(two, isEmpty, reason: 'two price boxes are not a results list');
      final three = parseOffers(unknown, [
        tile('Lamp one', 'LI.card'),
        tile('Lamp two', 'LI.card'),
        tile('Lamp three', 'LI.card'),
        tile('Deal of the day', 'DIV.promo'),
      ]);
      expect(three.map((o) => o.title), ['Lamp one', 'Lamp two', 'Lamp three']);
      expect(three.first.price, 1250, reason: 'invisible characters inside the price are dropped');
      expect(parseOffers(unknown, [tile('Lamp from the page data', '', src: 'ld')]), hasLength(1));
    });

    test('a shop whose product links are known needs no three', () {
      final amazon = shopById('amazon-uk')!;
      expect(
        parseOffers(amazon, [tile('Desk lamp', 'DIV.s', url: 'https://www.amazon.co.uk/dp/B000000001')]),
        hasLength(1),
      );
    });

    test('advert links are dropped', () {
      final amazon = shopById('amazon-uk')!;
      expect(
        parseOffers(amazon, [
          tile('Desk lamp', 'DIV.s', url: 'https://www.amazon.co.uk/sspa/click?url=%2Fdp%2FB000000001'),
          tile('Desk lamp', 'DIV.s', url: 'https://aax-eu.amazon.co.uk/x/c/B000000001'),
        ]),
        isEmpty,
      );
    });

    test('check and sign-in pages are known by their address', () {
      for (final u in [
        'https://www.shein.co.uk/risk/challenge?captcha_type=909&redirection=x',
        'https://www.temu.com/bgn_verification.html?verifyCode=1',
        'https://www.temu.com/login.html?from=https%3A%2F%2Fwww.temu.com%2Fuk%2Fsearch_result.html',
        'https://www.aliexpress.com/punish?x5secdata=1',
        'https://shop.example/challenge',
      ]) {
        expect(isWallAddress(Uri.parse(u)), isTrue, reason: u);
      }
      for (final u in [
        'https://www.amazon.co.uk/s?k=lamp',
        'https://www.temu.com/uk/search_result.html?search_key=lamp',
        'https://shop.example/challenger-bike-p-1.html',
      ]) {
        expect(isWallAddress(Uri.parse(u)), isFalse, reason: u);
      }
    });

    test('Hacoo is not searched on the web', () {
      expect(shopById('hacoo')!.search, isNull);
      expect(shopById('hacoo')!.home, 'https://hacoo.app/');
      expect(shopFor(Uri.parse('https://www.hacoo.com/p/1')).id, 'hacoo');
    });
  });

  group('ranking', () {
    test('the user\'s search over what the shops listed: results, and sensible ones first', () {
      final all = walkingShoes().where((o) => !o.$2).map((o) => o.$1).toList();
      expect(all.length, greaterThan(60));
      final q = readQuery('walking shoes for all terrains, easy slip in', attributes: lex);
      final ranked = rankScored(q, all, attributes: lex);
      expect(ranked.length, greaterThan(40), reason: 'the old two-thirds rule kept none');
      // The first five are outdoor footwear that slips on, the next five
      // at least one of the two (the research's labels also mark loafers and
      // snow boots down, which words alone cannot tell apart), and none is a
      // sandal, clog or slipper.
      for (final (i, r) in ranked.take(10).indexed) {
        final t = r.offer.title.toLowerCase();
        final outdoor = RegExp(r'walk|hik|trail|trek|outdoor|rugged').hasMatch(t);
        final slip = RegExp(r'slip[- ]?on|slip[- ]?ins?\b|hands?[- ]free|elastic').hasMatch(t);
        expect(i < 5 ? outdoor && slip : outdoor || slip, isTrue, reason: t);
        expect(t, isNot(matches(RegExp(r'sandal|clog|slipper|chef|water shoe'))), reason: t);
      }
      // Twice the shop's own order on the research's labels (0.215).
      final top = ranked.take(10).map((r) => grade(r.offer.title)).toList();
      expect(ndcg(top, all.map((o) => grade(o.title)).toList()), greaterThan(0.4));
      expect(ranked.first.why, containsAll(['All-terrain', 'Slip-on']));
    });

    test('with meaning scores the same search still ranks sensibly', () {
      final all = walkingShoes().where((o) => !o.$2).map((o) => o.$1).toList();
      final q = readQuery('walking shoes for all terrains, easy slip in', attributes: lex);
      // A stand-in for the meaning model: closer when the title says more
      // of what was asked.
      final meaning = {for (final o in all) o.id: grade(o.title) / 2};
      final ranked = rankScored(q, all, attributes: lex, meaning: meaning);
      expect(ranked.take(5).every((r) => grade(r.offer.title) == 2), isTrue);
    });

    test('a short search needs all its words; a longer one ranks by how much matched', () {
      final q = readQuery('reading glasses');
      final r = rankOffers(q, [
        offer('Reading lamp', 300),
        offer('Glasses case', 200),
        offer('Reading glasses', 900),
      ]);
      expect(r.map((o) => o.title), ['Reading glasses']);
      final long = readQuery('blue light reading glasses for screens', attributes: lex);
      final ranked = rankScored(long, [
        offer('Reading glasses', 900),
        offer('Blue light glasses for computer screens', 700),
        offer('Desk lamp', 200),
      ], attributes: lex);
      expect(ranked.map((o) => o.offer.title), [
        'Blue light glasses for computer screens',
        'Reading glasses',
      ]);
      expect(ranked.first.why, contains('Blue light'));
    });

    test('rare words count more than common ones', () {
      final q = readQuery('trail running shoes');
      final ranked = rankOffers(q, [
        offer('Running shoes', 500),
        offer('Running shoes men', 400),
        offer('Trail running shoes', 900),
        offer('Shoes', 100),
        offer('Running shoes women', 450),
      ]);
      expect(ranked.first.title, 'Trail running shoes');
    });
  });
}

Offer offer(String title, int price, {String shop = 'amazon-uk'}) => Offer(
  shop: shop,
  url: 'https://www.amazon.co.uk/dp/${title.hashCode.abs().toString().padLeft(10, '0').substring(0, 10)}',
  title: title,
  price: price,
  currency: 'GBP',
);
