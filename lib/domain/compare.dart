import 'money.dart';
import 'shops.dart';
import 'watch.dart' show Freshness, freshness;

/// One place to buy the product, as the compare view shows it.
class Deal {
  const Deal({
    required this.shop,
    required this.url,
    required this.title,
    required this.price,
    required this.currency,
    required this.seen,
    this.shipping,
    this.rating,
    this.reviews,
    this.seller = '',
    this.warranty = '',
    this.inStock = true,
    this.saved = false,
  });

  final Shop shop;
  final String url;
  final String title;
  final int price;
  final String currency;

  /// When the price was read (ISO 8601).
  final String? seen;
  final int? shipping;
  final double? rating;
  final int? reviews;
  final String seller;
  final String warranty;
  final bool inStock;

  /// The vault item itself, rather than an offer found for it.
  final bool saved;
}

/// A deal with its delivered cost worked out.
class Costed {
  const Costed(this.deal, this.landed);
  final Deal deal;

  /// Null when the price could not be converted (no exchange rate).
  final Landed? landed;
}

/// The best deal, and why, in plain words.
class Best {
  const Best(this.deal, this.reason);
  final Costed deal;
  final String reason;
}

/// Ratings under this, with enough reviews to mean it, rule a shop out.
const minRating = 4.0;
const _enoughReviews = 20;

/// The deals in order, cheapest delivered first (those with no total last),
/// and the best one: the cheapest delivered, in stock, from a seller rated
/// at least [minRating] or not rated (or rated by too few to tell). A price
/// over a day old still counts, but the reason says so.
(List<Costed>, Best?) compareDeals(
  Iterable<Deal> deals, {
  required String home,
  required FxRates? fx,
  DateTime? now,
}) {
  final costed = [
    for (final d in deals)
      Costed(
        d,
        landedCost(
          price: d.price,
          shipping: d.shipping,
          currency: d.currency,
          home: home,
          fromAbroad: d.shop.fromAbroad,
          fx: fx,
        ),
      ),
  ]..sort((a, b) => (a.landed?.total ?? 1 << 50).compareTo(b.landed?.total ?? 1 << 50));

  bool trusted(Deal d) => d.rating == null || d.rating! >= minRating || (d.reviews ?? 0) < _enoughReviews;
  final ok = costed.where((c) => c.landed != null && c.deal.inStock && trusted(c.deal)).toList();
  if (ok.isEmpty) return (costed, null);
  final best = ok.first;
  final why = <String>[];
  final rest = ok.skip(1).toList();
  if (rest.isEmpty) {
    why.add('the only one in stock from a well-rated seller');
  } else {
    final saving = rest.first.landed!.total - best.landed!.total;
    why.add(
      saving > 0
          ? '${showPrice(saving, home)} less delivered than the next'
          : 'the same delivered price as the next',
    );
  }
  final cheaper = costed.where((c) => c.landed != null && c.landed!.total < best.landed!.total).toList();
  if (cheaper.any((c) => !c.deal.inStock)) why.add('a cheaper one is out of stock');
  if (cheaper.any((c) => c.deal.inStock && !trusted(c.deal))) {
    why.add('a cheaper one is rated under ${minRating.toStringAsFixed(1)}');
  }
  if (best.deal.rating != null) {
    why.add(
      'rated ${best.deal.rating!.toStringAsFixed(1)}${best.deal.reviews == null ? '' : ' by ${best.deal.reviews}'}',
    );
  }
  if (best.deal.warranty.isNotEmpty) why.add('states its warranty or returns');
  if (best.landed!.estimate) why.add('the total is an estimate');
  if (freshness(best.deal.seen, now ?? DateTime.now().toUtc()) != Freshness.fresh) {
    why.add('its price is over a day old');
  }
  final text = why.join('; ');
  return (costed, Best(best, '${text[0].toUpperCase()}${text.substring(1)}.'));
}
