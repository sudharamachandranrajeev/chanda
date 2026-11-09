import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

import 'embeddings.dart';

// "Picture search": an optional, downloaded picture model that finds things
// that look alike, names what is in a photo (what it is, its colour, its
// pattern) and gives the taste model a sense of looks. It runs on the
// device; nothing is sent anywhere after the download.
//
// Model: Marqo-FashionSigLIP (Apache-2.0), its picture half only, int8 ONNX,
// pinned to one revision and checked by SHA-256. Its text half is not
// needed on the device: the vectors of a fixed list of labels are made once
// by tool/picture_labels.py and shipped in assets/pictures/.

/// The local setting that turns picture search on once downloaded.
const pictureSetting = 'chanda.pictures';

const _repo =
    'https://huggingface.co/Marqo/marqo-fashionSigLIP/resolve/c56244cc94f92419e8369fa71efdaf403b124ce8';

const pictureFiles = [
  ModelFile(
    'vision_model_int8.onnx',
    93973410,
    'dae6e934667af50590c3d0ca69c7b14edc71f4df1b4f670e5ba6bc623495b691',
    repo: _repo,
    remote: 'onnx/vision_model_int8.onnx',
  ),
];

/// The model's input for a picture: squashed to 224×224 (bicubic), RGB,
/// scaled to −1…1, channels first. Null when [bytes] is not a picture.
Float32List? pictureInput(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final rgb = decoded.convert(numChannels: 3, format: img.Format.uint8);
  final small = rgb.width == 224 && rgb.height == 224
      ? rgb
      : img.copyResize(rgb, width: 224, height: 224, interpolation: img.Interpolation.cubic);
  final px = small.getBytes(order: img.ChannelOrder.rgb);
  const plane = 224 * 224;
  final out = Float32List(3 * plane);
  for (var i = 0; i < plane; i++) {
    for (var c = 0; c < 3; c++) {
      out[c * plane + i] = px[i * 3 + c] / 127.5 - 1;
    }
  }
  return out;
}

/// Turns pictures into unit vectors that are close when they look alike.
abstract class PictureEmbedder {
  /// One vector per picture, null for one that could not be read.
  Future<List<Float32List?>> embed(List<Uint8List> pictures);
}

/// The downloaded model, run with ONNX Runtime on the device.
class OnnxPictureEmbedder implements PictureEmbedder {
  OnnxPictureEmbedder._(this._session);
  final OrtSession _session;

  static Future<OnnxPictureEmbedder> load(Directory dir) async =>
      OnnxPictureEmbedder._(await OnnxRuntime().createSession('${dir.path}/${pictureFiles.single.name}'));

  Future<void> close() => _session.close();

  @override
  Future<List<Float32List?>> embed(List<Uint8List> pictures) async {
    final inputs = await Isolate.run(() => [for (final p in pictures) pictureInput(p)]);
    final good = [
      for (var i = 0; i < inputs.length; i++)
        if (inputs[i] != null) i,
    ];
    final out = List<Float32List?>.filled(pictures.length, null);
    for (var at = 0; at < good.length; at += 8) {
      final part = good.sublist(at, min(at + 8, good.length));
      final data = Float32List(part.length * 3 * 224 * 224);
      for (var k = 0; k < part.length; k++) {
        data.setAll(k * 3 * 224 * 224, inputs[part[k]]!);
      }
      final input = await OrtValue.fromList(data, [part.length, 3, 224, 224]);
      Map<String, OrtValue>? res;
      try {
        res = await _session.run({'pixel_values': input});
        final flat = await res['image_embeds']!.asFlattenedList();
        final dim = flat.length ~/ part.length;
        for (var k = 0; k < part.length; k++) {
          out[part[k]] = unit([for (var d = 0; d < dim; d++) (flat[k * dim + d] as num).toDouble()]);
        }
      } finally {
        await input.dispose();
        for (final v in res?.values ?? const <OrtValue>[]) {
          await v.dispose();
        }
      }
    }
    return out;
  }
}

/// [v] scaled to length 1.
Float32List unit(List<double> v) {
  final out = Float32List.fromList(v);
  var n = 0.0;
  for (final x in out) {
    n += x * x;
  }
  n = sqrt(n);
  if (n > 0) {
    for (var i = 0; i < out.length; i++) {
      out[i] /= n;
    }
  }
  return out;
}

/// A label the picture model can put on a photo.
class PictureLabel {
  const PictureLabel(this.kind, this.name, this.vec);

  /// category | colour | pattern
  final String kind;
  final String name;
  final Float32List vec;
}

/// What a photo shows, as far as the labels go.
class PictureTags {
  const PictureTags({required this.category, this.colour, this.pattern});
  final String category;
  final String? colour;
  final String? pattern;

  /// Words for a shop's search box: "black dress", "striped shirt".
  String get words => [?colour, ?pattern, category].join(' ');
}

/// The shipped labels (assets/pictures/labels.*).
Future<List<PictureLabel>> loadLabels() async {
  final meta = jsonDecode(await rootBundle.loadString('assets/pictures/labels.json', cache: false)) as Map;
  final bin = await rootBundle.load('assets/pictures/labels.bin');
  return labelsFrom(meta, bin);
}

List<PictureLabel> labelsFrom(Map meta, ByteData bin) {
  final dims = meta['dims'] as int;
  final labels = meta['labels'] as List;
  return [
    for (var i = 0; i < labels.length; i++)
      PictureLabel(
        '${(labels[i] as Map)['kind']}',
        '${(labels[i] as Map)['name']}',
        Float32List.fromList([
          for (var d = 0; d < dims; d++) halfToDouble(bin.getUint16((i * dims + d) * 2, Endian.little)),
        ]),
      ),
  ];
}

/// An IEEE 754 half-precision number as a double.
double halfToDouble(int h) {
  final sign = (h & 0x8000) != 0 ? -1.0 : 1.0;
  final exp = (h >> 10) & 0x1f;
  final frac = h & 0x3ff;
  if (exp == 0) return sign * frac * pow(2, -24);
  if (exp == 31) return frac == 0 ? sign * double.infinity : double.nan;
  return sign * (1 + frac / 1024) * pow(2, exp - 15);
}

/// The best label of each kind for picture vector [v]. A colour is named
/// unless the best is "multicolour"; a pattern only when it clearly beats
/// the next and is not "plain" (the model is unsure of patterns).
PictureTags pictureTags(Float32List v, List<PictureLabel> labels) {
  List<(double, String)> ranked(String kind) => [
    for (final l in labels)
      if (l.kind == kind) (cosine(v, l.vec), l.name),
  ]..sort((a, b) => b.$1.compareTo(a.$1));
  final colours = ranked('colour');
  final patterns = ranked('pattern');
  final colour = colours.firstOrNull?.$2;
  final pattern = patterns.length > 1 && patterns[0].$1 - patterns[1].$1 >= 0.01 && patterns[0].$2 != 'plain'
      ? patterns[0].$2
      : null;
  return PictureTags(
    category: ranked('category').firstOrNull?.$2 ?? '',
    colour: colour == 'multicolour' ? null : colour,
    pattern: pattern,
  );
}
