import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:brahma_core/brahma_core.dart' show currencyInfo;
import 'package:http/http.dart' as http;

import 'offers.dart';
import 'query.dart';
import 'shop_api.dart' show ShopBusy, apiAgent, retryAfter;
import 'shops.dart';

/// Where the user's own eBay keys are kept in the vault's local settings:
/// on this device only, never synced (like the AI and cloud keys).
const ebayIdSetting = 'chanda.api.ebay.id';
const ebaySecretSetting = 'chanda.api.ebay.secret';

/// The shop eBay's offers belong to (the seed list's eBay UK).
const ebayShopId = 'ebay.co.uk';

/// eBay's Browse API with the user's own application keys (their own
/// developer account, their own call allowance). Chanda sends no affiliate
/// header and no end-user context: the results are plain listings, and
/// opening one goes to its ordinary eBay page.
class EbayApi {
  EbayApi({required this.id, required this.secret, required http.Client client, DateTime Function()? clock})
    : _http = client,
      _now = clock ?? DateTime.now;

  final String id;
  final String secret;
  final http.Client _http;
  final DateTime Function() _now;

  static final tokenUrl = Uri.parse('https://api.ebay.com/identity/v1/oauth2/token');
  static const scope = 'https://api.ebay.com/oauth/api_scope';
  static final searchUrl = Uri.parse('https://api.ebay.com/buy/browse/v1/item_summary/search');

  String? _token;
  DateTime _expires = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _blockedUntil;

  /// A token for the application (client-credentials grant), kept until it
  /// is nearly over.
  Future<String> _bearer() async {
    if (_token != null && _now().isBefore(_expires)) return _token!;
    final r = await _http
        .post(
          tokenUrl,
          headers: {
            'authorization': 'Basic ${base64.encode(utf8.encode('$id:$secret'))}',
            'content-type': 'application/x-www-form-urlencoded',
            'user-agent': apiAgent,
          },
          body: 'grant_type=client_credentials&scope=${Uri.encodeQueryComponent(scope)}',
        )
        .timeout(const Duration(seconds: 20));
    if (r.statusCode == 401 || r.statusCode == 400) {
      throw StateError('eBay did not accept the keys. Check them in Settings.');
    }
    if (r.statusCode != 200) throw StateError('eBay: HTTP ${r.statusCode}');
    final j = jsonDecode(r.body) as Map;
    _token = '${j['access_token']}';
    _expires = _now().add(Duration(seconds: ((j['expires_in'] as num?) ?? 7200).toInt() - 120));
    return _token!;
  }

  /// Items listed for [q] at eBay UK, as offers. Throws [ShopBusy] when
  /// eBay asks for a pause (429 or 503 with Retry-After).
  Future<List<Offer>> search(Query q, {int limit = 50}) async {
    final blocked = _blockedUntil;
    if (blocked != null && _now().isBefore(blocked)) throw ShopBusy('eBay', blocked);
    final words = q.shopWords();
    if (words.isEmpty) return const [];
    final r = await _http
        .get(
          searchUrl.replace(queryParameters: {'q': words, 'limit': '$limit'}),
          headers: {
            'authorization': 'Bearer ${await _bearer()}',
            'x-ebay-c-marketplace-id': 'EBAY_GB',
            'user-agent': apiAgent,
            'accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (r.statusCode == 429 || r.statusCode == 503) {
      final until = _now().add(retryAfter(r.headers['retry-after'], _now()) ?? const Duration(minutes: 1));
      _blockedUntil = until;
      throw ShopBusy('eBay', until);
    }
    if (r.statusCode == 401) {
      _token = null;
      throw StateError('eBay did not accept the keys. Check them in Settings.');
    }
    if (r.statusCode != 200) throw StateError('eBay: HTTP ${r.statusCode}');
    return ebayOffers(r.body);
  }
}

/// Offers from a Browse API `item_summary/search` reply. Price is in the
/// listing's own currency; the link is the plain item page.
List<Offer> ebayOffers(String body) {
  final Object? j;
  try {
    j = jsonDecode(body);
  } on FormatException {
    return const [];
  }
  final items = j is Map ? j['itemSummaries'] : null;
  final out = <Offer>[];
  for (final i in items is List ? items : const []) {
    if (i is! Map || i['price'] is! Map) continue;
    final price = i['price'] as Map;
    final value = double.tryParse('${price['value'] ?? ''}');
    final code = '${price['currency'] ?? ''}'.toUpperCase();
    final title = '${i['title'] ?? ''}'.trim();
    final key = RegExp(r'(\d{9,})').firstMatch('${i['legacyItemId'] ?? ''}${i['itemId'] ?? ''}')?[1];
    if (value == null || value <= 0 || code.isEmpty || title.length < 3 || key == null) continue;
    final image = i['image'] is Map ? '${(i['image'] as Map)['imageUrl'] ?? ''}' : '';
    out.add(
      Offer(
        shop: ebayShopId,
        url: 'https://www.ebay.co.uk/itm/$key',
        title: title,
        image: image,
        price: (value * pow(10, currencyInfo(code).scale)).round(),
        currency: code,
        source: OfferSource.api,
      ),
    );
  }
  return out;
}

/// Whether [shop] is the eBay the user's keys search.
bool isEbay(Shop shop) => shop.id == ebayShopId;
