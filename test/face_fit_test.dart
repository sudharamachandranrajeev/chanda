import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:chanda/domain/face_fit.dart';
import 'package:flutter_test/flutter_test.dart';

// The face maths against a Python reference (test/fixtures/face_reference.json,
// made from the real models' outputs on a public-domain painted portrait).

List<double> nums(Object? l) => [for (final v in l! as List) (v as num).toDouble()];

void main() {
  final fx = jsonDecode(File('test/fixtures/face_reference.json').readAsStringSync()) as Map;
  final face = fx['face'] as Map;

  test('896 anchors where the reference puts them', () {
    expect(faceAnchors, hasLength(896));
    for (final e in (fx['anchors'] as Map).entries) {
      final a = faceAnchors[int.parse(e.key as String)];
      final want = nums(e.value);
      expect(a.x, closeTo(want[0], 1e-5), reason: 'anchor ${e.key}');
      expect(a.y, closeTo(want[1], 1e-5), reason: 'anchor ${e.key}');
    }
  });

  test('the models\' inputs are sampled as the reference samples them', () {
    final s = fx['synthetic'] as Map;
    final w = s['w'] as int, h = s['h'] as int;
    final rgb = Uint8List(w * h * 3);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        rgb.setAll((y * w + x) * 3, [(x * 7 + y * 3) % 256, (x * x + y) % 256, (x ^ y) % 256]);
      }
    }
    final det = detectorInput(rgb, w, h);
    for (final p in (s['detector'] as List).map(nums)) {
      final o = ((p[1] * 128 + p[0]) * 3).toInt();
      for (var c = 0; c < 3; c++) {
        expect(det[o + c], closeTo(p[2 + c], 1e-4), reason: 'detector at ${p.take(2)}');
      }
    }
    final r = nums(s['region']);
    final mesh = meshInput(rgb, w, h, FaceRegion(r[0], r[1], r[2], r[3]));
    for (final p in (s['mesh'] as List).map(nums)) {
      final o = ((p[1] * 256 + p[0]) * 3).toInt();
      for (var c = 0; c < 3; c++) {
        expect(mesh[o + c], closeTo(p[2 + c], 1e-4), reason: 'mesh at ${p.take(2)}');
      }
    }
  });

  test('raw detector output decodes and merges into the reference face', () {
    final reg = List<double>.filled(896 * 16, 0);
    final logits = List<double>.filled(896, -100);
    for (final d in (face['raw'] as List).cast<Map>()) {
      final i = d['i'] as int;
      reg.setAll(i * 16, nums(d['reg']));
      logits[i] = (d['logit'] as num).toDouble();
    }
    final decoded = decodeFaces(reg, logits);
    expect(decoded, hasLength(face['decoded']));
    final merged = mergeFaces(decoded);
    final want = (face['merged'] as List).cast<Map>();
    expect(merged, hasLength(want.length));
    final m = merged.single, w = want.single;
    expect(m.score, closeTo((w['score'] as num).toDouble(), 1e-4));
    final box = nums(w['box']);
    expect([m.left, m.top, m.right, m.bottom], [for (final v in box) closeTo(v, 1e-4)]);
    for (var k = 0; k < 6; k++) {
      expect(m.keypoints[k].x, closeTo(nums((w['kps'] as List)[k])[0], 1e-4));
      expect(m.keypoints[k].y, closeTo(nums((w['kps'] as List)[k])[1], 1e-4));
    }

    // Onto the photo, then the mesh model's region.
    final onPhoto = boxOnPhoto(m, letterbox(face['w'] as int, face['h'] as int), 128);
    expect(
      [onPhoto.left, onPhoto.top, onPhoto.right, onPhoto.bottom],
      [for (final v in nums(face['box'])) closeTo(v, 0.01)],
    );
    final r = faceRegion(onPhoto);
    final wr = nums(face['region']);
    expect(
      [r.cx, r.cy, r.side, r.angle],
      [for (final (i, v) in wr.indexed) closeTo(v, i == 3 ? 1e-4 : 0.01)],
    );
  });

  test('mesh points map back onto the photo and read the eyes and the head', () {
    final wr = nums(face['region']);
    final mesh = meshOnPhoto(nums(face['crop']), FaceRegion(wr[0], wr[1], wr[2], wr[3]));
    for (final e in (face['mesh'] as Map).entries) {
      final i = int.parse(e.key as String);
      final want = nums(e.value);
      for (var c = 0; c < 3; c++) {
        expect(mesh[i * 3 + c], closeTo(want[c], 0.01), reason: 'point $i');
      }
    }
    final f = FaceReading(mesh);
    final want = (face['reading'] as Map).map((k, v) => MapEntry(k, (v as num).toDouble()));
    expect(f.irisWidth, closeTo(want['irisWidth']!, 0.01));
    expect(f.roll, closeTo(want['roll']!, 1e-4));
    expect(f.yaw, closeTo(want['yaw']!, 1e-4));
    expect(f.pitch, closeTo(want['pitch']!, 1e-4));
    expect(f.bridgeOffset, closeTo(want['bridgeOffset']!, 0.01));
    // The pupils sit between each eye's corners (33-133 and 362-263).
    expect(f.rightPupil.x, inExclusiveRange(f.point(33).x, f.point(133).x));
    expect(f.leftPupil.x, inExclusiveRange(f.point(362).x, f.point(263).x));
    // A face turned about 12 degrees: fine, with a note.
    expect(faceProblem([f]), isNull);
    expect(degrees(f.yaw), greaterThan(warnYawDegrees));
  });

  test('no face, several faces, or a turned head: no fit', () {
    final wr = nums(face['region']);
    final straight = FaceReading(meshOnPhoto(nums(face['crop']), FaceRegion(wr[0], wr[1], wr[2], wr[3])));
    expect(faceProblem([]), FaceProblem.none);
    expect(faceProblem([straight, straight]), FaceProblem.several);
    Float64List turned(double dz) {
      final m = Float64List.fromList(straight.mesh);
      m[Mesh.leftCheek * 3 + 2] += dz;
      return m;
    }

    final width = straight.point(Mesh.rightCheek).distanceTo(straight.point(Mesh.leftCheek));
    expect(faceProblem([FaceReading(turned(width * 0.6))]), FaceProblem.turned);
    // A tilt is only turned back, unless it is extreme.
    final rot = Float64List.fromList(straight.mesh);
    for (var i = 0; i < Mesh.points; i++) {
      final x = rot[i * 3], y = rot[i * 3 + 1];
      rot[i * 3] = x * cos(0.7) - y * sin(0.7);
      rot[i * 3 + 1] = x * sin(0.7) + y * cos(0.7);
    }
    expect(faceProblem([FaceReading(rot)]), FaceProblem.tilted);
    for (final p in FaceProblem.values) {
      expect(faceProblemText(p), isNotEmpty);
    }
  });

  test('scale from the iris, or from a typed pupil distance', () {
    const r = Point(100.0, 200.0), l = Point(220.0, 200.0);
    final iris = faceScale(right: r, left: l, irisPx: 23.4);
    expect(iris.source, ScaleSource.iris);
    expect(iris.pxPerMm, closeTo(2, 1e-9));
    expect(measuredPd(r, l, iris), closeTo(60, 1e-9));
    expect(iris.tolerance, 0.05);
    final typed = faceScale(right: r, left: l, irisPx: 23.4, typedPd: 64);
    expect(typed.source, ScaleSource.typedPd);
    expect(typed.pxPerMm, closeTo(120 / 64, 1e-9));
    // A turned head shows the pupils closer together than they are.
    final turned = faceScale(right: r, left: l, irisPx: 23.4, typedPd: 64, yaw: 0.2);
    expect(turned.pxPerMm, closeTo(120 / (64 * cos(0.2)), 1e-9));
    expect(typed.describe, contains('typed'));
  });
}
