import 'dart:math';
import 'dart:typed_data';

import 'package:chanda/domain/face_fit.dart';
import 'package:chanda/domain/glasses_fit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// A drawn pair of glasses from the front on a light grey background:
/// two rims (lenses 60×40 inside), a bridge, and a soft shadow-free edge.
(Uint8List, int, int) drawnGlasses({int w = 240, int h = 120, int bg = 235}) {
  final p = img.Image(width: w, height: h)..clear(img.ColorRgb8(bg, bg, bg));
  final black = img.ColorRgb8(20, 20, 20);
  img.drawRect(p, x1: 40, y1: 40, x2: 108, y2: 86, color: black, thickness: 4);
  img.drawRect(p, x1: 132, y1: 40, x2: 200, y2: 86, color: black, thickness: 4);
  img.fillRect(p, x1: 108, y1: 52, x2: 132, y2: 55, color: black);
  return (p.getBytes(order: img.ChannelOrder.rgb), w, h);
}

void main() {
  test('a frame on a plain background is cut out, lenses left faint', () {
    final (rgb, w, h) = drawnGlasses();
    expect(plainBackground(rgb, w, h), isTrue);
    final alpha = floodAlpha(rgb, w, h);
    expect(alpha[5 * w + 5], 0); // background
    expect(alpha[40 * w + 60], 255); // rim
    expect(alpha[63 * w + 74], 40); // inside a lens
    expect(alpha[53 * w + 120], 255); // bridge
    final (cut, problem) = cutOut(rgb, w, h, alpha);
    expect(problem, isNull);
    // The rims' outer box: about 40…200 by 40…86 (thick lines grow a little).
    expect(cut!.width, inInclusiveRange(160, 166));
    expect(cut.height, inInclusiveRange(46, 52));
    expect(cut.rgba.length, cut.width * cut.height * 4);
  });

  test('lenses the cut-out model filled in are made faint again', () {
    final (rgb, w, h) = drawnGlasses();
    final model = Uint8List(w * h);
    for (var y = 36; y < 92; y++) {
      for (var x = 36; x < 205; x++) {
        model[y * w + x] = 230;
      }
    }
    final a = clearLenses(rgb, w, h, model);
    expect(a[63 * w + 74], 40);
    expect(a[40 * w + 60], 230);
    expect(a[5 * w + 5], 0);
  });

  test('a busy background is not plain', () {
    final p = img.Image(width: 100, height: 60);
    for (var y = 0; y < 60; y++) {
      for (var x = 0; x < 100; x++) {
        p.setPixelRgb(x, y, (x * 37) % 256, (y * 53) % 256, (x * y) % 256);
      }
    }
    expect(plainBackground(p.getBytes(order: img.ChannelOrder.rgb), 100, 60), isFalse);
  });

  test('a cut-out that is empty, whole, or not from the front is refused', () {
    final (rgb, w, h) = drawnGlasses();
    expect(cutOut(rgb, w, h, Uint8List(w * h)).$2, CutoutProblem.empty);
    expect(cutOut(rgb, w, h, Uint8List(w * h)..fillRange(0, w * h, 255)).$2, CutoutProblem.whole);
    final tall = Uint8List(w * h);
    for (var y = 10; y < 110; y++) {
      for (var x = 100; x < 160; x++) {
        tall[y * w + x] = 255;
      }
    }
    expect(cutOut(rgb, w, h, tall).$2, CutoutProblem.notFront);
    // Wide enough, but one side much bigger than the other: seen from an angle.
    final angled = Uint8List(w * h);
    for (var y = 30; y < 90; y++) {
      for (var x = 20; x < 220; x++) {
        if (x < 120 || (y > 55 && y < 65)) angled[y * w + x] = 255;
      }
    }
    expect(cutOut(rgb, w, h, angled).$2, CutoutProblem.notFront);
    for (final p in CutoutProblem.values) {
      expect(cutoutProblemText(p), isNotEmpty);
    }
  });

  test('the cut-out model\'s input and its mask as transparency', () {
    // One colour everywhere: every input value is that colour, normalised.
    final rgb = Uint8List(50 * 40 * 3);
    for (var i = 0; i < 50 * 40; i++) {
      rgb.setAll(i * 3, [255, 128, 0]);
    }
    final x = cutterInput(rgb, 50, 40);
    const plane = cutterSide * cutterSide;
    expect(x.length, 3 * plane);
    expect(x[plane ~/ 2], closeTo((1 - 0.485) / 0.229, 1e-4));
    expect(x[plane + 777], closeTo((128 / 255 - 0.456) / 0.224, 1e-4));
    expect(x[2 * plane + 5], closeTo((0 - 0.406) / 0.225, 1e-4));

    // Left half 0.1, right half 0.9 on a 4×4 mask: stretched to 0…255.
    final mask = [for (var i = 0; i < 16; i++) i % 4 < 2 ? 0.1 : 0.9];
    final a = alphaFromMask(mask, 4, 8, 2);
    expect(a.sublist(0, 8), [0, 0, 0, 64, 191, 255, 255, 255]);
    expect(alphaFromMask(List.filled(16, 0.5), 4, 2, 2), [0, 0, 0, 0]);
  });

  test('glasses sit at true width on the bridge, turned with the eyes', () {
    const r = Point(100.0, 200.0), l = Point(220.0, 200.0);
    final p = placeGlasses(right: r, left: l, pxPerMm: 2, frameMm: 130, aspect: 0.4);
    expect(p.width, 260);
    expect(p.height, closeTo(104, 1e-9));
    expect(p.angle, 0);
    // The pupils at 45% of the frame's height: its middle a little lower.
    expect(p.centre.x, 160);
    expect(p.centre.y, closeTo(200 + 0.05 * 104, 1e-9));

    // A head leaning 30 degrees: the frame leans with it.
    final a = pi / 6;
    final l2 = Point(100 + 120 * cos(a), 200 + 120 * sin(a));
    final t = placeGlasses(right: r, left: l2, pxPerMm: 2, frameMm: 130, aspect: 0.4);
    expect(t.angle, closeTo(a, 1e-9));
    expect(t.centre.x, closeTo(100 + 60 * cos(a) - sin(a) * 5.2, 1e-9));
    expect(t.centre.y, closeTo(200 + 60 * sin(a) + cos(a) * 5.2, 1e-9));

    // A turned head: narrower, and centred on the nose bridge.
    final y = placeGlasses(
      right: r,
      left: l,
      pxPerMm: 2,
      frameMm: 130,
      aspect: 0.4,
      yaw: 0.3,
      bridgeOffset: 8,
    );
    expect(y.width, closeTo(260 * cos(0.3), 1e-9));
    expect(y.height, closeTo(104, 1e-9));
    expect(y.centre.x, 168);
  });

  test('face width across the cheekbones at a scale', () {
    final mesh = Float64List(Mesh.points * 3);
    mesh[Mesh.rightCheek * 3] = 100;
    mesh[Mesh.leftCheek * 3] = 380;
    mesh[Mesh.rightIris * 3] = 180;
    mesh[Mesh.leftIris * 3] = 300;
    expect(faceWidthMm(FaceReading(mesh), 2), closeTo(140, 1e-9));
  });
}
