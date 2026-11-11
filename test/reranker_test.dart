import 'package:chanda/app/providers.dart';
import 'package:chanda/domain/offers.dart';
import 'package:chanda/domain/reranker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_harness.dart';
import 'ranking_test.dart' show offer;

/// Scores titles by the words it is told to like, and counts what it read.
class FakeReranker implements Reranker {
  FakeReranker(this.likes);
  final List<String> likes;
  final read = <String>[];
  String? lastQuery;

  @override
  Future<List<double>> score(String query, List<String> titles) async {
    lastQuery = query;
    read.addAll(titles);
    return [for (final t in titles) likes.where((w) => t.toLowerCase().contains(w)).length.toDouble()];
  }
}

RankedOffer ranked(String title, double score) => RankedOffer(offer(title, 1000), score, const []);

void main() {
  group('pairIds', () {
    test('reads the search and the title together with the model\'s markers', () {
      expect(pairIds([10, 11], [20, 21, 22]), [1, 10, 11, 2, 20, 21, 22, 2]);
    });

    test('a long pair loses tokens from the longer side first, as the model\'s tokenizer does', () {
      final ids = pairIds(List.filled(10, 7), List.filled(200, 9));
      expect(ids.length, 128);
      expect(ids.where((i) => i == 7).length, 10, reason: 'the short search is kept whole');
      final even = pairIds(List.filled(100, 7), List.filled(100, 9));
      expect(even.length, 128);
      expect(even.where((i) => i == 7).length, 63);
      expect(even.where((i) => i == 9).length, 62);
    });
  });

  test('the tokenizer settings lose only their Strip step', () {
    final json = {
      'model': {'type': 'Unigram'},
      'normalizer': {
        'type': 'Sequence',
        'normalizers': [
          {'type': 'Strip', 'strip_left': true, 'strip_right': true},
          {'type': 'Precompiled', 'precompiled_charsmap': 'x'},
        ],
      },
    };
    expect(withoutStrip(json), {
      'model': {'type': 'Unigram'},
      'normalizer': {
        'type': 'Sequence',
        'normalizers': [
          {'type': 'Precompiled', 'precompiled_charsmap': 'x'},
        ],
      },
    });
    expect(
      withoutStrip({
        'normalizer': {'type': 'Strip'},
      })['normalizer'],
      isNull,
    );
    expect(withoutStrip({'normalizer': null}), {'normalizer': null});
  });

  group('rerank', () {
    final list = [ranked('a', 0.9), ranked('b', 0.8), ranked('c', 0.7), ranked('d', 0.6)];
    String order(List<RankedOffer> r) => r.map((e) => e.offer.title).join();

    test('reorders only the top by the model, and keeps the rest in place', () {
      final scores = {list[0].offer.id: 0.1, list[1].offer.id: 0.5, list[2].offer.id: 0.9};
      expect(order(rerank(list, scores, top: 3)), 'cbad');
    });

    test('offers not scored yet stay after the scored ones of the top', () {
      final scores = {list[1].offer.id: 0.5};
      expect(order(rerank(list, scores, top: 3)), 'bacd');
    });

    test('ties keep the attribute order; no scores change nothing', () {
      final scores = {for (final r in list) r.offer.id: 1.0};
      expect(order(rerank(list, scores, top: 4)), 'abcd');
      expect(order(rerank(list, const {}, top: 4)), 'abcd');
    });

    test('never brings back an offer the scoring left out', () {
      final scores = {list[3].offer.id: 5.0, offer('e', 1).id: 9.0};
      expect(order(rerank(list.take(3).toList(), scores, top: 10)), 'abc');
    });
  });

  test('the reranker reads the short shop query when there is one', () {
    expect(
      rerankQuery('slip on walking shoes', 'walking shoes for all terrains, easy slip in'),
      'slip on walking shoes',
    );
    expect(rerankQuery(' ', 'desk lamp'), 'desk lamp');
  });

  test('the download is pinned, checked and about 96 MB', () {
    expect(
      rerankFiles.every((f) => f.url.path.contains('/resolve/b5c6e9da73abc3711f593f705371cdbe9e0fe422/')),
      isTrue,
    );
    expect(rerankFiles.every((f) => f.sha256.length == 64), isTrue);
    expect((rerankFiles.fold<int>(0, (n, f) => n + f.size) / 1e6).round(), 96);
  });

  testWidgets('with sharper ranking on, the model reorders the shops\' best matches', (tester) async {
    final model = FakeReranker(['marble']);
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run(
      offers: {
        'amazon-uk': [offer('Brass desk lamp, LED', 2999), offer('Marble desk lamp', 8999)],
      },
      extra: [rerankerProvider.overrideWith((_) async => model)],
    );
    await app.go('Search');
    await tester.enterText(find.byType(TextField).first, 'desk lamp');
    await app.tap(find.widgetWithText(FilledButton, 'Search'));
    await app.settle();
    expect(model.read, containsAll(['Brass desk lamp, LED', 'Marble desk lamp']));
    expect(model.read.length, 2, reason: 'each offer is read once');
    final marble = tester.getTopLeft(find.text('Marble desk lamp'));
    final brass = tester.getTopLeft(find.text('Brass desk lamp, LED'));
    expect(
      marble.dy < brass.dy || (marble.dy == brass.dy && marble.dx < brass.dx),
      isTrue,
      reason: 'the model put the dearer lamp first',
    );
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('Settings offers Sharper ranking as a download, off by default', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run();
    await app.go('Settings');
    await tester.scrollUntilVisible(
      find.text('Sharper ranking'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await app.settle();
    expect(find.text('Sharper ranking'), findsOneWidget);
    expect(find.textContaining('96 MB download'), findsOneWidget);
    await app.close();
  });
}
