import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'screen_text.dart';

// Built-in text recognition for Windows and Linux: PP-OCRv5 mobile text
// detection and Latin-script recognition (Apache-2.0, PaddlePaddle), shipped
// with the app and run with ONNX Runtime on the device. No download, no
// account, nothing sent anywhere. Android uses ML Kit instead.
//
// Models: PaddlePaddle/PP-OCRv5_mobile_det_onnx at e6f4fa8 and
// PaddlePaddle/latin_PP-OCRv5_mobile_rec_onnx at 89d3a50 (dictionary from
// its inference.yml).

const _detAsset = 'assets/ocr/ppocr5-det-e6f4fa8.onnx';
const _recAsset = 'assets/ocr/ppocr5-latin-rec-89d3a50.onnx';
const _dict = 'assets/ocr/latin_dict.txt';

/// One line of text found on a picture, in its pixels.
class TextBox {
  const TextBox(this.left, this.top, this.right, this.bottom);
  final double left, top, right, bottom;
  double get height => bottom - top;
}

/// The detector's input for an RGB picture of [w]×[h]: its long side
/// scaled to 960 and both sides to multiples of 32, channels in BGR order,
/// normalised as the model was trained.
({Float32List data, int w, int h}) detInput(Uint8List rgb, int w, int h) {
  final ratio = 960 / max(w, h);
  final rw = max(32, (w * ratio / 32).round() * 32);
  final rh = max(32, (h * ratio / 32).round() * 32);
  final src = img.Image.fromBytes(width: w, height: h, bytes: rgb.buffer, numChannels: 3);
  final small = img.copyResize(src, width: rw, height: rh, interpolation: img.Interpolation.linear);
  final px = small.getBytes(order: img.ChannelOrder.bgr);
  const mean = [0.485, 0.456, 0.406], std = [0.229, 0.224, 0.225];
  final out = Float32List(3 * rw * rh);
  final plane = rw * rh;
  for (var i = 0; i < plane; i++) {
    for (var c = 0; c < 3; c++) {
      out[c * plane + i] = (px[i * 3 + c] / 255 - mean[c]) / std[c];
    }
  }
  return (data: out, w: rw, h: rh);
}

/// Text boxes from the detector's probability map ([pw]×[ph]), in the
/// picture's own pixels ([w]×[h]). Screens show text level, so each
/// region's upright bounding box is enough: pixels over 0.3 are joined into
/// regions, regions averaging under 0.6 are dropped, and each box is grown
/// as the model expects (area × 1.5 / perimeter on every side).
List<TextBox> boxesFrom(List<double> prob, int pw, int ph, int w, int h) {
  final on = Uint8List(pw * ph);
  for (var i = 0; i < on.length; i++) {
    if (prob[i] > 0.3) on[i] = 1;
  }
  final seen = Uint8List(pw * ph);
  final stack = <int>[];
  final out = <TextBox>[];
  final sx = w / pw, sy = h / ph;
  for (var start = 0; start < on.length; start++) {
    if (on[start] == 0 || seen[start] == 1) continue;
    seen[start] = 1;
    stack.add(start);
    var x0 = pw, y0 = ph, x1 = 0, y1 = 0;
    var sum = 0.0, n = 0;
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      final x = p % pw, y = p ~/ pw;
      sum += prob[p];
      n++;
      if (x < x0) x0 = x;
      if (x > x1) x1 = x;
      if (y < y0) y0 = y;
      if (y > y1) y1 = y;
      void visit(int q) {
        if (on[q] == 1 && seen[q] == 0) {
          seen[q] = 1;
          stack.add(q);
        }
      }

      if (x > 0) visit(p - 1);
      if (x < pw - 1) visit(p + 1);
      if (y > 0) visit(p - pw);
      if (y < ph - 1) visit(p + pw);
    }
    final bw = x1 - x0 + 1, bh = y1 - y0 + 1;
    if (min(bw, bh) < 3 || sum / n < 0.6) continue;
    final d = bw * bh * 1.5 / (2 * (bw + bh));
    out.add(
      TextBox(
        max(0, (x0 - d) * sx),
        max(0, (y0 - d) * sy),
        min(w.toDouble(), (x1 + 1 + d) * sx),
        min(h.toDouble(), (y1 + 1 + d) * sy),
      ),
    );
  }
  out.sort((a, b) => a.top != b.top ? a.top.compareTo(b.top) : a.left.compareTo(b.left));
  return out;
}

/// The recogniser's input for one box: cut out, scaled to 48 pixels high
/// (width in proportion, at most 3200), BGR, scaled to −1…1.
({Float32List data, int w}) recInput(img.Image src, TextBox b) {
  final x = b.left.floor(), y = b.top.floor();
  final cw = max(1, b.right.ceil() - x), ch = max(1, b.bottom.ceil() - y);
  final crop = img.copyCrop(src, x: x, y: y, width: cw, height: ch);
  final rw = max(8, min(3200, (48 * cw / ch).round()));
  final px = img
      .copyResize(crop, width: rw, height: 48, interpolation: img.Interpolation.linear)
      .getBytes(order: img.ChannelOrder.bgr);
  final plane = rw * 48;
  final out = Float32List(3 * plane);
  for (var i = 0; i < plane; i++) {
    for (var c = 0; c < 3; c++) {
      out[c * plane + i] = px[i * 3 + c] / 127.5 - 1;
    }
  }
  return (data: out, w: rw);
}

/// Greedy CTC decoding of [steps]×[classes] scores: class 0 is the blank,
/// 1…n the dictionary, the last a space. Returns the text and the mean
/// score of its characters.
(String, double) ctcDecode(List<double> scores, int steps, int classes, List<String> chars) {
  final out = StringBuffer();
  var prev = 0, sum = 0.0, n = 0;
  for (var t = 0; t < steps; t++) {
    var best = 0;
    var top = scores[t * classes];
    for (var c = 1; c < classes; c++) {
      final v = scores[t * classes + c];
      if (v > top) {
        top = v;
        best = c;
      }
    }
    if (best != 0 && best != prev) {
      out.write(best <= chars.length ? chars[best - 1] : ' ');
      sum += top;
      n++;
    }
    prev = best;
  }
  return (out.toString().trim(), n == 0 ? 0 : sum / n);
}

/// The two built-in models, loaded once.
class PpOcr {
  PpOcr._(this._det, this._rec, this._chars);
  final OrtSession _det;
  final OrtSession _rec;
  final List<String> _chars;

  static Future<PpOcr>? _loading;

  /// The shared instance, loaded on first use.
  static Future<PpOcr> instance() => _loading ??= () async {
    final ort = OnnxRuntime();
    final chars = (await rootBundle.loadString(_dict)).split('\n');
    if (chars.isNotEmpty && chars.last.isEmpty) chars.removeLast();
    return PpOcr._(
      await ort.createSession(await _extract(_detAsset)),
      await ort.createSession(await _extract(_recAsset)),
      chars,
    );
  }();

  /// ONNX Runtime opens models from files: the bundled model is copied into
  /// the app's own folder (not the shared temporary folder), once per
  /// version, since its name carries the model's revision.
  static Future<String> _extract(String asset) async {
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/models/ocr');
    final file = File('${dir.path}/${asset.split('/').last}');
    final data = await rootBundle.load(asset);
    if (file.existsSync() && file.lengthSync() == data.lengthInBytes) return file.path;
    await dir.create(recursive: true);
    final part = File('${file.path}.part');
    await part.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
    await part.rename(file.path);
    return file.path;
  }

  /// The lines of text in [png] that read with confidence, top to bottom,
  /// and the picture's height.
  Future<(List<ScreenLine>, double)> read(Uint8List png) async {
    final prep = await Isolate.run(() {
      final decoded = img.decodePng(png) ?? img.decodeImage(png);
      if (decoded == null) throw const FormatException('Not a picture');
      final rgb = decoded
          .convert(numChannels: 3, format: img.Format.uint8)
          .getBytes(order: img.ChannelOrder.rgb);
      final d = detInput(rgb, decoded.width, decoded.height);
      return (rgb: rgb, w: decoded.width, h: decoded.height, det: d);
    });
    final prob = await _run(_det, prep.det.data, [1, 3, prep.det.h, prep.det.w]);
    final (boxes, inputs) = await Isolate.run(() {
      final boxes = boxesFrom(prob, prep.det.w, prep.det.h, prep.w, prep.h).take(150).toList();
      final src = img.Image.fromBytes(width: prep.w, height: prep.h, bytes: prep.rgb.buffer, numChannels: 3);
      return (boxes, [for (final b in boxes) recInput(src, b)]);
    });
    final lines = <ScreenLine>[];
    for (var i = 0; i < boxes.length; i++) {
      final scores = await _run(_rec, inputs[i].data, [1, 3, 48, inputs[i].w]);
      final classes = _chars.length + 2;
      final (text, conf) = ctcDecode(scores, scores.length ~/ classes, classes, _chars);
      if (text.isNotEmpty && conf >= 0.5) {
        lines.add(ScreenLine(text, top: boxes[i].top, height: boxes[i].height));
      }
    }
    return (lines, prep.h.toDouble());
  }

  Future<List<double>> _run(OrtSession s, Float32List data, List<int> shape) async {
    final input = await OrtValue.fromList(data, shape);
    Map<String, OrtValue>? out;
    try {
      out = await s.run({s.inputNames.first: input});
      return [for (final v in await out.values.first.asFlattenedList()) (v as num).toDouble()];
    } finally {
      await input.dispose();
      for (final v in out?.values ?? const <OrtValue>[]) {
        await v.dispose();
      }
    }
  }
}
