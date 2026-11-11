import 'dart:math';
import 'dart:typed_data';

import 'package:chanda/domain/body_mask.dart';
import 'package:chanda/domain/garment_fit.dart';
import 'package:chanda/domain/glasses_fit.dart';
import 'package:chanda/domain/pose_fit.dart';
import 'package:flutter_test/flutter_test.dart';

// Clothes on a body photo, on drawn garments and a drawn body (no photos).

/// Whether (x, y) is inside the polygon [poly].
bool inside(List<(double, double)> poly, double x, double y) {
  var odd = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final (xi, yi) = poly[i];
    final (xj, yj) = poly[j];
    if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) odd = !odd;
  }
  return odd;
}

/// A [w]×[h] alpha with [poly] solid.
Uint8List drawAlpha(int w, int h, List<(double, double)> poly) {
  final a = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (inside(poly, x + 0.5, y + 0.5)) a[y * w + x] = 255;
    }
  }
  return a;
}

List<(double, double)> neckline(double cx, double top, double half, double depth) => [
  for (var k = 1; k < 16; k++) (cx - half * cos(pi * k / 16), top + depth * sin(pi * k / 16)),
];

/// A tee laid flat, 300×300: neck, sloped shoulders, sleeves out and down.
List<(double, double)> tee() => [
  (115, 10),
  ...neckline(150, 10, 35, 24),
  (185, 10),
  (237, 27),
  (300, 95),
  (262, 130),
  (237, 108),
  (240, 299),
  (60, 299),
  (63, 108),
  (38, 130),
  (0, 95),
  (63, 27),
];

/// A sleeveless dress, 240×480.
List<(double, double)> dress() => [
  (95, 0),
  ...neckline(120, 0, 25, 40),
  (145, 0),
  (165, 0),
  (170, 60),
  (185, 100),
  (178, 190),
  (239, 479),
  (1, 479),
  (62, 190),
  (55, 100),
  (70, 60),
  (75, 0),
];

/// A skirt, 280×280.
List<(double, double)> skirt() => [(80, 0), (200, 0), (205, 20), (279, 279), (1, 279), (75, 20)];

Cutout cutoutOf(int w, int h, List<(double, double)> poly) {
  final a = drawAlpha(w, h, poly);
  final rgba = Uint8List(w * h * 4);
  for (var i = 0; i < w * h; i++) {
    rgba[i * 4] = 200;
    rgba[i * 4 + 1] = (i ~/ w) % 20 < 10 ? 40 : 180;
    rgba[i * 4 + 2] = 40;
    rgba[i * 4 + 3] = a[i];
  }
  return Cutout(rgba, w, h);
}

/// A person facing the camera on a 400×800 photo, arms a little out.
BodyReading drawnBody({bool elbowsShow = true}) {
  final p = Float64List(Body.outputs * 5);
  void set(int i, double x, double y, {double v = 0.99}) {
    p[i * 5] = x;
    p[i * 5 + 1] = y;
    p[i * 5 + 3] = v;
    p[i * 5 + 4] = 0.99;
  }

  set(Body.nose, 200, 90);
  set(Body.rightShoulder, 140, 190);
  set(Body.leftShoulder, 260, 190);
  set(Body.rightElbow, 110, 310, v: elbowsShow ? 0.99 : 0.1);
  set(Body.leftElbow, 290, 310, v: elbowsShow ? 0.99 : 0.1);
  set(Body.rightWrist, 95, 420);
  set(Body.leftWrist, 305, 420);
  set(Body.rightIndex, 90, 450);
  set(Body.rightPinky, 96, 450);
  set(Body.leftIndex, 310, 450);
  set(Body.leftPinky, 304, 450);
  set(Body.rightHip, 170, 420);
  set(Body.leftHip, 230, 420);
  set(Body.rightKnee, 170, 600);
  set(Body.leftKnee, 230, 600);
  set(Body.rightAnkle, 170, 770);
  set(Body.leftAnkle, 230, 770);
  return BodyReading(p);
}

const bw = 400, bh = 800;

/// The drawn body's parts: hair, face, neck, a close-fitting top, arms,
/// legs.
Uint8List bodyParts(BodyReading b) {
  final parts = Uint8List(bw * bh);
  for (var y = 0; y < bh; y++) {
    for (var x = 0; x < bw; x++) {
      final p = Point(x + 0.5, y + 0.5);
      var part = Part.background;
      if (p.distanceTo(const Point(200, 90)) < 45) part = y < 65 ? Part.hair : Part.faceSkin;
      if (x >= 185 && x < 215 && y >= 130 && y < 180) part = Part.bodySkin;
      if (x >= 135 && x < 265 && y >= 175 && y < 440) part = Part.clothes;
      if (part == Part.background) {
        for (final (a, c) in [
          (Body.rightShoulder, Body.rightElbow),
          (Body.rightElbow, Body.rightWrist),
          (Body.leftShoulder, Body.leftElbow),
          (Body.leftElbow, Body.leftWrist),
        ]) {
          if (segmentDistance(p, b.point(a), b.point(c)).$1 < 14) part = Part.bodySkin;
        }
      }
      if (part == Part.background && x >= 150 && x < 250 && y >= 440 && y < 780) part = Part.bodySkin;
      parts[y * bw + x] = part;
    }
  }
  return splitArms(parts, bw, bh, b);
}

void main() {
  test('kinds of clothes from titles, tags and lists', () {
    expect(garmentKind(title: 'Striped cotton T-shirt'), GarmentKind.top);
    expect(garmentKind(title: 'Linen shirt', list: 'Dresses'), GarmentKind.top);
    expect(garmentKind(title: 'Wrap midi dress'), GarmentKind.dress);
    expect(garmentKind(title: 'Pleated midi skirt'), GarmentKind.skirt);
    expect(garmentKind(title: 'Slim jeans'), GarmentKind.trousers);
    expect(garmentKind(title: 'Leather dress shoes'), isNull);
    expect(garmentKind(title: 'Round reading glasses'), isNull);
    expect(garmentKind(title: 'Item 42', tags: 'hoodie'), GarmentKind.top);
  });

  group('cutting out', () {
    test('holes inside the garment are filled, the rest is cropped away', () {
      const w = 120, h = 100;
      final alpha = drawAlpha(w, h, [(20, 10), (100, 10), (100, 90), (20, 90)]);
      // A print the background fill took for background.
      for (var y = 40; y < 60; y++) {
        for (var x = 50; x < 70; x++) {
          alpha[y * w + x] = 0;
        }
      }
      final (c, p) = cutGarment(Uint8List(w * h * 3), w, h, alpha);
      expect(p, isNull);
      expect((c!.width, c.height), (80, 80));
      expect(cutoutAlpha(c).every((a) => a == 255), isTrue);
    });

    test('nothing, everything, or pieces are refused', () {
      const w = 100, h = 100;
      expect(cutGarment(Uint8List(w * h * 3), w, h, Uint8List(w * h)).$2, GarmentProblem.empty);
      final all = Uint8List(w * h)..fillRange(0, w * h, 255);
      expect(cutGarment(Uint8List(w * h * 3), w, h, all).$2, GarmentProblem.whole);
      final stripes = drawAlpha(w, h, [(10, 10), (90, 10), (90, 90), (10, 90)]);
      for (var y = 10; y < 90; y++) {
        if (y % 20 >= 10) stripes.fillRange(y * w, y * w + w, 0);
      }
      expect(cutGarment(Uint8List(w * h * 3), w, h, stripes).$2, GarmentProblem.empty);
    });
  });

  group('reading the shape', () {
    test('a tee: neckline, seams, armpits, sleeves', () {
      final (s, p) = readGarmentShape(drawAlpha(301, 300, tee()), 301, 300, GarmentKind.top);
      expect(p, isNull);
      expect(s!.notch!.x, closeTo(150, 2));
      expect(s.notch!.y, closeTo(34, 2));
      expect(s.topLeft.x, closeTo(63, 3));
      expect(s.topRight.x, closeTo(238, 3));
      expect(s.armpitLeft!.y, inInclusiveRange(108, 140));
      expect(s.sleeveLeft, isNotNull);
      expect(s.sleeveRight, isNotNull);
      // The sleeve runs out along its top edge to its end.
      final l = s.sleeveLeft!;
      expect(l.along.x, lessThan(0));
      expect(l.edge(l.t.length - 1, top: true).x, closeTo(0, 8));
      expect(garmentMirrored(cutoutOf(301, 300, tee())), greaterThan(minGarmentMirror));
    });

    test('a sleeveless dress hangs from its straps', () {
      final (s, p) = readGarmentShape(drawAlpha(240, 480, dress()), 240, 480, GarmentKind.dress);
      expect(p, isNull);
      expect(s!.sleeveLeft, isNull);
      expect(s.topLeft.x, closeTo(85, 3));
      expect(s.topRight.x, closeTo(155, 3));
      expect(s.topY, closeTo(0, 1));
    });

    test('a skirt is read from its waistband', () {
      final (s, p) = readGarmentShape(drawAlpha(280, 280, skirt()), 280, 280, GarmentKind.skirt);
      expect(p, isNull);
      expect(s!.topRight.x - s.topLeft.x, closeTo(125, 6));
      expect(s.notch, isNull);
    });

    test('what is refused', () {
      // A plain rectangle has no neckline.
      final box = drawAlpha(200, 220, [(0, 0), (200, 0), (200, 220), (0, 220)]);
      expect(readGarmentShape(box, 200, 220, GarmentKind.top).$2, GarmentProblem.neck);
      // A long thin strip is not a top seen from the front.
      final strip = drawAlpha(100, 400, [(0, 0), (100, 0), (100, 400), (0, 400)]);
      expect(readGarmentShape(strip, 100, 400, GarmentKind.top).$2, GarmentProblem.notFront);
      expect(readGarmentShape(box, 200, 220, GarmentKind.trousers).$2, GarmentProblem.unsupported);
      expect(garmentProblemText(GarmentProblem.unsupported), contains('trousers'));
    });
  });

  group('fitting on a drawn body', () {
    final body = drawnBody();
    final parts = bodyParts(body);
    final photo = Uint8List(bw * bh * 3)..fillRange(0, bw * bh * 3, 90);

    (FitPicture?, FitProblem?) fit(Cutout c, GarmentKind k, {BodyReading? on}) {
      final (s, p) = readGarmentShape(cutoutAlpha(c), c.width, c.height, k);
      expect(p, isNull);
      return fitGarment(rgb: photo, w: bw, h: bh, parts: parts, body: on ?? body, cut: c, shape: s!);
    }

    for (final (name, cut, kind) in [
      ('tee', cutoutOf(301, 300, tee()), GarmentKind.top),
      ('dress', cutoutOf(240, 480, dress()), GarmentKind.dress),
      ('skirt', cutoutOf(280, 280, skirt()), GarmentKind.skirt),
    ]) {
      test('a $name covers the body, keeps the face, hair and hands, and never narrows it', () {
        final (f, p) = fit(cut, kind);
        expect(p, isNull);
        var changed = 0;
        for (var i = 0; i < bw * bh; i++) {
          final same = f!.rgb[i * 3] == 90 && f.rgb[i * 3 + 1] == 90 && f.rgb[i * 3 + 2] == 90;
          if (f.drawn[i] == 0) {
            expect(same, isTrue, reason: 'pixel $i changed where nothing was drawn');
          } else {
            changed++;
          }
          final part = parts[i];
          if (part == Part.hair || part == Part.faceSkin || part == Part.hand) {
            expect(f.drawn[i], 0, reason: 'drawn over ${part == Part.hand ? 'a hand' : 'the head'}');
          }
        }
        expect(changed, greaterThan(5000));
        // The outline afterwards: the garment counts as clothes where drawn.
        final after = Uint8List.fromList(parts);
        for (var i = 0; i < bw * bh; i++) {
          if (f!.drawn[i] >= 128) after[i] = Part.clothes;
        }
        final rows = outlineRows(body);
        expect(
          outlineShrunk(measureOutline(parts, bw, bh, rows), measureOutline(after, bw, bh, rows)),
          isEmpty,
        );
        // The torso's clothes are covered.
        if (kind != GarmentKind.skirt) {
          for (final (x, y) in [(200, 250), (150, 300), (240, 380)]) {
            expect(f!.drawn[y * bw + x], greaterThan(128), reason: '($x, $y)');
          }
        }
      });
    }

    test('sleeves need the elbows', () {
      expect(
        fit(cutoutOf(301, 300, tee()), GarmentKind.top, on: drawnBody(elbowsShow: false)).$2,
        FitProblem.arms,
      );
      // A sleeveless dress does not.
      expect(
        fit(cutoutOf(240, 480, dress()), GarmentKind.dress, on: drawnBody(elbowsShow: false)).$2,
        isNull,
      );
    });

    test('a garment that would leave much of what is worn showing is refused', () {
      // A long loose layer hanging off to one side, apart from the body.
      final loose = Uint8List.fromList(parts);
      for (var y = 200; y < 400; y++) {
        for (var x = 330; x < 396; x++) {
          loose[y * bw + x] = Part.clothes;
        }
      }
      final c = cutoutOf(301, 300, tee());
      final (s, _) = readGarmentShape(cutoutAlpha(c), 301, 300, GarmentKind.top);
      expect(
        fitGarment(rgb: photo, w: bw, h: bh, parts: loose, body: body, cut: c, shape: s!).$2,
        FitProblem.cover,
      );
    });
  });

  test('a cloud result is only taken where there are clothes', () {
    final photo = Uint8List.fromList(List.filled(4 * 3, 10));
    final result = Uint8List.fromList(List.filled(4 * 3, 200));
    final before = Uint8List.fromList([Part.clothes, Part.faceSkin, Part.background, Part.bodySkin]);
    final after = Uint8List.fromList([Part.clothes, Part.clothes, Part.background, Part.clothes]);
    final out = pasteBack(photo, result, before, after);
    expect([for (var i = 0; i < 4; i++) out[i * 3]], [200, 10, 10, 200]);
  });

  test('the outline message names the places', () {
    expect(outlineProblemText(['waist', 'hips']), contains('waist and hips'));
    expect(fitProblemText(FitProblem.arms), contains('elbows'));
  });
}
