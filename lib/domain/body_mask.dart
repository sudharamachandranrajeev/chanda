import 'dart:math';
import 'dart:typed_data';

import 'face_fit.dart';
import 'pose_fit.dart';

// Which part of the body each pixel of a body photo is: the segmentation
// model's answer, tidied with the body's joints. Used to keep hair, face,
// arms and hands in front of a garment, and to measure the body's outline
// before and after so a fit can never make anyone thinner.
//
// The segmentation model (MediaPipe multiclass selfie, 256×256) looks at a
// square of the photo and gives six scores (logits) per pixel; softmax turns
// them into shares, which are scaled up to the photo and the largest wins.
// A tall region is covered by several squares stacked down the body.
// The model gives arms, hands and neck one class (body skin); the joints
// split them.

/// The parts of a body photo. The first six are the model's classes.
abstract final class Part {
  static const background = 0, hair = 1, bodySkin = 2, faceSkin = 3, clothes = 4, others = 5;

  /// Added from the joints: an arm (skin or sleeve) and a hand.
  static const arm = 6, hand = 7;

  /// Not looked at.
  static const unknown = 255;

  static const classes = 6;
}

const segmenterSide = 256;

/// The rectangle (left, top, right, bottom) round the body's points the
/// model sees, with room for the head above and a margin round the rest.
(double, double, double, double) bodyBox(BodyReading b) {
  var x0 = double.infinity, y0 = double.infinity, x1 = -double.infinity, y1 = -double.infinity;
  for (var i = 0; i < Body.points; i++) {
    if (b.visibility(i) <= 0.5) continue;
    final p = b.point(i);
    x0 = min(x0, p.x);
    x1 = max(x1, p.x);
    y0 = min(y0, p.y);
    y1 = max(y1, p.y);
  }
  if (x0 > x1) {
    final c = b.hips;
    return (c.x - 1, c.y - 1, c.x + 1, c.y + 1);
  }
  final pad = 0.1 * (y1 - y0);
  return (x0 - pad, y0 - 1.5 * pad, x1 + pad, y1 + pad);
}

/// Squares (no turn) covering the rectangle [left], [top], [right],
/// [bottom] (photo pixels): one square when the rectangle is not much
/// taller than wide, else several stacked down it, each as wide as the
/// rectangle is wide (or tall enough to cover it in three at most), with a
/// little overlap.
List<FaceRegion> segmentSquares(double left, double top, double right, double bottom) {
  final w = right - left, h = bottom - top;
  final cx = (left + right) / 2;
  if (h <= w * 1.25) return [FaceRegion(cx, (top + bottom) / 2, max(w, h), 0)];
  final n = min(3, (h / w).ceil());
  final side = max(w, h / n * 1.1);
  final step = n == 1 ? 0.0 : (h - side) / (n - 1);
  return [for (var i = 0; i < n; i++) FaceRegion(cx, top + side / 2 + step * i, side, 0)];
}

/// Softmax over each pixel's [Part.classes] logits (256×256×6, channels
/// last), in place shares 0…1.
Float32List softmaxClasses(List<double> logits) {
  const c = Part.classes;
  final out = Float32List(logits.length);
  for (var i = 0; i < logits.length; i += c) {
    var top = -double.infinity;
    for (var k = 0; k < c; k++) {
      top = max(top, logits[i + k]);
    }
    var sum = 0.0;
    for (var k = 0; k < c; k++) {
      final e = exp(logits[i + k] - top);
      out[i + k] = e;
      sum += e;
    }
    for (var k = 0; k < c; k++) {
      out[i + k] /= sum;
    }
  }
  return out;
}

/// The part of each pixel of a [w]×[h] photo, from the [shares] (softmax,
/// 256×256×6) the model gave for each of [squares]: shares scaled up
/// bilinearly, the largest wins. A pixel in several squares takes the one
/// whose middle is nearest; pixels in none are [Part.unknown].
Uint8List partsOnPhoto(List<Float32List> shares, List<FaceRegion> squares, int w, int h) {
  final out = Uint8List(w * h)..fillRange(0, w * h, Part.unknown);
  const s = segmenterSide, c = Part.classes;
  final v = Float64List(c);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var best = -1;
      var bestD = double.infinity;
      for (var t = 0; t < squares.length; t++) {
        final q = squares[t];
        final half = q.side / 2;
        if (x + 0.5 < q.cx - half ||
            x + 0.5 > q.cx + half ||
            y + 0.5 < q.cy - half ||
            y + 0.5 > q.cy + half) {
          continue;
        }
        final d = (y + 0.5 - q.cy).abs() + (x + 0.5 - q.cx).abs();
        if (d < bestD) {
          bestD = d;
          best = t;
        }
      }
      if (best < 0) continue;
      final q = squares[best];
      final k = s / q.side;
      final sx = ((x + 0.5 - (q.cx - q.side / 2)) * k - 0.5).clamp(0.0, s - 1.0);
      final sy = ((y + 0.5 - (q.cy - q.side / 2)) * k - 0.5).clamp(0.0, s - 1.0);
      final x0 = sx.floor(), y0 = sy.floor();
      final x1 = min(x0 + 1, s - 1), y1 = min(y0 + 1, s - 1);
      final fx = sx - x0, fy = sy - y0;
      final p = shares[best];
      var top = 0;
      for (var k2 = 0; k2 < c; k2++) {
        v[k2] =
            p[(y0 * s + x0) * c + k2] * (1 - fx) * (1 - fy) +
            p[(y0 * s + x1) * c + k2] * fx * (1 - fy) +
            p[(y1 * s + x0) * c + k2] * (1 - fx) * fy +
            p[(y1 * s + x1) * c + k2] * fx * fy;
        if (v[k2] > v[top]) top = k2;
      }
      out[y * w + x] = top;
    }
  }
  return out;
}

/// Distance from [p] to the segment [a]–[b], and how far along it (0-1) the
/// nearest point is.
(double, double) segmentDistance(Px p, Px a, Px b) {
  final d = b - a;
  final len2 = d.x * d.x + d.y * d.y;
  final t = len2 == 0 ? 0.0 : (((p.x - a.x) * d.x + (p.y - a.y) * d.y) / len2).clamp(0.0, 1.0);
  final q = Point(a.x + d.x * t, a.y + d.y * t);
  return (p.distanceTo(q), t);
}

/// An arm's width either side of its bones, as a share of the shoulder
/// span: a sleeve or arm within this of the bones counts as arm.
const armReach = 0.13;

/// How far down the upper arm (0-1 from the shoulder) the arm starts to
/// count as in front of a garment's body: above it the garment's shoulder
/// covers the arm.
const armFrom = 0.35;

/// [parts] with arms and hands told apart from the neck and the rest, using
/// [body]'s joints: skin nearest an arm's bones is arm, nearest a hand is
/// hand; clothes close to the lower arm bones are a sleeve on an arm.
Uint8List splitArms(Uint8List parts, int w, int h, BodyReading body) {
  final out = Uint8List.fromList(parts);
  final span = max(body.shoulderSpan, 1.0);
  final reach = armReach * span;
  final sides = [
    (Body.rightShoulder, Body.rightElbow, Body.rightWrist, Body.rightIndex, Body.rightPinky),
    (Body.leftShoulder, Body.leftElbow, Body.leftWrist, Body.leftIndex, Body.leftPinky),
  ];
  final bones = <(Px, Px, int, bool)>[];
  for (final (s, e, wr, ix, pk) in sides) {
    final hand = body.mid(ix, pk);
    final wrist = body.point(wr);
    // The hand reaches past the knuckles the model marks.
    final tip = Point(hand.x + (hand.x - wrist.x) * 0.6, hand.y + (hand.y - wrist.y) * 0.6);
    bones
      ..add((body.point(s), body.point(e), Part.arm, true))
      ..add((body.point(e), wrist, Part.arm, false))
      ..add((wrist, tip, Part.hand, false));
  }
  // The rest of the body, so neck and legs are not taken for arms.
  final others = [
    (body.shoulders, body.point(Body.nose)),
    (body.point(Body.rightShoulder), body.point(Body.leftShoulder)),
    (body.shoulders, body.hips),
    (body.point(Body.rightHip), body.point(Body.rightKnee)),
    (body.point(Body.leftHip), body.point(Body.leftKnee)),
    (body.point(Body.rightKnee), body.point(Body.rightAnkle)),
    (body.point(Body.leftKnee), body.point(Body.leftAnkle)),
  ];
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      final part = parts[i];
      if (part != Part.bodySkin && part != Part.clothes && part != Part.others) continue;
      final p = Point(x + 0.5, y + 0.5);
      var best = double.infinity, bestPart = -1;
      var bestT = 0.0, upper = false;
      for (final (a, b, which, isUpper) in bones) {
        final (d, t) = segmentDistance(p, a, b);
        if (d < best) {
          best = d;
          bestPart = which;
          bestT = t;
          upper = isUpper;
        }
      }
      var rest = double.infinity;
      for (final (a, b) in others) {
        rest = min(rest, segmentDistance(p, a, b).$1);
      }
      if (upper && bestT < armFrom) continue;
      if (part == Part.bodySkin) {
        if (best < rest) out[i] = bestPart;
      } else if (best < reach && (bestPart == Part.hand || best < rest)) {
        out[i] = bestPart;
      }
    }
  }
  return out;
}

/// Whether part [p] is the person (anything but background or unknown).
bool isPerson(int p) => p != Part.background && p != Part.unknown;

/// Whether part [p] is the torso, legs or what is worn on them: the person
/// without hair, face, arms and hands.
bool isTorso(int p) => isPerson(p) && p != Part.hair && p != Part.faceSkin && p != Part.arm && p != Part.hand;

/// Whether part [p] is an arm or a hand: in front of the torso, the torso
/// carries on behind it.
bool isLimb(int p) => p == Part.arm || p == Part.hand;

/// The outline of the body across row [y] of [parts] ([w] wide): the left
/// and right ends of the stretch of person (or of parts [of] says yes to)
/// through [x], gaps of up to [gap] pixels bridged; null when [x] is not on
/// it. Parts [through] says yes to carry the stretch on without being its
/// ends (an arm in front of the torso).
(int, int)? outlineAt(
  Uint8List parts,
  int w,
  int y,
  int x, {
  int gap = 3,
  bool Function(int) of = isPerson,
  bool Function(int)? through,
}) {
  final row = y * w;
  bool on(int xx) => xx >= 0 && xx < w && of(parts[row + xx]);
  bool passes(int xx) => xx >= 0 && xx < w && through != null && through(parts[row + xx]);
  // Start from the nearest pixel within a few pixels of x.
  var start = -1;
  for (var d = 0; d <= gap && start < 0; d++) {
    if (on(x - d) || passes(x - d)) start = x - d;
    if (start < 0 && (on(x + d) || passes(x + d))) start = x + d;
  }
  if (start < 0) return null;
  int reach(int dir) {
    var end = on(start) ? start : -1;
    for (var miss = 0, xx = start + dir; xx >= 0 && xx < w && miss <= gap; xx += dir) {
      if (on(xx)) {
        end = xx;
        miss = 0;
      } else if (passes(xx)) {
        miss = 0;
      } else {
        miss++;
      }
    }
    return end;
  }

  final l = reach(-1), r = reach(1);
  if (l < 0 && r < 0) return null;
  return (l < 0 ? r : l, r < 0 ? l : r);
}

/// The body's outline width (pixels) at the shoulders, waist and hips, and
/// across the legs where they are measured (see [legRows]).
class Outline {
  const Outline(this.shoulder, this.waist, this.hip, [this.legs = const []]);
  final int shoulder, waist, hip;

  /// One width per place of [legRows], in the same order.
  final List<int> legs;

  List<int> get all => [shoulder, waist, hip, ...legs];
}

/// Where to measure each leg: across the thigh (a third of the way from the
/// hip to the knee), at the knee and across the calf (a third of the way
/// from the knee to the ankle), where [b]'s points for them are seen on its
/// [w]×[h] photo. Each is (place, row, middle).
List<(String, int, int)> legRows(BodyReading b, int w, int h) {
  final out = <(String, int, int)>[];
  for (final (hip, knee, ankle) in const [
    (Body.rightHip, Body.rightKnee, Body.rightAnkle),
    (Body.leftHip, Body.leftKnee, Body.leftAnkle),
  ]) {
    if (!b.sees(hip, w, h) || !b.sees(knee, w, h)) continue;
    final hp = b.point(hip), kp = b.point(knee);
    (String, int, int) at(String name, Px p) => (name, p.y.round(), p.x.round());
    out
      ..add(at('thighs', hp + (kp - hp) * (1 / 3)))
      ..add(at('knees', kp));
    if (b.sees(ankle, w, h)) out.add(at('calves', kp + (b.point(ankle) - kp) * (1 / 3)));
  }
  return out;
}

/// Where to measure the outline on a body: rows and middles at the
/// shoulders (a little below the joints, under the armpits' top), the waist
/// (60% of the way to the hips) and the hips.
List<(int, int)> outlineRows(BodyReading b) {
  final s = b.shoulders, hp = b.hips;
  (int, int) at(double t) => ((s.y + (hp.y - s.y) * t).round(), (s.x + (hp.x - s.x) * t).round());
  return [at(0.12), at(0.6), at(1.0)];
}

/// [parts]' outline widths at [rows] (from [outlineRows]) and at [legs]
/// (from [legRows]); 0 where the row misses the person.
Outline measureOutline(
  Uint8List parts,
  int w,
  int h,
  List<(int, int)> rows, [
  List<(String, int, int)> legs = const [],
]) {
  int width((int, int) r) {
    final (y, x) = r;
    if (y < 0 || y >= h) return 0;
    final o = outlineAt(parts, w, y, x.clamp(0, w - 1));
    return o == null ? 0 : o.$2 - o.$1 + 1;
  }

  return Outline(width(rows[0]), width(rows[1]), width(rows[2]), [
    for (final (_, y, x) in legs) width((y, x)),
  ]);
}

/// The most a fitted picture may narrow the body's outline at the
/// shoulders, waist or hips (a share; 0.03 = 3%) before it is refused. It
/// leaves room for the segmentation's own wobble; a garment drawn on top
/// can only widen the outline, so anything more is a change to the body.
const maxOutlineShrink = 0.03;

/// Where [after] is narrower than [before] by more than [maxOutlineShrink]:
/// the names of those places ("shoulders", "waist", "hips", and for the
/// legs the names in [legs], from [legRows]), each once; empty when the
/// outline is kept.
List<String> outlineShrunk(Outline before, Outline after, [List<(String, int, int)> legs = const []]) => {
  for (final (name, b, a) in [
    ('shoulders', before.shoulder, after.shoulder),
    ('waist', before.waist, after.waist),
    ('hips', before.hip, after.hip),
    for (var i = 0; i < legs.length && i < before.legs.length && i < after.legs.length; i++)
      (legs[i].$1, before.legs[i], after.legs[i]),
  ])
    if (b > 0 && a < b * (1 - maxOutlineShrink)) name,
}.toList();
