import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'face_fit.dart';

// Glasses on a face photo, in 2D: the frame cut out of the product picture
// and drawn at its true width, centred on the nose bridge between the
// pupils, turned with the eye line and narrowed a little when the head is
// turned. The face photo itself is never changed.
//
// Cut-out: a picture on a plain background is cut by filling the
// background in from the edges (clear lenses, which the fill cannot reach,
// stay faintly visible); any other picture goes through the cut-out model
// (U²-Netp), whose mask becomes the frame's transparency.

/// A frame cut out of its product picture: RGBA, cropped to the frame.
class Cutout {
  const Cutout(this.rgba, this.width, this.height);
  final Uint8List rgba;
  final int width, height;

  /// Height over width.
  double get aspect => height / width;
}

/// How far (0-255, per channel) a pixel may be from the background colour
/// and still count as background.
const backgroundTolerance = 28;

/// The median colour of the picture's border.
List<int> _borderColour(Uint8List rgb, int w, int h) {
  final chans = [<int>[], <int>[], <int>[]];
  void add(int x, int y) {
    for (var c = 0; c < 3; c++) {
      chans[c].add(rgb[(y * w + x) * 3 + c]);
    }
  }

  for (var x = 0; x < w; x++) {
    add(x, 0);
    add(x, h - 1);
  }
  for (var y = 1; y < h - 1; y++) {
    add(0, y);
    add(w - 1, y);
  }
  return [for (final c in chans) (c..sort())[c.length ~/ 2]];
}

int _distance(Uint8List rgb, int i, List<int> bg) =>
    max((rgb[i * 3] - bg[0]).abs(), max((rgb[i * 3 + 1] - bg[1]).abs(), (rgb[i * 3 + 2] - bg[2]).abs()));

/// Whether the picture stands on a plain background: nearly all of its
/// border is one colour.
bool plainBackground(Uint8List rgb, int w, int h) {
  final bg = _borderColour(rgb, w, h);
  var near = 0, all = 0;
  void count(int x, int y) {
    all++;
    if (_distance(rgb, y * w + x, bg) < backgroundTolerance) near++;
  }

  for (var x = 0; x < w; x++) {
    count(x, 0);
    count(x, h - 1);
  }
  for (var y = 1; y < h - 1; y++) {
    count(0, y);
    count(w - 1, y);
  }
  return near >= all * 0.9;
}

/// Transparency for a picture on a plain background: the background
/// reached from the edges is clear (0), background-coloured areas the fill
/// cannot reach (clear lenses) are faint (40), the rest is solid (255),
/// with edges softened by one pixel.
Uint8List floodAlpha(Uint8List rgb, int w, int h) {
  final bg = _borderColour(rgb, w, h);
  final n = w * h;
  final near = Uint8List(n);
  for (var i = 0; i < n; i++) {
    if (_distance(rgb, i, bg) < backgroundTolerance) near[i] = 1;
  }
  final out = Uint8List(n)..fillRange(0, n, 255);
  final stack = <int>[];
  void seed(int i) {
    if (near[i] == 1) {
      near[i] = 2;
      stack.add(i);
    }
  }

  for (var x = 0; x < w; x++) {
    seed(x);
    seed((h - 1) * w + x);
  }
  for (var y = 0; y < h; y++) {
    seed(y * w);
    seed(y * w + w - 1);
  }
  while (stack.isNotEmpty) {
    final i = stack.removeLast();
    out[i] = 0;
    final x = i % w;
    if (x > 0) seed(i - 1);
    if (x < w - 1) seed(i + 1);
    if (i >= w) seed(i - w);
    if (i < n - w) seed(i + w);
  }
  for (var i = 0; i < n; i++) {
    if (near[i] == 1) out[i] = 40;
  }
  return _soften(out, w, h);
}

/// Each pixel next to a clear one blended with its 3×3 neighbours.
Uint8List _soften(Uint8List a, int w, int h) {
  final out = Uint8List.fromList(a);
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final i = y * w + x;
      if (a[i] == 0) continue;
      if (a[i - 1] != 0 && a[i + 1] != 0 && a[i - w] != 0 && a[i + w] != 0) continue;
      var s = 0;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          s += a[i + dy * w + dx];
        }
      }
      out[i] = s ~/ 9;
    }
  }
  return out;
}

/// [alpha] (from the cut-out model, which fills lenses in) with pixels
/// close to the picture's background colour made faint (40), so clear
/// lenses show the face through them.
Uint8List clearLenses(Uint8List rgb, int w, int h, Uint8List alpha) {
  final bg = _borderColour(rgb, w, h);
  final out = Uint8List.fromList(alpha);
  for (var i = 0; i < w * h; i++) {
    if (out[i] > 40 && _distance(rgb, i, bg) < backgroundTolerance) out[i] = 40;
  }
  return out;
}

/// The cut-out model's side.
const cutterSide = 320;

/// The cut-out model's input: the picture squeezed to 320×320 (averaging
/// pixels, so thin rims are not lost), normalised with the ImageNet mean
/// and spread, channels first.
Float32List cutterInput(Uint8List rgb, int w, int h) {
  const mean = [0.485, 0.456, 0.406], std = [0.229, 0.224, 0.225];
  var px = rgb;
  if (w != cutterSide || h != cutterSide) {
    final src = img.Image.fromBytes(width: w, height: h, bytes: rgb.buffer, numChannels: 3);
    px = img
        .copyResize(src, width: cutterSide, height: cutterSide, interpolation: img.Interpolation.average)
        .getBytes(order: img.ChannelOrder.rgb);
  }
  const plane = cutterSide * cutterSide;
  final out = Float32List(3 * plane);
  for (var i = 0; i < plane; i++) {
    for (var c = 0; c < 3; c++) {
      out[c * plane + i] = (px[i * 3 + c] / 255 - mean[c]) / std[c];
    }
  }
  return out;
}

/// Transparency at [w]×[h] from the model's [mask] ([side]×[side], any
/// range): stretched to 0…255 and scaled up bilinearly.
Uint8List alphaFromMask(List<double> mask, int side, int w, int h) {
  var lo = double.infinity, hi = -double.infinity;
  for (final v in mask) {
    lo = min(lo, v);
    hi = max(hi, v);
  }
  final span = hi - lo < 1e-6 ? 1.0 : hi - lo;
  final out = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    final sy = ((y + 0.5) * side / h - 0.5).clamp(0.0, side - 1.0);
    final y0 = sy.floor(), y1 = min(y0 + 1, side - 1);
    final fy = sy - y0;
    for (var x = 0; x < w; x++) {
      final sx = ((x + 0.5) * side / w - 0.5).clamp(0.0, side - 1.0);
      final x0 = sx.floor(), x1 = min(x0 + 1, side - 1);
      final fx = sx - x0;
      final v =
          mask[y0 * side + x0] * (1 - fx) * (1 - fy) +
          mask[y0 * side + x1] * fx * (1 - fy) +
          mask[y1 * side + x0] * (1 - fx) * fy +
          mask[y1 * side + x1] * fx * fy;
      out[y * w + x] = ((v - lo) / span * 255).round().clamp(0, 255);
    }
  }
  return out;
}

/// Why a product picture cannot be used for a fit.
enum CutoutProblem {
  /// Nothing stood out from the background.
  empty,

  /// The cut-out fills the picture: the background did not come away.
  whole,

  /// The shape is not a frame seen from the front (too tall for its width).
  notFront,
}

String cutoutProblemText(CutoutProblem p) => switch (p) {
  CutoutProblem.empty => 'Chanda cannot find the frame on this picture. Try another picture of it.',
  CutoutProblem.whole =>
    'Chanda cannot separate the frame from the background on this picture. Try another picture of it.',
  CutoutProblem.notFront =>
    'This picture does not show the frame from the front. Pick a picture of the frame facing you.',
};

/// The frame from [rgb] with transparency [alpha]: cropped to where it is
/// solid (alpha 128 and over), or the reason it cannot be used.
(Cutout?, CutoutProblem?) cutOut(Uint8List rgb, int w, int h, Uint8List alpha) {
  var x0 = w, y0 = h, x1 = -1, y1 = -1;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (alpha[y * w + x] >= 128) {
        x0 = min(x0, x);
        x1 = max(x1, x);
        y0 = min(y0, y);
        y1 = max(y1, y);
      }
    }
  }
  if (x1 < 0 || x1 - x0 < 16) return (null, CutoutProblem.empty);
  final cw = x1 - x0 + 1, ch = y1 - y0 + 1;
  if (cw >= w * 0.98 && ch >= h * 0.98) return (null, CutoutProblem.whole);
  // A frame from the front is two to four times as wide as it is tall, and
  // its two halves mirror each other.
  if (ch / cw > 0.6 || _mirrored(alpha, w, x0, y0, cw, ch) < 0.5) return (null, CutoutProblem.notFront);
  final out = Uint8List(cw * ch * 4);
  for (var y = 0; y < ch; y++) {
    for (var x = 0; x < cw; x++) {
      final s = (y + y0) * w + x + x0, o = (y * cw + x) * 4;
      out[o] = rgb[s * 3];
      out[o + 1] = rgb[s * 3 + 1];
      out[o + 2] = rgb[s * 3 + 2];
      out[o + 3] = alpha[s];
    }
  }
  return (Cutout(out, cw, ch), null);
}

/// The share of the solid pixels in the box ([x0], [y0], [cw]×[ch]) whose
/// mirror image across the box's middle is solid too.
double _mirrored(Uint8List alpha, int w, int x0, int y0, int cw, int ch) {
  var solid = 0, both = 0;
  for (var y = y0; y < y0 + ch; y++) {
    for (var x = 0; x < cw; x++) {
      if (alpha[y * w + x0 + x] < 128) continue;
      solid++;
      if (alpha[y * w + x0 + cw - 1 - x] >= 128) both++;
    }
  }
  return solid == 0 ? 0 : both / solid;
}

/// Where the pupils sit in a frame seen from the front, as a share of its
/// height from the top: a little above the middle of the lenses.
const pupilHeight = 0.45;

/// Where and how big to draw a frame on the face photo, in its pixels.
class GlassesPlacement {
  const GlassesPlacement(this.centre, this.width, this.height, this.angle);
  final Px centre;
  final double width, height;

  /// Turn in radians, clockwise on the photo.
  final double angle;
}

/// A frame [frameMm] wide with picture [aspect] (height over width), on a
/// face whose pupils are at [right] and [left], at [pxPerMm]: the frame's
/// middle on the nose bridge ([bridgeOffset] pixels along the eye line from
/// the point between the pupils), turned with the eye line, the pupils at
/// [pupilHeight] of its height, narrowed by the head's [yaw].
GlassesPlacement placeGlasses({
  required Px right,
  required Px left,
  required double pxPerMm,
  required double frameMm,
  required double aspect,
  double yaw = 0,
  double bridgeOffset = 0,
}) {
  final d = left - right;
  final len = d.magnitude;
  final ex = len == 0 ? 1.0 : d.x / len, ey = len == 0 ? 0.0 : d.y / len;
  // Down the face, square to the eye line.
  final nx = -ey, ny = ex;
  final width = frameMm * pxPerMm * cos(yaw);
  final height = frameMm * pxPerMm * aspect;
  final down = (0.5 - pupilHeight) * height;
  return GlassesPlacement(
    Point(
      (right.x + left.x) / 2 + ex * bridgeOffset + nx * down,
      (right.y + left.y) / 2 + ey * bridgeOffset + ny * down,
    ),
    width,
    height,
    atan2(ey, ex),
  );
}

/// The face's width across the cheekbones in millimetres, for a rough
/// comparison with a frame's width.
double faceWidthMm(FaceReading f, double pxPerMm) =>
    f.point(Mesh.rightCheek).distanceTo(f.point(Mesh.leftCheek)) / pxPerMm / cos(f.yaw);
