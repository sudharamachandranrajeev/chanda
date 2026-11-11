import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_sentencepiece_tokenizer/dart_sentencepiece_tokenizer.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'embeddings.dart' show ModelFile;
import 'offers.dart';

// "Sharper ranking": an optional, downloaded model that reads the search and
// each title together and says how well they fit (a cross-encoder). It
// reorders the best matches after the attribute and word scoring. It runs on
// the device; nothing is sent anywhere after the download.
//
// Model: mxbai-rerank-xsmall-v1 (Apache-2.0) by Mixedbread, its int8 ONNX
// export, pinned to one revision and checked by SHA-256.

/// The local setting that turns sharper ranking on once downloaded.
const sharperRankingSetting = 'chanda.sharper_ranking';

const _repo =
    'https://huggingface.co/mixedbread-ai/mxbai-rerank-xsmall-v1/resolve/b5c6e9da73abc3711f593f705371cdbe9e0fe422';

const rerankFiles = [
  ModelFile(
    'model_quantized.onnx',
    87245802,
    '15ef19a6de90be7d52b627f2c784107bd806e64826450f41fb75fa4f0179ab30',
    repo: _repo,
    remote: 'onnx/model_quantized.onnx',
  ),
  ModelFile(
    'tokenizer.json',
    8649139,
    '305674b4d785287feecfb5f73f24aa75e9b57c87c579cfe24fbd207987d4b4c4',
    repo: _repo,
  ),
];

/// How many of the best matches are reordered: fewer on a phone, where the
/// model runs two to three times slower.
int get rerankTop => Platform.isAndroid || Platform.isIOS ? 30 : 60;

/// Scores how well each title fits the search: higher fits better.
abstract class Reranker {
  Future<List<double>> score(String query, List<String> titles);
}

/// The model's tokenizer settings ([json], from its tokenizer.json) without
/// the Strip step, which the tokenizer library cannot load. Strip trims
/// whitespace at both ends; [OnnxReranker] trims the text itself instead.
Map<String, dynamic> withoutStrip(Map<String, dynamic> json) {
  final normalizer = json['normalizer'];
  if (normalizer is! Map<String, dynamic>) return json;
  if (normalizer['type'] == 'Strip') return {...json, 'normalizer': null};
  if (normalizer['type'] != 'Sequence') return json;
  final steps = [
    for (final n in normalizer['normalizers'] as List)
      if (n is! Map || n['type'] != 'Strip') n,
  ];
  return {
    ...json,
    'normalizer': {...normalizer, 'normalizers': steps},
  };
}

/// The model's tokens for [query] and [title] read together:
/// `[CLS] query [SEP] title [SEP]`, cut to [maxTokens] by trimming the
/// longer of the two first (as the model's own tokenizer does).
List<int> pairIds(List<int> query, List<int> title, {int maxTokens = 128, int cls = 1, int sep = 2}) {
  var a = query.length, b = title.length;
  final room = maxTokens - 3;
  while (a + b > room) {
    if (a > b) {
      a--;
    } else {
      b--;
    }
  }
  return [cls, ...query.take(a), sep, ...title.take(b), sep];
}

/// The downloaded model, run with ONNX Runtime on the device.
class OnnxReranker implements Reranker {
  OnnxReranker._(this._session, this._tokenizer);

  final OrtSession _session;
  final SentencePieceTokenizer _tokenizer;

  /// Titles per run of the model. One: the int8 model quantizes each run's
  /// values with one shared scale, so titles batched together (and their
  /// padding) moved each other's scores. Against the reference, one per run
  /// kept the rank correlation at 0.99; sixteen dropped it to 0.97, for 30%
  /// less time.
  static const _batch = 1;

  static Future<OnnxReranker> load(Directory dir) async {
    final json = jsonDecode(await File('${dir.path}/tokenizer.json').readAsString()) as Map<String, dynamic>;
    final tokenizer = TokenizerJsonLoader.fromJsonString(jsonEncode(withoutStrip(json)));
    final session = await OnnxRuntime().createSession('${dir.path}/model_quantized.onnx');
    return OnnxReranker._(session, tokenizer);
  }

  Future<void> close() => _session.close();

  // The text is trimmed here, in place of the tokenizer's Strip step.
  List<int> _tokens(String text) => _tokenizer.encode(text.trim(), addSpecialTokens: false).ids.toList();

  /// The model's tokens for [query] and [title] together.
  List<int> idsFor(String query, String title) => pairIds(_tokens(query), _tokens(title));

  @override
  Future<List<double>> score(String query, List<String> titles) async {
    final q = _tokens(query);
    final out = <double>[];
    for (var at = 0; at < titles.length; at += _batch) {
      final ids = [for (final t in titles.skip(at).take(_batch)) pairIds(q, _tokens(t))];
      final seq = ids.map((e) => e.length).reduce(max);
      final input = Int64List(ids.length * seq);
      final mask = Int64List(ids.length * seq);
      for (var b = 0; b < ids.length; b++) {
        for (var t = 0; t < ids[b].length; t++) {
          input[b * seq + t] = ids[b][t];
          mask[b * seq + t] = 1;
        }
      }
      final shape = [ids.length, seq];
      final inputs = {
        'input_ids': await OrtValue.fromList(input, shape),
        'attention_mask': await OrtValue.fromList(mask, shape),
      };
      Map<String, OrtValue>? result;
      try {
        result = await _session.run(inputs);
        final logits = await result['logits']!.asFlattenedList();
        out.addAll([for (final v in logits) (v as num).toDouble()]);
      } finally {
        for (final v in inputs.values) {
          await v.dispose();
        }
        for (final v in result?.values ?? const <OrtValue>[]) {
          await v.dispose();
        }
      }
    }
    return out;
  }
}

/// [ranked] with its first [top] reordered by the model's [scores] (by
/// [Offer.id]); offers it has not scored yet keep their place after the
/// scored ones of the top, and everything past the top stays as it was.
/// Only offers the attribute and word scoring kept are ever reordered: the
/// model never brings back one they left out.
List<RankedOffer> rerank(List<RankedOffer> ranked, Map<String, double> scores, {int? top}) {
  final n = min(top ?? rerankTop, ranked.length);
  if (scores.isEmpty || n < 2) return ranked;
  final head = ranked.take(n).toList();
  final scored = [
    for (final r in head)
      if (scores.containsKey(r.offer.id)) r,
  ];
  final order = {for (var i = 0; i < head.length; i++) head[i].offer.id: i};
  scored.sort((a, b) {
    final c = scores[b.offer.id]!.compareTo(scores[a.offer.id]!);
    return c != 0 ? c : order[a.offer.id]!.compareTo(order[b.offer.id]!);
  });
  return [
    ...scored,
    for (final r in head)
      if (!scores.containsKey(r.offer.id)) r,
    ...ranked.skip(n),
  ];
}

/// What the reranker reads as the search: the short shop query (the thing
/// and its must-haves), which it ranks by better than the whole sentence.
String rerankQuery(String shopWords, String words) => shopWords.trim().isNotEmpty ? shopWords : words;
