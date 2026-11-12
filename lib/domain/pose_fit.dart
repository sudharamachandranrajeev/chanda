import 'dart:math';
import 'dart:typed_data';

import 'face_fit.dart';

// Finding a body and its joints on a photo, as the body models need it: the
// pure maths around the two models, so it can be tested without them.
//
//   1. The body detector (BlazePose) sees the photo squeezed into 224×224
//      with black borders. Its 2254 outputs are boxes relative to fixed
//      anchor points, each with four key points: the middle of the hips, a
//      point on a circle round the whole body, the middle of the shoulders
//      and a point on a circle round the upper body. They are decoded, kept
//      above a score, and overlapping ones merged.
//   2. Each body gives a square region: centred on the hips, twice the
//      circle's radius and then 1.25 times that, turned so the body stands
//      upright. That region is cut out at 256×256 for the landmark model,
//      whose 33 body points (plus 6 helper points) are refined with its
//      heatmap and mapped back onto the photo.
//
// This follows Google's MediaPipe pose landmarker graphs (Apache-2.0). The
// Python reference the tests compare against comes within a few pixels of
// MediaPipe's own results on its test photos (the rest is preprocessing).

/// Body point indices. "Right" is the person's right, which is the left of
/// a photo of them facing the camera.
abstract final class Body {
  static const points = 33, outputs = 39;
  static const nose = 0, rightEar = 8, leftEar = 7, mouthRight = 10, mouthLeft = 9;
  static const rightShoulder = 12, leftShoulder = 11;
  static const rightElbow = 14, leftElbow = 13;
  static const rightWrist = 16, leftWrist = 15;
  static const rightPinky = 18,
      leftPinky = 17,
      rightIndex = 20,
      leftIndex = 19,
      rightThumb = 22,
      leftThumb = 21;
  static const rightHip = 24, leftHip = 23;
  static const rightKnee = 26, leftKnee = 25;
  static const rightAnkle = 28, leftAnkle = 27;
  static const rightHeel = 30, leftHeel = 29;

  /// The helper points that place the body's region: hips, whole-body size.
  static const centre = 33, size = 34;
}

/// The detector's input side and the landmark model's.
const poseDetectorSide = 224, poseLandmarkSide = 256;

/// The detector's 2254 anchor centres (0-1 in its 224×224 input): two per
/// cell of a 28×28 grid, two per cell of 14×14, six per cell of 7×7.
final List<Px> poseAnchors = () {
  final out = <Px>[];
  for (final (grid, perCell) in const [(28, 2), (14, 2), (7, 6)]) {
    for (var y = 0; y < grid; y++) {
      for (var x = 0; x < grid; x++) {
        for (var k = 0; k < perCell; k++) {
          out.add(Point((x + 0.5) / grid, (y + 0.5) / grid));
        }
      }
    }
  }
  return List<Px>.unmodifiable(out);
}();

/// The bodies in the detector's raw output: [regressors] (2254×12) and
/// [logits] (2254), 0-1 across its input, before merging.
List<FaceBox> decodeBodies(List<double> regressors, List<double> logits, {double minScore = 0.5}) =>
    decodeDetections(
      regressors,
      logits,
      poseAnchors,
      size: poseDetectorSide,
      keypoints: 4,
      minScore: minScore,
    );

/// The detector's input: 224×224, letterboxed, scaled to −1…1.
Float32List poseDetectorInput(Uint8List rgb, int w, int h) => sampleInput(
  rgb,
  w,
  h,
  letterbox(w, h, size: poseDetectorSide),
  poseDetectorSide,
  scale: 1 / 127.5,
  offset: -1,
);

/// The square region round a body whose hip middle is [centre] and whose
/// whole-body circle passes through [edge] (photo pixels): centred on the
/// hips, 2.5 times the circle's radius, turned so [edge] is straight up.
FaceRegion bodyRegion(Px centre, Px edge) {
  final size = 2 * centre.distanceTo(edge);
  return FaceRegion(
    centre.x,
    centre.y,
    size * 1.25,
    normalAngle(pi / 2 - atan2(-(edge.y - centre.y), edge.x - centre.x)),
  );
}

/// The landmark model's input for [r]: 256×256, 0…1.
Float32List poseLandmarkInput(Uint8List rgb, int w, int h, FaceRegion r) =>
    unitInput(rgb, w, h, r.crop(poseLandmarkSide), poseLandmarkSide);

/// The landmark model's points ([raw]: 39 × x, y, z, visibility, presence
/// in crop pixels and logits) moved to the centre of their spot on the
/// [heatmap] (64×64×39), as MediaPipe refines them: the weighted middle of
/// a 7×7 window round each point, when the window is sure of it (0.5).
List<double> refineFromHeatmap(List<double> raw, List<double> heatmap, {int side = 64}) {
  final out = List<double>.of(raw);
  const n = Body.outputs;
  for (var i = 0; i < n; i++) {
    final x = raw[i * 5], y = raw[i * 5 + 1];
    if (x < 0 || y < 0) continue;
    final cc = (x / poseLandmarkSide * side).floor(), cr = (y / poseLandmarkSide * side).floor();
    if (cc >= side || cr >= side) continue;
    var sum = 0.0, wc = 0.0, wr = 0.0, best = 0.0;
    for (var r = max(0, cr - 3); r < min(side, cr + 4); r++) {
      for (var c = max(0, cc - 3); c < min(side, cc + 4); c++) {
        final v = _sigmoid(heatmap[(r * side + c) * n + i]);
        sum += v;
        best = max(best, v);
        wc += c * v;
        wr += r * v;
      }
    }
    if (best >= 0.5 && sum > 0) {
      out[i * 5] = wc / side / sum * poseLandmarkSide;
      out[i * 5 + 1] = wr / side / sum * poseLandmarkSide;
    }
  }
  return out;
}

double _sigmoid(double v) => 1 / (1 + exp(-v.clamp(-100.0, 100.0)));

/// The 39 points ([raw], refined, in crop pixels) on the photo: x, y in
/// photo pixels, z (depth, larger is further) at the same scale, then
/// visibility and presence (0-1).
Float64List bodyOnPhoto(List<double> raw, FaceRegion r) {
  final m = r.crop(poseLandmarkSide);
  final k = r.side / poseLandmarkSide;
  const n = Body.outputs;
  final out = Float64List(n * 5);
  for (var i = 0; i < n; i++) {
    final p = m.apply(raw[i * 5], raw[i * 5 + 1]);
    out[i * 5] = p.x;
    out[i * 5 + 1] = p.y;
    out[i * 5 + 2] = raw[i * 5 + 2] * k;
    out[i * 5 + 3] = _sigmoid(raw[i * 5 + 3]);
    out[i * 5 + 4] = _sigmoid(raw[i * 5 + 4]);
  }
  return out;
}

/// What the landmark model says about one body on a photo.
class BodyReading {
  BodyReading(this.points, {this.region});

  /// 39 × (x, y, z, visibility, presence), photo pixels.
  final Float64List points;

  /// The region the points were read in, when known.
  final FaceRegion? region;

  Px point(int i) => Point(points[i * 5], points[i * 5 + 1]);
  double depth(int i) => points[i * 5 + 2];
  double visibility(int i) => points[i * 5 + 3];
  double presence(int i) => points[i * 5 + 4];

  /// Whether point [i] is on the photo ([w]×[h]) and the model sees it.
  bool sees(int i, int w, int h, {double min = 0.5}) {
    final p = point(i);
    return visibility(i) >= min && presence(i) >= min && p.x >= 0 && p.y >= 0 && p.x < w && p.y < h;
  }

  Px mid(int a, int b) =>
      Point((points[a * 5] + points[b * 5]) / 2, (points[a * 5 + 1] + points[b * 5 + 1]) / 2);

  Px get shoulders => mid(Body.rightShoulder, Body.leftShoulder);
  Px get hips => mid(Body.rightHip, Body.leftHip);

  /// Shoulder joint to shoulder joint, in pixels.
  double get shoulderSpan => point(Body.rightShoulder).distanceTo(point(Body.leftShoulder));

  /// Middle of the shoulders to middle of the hips, in pixels.
  double get torsoLength => shoulders.distanceTo(hips);

  /// Body turned left or right (radians; 0 faces the camera), from how much
  /// deeper one shoulder is than the other.
  double get turn => atan2(depth(Body.leftShoulder) - depth(Body.rightShoulder), max(shoulderSpan, 1e-6));
}

/// Why a body photo cannot be used for clothes.
enum BodyProblem {
  /// No person found.
  none,

  /// More than one person.
  several,

  /// Turned to the side.
  turned,

  /// Shoulders or hips are not in the photo or hidden.
  cropped,

  /// The knees (or, for trousers, the ankles) are not in the photo or
  /// hidden: the legs cannot be placed, and are never guessed.
  legs,
}

/// The widest turn, and the narrowest shoulders for the torso's length,
/// that still give a fair fit. The model's depths are rough (a person
/// turned a little reads 30-40 degrees), so the turn allowed is generous
/// and the shoulders' width does most of the work.
const maxTurnDegrees = 50.0, minShoulderToTorso = 0.45;

/// Which points a garment needs to see on the body.
enum BodyNeeds {
  /// Shoulders and hips (tops).
  torso,

  /// Shoulders, hips and knees (dresses, skirts).
  knees,

  /// Hips, knees and ankles (trousers).
  legs,
}

/// What stops [bodies] (the people found on a [w]×[h] photo) from giving a
/// fair fit for a garment that [needs] them, or null when the one body is
/// fine.
BodyProblem? bodyProblem(List<BodyReading> bodies, int w, int h, BodyNeeds needs) {
  if (bodies.isEmpty) return BodyProblem.none;
  if (bodies.length > 1) return BodyProblem.several;
  final b = bodies.single;
  const torso = [Body.rightShoulder, Body.leftShoulder, Body.rightHip, Body.leftHip];
  final legs = [
    if (needs != BodyNeeds.torso) ...[Body.rightKnee, Body.leftKnee],
    if (needs == BodyNeeds.legs) ...[Body.rightAnkle, Body.leftAnkle],
  ];
  if (!torso.every((i) => b.sees(i, w, h))) return BodyProblem.cropped;
  if (!legs.every((i) => b.sees(i, w, h))) return BodyProblem.legs;
  // From the front, the person's right shoulder is on the left of the photo,
  // the shoulders are wide for the torso, and neither is much further away.
  final rs = b.point(Body.rightShoulder), ls = b.point(Body.leftShoulder);
  if (rs.x >= ls.x || b.shoulderSpan < minShoulderToTorso * b.torsoLength) return BodyProblem.turned;
  if (degrees(b.turn).abs() > maxTurnDegrees) return BodyProblem.turned;
  return null;
}

/// The plain-words reason for [p].
String bodyProblemText(BodyProblem p) => switch (p) {
  BodyProblem.none =>
    'Chanda cannot find a person on your body photo. Use a photo of all of you, standing, facing the camera.',
  BodyProblem.several => 'There is more than one person on your body photo. Use a photo with only you on it.',
  BodyProblem.turned => 'You are turned to the side on your body photo. Use a photo facing the camera.',
  BodyProblem.cropped =>
    'Part of you that this needs is outside your body photo or hidden. Use a photo of all of you, from head '
        'to feet, with your arms a little away from your sides.',
  BodyProblem.legs =>
    'Chanda cannot see your knees or ankles on your body photo, and it does not guess where your legs are. '
        'Use a photo of all of you, from head to feet, with nothing in front of your legs.',
};
