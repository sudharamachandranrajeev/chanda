import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

import 'embeddings.dart' show ModelFile;
import 'face_fit.dart';
import 'glasses_fit.dart';

// "Try-on": one optional download of small models that run on the device.
// Nothing is sent anywhere after the download.
//
//   face_detector.onnx, face_landmarks.onnx: MediaPipe BlazeFace (short
//     range) and Face Mesh V2 with irises (Apache-2.0, Google), as ONNX in
//     fernandotonon/QtMeshEditor-models.
//   pose_detector.onnx, pose_landmarks.onnx: MediaPipe BlazePose full
//     (Apache-2.0), same repository. For clothes (not used yet).
//   selfie_multiclass_256.onnx: MediaPipe multiclass selfie segmenter 256
//     (Apache-2.0), senty-au/selfie_multiclass_256x256-ONNX. For clothes.
//   u2netp.onnx: U²-Netp (Apache-2.0), BritishWerewolf/U-2-Netp. Cuts the
//     product out of its picture.
//
// Each is pinned to one revision and checked by SHA-256 (sizes and hashes
// were checked against the research downloads). About 51 MB in all.

/// The local setting that turns try-on on once downloaded.
const tryOnSetting = 'chanda.tryon';

const _mocap =
    'https://huggingface.co/fernandotonon/QtMeshEditor-models/resolve/045920a5d780d312f1c39d2bf72b512e748f780b';
const _segmenter =
    'https://huggingface.co/senty-au/selfie_multiclass_256x256-ONNX/resolve/6db8421a7150ac20558f2c24675078eb3a1a04d0';
const _cutter =
    'https://huggingface.co/BritishWerewolf/U-2-Netp/resolve/7112208dbac3a3642496c8d54e2f0f9bb3dc1dc8';

const tryOnFiles = [
  ModelFile(
    'face_detector.onnx',
    418437,
    '02a04d5d37c3558dc4d5274f7f8f0f0f01ac94e46c5ffb2cee82395d47e23181',
    repo: _mocap,
    remote: 'mocap/face/face_detector.onnx',
  ),
  ModelFile(
    'face_landmarks.onnx',
    4920979,
    'd16e5a55e6a480284d468ee32469692464049518c311662ab3956681de31e3e9',
    repo: _mocap,
    remote: 'mocap/face/face_landmarks.onnx',
  ),
  ModelFile(
    'pose_detector.onnx',
    11926470,
    '389df409fbf7f6b163fcc1dfbea307ac30f21b75e6c84d96f5b41c7b732ffde4',
    repo: _mocap,
    remote: 'mocap/pose/pose_detector.onnx',
  ),
  ModelFile(
    'pose_landmarks.onnx',
    12766212,
    '528137735df0bf09f491de38d67532f85cf0962d01e8dd28dcf95709c66479d9',
    repo: _mocap,
    remote: 'mocap/pose/pose_landmarks.onnx',
  ),
  ModelFile(
    'selfie_multiclass_256.onnx',
    16454560,
    '35ec1ecd9ee7f85073c99c00020b7f6751b69506eeacf683bc8665f6117f85b0',
    repo: _segmenter,
    remote: 'onnx/model.onnx',
  ),
  ModelFile(
    'u2netp.onnx',
    4574861,
    '309c8469258dda742793dce0ebea8e6dd393174f89934733ecc8b14c76f4ddd8',
    repo: _cutter,
    remote: 'onnx/model.onnx',
  ),
];

/// A decoded picture: RGB, 8 bits per channel.
typedef Rgb = ({Uint8List rgb, int w, int h});

/// [bytes] decoded to RGB, upright; null when it is not a picture.
Rgb? decodeRgb(Uint8List bytes) {
  final d = img.decodeImage(bytes);
  if (d == null) return null;
  final up = img.bakeOrientation(d).convert(numChannels: 3, format: img.Format.uint8);
  return (rgb: up.getBytes(order: img.ChannelOrder.rgb), w: up.width, h: up.height);
}

/// Runs [s] on one input ([data] shaped [shape]) and returns [outputs].
Future<List<List<double>>> _run(OrtSession s, Float32List data, List<int> shape, List<String> outputs) async {
  final values = {s.inputNames.first: await OrtValue.fromList(data, shape)};
  Map<String, OrtValue>? out;
  try {
    out = await s.run(values);
    return [
      for (final o in outputs) [for (final v in await out[o]!.asFlattenedList()) (v as num).toDouble()],
    ];
  } finally {
    for (final v in values.values) {
      await v.dispose();
    }
    for (final v in out?.values ?? const <OrtValue>[]) {
      await v.dispose();
    }
  }
}

/// Finds the faces on a photo.
abstract class FaceFinding {
  Future<List<FaceReading>> find(Rgb photo);
}

/// Cuts a frame out of its product picture.
abstract class FrameCutting {
  Future<(Cutout?, CutoutProblem?)> cut(Uint8List picture);
}

/// The loaded try-on models.
class TryOnModels {
  TryOnModels(this.faces, this.frames, {this.onClose});
  final FaceFinding faces;
  final FrameCutting frames;
  final Future<void> Function()? onClose;

  static Future<TryOnModels> load(Directory dir) async {
    final f = await FaceFinder.load(dir);
    final c = await FrameCutter.load(dir);
    return TryOnModels(
      f,
      c,
      onClose: () async {
        await f.close();
        await c.close();
      },
    );
  }

  Future<void> close() async => onClose?.call();
}

/// Finds faces and their mesh with the two face models.
class FaceFinder implements FaceFinding {
  FaceFinder._(this._detector, this._mesh);
  final OrtSession _detector;
  final OrtSession _mesh;

  /// At most this many faces get a mesh; more than one already means the
  /// photo cannot be used.
  static const maxFaces = 3;

  static Future<FaceFinder> load(Directory dir) async {
    final ort = OnnxRuntime();
    return FaceFinder._(
      await ort.createSession('${dir.path}/face_detector.onnx'),
      await ort.createSession('${dir.path}/face_landmarks.onnx'),
    );
  }

  Future<void> close() async {
    await _detector.close();
    await _mesh.close();
  }

  /// Every face on [photo] whose mesh the model is sure of.
  @override
  Future<List<FaceReading>> find(Rgb photo) async {
    final input = await Isolate.run(() => detectorInput(photo.rgb, photo.w, photo.h));
    final names = _detector.outputNames;
    final regName = names.firstWhere((n) => n.contains('regress'), orElse: () => names.first);
    final clsName = names.firstWhere((n) => n != regName);
    final [reg, cls] = await _run(_detector, input, const [1, 128, 128, 3], [regName, clsName]);
    final boxes = mergeFaces(decodeFaces(reg, cls));
    final view = letterbox(photo.w, photo.h);
    final out = <FaceReading>[];
    for (final b in boxes.take(maxFaces)) {
      final region = faceRegion(boxOnPhoto(b, view, 128));
      final crop = await Isolate.run(() => meshInput(photo.rgb, photo.w, photo.h, region));
      final [points, presence] = await _run(_mesh, crop, const [
        1,
        256,
        256,
        3,
      ], _mesh.outputNames.take(2).toList());
      if (1 / (1 + exp(-presence.first)) < 0.5) continue;
      out.add(FaceReading(meshOnPhoto(points, region)));
    }
    return out;
  }
}

/// Cuts a frame out of its product picture: by filling a plain background,
/// else with the cut-out model.
class FrameCutter implements FrameCutting {
  FrameCutter._(this._model);
  final OrtSession _model;

  static Future<FrameCutter> load(Directory dir) async =>
      FrameCutter._(await OnnxRuntime().createSession('${dir.path}/u2netp.onnx'));

  Future<void> close() => _model.close();

  /// The model's transparency for [p].
  Future<Uint8List> modelAlpha(Rgb p) async {
    final x = await Isolate.run(() => cutterInput(p.rgb, p.w, p.h));
    final [mask] = await _run(_model, x, const [1, 3, cutterSide, cutterSide], [_model.outputNames.first]);
    return Isolate.run(() => alphaFromMask(mask, cutterSide, p.w, p.h));
  }

  /// The frame on [picture], or why it cannot be cut out.
  @override
  Future<(Cutout?, CutoutProblem?)> cut(Uint8List picture) async {
    final p = await Isolate.run(() {
      final d = decodeRgb(picture);
      if (d == null) return null;
      // Product pictures can be huge; 1024 pixels is plenty for a frame.
      final long = max(d.w, d.h);
      if (long <= 1024) return d;
      final src = img.Image.fromBytes(width: d.w, height: d.h, bytes: d.rgb.buffer, numChannels: 3);
      final small = img.copyResize(
        src,
        width: d.w >= d.h ? 1024 : null,
        height: d.h > d.w ? 1024 : null,
        interpolation: img.Interpolation.average,
      );
      return (rgb: small.getBytes(order: img.ChannelOrder.rgb), w: small.width, h: small.height);
    });
    if (p == null) return (null, CutoutProblem.empty);
    final plain = await Isolate.run(() {
      if (!plainBackground(p.rgb, p.w, p.h)) return null;
      return cutOut(p.rgb, p.w, p.h, floodAlpha(p.rgb, p.w, p.h));
    });
    if (plain != null && plain.$1 != null) return plain;
    final alpha = await modelAlpha(p);
    return Isolate.run(() => cutOut(p.rgb, p.w, p.h, clearLenses(p.rgb, p.w, p.h, alpha)));
  }
}
