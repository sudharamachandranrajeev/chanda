import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:chanda/domain/face_fit.dart';
import 'package:chanda/domain/pose_fit.dart';
import 'package:flutter_test/flutter_test.dart';

// The body maths against a Python reference (test/fixtures/pose_reference.json,
// made from the real models' outputs on a stock photo; numbers only).

List<double> nums(Object? l) => [for (final v in l! as List) (v as num).toDouble()];

void main() {
  final fx = jsonDecode(File('test/fixtures/pose_reference.json').readAsStringSync()) as Map;
  final body = fx['body'] as Map;

  test('2254 anchors where the reference puts them', () {
    expect(poseAnchors, hasLength(fx['anchorCount']));
    for (final e in (fx['anchors'] as Map).entries) {
      final a = poseAnchors[int.parse(e.key as String)];
      final want = nums(e.value);
      expect(a.x, closeTo(want[0], 1e-3), reason: 'anchor ${e.key}');
      expect(a.y, closeTo(want[1], 1e-3), reason: 'anchor ${e.key}');
    }
  });

  test('raw detector output decodes, merges and gives the reference body region', () {
    final reg = List<double>.filled(2254 * 12, 0);
    final logits = List<double>.filled(2254, -100);
    for (final d in (body['raw'] as List).cast<Map>()) {
      final i = d['i'] as int;
      reg.setAll(i * 12, nums(d['reg']));
      logits[i] = (d['logit'] as num).toDouble();
    }
    final decoded = decodeBodies(reg, logits);
    expect(decoded, hasLength(body['decoded']));
    final merged = mergeFaces(decoded);
    final want = (body['merged'] as List).cast<Map>();
    expect(merged, hasLength(want.length));
    final m = merged.single, w = want.single;
    expect(m.score, closeTo((w['score'] as num).toDouble(), 1e-3));
    expect([m.left, m.top, m.right, m.bottom], [for (final v in nums(w['box'])) closeTo(v, 1e-3)]);
    expect(m.keypoints, hasLength(4));

    // Onto the photo, then the landmark model's region.
    final view = letterbox(body['w'] as int, body['h'] as int, size: poseDetectorSide);
    final onPhoto = boxOnPhoto(m, view, poseDetectorSide);
    final kps = [for (final e in body['kps'] as List) ...nums(e)];
    for (var k = 0; k < 4; k++) {
      expect(onPhoto.keypoints[k].x, closeTo(kps[k * 2], 0.05));
      expect(onPhoto.keypoints[k].y, closeTo(kps[k * 2 + 1], 0.05));
    }
    final r = bodyRegion(onPhoto.keypoints[0], onPhoto.keypoints[1]);
    final region = nums(body['region']);
    expect([r.cx, r.cy, r.side, r.angle], [for (final v in region) closeTo(v, 0.05)]);
  });

  test('the heatmap pulls points to their spot, as the reference does', () {
    final rf = fx['refine'] as Map;
    final heat = List<double>.filled(64 * 64 * 39, -20);
    for (final c in (rf['cells'] as List).map(nums)) {
      heat[(c[0].toInt() * 64 + c[1].toInt()) * 39 + c[2].toInt()] = c[3];
    }
    final out = refineFromHeatmap(nums(rf['raw']), heat);
    final want = nums(rf['out']);
    for (var i = 0; i < want.length; i++) {
      expect(out[i], closeTo(want[i], 0.02), reason: 'value $i');
    }
  });

  test('landmarks land on the photo where the reference puts them', () {
    final r = nums(body['region']);
    final region = FaceRegion(r[0], r[1], r[2], r[3]);
    final photo = bodyOnPhoto(nums(body['raw39']), region);
    // The fixture's raw values are the model's before refining, so only
    // points the heatmap leaves alone are compared exactly; the rest within
    // a few pixels (one heatmap cell is region / 64).
    final cell = region.side / 64;
    for (final e in (body['points'] as Map).entries) {
      final i = int.parse(e.key as String);
      final want = nums(e.value);
      final b = BodyReading(photo);
      expect(b.point(i).x, closeTo(want[0], cell * 1.5), reason: 'point $i');
      expect(b.point(i).y, closeTo(want[1], cell * 1.5), reason: 'point $i');
      expect(b.visibility(i), closeTo(want[3], 0.02), reason: 'visibility $i');
    }
  });

  group('what stops a body photo', () {
    BodyReading person({double lsx = 300, double rsx = 200, double depthGap = 0, bool kneesOn = true}) {
      final p = Float64List(Body.outputs * 5);
      void set(int i, double x, double y, {double z = 0, double v = 0.99}) {
        p[i * 5] = x;
        p[i * 5 + 1] = y;
        p[i * 5 + 2] = z;
        p[i * 5 + 3] = v;
        p[i * 5 + 4] = 0.99;
      }

      set(Body.rightShoulder, rsx, 200, z: -depthGap / 2);
      set(Body.leftShoulder, lsx, 200, z: depthGap / 2);
      set(Body.rightHip, 225, 400);
      set(Body.leftHip, 275, 400);
      set(Body.rightKnee, 225, 550, v: kneesOn ? 0.99 : 0.1);
      set(Body.leftKnee, 275, 550, v: kneesOn ? 0.99 : 0.1);
      set(Body.rightAnkle, 225, 700);
      set(Body.leftAnkle, 275, 700);
      return BodyReading(p);
    }

    test('a person facing the camera is fine for tops, dresses and legs', () {
      for (final n in BodyNeeds.values) {
        expect(bodyProblem([person()], 500, 800, n), isNull, reason: '$n');
      }
    });

    test('nobody, several, turned, and parts missing', () {
      expect(bodyProblem([], 500, 800, BodyNeeds.torso), BodyProblem.none);
      expect(bodyProblem([person(), person()], 500, 800, BodyNeeds.torso), BodyProblem.several);
      // Shoulders one over the other: seen from the side.
      expect(bodyProblem([person(lsx: 210)], 500, 800, BodyNeeds.torso), BodyProblem.turned);
      // The person's right shoulder on the right of the photo: back to the camera.
      expect(bodyProblem([person(lsx: 200, rsx: 300)], 500, 800, BodyNeeds.torso), BodyProblem.turned);
      expect(bodyProblem([person(depthGap: 300)], 500, 800, BodyNeeds.torso), BodyProblem.turned);
      expect(bodyProblem([person(kneesOn: false)], 500, 800, BodyNeeds.torso), isNull);
      expect(bodyProblem([person(kneesOn: false)], 500, 800, BodyNeeds.knees), BodyProblem.cropped);
      // The ankles are below the bottom of the photo.
      expect(bodyProblem([person()], 500, 650, BodyNeeds.legs), BodyProblem.cropped);
      expect(bodyProblemText(BodyProblem.cropped), contains('head to feet'));
    });
  });

  test('a turn is read from the shoulders\' depths', () {
    final p = Float64List(Body.outputs * 5);
    p[Body.rightShoulder * 5] = 200;
    p[Body.leftShoulder * 5] = 300;
    p[Body.leftShoulder * 5 + 2] = 100 * tan(20 * pi / 180);
    expect(degrees(BodyReading(p).turn), closeTo(20, 0.01));
  });
}
