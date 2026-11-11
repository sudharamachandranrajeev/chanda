import 'dart:convert';
import 'dart:math';

import 'attributes.dart';
import 'links.dart';
import 'money.dart';
import 'query.dart';
import 'reading.dart' show similarity;
import 'shops.dart';

/// A product a shop's search page listed.
class Offer {
  const Offer({
    required this.shop,
    required this.url,
    required this.title,
    required this.price,
    required this.currency,
    this.image = '',
    this.was,
    this.rating,
    this.reviews,
    this.inStock = true,
    this.source = OfferSource.page,
  });

  final String shop;

  /// The product page, cleaned of tracking.
  final String url;
  final String title;
  final String image;

  /// Minor units of [currency].
  final int price;
  final String currency;
  final int? was;
  final double? rating;
  final int? reviews;
  final bool inStock;

  /// How Chanda read it. One read from the screen is shown but never kept
  /// or compared: its price is confirmed on the product page first.
  final OfferSource source;

  /// Shop and link: the same product listed twice on a page is one offer.
  String get id => '$shop|$url';
}

/// Where an offer came from: the shop's search page (its data or tiles),
/// the shop's own product search for apps, or text read off a screenshot.
enum OfferSource { page, api, screen }

/// A shop showed its "are you a person" check instead of results. Only the
/// user can answer it, in the in-app browser, which shares its cookies.
class ShopCheck implements Exception {
  const ShopCheck(this.shop);
  final String shop;

  @override
  String toString() => '$shop asked for a check';
}

/// Links that are adverts' tracking redirects, not product pages.
final _adLink = RegExp(
  r'sponsored-ads\.|/sspa/|[/.]aax-|/gp/slredirect|/aclk\b|doubleclick\.',
  caseSensitive: false,
);

/// Turns [offerScript]'s JSON into offers at [shop], reading each price
/// with the page's own currency marks ([Shop.currency] settles a bare "$").
/// Tiles without a link, a title or a price are dropped; so are adverts and
/// a second tile for the same link. Where the shop's product links are not
/// known, a tile read from the page's layout counts only when at least
/// three tiles look alike (the results list), so a stray price box is not
/// taken for a product; the page's own product data always counts.
List<Offer> parseOffers(Shop shop, Object? json, {OfferSource source = OfferSource.page}) {
  final raw = json is String ? jsonDecode(json) : json;
  if (raw is! List) return const [];
  final tiles = raw.whereType<Map>().toList();
  final alike = <String, int>{};
  for (final r in tiles) {
    if (r['src'] == 'dom') alike.update('${r['sig']}', (n) => n + 1, ifAbsent: () => 1);
  }
  final out = <String, Offer>{};
  for (final r in tiles) {
    if (shop.productKey == null && r['src'] == 'dom' && (alike['${r['sig']}'] ?? 0) < 3) continue;
    final title = withoutInvisible('${r['title'] ?? ''}').replaceAll(RegExp(r'\s+'), ' ').trim();
    final link = Uri.tryParse(withoutInvisible('${r['url'] ?? ''}').trim());
    final price = parsePrice('${r['price'] ?? ''}', hint: shop.currency);
    if (title.length < 3 || link == null || !link.hasScheme || price == null || price.minor <= 0) continue;
    if (_adLink.hasMatch('$link')) continue;
    // Where the shop's product pages are known, a link elsewhere (a bundle
    // or promotion page) is not a product: its price is not one.
    if (shop.productKey != null && shop.keyOf(link).isEmpty) continue;
    final was = parsePrice('${r['was'] ?? ''}', hint: price.currency);
    final offer = Offer(
      shop: shop.id,
      url: '${cleanLink(link)}',
      title: title,
      image: '${r['image'] ?? ''}',
      price: price.minor,
      currency: price.currency,
      was: was != null && was.currency == price.currency && was.minor > price.minor ? was.minor : null,
      rating: switch (r['rating']) {
        final num n when n > 0 && n <= 5 => n.toDouble(),
        _ => null,
      },
      reviews: switch (r['reviews']) {
        final num n when n >= 0 => n.toInt(),
        _ => null,
      },
      inStock: r['inStock'] != false,
      source: source,
    );
    out.putIfAbsent(offer.id, () => offer);
  }
  return [...out.values];
}

/// How well [title] matches the words of [q]: the share of them it holds.
double relevance(Query q, String title) => q.words.trim().isEmpty ? 1 : similarityOf(q.words, title);

/// The share of [query]'s words found in [title] (0-1).
double similarityOf(String query, String title) {
  final want = _words(query);
  if (want.isEmpty) return 0;
  final have = _words(title);
  return want.where((w) => have.any((h) => h == w || (w.length > 3 && h.startsWith(w)))).length / want.length;
}

Set<String> _words(String s) =>
    s.toLowerCase().split(RegExp(r'[^\p{L}\p{N}]+', unicode: true)).where((w) => w.length > 1).toSet();

/// An offer with how well it matched a search and why.
class RankedOffer {
  const RankedOffer(this.offer, this.score, this.why);
  final Offer offer;

  /// 0-1: the share of the search's attributes the title holds, and of its
  /// words (rarer words count more), and with Smarter search on, how close
  /// in meaning the title is.
  final double score;

  /// What matched, for "why this matched" on the card: attributes first
  /// ("Slip-on"), then the search's own words.
  final List<String> why;
}

/// The offers worth showing for [q], best match first, then cheapest.
///
/// Kept: offers within its budget (in its currency; offers in another
/// currency are kept and left to the compare view), at its shops, of its
/// colours and materials, that match something it asks for. A search of one
/// or two words with nothing else needs all of them ("reading glasses" is
/// not a reading lamp); a longer one needs only one word or attribute, and
/// ranks by how much matched: there is no share of words a title must hold,
/// because shops never write "for", "easy" or "terrains".
///
/// [meaning]: with Smarter search on, how close each offer's title is to the
/// search in meaning (by [Offer.id], cosine similarity).
List<RankedOffer> rankScored(
  Query q,
  Iterable<Offer> offers, {
  Map<String, double>? meaning,
  Lexicon? attributes,
}) {
  final lex = attributes ?? lexicon;
  final shopsWanted = q.of('shop').toSet();
  final lo = q.minPrice, hi = q.maxPrice;
  final kept = [
    for (final o in offers)
      if ((shopsWanted.isEmpty || shopsWanted.contains(o.shop)) &&
          (o.currency != q.currency || ((lo == null || o.price >= lo) && (hi == null || o.price <= hi))) &&
          fitsFacets(q, o.title))
        o,
  ];
  final terms = <String>{
    for (final w in wordsOf(q.words))
      if (!stopWords.contains(w) && w.length > 1) w,
  }.toList();
  final want = [for (final id in q.of('attribute')) ?lex.byId(id)];
  final titles = {for (final o in kept) o.id: wordsOf(o.title)};
  bool has(List<String> title, String t) => title.any((h) => h == t || (t.length > 3 && h.startsWith(t)));

  // Rarer words count more (BM25's idf, over the offers found), but a word
  // counts once however often the title repeats it: titles are short and
  // shops repeat words to be found.
  final n = kept.length;
  final idf = {
    for (final t in terms)
      t: () {
        final df = kept.where((o) => has(titles[o.id]!, t)).length;
        return log(1 + (n - df + 0.5) / (df + 0.5));
      }(),
  };
  final allIdf = idf.values.fold(0.0, (a, b) => a + b);
  final cosines = [for (final o in kept) ?meaning?[o.id]];
  final cLo = cosines.isEmpty ? 0.0 : cosines.reduce(min), cHi = cosines.isEmpty ? 0.0 : cosines.reduce(max);
  final shortSearch = want.isEmpty && terms.length <= 2;

  final out = <RankedOffer>[];
  for (final o in kept) {
    final title = titles[o.id]!;
    final matched = [
      for (final t in terms)
        if (has(title, t)) t,
    ];
    final attrs = [
      for (final a in want)
        if (a.inTitle(title)) a,
    ];
    if (terms.isNotEmpty || want.isNotEmpty) {
      if (shortSearch ? matched.length < terms.length : matched.isEmpty && attrs.isEmpty) continue;
    }
    var text = allIdf == 0 ? (terms.isEmpty ? 1.0 : 0.0) : matched.fold(0.0, (a, t) => a + idf[t]!) / allIdf;
    if (meaning?[o.id] case final c? when cHi > cLo) text = 0.5 * text + 0.5 * (c - cLo) / (cHi - cLo);
    final score = want.isEmpty ? text : 0.5 * attrs.length / want.length + 0.5 * text;
    out.add(
      RankedOffer(o, score, [
        for (final a in attrs) a.label,
        for (final w in q.words.split(' '))
          if (wordsOf(w).any(matched.contains)) w.toLowerCase(),
      ]),
    );
  }
  out.sort((a, b) {
    // Scores a hair apart are a tie, settled by price.
    final r = (b.score * 1000).round().compareTo((a.score * 1000).round());
    return r != 0 ? r : a.offer.price.compareTo(b.offer.price);
  });
  return out;
}

/// The offers worth showing for [q], best match first, then cheapest (see
/// [rankScored]).
List<Offer> rankOffers(Query q, Iterable<Offer> offers, {Map<String, double>? meaning}) => [
  for (final r in rankScored(q, offers, meaning: meaning)) r.offer,
];

/// Whether two titles likely name the same product, by their words alone.
bool titlesAlike(String a, String b) => similarity(a, b) >= 0.6;

/// Reads the products on any shop's search page. It trusts schema.org
/// Product data when the page has it, and otherwise finds product links
/// whose tile shows a price in any currency, as the page draws it. Prices
/// stay text; [parseOffers] reads them. It reads only; it never clicks.
/// Returns JSON text.
const offerScript = r'''
(() => {
  const out = [];
  const clip = (s, n) => (s || '').replace(/[\u200B-\u200F\u2060\uFEFF]/g, '').replace(/\s+/g, ' ').trim().slice(0, n);
  const priceRe = /^(?:(?:[£€$¥￥￡＄₹₩₺₽₫₱฿₪]|US\s?\$|[A-Z]{2}\$|R\$|[A-Z]{3}\s?)\s?\d[\d.,\s  ]*|\d[\d.,\s  ]*\s?(?:€|zł|Kč|kr|Ft|lei|円|元|[A-Z]{3}))$/;
  const ratingRe = /(\d(?:[.,]\d)?)\s*(?:out of\s*5|\/\s*5|stars?)/i;
  const noStockRe = /out of stock|sold out|currently unavailable|no longer available/i;
  const awayRe = /sponsor|carousel|recommend|also[-_ ]?(bought|viewed)|recently/i;
  // Adverts: tracking redirects and tiles labelled as sponsored.
  const adRe = /sponsored-ads\.|\/sspa\/|[/.]aax-|\/gp\/slredirect|\/aclk\b|doubleclick\./i;
  const adLabelRe = /^(sponsored|sponsored ad|ad|advert|advertisement|promoted)$/i;
  const abs = (u) => { try { return new URL(u, document.baseURI).href; } catch (e) { return ''; } };

  // schema.org Product entries.
  const walk = (n) => {
    if (!n || typeof n !== 'object') return;
    if (Array.isArray(n)) return n.forEach(walk);
    const types = [].concat(n['@type'] || []);
    if (types.includes('Product') && n.name) {
      const o = [].concat(n.offers || [])[0] || {};
      const p = o.price ?? o.lowPrice;
      const cur = o.priceCurrency || '';
      const r = n.aggregateRating || {};
      if (p != null) out.push({
        title: clip(n.name, 300), price: cur + ' ' + p, url: abs(n.url || o.url || ''),
        image: abs([].concat(n.image || [])[0] || ''), rating: parseFloat(r.ratingValue) || null,
        reviews: parseInt(r.reviewCount || r.ratingCount) || null,
        inStock: o.availability ? !/OutOfStock|SoldOut|Discontinued/i.test(o.availability) : true,
        src: 'ld',
      });
    }
    for (const k in n) walk(n[k]);
  };
  for (const s of document.querySelectorAll('script[type="application/ld+json"]')) {
    try { walk(JSON.parse(s.textContent)); } catch (e) {}
  }

  // The page's own data blobs (Next.js, Nuxt and the like): objects with a
  // name, a price and a link. Trusted only when at least three agree.
  const json = [];
  const dig = (n, depth) => {
    if (!n || typeof n !== 'object' || depth > 12 || json.length > 120) return;
    if (Array.isArray(n)) return n.forEach((m) => dig(m, depth + 1));
    const name = n.name || n.title || n.productName;
    const link = n.url || n.link || n.href || n.productUrl || n.canonicalUrl;
    const raw = n.price ?? n.salePrice ?? n.currentPrice ?? n.minPrice;
    const p = raw && typeof raw === 'object' ? (raw.value ?? raw.amount ?? raw.current) : raw;
    if (typeof name === 'string' && typeof link === 'string' && /^(\/|https?:)/.test(link) && (typeof p === 'number' || (typeof p === 'string' && /\d/.test(p))) && !n['@type']) {
      const img = n.image || n.imageUrl || n.thumbnail || '';
      json.push({
        title: clip(name, 300), price: (typeof p === 'number' ? (n.currency || n.priceCurrency || '') + ' ' : '') + p,
        url: abs(link), image: abs(typeof img === 'string' ? img : (img && (img.url || img.src)) || ''),
        rating: parseFloat(n.rating || n.averageRating) || null, reviews: parseInt(n.reviewCount || n.reviews) || null,
        inStock: n.inStock !== false && n.available !== false, src: 'json',
      });
    }
    for (const k in n) dig(n[k], depth + 1);
  };
  for (const s of document.querySelectorAll('script[type="application/json"], script#__NEXT_DATA__')) {
    try { dig(JSON.parse(s.textContent), 0); } catch (e) {}
  }
  if (json.length >= 3) out.push(...json);

  const struck = (el) => {
    for (let e = el, i = 0; e && i < 4; e = e.parentElement, i++) {
      if (/^(DEL|S|STRIKE)$/.test(e.tagName)) return true;
      if (getComputedStyle(e).textDecorationLine.includes('line-through')) return true;
      if (e.getAttribute('data-a-strike') === 'true') return true;
      const tag = typeof e.className === 'string' ? e.className : '';
      if (/strike|was-?price|old-?price|original-?price|list-?price|basisprice|rrp/i.test(tag)) return true;
    }
    return false;
  };
  // An element's text without words only screen readers get ("Current
  // price £79.99" is £79.99) and without a leading "Price:" or "Now".
  const srRe = /sr-only|visually-?hidden|screen-?reader|a11y|assistive|offscreen/i;
  const textOf = (el) => {
    let t = '';
    for (const n of el.childNodes) {
      if (n.nodeType === 3) t += n.textContent;
      else if (n.nodeType === 1 && !(typeof n.className === 'string' && srRe.test(n.className) && !priceRe.test(clip(n.textContent, 40)))) t += textOf(n);
    }
    return t;
  };
  const priceText = (el) => clip(textOf(el), 60).replace(/^(?:(?:current|sale|now|our|special|offer)\s+)?(?:price\s*:?\s*)?(?:now\s+)?/i, '');
  // Price texts in [tile]: the smallest elements whose whole text is a price.
  const pricesIn = (tile) => {
    const found = [];
    for (const el of tile.querySelectorAll('*')) {
      if (/^(SCRIPT|STYLE|NOSCRIPT|OPTION|SELECT)$/.test(el.tagName)) continue;
      const t = priceText(el);
      if (t.length < 2 || t.length > 40 || !priceRe.test(t)) continue;
      if ([...el.children].some((c) => priceRe.test(priceText(c)))) continue;
      if (getComputedStyle(el).display === 'none') continue;
      found.push({text: t, struck: struck(el)});
    }
    return found;
  };

  const tiles = new Set();
  for (const a of document.querySelectorAll('a[href]')) {
    if (a.closest('header, nav, footer')) continue;
    const href = abs(a.getAttribute('href'));
    if (!/^https?:/.test(href) || /\/(s|search|w|wholesale)[/?]|\/(cart|basket|account|help|signin)/i.test(new URL(href).pathname + '/')) continue;
    if (adRe.test(href)) continue;
    let el = a;
    for (let i = 0; i < 7 && el && el !== document.body; i++, el = el.parentElement) {
      const text = el.innerText || '';
      if (text.length > 1200) break;
      const prices = pricesIn(el);
      if (!prices.length) continue;
      // A tile already read, or the list around several: not a product.
      if ([...tiles].some((t) => el.contains(t) || t.contains(el))) break;
      tiles.add(el);
      let away = false;
      for (let e = el, j = 0; e && j < 6; e = e.parentElement, j++) {
        const tag = (e.id || '') + ' ' + (typeof e.className === 'string' ? e.className : '');
        if (awayRe.test(tag)) { away = true; break; }
      }
      if (away) break;
      // An advert among the results: its label, or every link a redirect.
      const labels = [...el.querySelectorAll('span, div, a, p')].filter((e) => !e.children.length).map((e) => clip(e.textContent, 30));
      if (labels.some((l) => adLabelRe.test(l)) || /^(sponsored|ad)\b/i.test(clip(el.innerText, 30))) break;
      // The tile's product link: the one around its picture or heading,
      // and repeated (picture and title both link to the product). Badge
      // and "Learn more" links are neither.
      // The tile may be the link itself.
      const all = [...(el.matches('a[href]') ? [el] : []), ...el.querySelectorAll('a[href]')]
        .filter((l) => /^https?:/.test(abs(l.getAttribute('href'))));
      const links = all.filter((l) => !adRe.test(abs(l.getAttribute('href'))));
      if (all.length && !links.length) break;
      const pathOf = (l) => new URL(abs(l.getAttribute('href'))).pathname;
      const heads = 'h2, h3, h4, [class*="title" i]';
      const score = (l) => links.filter((m) => pathOf(m) === pathOf(l)).length +
        (l.querySelector('img') ? 2 : 0) + (l.querySelector(heads) || l.closest(heads) ? 2 : 0) -
        (/^(learn more|sponsored|see more|details|more info)/i.test(clip(l.innerText, 40)) ? 5 : 0);
      const pick = links.sort((x, y) => score(y) - score(x))[0] || a;
      const same = links.filter((l) => pathOf(l) === pathOf(pick));
      const now = prices.find((p) => !p.struck) || prices[0];
      const was = prices.find((p) => p.struck && p !== now);
      const img = el.querySelector('img');
      const lines = text.split('\n').map((l) => l.trim()).filter((l) => l.length > 3 && !/\d[.,]\d\d\b|^[£€$￡]/.test(l));
      const label = pick.getAttribute('aria-label') || pick.getAttribute('title') || '';
      // Title: the heading, else the link's own words when they are only a
      // name, else the picture's description, else the longest line.
      const h = el.querySelector(heads);
      const linkText = same.map((l) => clip(l.innerText, 300)).sort((x, y) => y.length - x.length)[0] || '';
      const plain = linkText.length >= 6 && !/\d[.,]\d\d\b|[£€$￡]/.test(linkText) ? linkText : '';
      const title = [clip(h && h.innerText, 300), plain, clip(label, 300), clip(img && img.alt, 300), lines.sort((x, y) => y.length - x.length)[0] || '']
        .find((t) => t && t.length >= 6) || '';
      let rating = null, reviews = null;
      const ratingText = [...el.querySelectorAll('[aria-label], [title]')].map((e) => e.getAttribute('aria-label') || e.getAttribute('title')).join(' ') + ' ' + text;
      const rm = ratingText.match(ratingRe);
      if (rm) rating = parseFloat(rm[1].replace(',', '.'));
      const vm = ratingText.match(/\(?\s*([\d][\d,.]*)\s*(k)?\s*\)?\s*(?:ratings|reviews)\b/i) || text.match(/\(([\d][\d,.]*)(k)?\)/i);
      if (vm) reviews = Math.round(parseFloat(vm[1].replace(/,/g, '')) * (vm[2] ? 1000 : 1));
      out.push({
        title, price: now.text, was: was ? was.text : '', url: abs(pick.getAttribute('href')),
        image: img ? (img.currentSrc || img.src || '') : '', rating, reviews,
        inStock: !noStockRe.test(text),
        // Tiles of one results list share their tag and classes.
        src: 'dom', sig: el.tagName + '.' + [...el.classList].filter((c) => !/\d/.test(c)).sort().join('.'),
      });
      break;
    }
  }
  return JSON.stringify(out.slice(0, 60));
})()
''';
