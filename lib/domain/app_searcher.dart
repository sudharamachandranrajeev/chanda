import 'ebay_api.dart';
import 'offers.dart';
import 'query.dart';
import 'shop_api.dart';
import 'shop_search.dart';
import 'shops.dart';

/// Searches every way Chanda has, best first: eBay with the user's own keys,
/// a shop's own product search (Shopify, WooCommerce) over plain HTTP, the
/// shop's search page in a hidden web view, and last the shop's live panel
/// with the user there. The first two need no web view at all.
class AppSearcher implements ShopSearcher {
  AppSearcher({required this.web, required this.apis, this.ebay});
  final WebShopSearcher web;
  final ShopApis apis;

  /// Set when the user added their own eBay keys in Settings.
  final EbayApi? ebay;

  @override
  Future<void> prepare(Iterable<Shop> shops) => apis.detect([
    for (final s in shops)
      // Shops whose pages Chanda reads by their own product links, and those
      // that wait for a person, are not asked: they are not on these platforms.
      if (s.productKey == null && !s.userPresent && !isEbay(s)) s,
  ]);

  @override
  SearchWay? wayFor(Shop shop) {
    if (isEbay(shop) && ebay != null) return SearchWay.api;
    if (apis.platformOf(shop) != null) return SearchWay.api;
    return web.wayFor(shop);
  }

  @override
  Future<List<Offer>> search(Shop shop, Query q) async {
    if (isEbay(shop) && ebay != null) return ebay!.search(q);
    if (apis.platformOf(shop) != null) {
      try {
        return await apis.search(shop, q);
      } on ShopBusy {
        rethrow;
      } on Object {
        // The shop's product search is off or changed: its page may still work.
        if (web.wayFor(shop) != SearchWay.hidden) rethrow;
      }
    }
    return web.search(shop, q);
  }
}
