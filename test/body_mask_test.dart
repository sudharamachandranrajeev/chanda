import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:chanda/domain/body_mask.dart';
import 'package:chanda/domain/face_fit.dart';
import 'package:chanda/domain/pose_fit.dart';
import 'package:flutter_test/flutter_test.dart';

// The body-part maths: against a numpy reference for the scaling up
// (test/fixtures/segment_reference.json, made from synthetic scores), and on
// drawn bodies for the arms and the outline.

/// A person facing the camera, arms out a little: joints on a 200×400 photo.
BodyReading drawnBody() {
  final p = Float64List(Body.outputs * 5);
  void set(int i, double x, double y) {
    p[i * 5] = x;
    p[i * 5 + 1] = y;
    p[i * 5 + 3] = 0.99;
    p[i * 5 + 4] = 0.99;
  }

  set(Body.nose, 100, 40);
  set(Body.rightShoulder, 70, 90);
  set(Body.leftShoulder, 130, 90);
  set(Body.rightElbow, 50, 150);
  set(Body.leftElbow, 150, 150);
  set(Body.rightWrist, 40, 205);
  set(Body.leftWrist, 160, 205);
  set(Body.rightIndex, 36, 222);
  set(Body.rightPinky, 40, 222);
  set(Body.leftIndex, 164, 222);
  set(Body.leftPinky, 160, 222);
  set(Body.rightHip, 85, 210);
  set(Body.leftHip, 115, 210);
  set(Body.rightKnee, 85, 300);
  set(Body.leftKnee, 115, 300);
  set(Body.rightAnkle, 85, 385);
  set(Body.leftAnkle, 115, 385);
  return BodyReading(p);
}

void main() {
  test('scores scale up onto the photo as the reference does', () {
    final fx = jsonDecode(File('test/fixtures/segment_reference.json').readAsStringSync()) as Map;
    final w = fx['w'] as int, h = fx['h'] as int;
    final squares = [
      for (final q in (fx['squares'] as List).cast<List>())
        FaceRegion((q[0] as num).toDouble(), (q[1] as num).toDouble(), (q[2] as num).toDouble(), 0),
    ];
    const s = segmenterSide;
    final shares = [
      for (var t = 0; t < squares.length; t++)
        softmaxClasses([
          for (var y = 0; y < s; y++)
            for (var x = 0; x < s; x++)
              for (var k = 0; k < Part.classes; k++) 3 * sin(0.05 * x * (k + 1) + 0.03 * y * k + t * 0.7 + k),
        ]),
    ];
    final parts = partsOnPhoto(shares, squares, w, h);
    final want = (fx['parts'] as List).cast<int>();
    var differ = 0;
    for (var i = 0; i < w * h; i++) {
      if (parts[i] != want[i]) differ++;
    }
    // Float32 against float64 may flip a near tie or two.
    expect(differ, lessThanOrEqualTo(w * h * 0.01));
  });

  test('softmax shares add up to one', () {
    final out = softmaxClasses([1, 2, 3, 4, 5, 6, -50, 0, 0, 0, 0, 200]);
    expect(out.sublist(0, 6).reduce((a, b) => a + b), closeTo(1, 1e-6));
    expect(out[11], closeTo(1, 1e-6));
  });

  test('tall rectangles get stacked squares that cover them', () {
    expect(segmentSquares(0, 0, 100, 110), hasLength(1));
    final q = segmentSquares(0, 0, 100, 400);
    expect(q, hasLength(3));
    expect(q.first.cy - q.first.side / 2, closeTo(0, 1e-9));
    expect(q.last.cy + q.last.side / 2, closeTo(400, 1e-9));
    for (final r in q) {
      expect(r.side, greaterThanOrEqualTo(100));
    }
  });

  group('on a drawn body', () {
    const w = 200, h = 400;
    final body = drawnBody();

    // Skin for the neck and arms, clothes for the torso, hair, a face.
    Uint8List drawn() {
      final parts = Uint8List(w * h);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final p = Point(x + 0.5, y + 0.5);
          var part = Part.background;
          if (p.distanceTo(const Point(100, 40)) < 22) part = y < 30 ? Part.hair : Part.faceSkin;
          if (x >= 92 && x < 108 && y >= 60 && y < 88) part = Part.bodySkin;
          if (x >= 66 && x < 134 && y >= 85 && y < 230) part = Part.clothes;
          for (final (a, b) in [
            (body.point(Body.rightShoulder), body.point(Body.rightElbow)),
            (body.point(Body.rightElbow), body.point(Body.rightWrist)),
            (body.point(Body.leftShoulder), body.point(Body.leftElbow)),
            (body.point(Body.leftElbow), body.point(Body.leftWrist)),
          ]) {
            if (part == Part.background && segmentDistance(p, a, b).$1 < 6) part = Part.bodySkin;
          }
          if (part == Part.background && (x >= 76 && x < 124) && y >= 230 && y < 390) part = Part.clothes;
          out(x, y, part, parts);
        }
      }
      return parts;
    }

    test('arms and hands are told apart from the neck', () {
      final parts = splitArms(drawn(), w, h, body);
      expect(parts[75 * w + 100], Part.bodySkin, reason: 'neck stays body skin');
      expect(parts[178 * w + 45], Part.arm, reason: 'lower arm');
      expect(parts[178 * w + 155], Part.arm, reason: 'lower arm');
      expect(parts[150 * w + 100], Part.clothes, reason: 'the middle of the torso');
      expect(parts[20 * w + 100], Part.hair);
    });

    test('the outline is measured across the body, arms bridged only by gaps', () {
      final parts = drawn();
      final rows = outlineRows(body);
      expect(rows[0].$1, (90 + 120 * 0.12).round());
      final o = measureOutline(parts, w, h, rows);
      expect(o.waist, 68);
      expect(o.hip, 68);
      // A narrower torso is caught; a wider one is fine.
      final thin = Uint8List.fromList(parts);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          if ((x < 70 || x >= 130) && thin[y * w + x] == Part.clothes) thin[y * w + x] = Part.background;
        }
      }
      final after = measureOutline(thin, w, h, rows);
      expect(outlineShrunk(o, after), containsAll(['waist', 'hips']));
      expect(outlineShrunk(o, Outline(o.shoulder + 4, o.waist + 4, o.hip)), isEmpty);
      // Within the allowance.
      expect(outlineShrunk(const Outline(100, 100, 100), const Outline(98, 97, 100)), isEmpty);
      expect(outlineShrunk(const Outline(100, 100, 100), const Outline(96, 100, 100)), ['shoulders']);
    });
  });
}

void out(int x, int y, int part, Uint8List parts) => parts[y * 200 + x] = part;
