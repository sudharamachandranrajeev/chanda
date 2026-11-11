import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:chanda/domain/reranker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Sharper ranking on the device against the reference: the model's own
// tokenizer and ONNX Runtime in Python, one pair per run. Needs the model's
// files and the reference made from them:
//   flutter test integration_test/reranker_parity_test.dart -d linux \
//     --dart-define=MODEL_DIR=/path/to/model --dart-define=REF=/path/to/ref.json
// MODEL_DIR holds model_quantized.onnx and tokenizer.json. REF has the
// titles, a 0/1 label per title, and per query the reference's token ids and
// score for each title.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const modelDir = String.fromEnvironment('MODEL_DIR');
  const refPath = String.fromEnvironment('REF');

  // ignore: avoid_print
  void log(String s) => print('PARITY $s');

  test('matches the reference tokens and scores', () async {
    final ref = jsonDecode(File(refPath).readAsStringSync()) as Map<String, dynamic>;
    final titles = (ref['titles'] as List).cast<String>();
    final labels = (ref['labels'] as List).cast<int>();
    final model = await OnnxReranker.load(Directory(modelDir));
    try {
      for (final MapEntry(key: query, value: v as Map<String, dynamic>)
          in (ref['queries'] as Map<String, dynamic>).entries) {
        final ids = (v['ids'] as List).map((e) => (e as List).cast<int>()).toList();
        final want = (v['scores'] as List).cast<num>().map((e) => e.toDouble()).toList();
        for (var i = 0; i < titles.length; i++) {
          expect(model.idsFor(query, titles[i]), ids[i], reason: 'tokens of "${titles[i]}"');
        }
        final watch = Stopwatch()..start();
        final got = await model.score(query, titles);
        final all = watch.elapsedMilliseconds;
        watch.reset();
        await model.score(query, titles.take(30).toList());
        final top30 = watch.elapsedMilliseconds;
        var worst = 0.0, sum = 0.0;
        for (var i = 0; i < titles.length; i++) {
          final d = (got[i] - want[i]).abs();
          worst = max(worst, d);
          sum += d;
        }
        final mean = sum / titles.length;
        final rho = spearman(got, want);
        final (device, reference) = (ndcg(got, labels), ndcg(want, labels));
        log(
          '"$query": ${titles.length} titles in $all ms, 30 in $top30 ms; '
          'score difference mean ${mean.toStringAsFixed(3)}, largest ${worst.toStringAsFixed(3)}; '
          'rank correlation ${rho.toStringAsFixed(3)}; '
          'NDCG@10 device ${device.toStringAsFixed(3)}, reference ${reference.toStringAsFixed(3)}',
        );
        // The int8 model's scores move by up to about 0.25 with the runtime's
        // version and kernel fusion alone (seen in the reference runtime by
        // turning fusion off), so the bar is the order, not exact scores.
        expect(mean, lessThan(0.1));
        expect(rho, greaterThan(0.95));
        expect(device, closeTo(reference, 0.05));
      }
    } finally {
      await model.close();
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}

/// Spearman's rank correlation of [a] and [b] (no ties expected).
double spearman(List<double> a, List<double> b) {
  List<int> ranks(List<double> x) {
    final order = List.generate(x.length, (i) => i)..sort((i, j) => x[i].compareTo(x[j]));
    final r = List.filled(x.length, 0);
    for (var i = 0; i < order.length; i++) {
      r[order[i]] = i;
    }
    return r;
  }

  final (ra, rb, n) = (ranks(a), ranks(b), a.length);
  var d2 = 0;
  for (var i = 0; i < n; i++) {
    d2 += (ra[i] - rb[i]) * (ra[i] - rb[i]);
  }
  return 1 - 6 * d2 / (n * (n * n - 1));
}

/// NDCG@[k] of the order [scores] give, with 0/1 [labels].
double ndcg(List<double> scores, List<int> labels, {int k = 10}) {
  double dcg(Iterable<int> gains) {
    var s = 0.0, i = 0;
    for (final g in gains.take(k)) {
      s += g / (log(i + 2) / ln2);
      i++;
    }
    return s;
  }

  final order = List.generate(scores.length, (i) => i)..sort((a, b) => scores[b].compareTo(scores[a]));
  final ideal = dcg([...labels]..sort((a, b) => b.compareTo(a)));
  return ideal == 0 ? 0 : dcg(order.map((i) => labels[i])) / ideal;
}
