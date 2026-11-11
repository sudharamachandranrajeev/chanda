import 'package:chanda/domain/attributes.dart';
import 'package:chanda/domain/offers.dart';
import 'package:chanda/domain/query.dart';
import 'package:chanda/domain/shop_search.dart';
import 'package:chanda/domain/shops.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Searches real shops in hidden web views on this device, as the app does,
// and prints how many products each listed and how many matched. It loads
// each shop's public search page like a browser and nothing more: no sign-in,
// no check is passed. Needs a network and a web view:
//   flutter test integration_test/search_live_test.dart -d linux \
//     --dart-define=QUERY="walking shoes for all terrains, easy slip in"
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const text = String.fromEnvironment('QUERY', defaultValue: 'walking shoes for all terrains, easy slip in');

  for (final id in ['amazon-uk', 'aliexpress']) {
    testWidgets('$id lists products for the search', (_) async {
      await loadLexicon();
      final q = readQuery(text);
      final watch = Stopwatch()..start();
      final offers = await WebShopSearcher().search(shopById(id)!, q);
      final ranked = rankScored(q, offers);
      // ignore: avoid_print
      print(
        'LIVE $id: "${q.shopWords()}" -> ${offers.length} tiles, ${ranked.length} match, '
        '${watch.elapsed.inSeconds}s\n${[for (final r in ranked.take(5)) '  ${r.offer.price} ${r.why} ${r.offer.title.length > 70 ? r.offer.title.substring(0, 70) : r.offer.title}'].join('\n')}',
      );
      expect(offers, isNotEmpty);
      expect(ranked, isNotEmpty);
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}
