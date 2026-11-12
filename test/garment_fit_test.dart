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

/// Trousers laid flat, 200×370: waistband 140 wide, the legs part 95 rows
/// down and run straight to the hems, a gap between them.
List<(double, double)> trousers() => [
  (30, 0),
  (170, 0),
  (176, 40),
  (172, 369),
  (112, 369),
  (100, 95),
  (88, 369),
  (28, 369),
  (24, 40),
];

/// Shorts laid flat, 240×200: the legs part 110 rows down and flare a
/// little.
List<(double, double)> shorts() => [
  (40, 0),
  (200, 0),
  (215, 60),
  (235, 199),
  (130, 199),
  (120, 110),
  (110, 199),
  (5, 199),
  (25, 60),
];

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
/// [kneesShow] false hides the knees; [crossed] crosses the legs.
BodyReading drawnBody({bool elbowsShow = true, bool kneesShow = true, bool crossed = false}) {
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
  set(Body.rightKnee, crossed ? 235 : 170, 600, v: kneesShow ? 0.99 : 0.1);
  set(Body.leftKnee, crossed ? 165 : 230, 600, v: kneesShow ? 0.99 : 0.1);
  set(Body.rightAnkle, crossed ? 240 : 170, 770);
  set(Body.leftAnkle, crossed ? 160 : 230, 770);
  return BodyReading(p);
}

const bw = 400, bh = 800;

/// The drawn body's parts: hair, face, neck, a close-fitting top, arms,
/// legs (together, or [legsApart] with a gap between them).
Uint8List bodyParts(BodyReading b, {bool legsApart = false}) {
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
      if (part == Part.background && x >= 150 && x < 250 && y >= 440 && y < 780) {
        part = legsApart && y >= 470 && x >= 192 && x < 208 ? Part.background : Part.bodySkin;
      }
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
    expect(garmentKind(title: 'High-rise wide leg trousers'), GarmentKind.trousers);
    expect(garmentKind(title: 'Stretch leggings'), GarmentKind.trousers);
    expect(garmentKind(title: 'Navy dress pants'), GarmentKind.trousers);
    expect(garmentKind(title: 'Denim cargo shorts'), GarmentKind.shorts);
    expect(garmentKind(title: 'A-line denim skirt'), GarmentKind.skirt);
    expect(garmentKind(title: 'Linen jumpsuit'), GarmentKind.onePiece);
    expect(garmentKind(title: 'Utility dungarees'), GarmentKind.onePiece);
    expect(garmentKind(title: 'Cargo jacket'), isNull);
    // The shop's category (JSON-LD) when the title names no garment; the
    // title wins when it does.
    expect(garmentKind(title: 'The Ridley 32', category: 'Men > Clothing > Jeans'), GarmentKind.trousers);
    expect(garmentKind(title: 'Linen shirt', category: 'Trousers'), GarmentKind.top);
    expect(garmentTag(title: 'The Ridley 32', category: 'Men > Clothing > Jeans'), 'jeans');
    expect(garmentTag(title: 'Style 7', category: ['Women', 'Shorts'].join(' > ')), 'shorts');
    expect(garmentTag(title: 'Slim jeans', category: 'Jeans'), '');
    expect(garmentTag(title: 'Desk lamp', category: 'Home > Lighting'), '');
    expect(bodyNeeds(GarmentKind.trousers), BodyNeeds.legs);
    expect(bodyNeeds(GarmentKind.shorts), BodyNeeds.knees);
    expect(onLegs(GarmentKind.shorts), isTrue);
    expect(onLegs(GarmentKind.skirt), isFalse);
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
      // Trousers need two legs with a gap between them.
      expect(readGarmentShape(box, 200, 220, GarmentKind.trousers).$2, GarmentProblem.legs);
      expect(
        readGarmentShape(drawAlpha(301, 300, tee()), 301, 300, GarmentKind.trousers).$2,
        GarmentProblem.legs,
      );
      expect(
        readGarmentShape(drawAlpha(280, 280, skirt()), 280, 280, GarmentKind.shorts).$2,
        GarmentProblem.legs,
      );
      // Long trousers are not shorts, nor shorts long trousers.
      expect(
        readGarmentShape(drawAlpha(200, 370, trousers()), 200, 370, GarmentKind.shorts).$2,
        GarmentProblem.notFront,
      );
      expect(
        readGarmentShape(drawAlpha(240, 200, shorts()), 240, 200, GarmentKind.trousers).$2,
        GarmentProblem.notFront,
      );
      // Legs joined at the bottom (a skirt with a slit) are not two legs.
      final joined = drawAlpha(200, 370, trousers());
      for (var x = 80; x < 120; x++) {
        joined[369 * 200 + x] = 255;
      }
      expect(readGarmentShape(joined, 200, 370, GarmentKind.trousers).$2, GarmentProblem.legs);
      expect(readGarmentShape(box, 200, 220, GarmentKind.onePiece).$2, GarmentProblem.unsupported);
      expect(garmentProblemText(GarmentProblem.unsupported), contains('jumpsuits'));
      expect(garmentProblemText(GarmentProblem.legs), contains('two legs'));
    });

    test('trousers: waistband, crotch and two legs', () {
      final (s, p) = readGarmentShape(drawAlpha(200, 370, trousers()), 200, 370, GarmentKind.trousers);
      expect(p, isNull);
      final legs = s!.legs!;
      // The gap is narrower than a pixel at its very top.
      expect(legs.crotch.y, closeTo(100, 8));
      expect(legs.crotch.x, closeTo(100, 2));
      expect(s.topLeft.x, closeTo(30, 2));
      expect(s.topRight.x, closeTo(170, 2));
      expect(legs.endLeft, closeTo(368, 2));
      expect(legs.endRight, closeTo(368, 2));
      // The inner edges run from the crotch down to the hems.
      expect(legs.innerLeft[300], closeTo(90, 2));
      expect(legs.innerRight[300], closeTo(110, 2));
      expect(legs.innerLeft[50], -1);
      expect(legs.gapMiddle(300), closeTo(100, 1));
      expect(s.sleeveLeft, isNull);
      expect(s.notch, isNull);
      expect(garmentMirrored(cutoutOf(200, 370, trousers())), greaterThan(minGarmentMirror));
    });

    test('shorts: short legs, low crotch', () {
      final (s, p) = readGarmentShape(drawAlpha(240, 200, shorts()), 240, 200, GarmentKind.shorts);
      expect(p, isNull);
      expect(s!.legs!.crotch.y, closeTo(112, 4));
      expect(s.legs!.endLeft, closeTo(198, 2));
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

  group('trousers and shorts on a drawn body', () {
    final photo = Uint8List(bw * bh * 3)..fillRange(0, bw * bh * 3, 90);

    (FitPicture?, FitProblem?) fit(Cutout c, GarmentKind k, BodyReading body, Uint8List parts) {
      final (s, p) = readGarmentShape(cutoutAlpha(c), c.width, c.height, k);
      expect(p, isNull);
      return fitGarment(rgb: photo, w: bw, h: bh, parts: parts, body: body, cut: c, shape: s!);
    }

    /// Checks what must hold for any fit [f] on [parts]: nothing changed
    /// where nothing was drawn, nothing over the head, hands or arms,
    /// nothing above the lower half, and the outline (body and legs) never
    /// narrower afterwards.
    void keepsTheBody(FitPicture f, BodyReading body, Uint8List parts) {
      final shoulders = body.shoulders.y, hips = body.hips.y;
      var changed = 0;
      for (var i = 0; i < bw * bh; i++) {
        final same = f.rgb[i * 3] == 90 && f.rgb[i * 3 + 1] == 90 && f.rgb[i * 3 + 2] == 90;
        if (f.drawn[i] == 0) {
          expect(same, isTrue, reason: 'pixel $i changed where nothing was drawn');
          continue;
        }
        changed++;
        final part = parts[i];
        expect(
          part == Part.hair || part == Part.faceSkin || part == Part.hand || part == Part.arm,
          isFalse,
          reason: 'drawn over part $part at ${i % bw}, ${i ~/ bw}',
        );
        expect(i ~/ bw + 0.5, greaterThanOrEqualTo((shoulders + hips) / 2), reason: 'drawn above the waist');
      }
      expect(changed, greaterThan(5000));
      final after = Uint8List.fromList(parts);
      for (var i = 0; i < bw * bh; i++) {
        if (f.drawn[i] >= 128) after[i] = Part.clothes;
      }
      final rows = outlineRows(body), legs = legRows(body, bw, bh);
      expect(legs, isNotEmpty);
      expect(
        outlineShrunk(
          measureOutline(parts, bw, bh, rows, legs),
          measureOutline(after, bw, bh, rows, legs),
          legs,
        ),
        isEmpty,
      );
    }

    for (final apart in [false, true]) {
      test('trousers follow both legs to the ankles (legs ${apart ? 'apart' : 'together'})', () {
        final body = drawnBody();
        final parts = bodyParts(body, legsApart: apart);
        final (f, p) = fit(cutoutOf(200, 370, trousers()), GarmentKind.trousers, body, parts);
        expect(p, isNull);
        keepsTheBody(f!, body, parts);
        // Both legs covered from the hips to the ankles, the seat too.
        for (final (x, y) in [
          (200, 400),
          (160, 470),
          (240, 470),
          (170, 600),
          (230, 600),
          (170, 740),
          (230, 740),
        ]) {
          expect(f.drawn[y * bw + x], greaterThan(128), reason: '($x, $y)');
        }
        // The leg's own width: each body leg is covered edge to edge.
        for (final x in [152, 188, 212, 248]) {
          expect(f.drawn[650 * bw + x], greaterThan(128), reason: 'leg edge at $x');
        }
        // No further than the heels.
        for (var i = 790 * bw; i < bw * bh; i++) {
          expect(f.drawn[i], 0, reason: 'drawn below the heels');
        }
      });
    }

    test('shorts stop above the knees', () {
      final body = drawnBody();
      final parts = bodyParts(body, legsApart: true);
      final (f, p) = fit(cutoutOf(240, 200, shorts()), GarmentKind.shorts, body, parts);
      expect(p, isNull);
      keepsTheBody(f!, body, parts);
      expect(f.drawn[470 * bw + 170], greaterThan(128));
      expect(f.drawn[470 * bw + 230], greaterThan(128));
      for (final x in [170, 230]) {
        expect(f.drawn[700 * bw + x], 0, reason: 'shorts reach the shins');
      }
    });

    test('legs that cannot be seen or followed are said, never guessed', () {
      final cut = cutoutOf(200, 370, trousers());
      final hidden = drawnBody(kneesShow: false);
      expect(fit(cut, GarmentKind.trousers, hidden, bodyParts(hidden)).$2, FitProblem.legs);
      final crossed = drawnBody(crossed: true);
      expect(fit(cut, GarmentKind.trousers, crossed, bodyParts(crossed)).$2, FitProblem.legs);
      expect(fitProblemText(FitProblem.legs), allOf(contains('knees and ankles'), contains('does not')));
      // Before any of that, the body photo is checked for the knees and
      // ankles a garment needs.
      expect(bodyProblem([hidden], bw, bh, bodyNeeds(GarmentKind.trousers)), BodyProblem.legs);
      expect(bodyProblem([hidden], bw, bh, bodyNeeds(GarmentKind.shorts)), BodyProblem.legs);
      expect(bodyProblem([hidden], bw, bh, bodyNeeds(GarmentKind.top)), isNull);
    });

    test('the lower half is below the middle of shoulders and hips', () {
      final body = drawnBody();
      expect(lowerHalf(body, const Point(200, 300)), isFalse);
      expect(lowerHalf(body, const Point(200, 310)), isTrue);
      expect(lowerHalf(body, const Point(170, 700)), isTrue);
    });

    test('trousers that would leave much of what is worn showing are refused', () {
      // Long loose clothes reaching out to one side, apart from the legs.
      final body = drawnBody();
      final loose = bodyParts(body, legsApart: true);
      for (var y = 450; y < 700; y++) {
        for (var x = 300; x < 396; x++) {
          loose[y * bw + x] = Part.clothes;
        }
      }
      expect(fit(cutoutOf(200, 370, trousers()), GarmentKind.trousers, body, loose).$2, FitProblem.cover);
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
