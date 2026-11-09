import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dart_sentencepiece_tokenizer/dart_sentencepiece_tokenizer.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:http/http.dart' as http;

// "Smarter search": an optional, downloaded sentence-embedding model that
// finds items by meaning ("specs" finds "reading glasses", and across
// languages), fused with the word search. It runs on the device; nothing
// is sent anywhere after the download.
//
// Model: paraphrase-multilingual-MiniLM-L12-v2 (Apache-2.0), quantised ONNX
// export by Qdrant, pinned to one revision and checked by SHA-256.

/// The local setting that turns smarter search on once downloaded.
const smartSearchSetting = 'chanda.smart_search';

const _repo =
    'https://huggingface.co/Qdrant/paraphrase-multilingual-MiniLM-L12-v2-onnx-Q/resolve/'
    'faf4aa4225822f3bc6376869cb1164e8e3feedd0';

class ModelFile {
  const ModelFile(this.name, this.size, this.sha256);
  final String name;
  final int size;
  final String sha256;
  Uri get url => Uri.parse('$_repo/$name');
}

const modelFiles = [
  ModelFile(
    'model_optimized.onnx',
    235052644,
    '634d0f66c29dc934c8fa72b8a4fe91dd4d420a22f1d82a241058d4316e659a99',
  ),
  ModelFile('tokenizer.json', 17083009, 'fa685fc160bbdbab64058d4fc91b60e62d207e8dc60b9af5c002c5ab946ded00'),
];

final modelBytes = modelFiles.fold<int>(0, (n, f) => n + f.size);

/// Every model file is in [dir] at its full size.
bool modelPresent(Directory dir) => modelFiles.every((f) {
  final file = File('${dir.path}/${f.name}');
  return file.existsSync() && file.lengthSync() == f.size;
});

/// Downloads the model into [dir], checking each file's SHA-256 before it
/// is kept. [progress] gets bytes done of [modelBytes]. A file already
/// there at its size is kept.
Future<void> downloadModel(
  Directory dir, {
  void Function(int done)? progress,
  http.Client? client,
  List<ModelFile> files = modelFiles,
}) async {
  await dir.create(recursive: true);
  final c = client ?? http.Client();
  var before = 0;
  try {
    for (final f in files) {
      final target = File('${dir.path}/${f.name}');
      if (target.existsSync() && target.lengthSync() == f.size) {
        before += f.size;
        progress?.call(before);
        continue;
      }
      final part = File('${target.path}.part');
      final res = await c.send(http.Request('GET', f.url));
      if (res.statusCode != 200) throw HttpException('Download failed (${res.statusCode})', uri: f.url);
      final sink = part.openWrite();
      final hashSink = _DigestSink();
      final hasher = sha256.startChunkedConversion(hashSink);
      var got = 0;
      try {
        await for (final chunk in res.stream) {
          sink.add(chunk);
          hasher.add(chunk);
          got += chunk.length;
          progress?.call(before + got);
        }
      } finally {
        await sink.close();
        hasher.close();
      }
      if (got != f.size || '${hashSink.value}' != f.sha256) {
        await part.delete();
        throw const FormatException('The downloaded model did not match its checksum. Try again.');
      }
      await part.rename(target.path);
      before += f.size;
    }
  } finally {
    if (client == null) c.close();
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

/// Turns texts into unit vectors that are close when the meanings are.
abstract class Embedder {
  Future<List<Float32List>> embed(List<String> texts);
}

/// The downloaded model, run with ONNX Runtime on the device.
class OnnxEmbedder implements Embedder {
  OnnxEmbedder._(this._session, this._tokenizer);

  final OrtSession _session;
  final SentencePieceTokenizer _tokenizer;

  static const _maxTokens = 128;

  static Future<OnnxEmbedder> load(Directory dir) async {
    final tokenizer = await TokenizerJsonLoader.fromJsonFile('${dir.path}/tokenizer.json');
    final session = await OnnxRuntime().createSession('${dir.path}/model_optimized.onnx');
    return OnnxEmbedder._(session, tokenizer);
  }

  Future<void> close() => _session.close();

  @override
  Future<List<Float32List>> embed(List<String> texts) async {
    if (texts.isEmpty) return const [];
    final ids = [
      for (final t in texts)
        () {
          final e = _tokenizer.encode(t).ids;
          // Keep the end-of-sequence token when cutting a long text.
          return e.length <= _maxTokens ? e.toList() : [...e.take(_maxTokens - 1), e.last];
        }(),
    ];
    final seq = ids.map((e) => e.length).reduce(max);
    final input = Int64List(texts.length * seq);
    final mask = Int64List(texts.length * seq);
    for (var b = 0; b < ids.length; b++) {
      for (var t = 0; t < ids[b].length; t++) {
        input[b * seq + t] = ids[b][t];
        mask[b * seq + t] = 1;
      }
    }
    final shape = [texts.length, seq];
    final inputs = {
      'input_ids': await OrtValue.fromList(input, shape),
      'attention_mask': await OrtValue.fromList(mask, shape),
      'token_type_ids': await OrtValue.fromList(Int64List(texts.length * seq), shape),
    };
    Map<String, OrtValue>? out;
    try {
      out = await _session.run(inputs);
      final hidden = await out['last_hidden_state']!.asFlattenedList();
      return meanPool(hidden, mask, batch: texts.length, seq: seq);
    } finally {
      for (final v in inputs.values) {
        await v.dispose();
      }
      for (final v in out?.values ?? const <OrtValue>[]) {
        await v.dispose();
      }
    }
  }
}

/// Averages each text's token vectors over its real tokens and scales the
/// result to length 1 (the model's sentence embedding).
List<Float32List> meanPool(List<dynamic> hidden, List<int> mask, {required int batch, required int seq}) {
  final dim = hidden.length ~/ (batch * seq);
  return [
    for (var b = 0; b < batch; b++)
      () {
        final v = Float32List(dim);
        var n = 0;
        for (var t = 0; t < seq; t++) {
          if (mask[b * seq + t] == 0) continue;
          n++;
          final at = (b * seq + t) * dim;
          for (var d = 0; d < dim; d++) {
            v[d] += (hidden[at + d] as num).toDouble();
          }
        }
        var norm = 0.0;
        for (var d = 0; d < dim; d++) {
          v[d] /= max(n, 1);
          norm += v[d] * v[d];
        }
        norm = sqrt(norm);
        if (norm > 0) {
          for (var d = 0; d < dim; d++) {
            v[d] /= norm;
          }
        }
        return v;
      }(),
  ];
}

/// Cosine similarity of two unit vectors.
double cosine(Float32List a, Float32List b) {
  var s = 0.0;
  for (var i = 0; i < a.length && i < b.length; i++) {
    s += a[i] * b[i];
  }
  return s;
}

Uint8List vectorBytes(Float32List v) => v.buffer.asUint8List(v.offsetInBytes, v.lengthInBytes);

Float32List vectorOf(Uint8List bytes) =>
    Float32List.fromList(Float32List.view(Uint8List.fromList(bytes).buffer, 0, bytes.length ~/ 4));

/// Reciprocal rank fusion: one ranking from several, each key scoring
/// 1 / (k + rank) in every list it is in.
List<T> fuseRankings<T>(List<List<T>> rankings, {int k = 60}) {
  final score = <T, double>{};
  for (final list in rankings) {
    for (var i = 0; i < list.length; i++) {
      score[list[i]] = (score[list[i]] ?? 0) + 1 / (k + i + 1);
    }
  }
  return score.keys.toList()..sort((a, b) => score[b]!.compareTo(score[a]!));
}

/// The keys close enough in meaning, closest first: at least 0.35 and
/// within 0.25 of the closest (the model's scores run high for anything in
/// the same field, so a fixed cut alone lets in neighbours).
List<T> nearest<T>(Map<T, double> scores, {int limit = 50}) {
  if (scores.isEmpty) return const [];
  final best = scores.values.reduce(max);
  final keep = scores.entries.where((e) => e.value >= 0.35 && e.value >= best - 0.25).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [for (final e in keep.take(limit)) e.key];
}
