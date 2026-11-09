import 'dart:convert';

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

  /// Shop and link: the same product listed twice on a page is one offer.
  String get id => '$shop|$url';
}

/// A shop showed its "are you a person" check instead of results. Only the
/// user can answer it, in the in-app browser, which shares its cookies.
class ShopCheck implements Exception {
  const ShopCheck(this.shop);
  final String shop;

  @override
  String toString() => '$shop asked for a check';
}

/// Turns [offerScript]'s JSON into offers at [shop], reading each price
/// with the page's own currency marks ([Shop.currency] settles a bare "$").
/// Tiles without a link, a title or a price are dropped; so is a second
/// tile for the same link.
List<Offer> parseOffers(Shop shop, Object? json) {
  final raw = json is String ? jsonDecode(json) : json;
  if (raw is! List) return const [];
  final out = <String, Offer>{};
  for (final r in raw) {
    if (r is! Map) continue;
    final title = '${r['title'] ?? ''}'.replaceAll(RegExp(r'\s+'), ' ').trim();
    final link = Uri.tryParse('${r['url'] ?? ''}');
    final price = parsePrice('${r['price'] ?? ''}', hint: shop.currency);
    if (title.length < 3 || link == null || !link.hasScheme || price == null || price.minor <= 0) continue;
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

/// How much of [q] a title must hold to be shown: all of a one- or
/// two-word search ("reading glasses" is not a reading lamp), at least two
/// thirds of a longer one.
double _enough(Query q) => q.words.split(' ').where((w) => w.length > 1).length <= 2 ? 1 : 0.66;

/// The offers worth showing for [q]: enough of its words, within its
/// budget (in its currency; offers in another currency are kept and left to
/// the compare view), at its shops, of its colours and materials. Best match
/// first, then cheapest.
List<Offer> rankOffers(Query q, Iterable<Offer> offers) {
  final shopsWanted = q.of('shop').toSet();
  final lo = q.minPrice, hi = q.maxPrice;
  final scored = [
    for (final o in offers)
      if (relevance(q, o.title) >= _enough(q) &&
          (shopsWanted.isEmpty || shopsWanted.contains(o.shop)) &&
          (o.currency != q.currency || ((lo == null || o.price >= lo) && (hi == null || o.price <= hi))) &&
          fitsFacets(q, o.title))
        (o, relevance(q, o.title)),
  ];
  scored.sort((a, b) {
    final r = b.$2.compareTo(a.$2);
    return r != 0 ? r : a.$1.price.compareTo(b.$1.price);
  });
  return [for (final s in scored) s.$1];
}

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
  const clip = (s, n) => (s || '').replace(/\s+/g, ' ').trim().slice(0, n);
  const priceRe = /^(?:(?:[£€$¥￥￡＄₹₩₺₽₫₱฿₪]|US\s?\$|[A-Z]{2}\$|R\$|[A-Z]{3}\s?)\s?\d[\d.,\s  ]*|\d[\d.,\s  ]*\s?(?:€|zł|Kč|kr|Ft|lei|円|元|[A-Z]{3}))$/;
  const ratingRe = /(\d(?:[.,]\d)?)\s*(?:out of\s*5|\/\s*5|stars?)/i;
  const noStockRe = /out of stock|sold out|currently unavailable|no longer available/i;
  const awayRe = /sponsor|carousel|recommend|also[-_ ]?(bought|viewed)|recently/i;
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
      });
    }
    for (const k in n) walk(n[k]);
  };
  for (const s of document.querySelectorAll('script[type="application/ld+json"]')) {
    try { walk(JSON.parse(s.textContent)); } catch (e) {}
  }

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
  // Price texts in [tile]: the smallest elements whose whole text is a price.
  const pricesIn = (tile) => {
    const found = [];
    for (const el of tile.querySelectorAll('*')) {
      if (/^(SCRIPT|STYLE|NOSCRIPT|OPTION|SELECT)$/.test(el.tagName)) continue;
      const t = clip(el.textContent, 40);
      if (t.length < 2 || !priceRe.test(t)) continue;
      if ([...el.children].some((c) => priceRe.test(clip(c.textContent, 40)))) continue;
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
      // The tile's product link: the one around its picture or heading,
      // and repeated (picture and title both link to the product). Badge
      // and "Learn more" links are neither.
      const links = [...el.querySelectorAll('a[href]')].filter((l) => /^https?:/.test(abs(l.getAttribute('href'))));
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
      });
      break;
    }
  }
  return JSON.stringify(out.slice(0, 60));
})()
''';
