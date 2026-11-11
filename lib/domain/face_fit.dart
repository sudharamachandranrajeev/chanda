import 'dart:math';
import 'dart:typed_data';

// Finding a face and its pupils on a photo, as the face models need it:
// the pure maths around the two models, so it can be tested without them.
//
//   1. The face detector (BlazeFace, short range) sees the photo squeezed
//      into 128×128 with black borders. Its 896 outputs are boxes relative
//      to fixed anchor points; they are decoded, kept above a score, and
//      overlapping boxes are merged (weighted non-maximum suppression).
//   2. Each face gives a square region around it, 1.5 times its box and
//      turned so the eyes are level. That region is cut out at 256×256 for
//      the face mesh model (Face Mesh V2 with irises), whose 478 points are
//      mapped back onto the photo.
//
// This follows Google's MediaPipe face landmarker graphs (Apache-2.0). The
// Python reference that the tests compare against matches MediaPipe's own
// results to within about a pixel on its test portraits.

/// Mesh point indices: the iris centres and rings, and a few face points.
/// "Right" is the person's right, which is the left of a photo of them.
abstract final class Mesh {
  static const points = 478;
  static const rightIris = 468, leftIris = 473;
  static const rightIrisRing = [469, 470, 471, 472], leftIrisRing = [474, 475, 476, 477];
  static const rightCheek = 234, leftCheek = 454, forehead = 10, chin = 152, noseBridge = 168;
}

/// A point on the photo, in pixels.
typedef Px = Point<double>;

/// A box from a detector, with its key points and its score (0-1). For a
/// face: six key points (right eye, left eye, nose tip, mouth, right ear,
/// left ear); for a body: four (see lib/domain/pose_fit.dart).
class FaceBox {
  const FaceBox(this.score, this.left, this.top, this.right, this.bottom, this.keypoints);
  final double score, left, top, right, bottom;
  final List<Px> keypoints;

  double get width => right - left;
  double get height => bottom - top;
  double get area => max(0, width) * max(0, height);

  double overlap(FaceBox o) {
    final w = min(right, o.right) - max(left, o.left);
    final h = min(bottom, o.bottom) - max(top, o.top);
    if (w <= 0 || h <= 0) return 0;
    final inter = w * h;
    final union = area + o.area - inter;
    return union > 0 ? inter / union : 0;
  }
}

/// The detector's 896 anchor centres (0-1 in its 128×128 input): two per
/// cell of a 16×16 grid, then six per cell of an 8×8 grid.
final List<Px> faceAnchors = () {
  final out = <Px>[];
  for (final (grid, perCell) in const [(16, 2), (8, 6)]) {
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

/// The faces in the detector's raw output: [regressors] (896×16) and
/// [logits] (896), kept when their score reaches [minScore]. Coordinates
/// are 0-1 across the detector's input.
List<FaceBox> decodeFaces(List<double> regressors, List<double> logits, {double minScore = 0.5}) =>
    decodeDetections(regressors, logits, faceAnchors, size: 128, keypoints: 6, minScore: minScore);

/// The boxes in a MediaPipe-style detector's raw output: per anchor in
/// [anchors], a box (centre x, y, width, height) and [keypoints] points in
/// [regressors] (input pixels, relative to the anchor), and a score logit in
/// [logits]. Kept when the score reaches [minScore]; 0-1 across the [size]
/// square input.
List<FaceBox> decodeDetections(
  List<double> regressors,
  List<double> logits,
  List<Px> anchors, {
  required int size,
  required int keypoints,
  double minScore = 0.5,
}) {
  final stride = 4 + 2 * keypoints;
  final out = <FaceBox>[];
  for (var i = 0; i < anchors.length; i++) {
    final score = 1 / (1 + exp(-logits[i].clamp(-100.0, 100.0)));
    if (score < minScore) continue;
    final a = anchors[i];
    double r(int k) => regressors[i * stride + k] / size;
    final cx = r(0) + a.x, cy = r(1) + a.y, w = r(2), h = r(3);
    out.add(
      FaceBox(score, cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2, [
        for (var k = 0; k < keypoints; k++) Point(r(4 + 2 * k) + a.x, r(5 + 2 * k) + a.y),
      ]),
    );
  }
  return out;
}

/// Overlapping boxes (overlap over [threshold]) merged into one, each
/// weighted by its score; the merged box keeps the best score.
List<FaceBox> mergeFaces(List<FaceBox> boxes, {double threshold = 0.3}) {
  var rest = [...boxes]..sort((a, b) => b.score.compareTo(a.score));
  final out = <FaceBox>[];
  while (rest.isNotEmpty) {
    final top = rest.first;
    final group = [
      for (final b in rest)
        if (top.overlap(b) > threshold) b,
    ];
    rest = [
      for (final b in rest)
        if (top.overlap(b) <= threshold) b,
    ];
    final total = group.fold<double>(0, (s, b) => s + b.score);
    double avg(double Function(FaceBox b) f) => group.fold<double>(0, (s, b) => s + f(b) * b.score) / total;
    out.add(
      FaceBox(top.score, avg((b) => b.left), avg((b) => b.top), avg((b) => b.right), avg((b) => b.bottom), [
        for (var k = 0; k < top.keypoints.length; k++)
          Point(avg((b) => b.keypoints[k].x), avg((b) => b.keypoints[k].y)),
      ]),
    );
  }
  return out;
}

/// [rgb] ([w]×[h]) as a [size]×[size] input through [m], 0…1, channels
/// last: the input of the body and segmentation models.
Float32List unitInput(Uint8List rgb, int w, int h, Affine m, int size) =>
    sampleInput(rgb, w, h, m, size, scale: 1 / 255, offset: 0);

/// Maps a model's square input onto the photo: the input pixel (u, v)
/// (continuous, 0…size) is the photo point (a·u + b·v + c, d·u + e·v + f),
/// also continuous (pixel i covers i…i+1).
class Affine {
  const Affine(this.a, this.b, this.c, this.d, this.e, this.f);
  final double a, b, c, d, e, f;

  Px apply(double u, double v) => Point(a * u + b * v + c, d * u + e * v + f);
}

/// The detector's view of a [w]×[h] photo: the photo centred in a square
/// as long as its long side (the rest black), at [size] pixels.
Affine letterbox(int w, int h, {int size = 128}) {
  final side = max(w, h).toDouble();
  final k = side / size;
  return Affine(k, 0, w / 2 - side / 2, 0, k, h / 2 - side / 2);
}

/// The square region the mesh model looks at: centre, side and turn (in
/// radians, clockwise on the photo), all in photo pixels.
class FaceRegion {
  const FaceRegion(this.cx, this.cy, this.side, this.angle);
  final double cx, cy, side, angle;

  /// From the crop's [size]×[size] pixels onto the photo.
  Affine crop(int size) {
    final c = cos(angle), s = sin(angle), q = side / size;
    return Affine(
      c * q,
      -s * q,
      cx - c * side / 2 + s * side / 2,
      s * q,
      c * q,
      cy - s * side / 2 - c * side / 2,
    );
  }
}

/// A detected face (in photo pixels) as the mesh model's region: the box's
/// centre, 1.5 times its longer side, turned so the eyes are level.
FaceRegion faceRegion(FaceBox b) {
  final r = b.keypoints[0], l = b.keypoints[1];
  return FaceRegion(
    (b.left + b.right) / 2,
    (b.top + b.bottom) / 2,
    1.5 * max(b.width, b.height),
    normalAngle(-atan2(-(l.y - r.y), l.x - r.x)),
  );
}

double normalAngle(double a) => a - 2 * pi * ((a + pi) / (2 * pi)).floorToDouble();

/// [b] (0-1 across a model input that [m] maps at [size] pixels) in photo
/// pixels.
FaceBox boxOnPhoto(FaceBox b, Affine m, int size) {
  Px p(Px q) => m.apply(q.x * size, q.y * size);
  final tl = p(Point(b.left, b.top)), br = p(Point(b.right, b.bottom));
  return FaceBox(b.score, tl.x, tl.y, br.x, br.y, [for (final k in b.keypoints) p(k)]);
}

/// A [size]×[size] RGB input cut from the photo [rgb] ([w]×[h], 8 bits per
/// channel) through [m], sampled bilinearly (black outside the photo), each
/// channel value v stored as v·[scale] + [offset], channels last.
Float32List sampleInput(
  Uint8List rgb,
  int w,
  int h,
  Affine m,
  int size, {
  required double scale,
  required double offset,
}) {
  final out = Float32List(size * size * 3);
  for (var v = 0; v < size; v++) {
    for (var u = 0; u < size; u++) {
      final p = m.apply(u + 0.5, v + 0.5);
      final x = p.x - 0.5, y = p.y - 0.5;
      final x0 = x.floor(), y0 = y.floor();
      final fx = x - x0, fy = y - y0;
      final o = (v * size + u) * 3;
      for (var c = 0; c < 3; c++) {
        double px(int xx, int yy) =>
            xx < 0 || yy < 0 || xx >= w || yy >= h ? 0 : rgb[(yy * w + xx) * 3 + c] * 1.0;
        final value =
            px(x0, y0) * (1 - fx) * (1 - fy) +
            px(x0 + 1, y0) * fx * (1 - fy) +
            px(x0, y0 + 1) * (1 - fx) * fy +
            px(x0 + 1, y0 + 1) * fx * fy;
        out[o + c] = value * scale + offset;
      }
    }
  }
  return out;
}

/// The detector's input: 128×128, scaled to −1…1.
Float32List detectorInput(Uint8List rgb, int w, int h) =>
    sampleInput(rgb, w, h, letterbox(w, h), 128, scale: 1 / 127.5, offset: -1);

/// The mesh model's input for [r]: 256×256, scaled to 0…1.
Float32List meshInput(Uint8List rgb, int w, int h, FaceRegion r) =>
    sampleInput(rgb, w, h, r.crop(256), 256, scale: 1 / 255, offset: 0);

/// The mesh model's 478 points ([raw]: x, y, z in crop pixels) on the
/// photo: x, y in photo pixels and z (depth, larger is further) at the
/// same scale.
Float64List meshOnPhoto(List<double> raw, FaceRegion r) {
  final m = r.crop(256);
  final k = r.side / 256;
  final out = Float64List(Mesh.points * 3);
  for (var i = 0; i < Mesh.points; i++) {
    final p = m.apply(raw[i * 3], raw[i * 3 + 1]);
    out[i * 3] = p.x;
    out[i * 3 + 1] = p.y;
    out[i * 3 + 2] = raw[i * 3 + 2] * k;
  }
  return out;
}

/// What the mesh says about the eyes and the way the head is held.
class FaceReading {
  FaceReading(this.mesh);

  /// 478 × (x, y, z) in photo pixels.
  final Float64List mesh;

  Px point(int i) => Point(mesh[i * 3], mesh[i * 3 + 1]);
  double depth(int i) => mesh[i * 3 + 2];

  /// The centres of the person's right and left pupils.
  Px get rightPupil => point(Mesh.rightIris);
  Px get leftPupil => point(Mesh.leftIris);

  /// The irises' width in pixels: the mean of both, side to side.
  double get irisWidth =>
      (point(Mesh.rightIrisRing[0]).distanceTo(point(Mesh.rightIrisRing[2])) +
          point(Mesh.leftIrisRing[0]).distanceTo(point(Mesh.leftIrisRing[2]))) /
      2;

  /// Head tilt towards a shoulder (radians, clockwise on the photo).
  double get roll => atan2(leftPupil.y - rightPupil.y, leftPupil.x - rightPupil.x);

  /// Head turned left or right (radians; 0 faces the camera), from how
  /// much deeper one cheek is than the other.
  double get yaw {
    final r = point(Mesh.rightCheek), l = point(Mesh.leftCheek);
    return atan2(depth(Mesh.leftCheek) - depth(Mesh.rightCheek), r.distanceTo(l));
  }

  /// Head tipped up or down (radians), from forehead and chin depth.
  double get pitch {
    final t = point(Mesh.forehead), b = point(Mesh.chin);
    return atan2(depth(Mesh.chin) - depth(Mesh.forehead), t.distanceTo(b));
  }

  /// How far along the eye line the nose bridge sits from the point midway
  /// between the pupils, in pixels (it moves when the head turns).
  double get bridgeOffset {
    final r = rightPupil, l = leftPupil;
    final mid = Point((r.x + l.x) / 2, (r.y + l.y) / 2);
    final d = l - r;
    final n = d.magnitude;
    if (n == 0) return 0;
    final b = point(Mesh.noseBridge) - mid;
    return (b.x * d.x + b.y * d.y) / n;
  }
}

/// Why a photo cannot be used for a fit.
enum FaceProblem {
  /// No face found.
  none,

  /// More than one face.
  several,

  /// The head is turned or tipped too far for a fair fit.
  turned,

  /// The head leans too far to one side.
  tilted,
}

/// The largest turn, tip and lean that still gives a fair fit, and the
/// turn from which the fit is shown as less exact.
const maxYawDegrees = 20.0, maxPitchDegrees = 20.0, maxRollDegrees = 30.0, warnYawDegrees = 10.0;

double degrees(double radians) => radians * 180 / pi;

/// What stops [faces] (the faces found on a photo) from giving a fair fit,
/// or null when the one face is fine.
FaceProblem? faceProblem(List<FaceReading> faces) {
  if (faces.isEmpty) return FaceProblem.none;
  if (faces.length > 1) return FaceProblem.several;
  final f = faces.single;
  if (degrees(f.yaw).abs() > maxYawDegrees || degrees(f.pitch).abs() > maxPitchDegrees) {
    return FaceProblem.turned;
  }
  if (degrees(f.roll).abs() > maxRollDegrees) return FaceProblem.tilted;
  return null;
}

/// The plain-words reason for [p].
String faceProblemText(FaceProblem p) => switch (p) {
  FaceProblem.none =>
    'Chanda cannot find a face on this photo. Use a clear photo of your face, looking at the camera.',
  FaceProblem.several => 'There is more than one face on this photo. Use a photo with only your face on it.',
  FaceProblem.turned =>
    'Your head is turned too far on this photo for a fair fit. Use a photo looking straight at the camera.',
  FaceProblem.tilted =>
    'Your head leans too far to one side on this photo for a fair fit. Use a photo with your head upright.',
};

/// The average adult iris is 11.7 mm across; real irises vary by a few per
/// cent, which is most of the tolerance of a fit scaled from it.
const irisMm = 11.7;

/// Where the photo's scale (pixels per millimetre) came from.
enum ScaleSource { iris, typedPd }

/// The photo's scale at the face, and how sure it is.
class FaceScale {
  const FaceScale(this.pxPerMm, this.source);
  final double pxPerMm;
  final ScaleSource source;

  /// The likely error, as a fraction (0.05 = 5%).
  double get tolerance => source == ScaleSource.iris ? 0.05 : 0.04;

  String get describe => switch (source) {
    ScaleSource.iris => 'Size from your iris (about 11.7 mm across), about ±5%.',
    ScaleSource.typedPd => 'Size from the pupil distance you typed, about ±4%.',
  };
}

/// The scale of a face photo: from the pupil distance the person typed
/// ([typedPd], millimetres) when there is one, measured between [right] and
/// [left] pupils and allowing for the head's [yaw]; else from the iris width
/// ([irisPx], pixels).
FaceScale faceScale({
  required Px right,
  required Px left,
  required double irisPx,
  double yaw = 0,
  double? typedPd,
}) {
  if (typedPd != null && typedPd > 0) {
    return FaceScale(right.distanceTo(left) / (typedPd * cos(yaw)), ScaleSource.typedPd);
  }
  return FaceScale(irisPx / irisMm, ScaleSource.iris);
}

/// The pupil distance in millimetres the photo shows at [scale].
double measuredPd(Px right, Px left, FaceScale scale, {double yaw = 0}) =>
    right.distanceTo(left) / scale.pxPerMm / cos(yaw);
