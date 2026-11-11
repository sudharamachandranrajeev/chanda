import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chanda/domain/embeddings.dart';
import 'package:chanda/domain/face_fit.dart';
import 'package:chanda/domain/glasses_fit.dart';
import 'package:chanda/domain/tryon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Runs the real try-on models on this device. Needs the models downloaded
// to a folder; optionally the public-domain painted portrait the face
// reference was made from (test/fixtures/face_reference.json), and a photo
// of glasses:
//   flutter test integration_test/tryon_test.dart -d linux \
//     --dart-define=TRYON_DIR=/path --dart-define=FACE=/path/portrait.jpg \
//     --dart-define=GLASSES=/path/photo.jpg
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const dir = String.fromEnvironment('TRYON_DIR');
  const face = String.fromEnvironment('FACE');
  const glasses = String.fromEnvironment('GLASSES');

  testWidgets('the face models find the reference face, and no face on a pattern', (_) async {
    expect(modelPresent(Directory(dir), tryOnFiles), isTrue, reason: 'models in $dir');
    final finder = await FaceFinder.load(Directory(dir));
    final pattern = Uint8List(320 * 240 * 3);
    for (var i = 0; i < pattern.length; i++) {
      pattern[i] = (i * 31) % 256;
    }
    expect(await finder.find((rgb: pattern, w: 320, h: 240)), isEmpty);
    if (face.isNotEmpty) {
      final photo = decodeRgb(await File(face).readAsBytes())!;
      final watch = Stopwatch()..start();
      final found = await finder.find(photo);
      printTiming('face', watch);
      expect(found, hasLength(1));
      final f = found.single;
      final ref =
          (jsonDecode(await File('test/fixtures/face_reference.json').readAsString()) as Map)['face'] as Map;
      // Pictures decode a little differently from the reference's decoder,
      // so allow about a pixel on a 1000-pixel photo.
      for (final e in (ref['mesh'] as Map).entries) {
        final i = int.parse(e.key as String);
        final want = [for (final v in e.value as List) (v as num).toDouble()];
        // The face outline moves more than the eyes between decoders.
        final tol = i >= Mesh.rightIris || i == 33 || i == 133 || i == 362 || i == 263 ? 1.5 : 3.0;
        expect(f.point(i).x, closeTo(want[0], tol), reason: 'point $i');
        expect(f.point(i).y, closeTo(want[1], tol), reason: 'point $i');
      }
      final reading = ref['reading'] as Map;
      expect(f.irisWidth, closeTo((reading['irisWidth'] as num).toDouble(), 0.5));
      expect(faceProblem(found), isNull);
    }
    await finder.close();
  });

  testWidgets('the cut-out model matches the reference and cuts out a frame', (_) async {
    final cutter = await FrameCutter.load(Directory(dir));
    // The frame drawn by the reference script, at the model's own size.
    final rgb = Uint8List(320 * 320 * 3);
    for (var y = 0; y < 320; y++) {
      for (var x = 0; x < 320; x++) {
        bool ring(int cx) {
          final v = ((x - cx) / 45) * ((x - cx) / 45) + ((y - 160) / 30) * ((y - 160) / 30);
          return v > 0.8 && v < 1.0;
        }

        final dark = ring(110) || ring(210) || (x > 150 && x < 170 && y > 150 && y < 156);
        rgb.fillRange((y * 320 + x) * 3, (y * 320 + x) * 3 + 3, dark ? 30 : 240);
      }
    }
    final alpha = await cutter.modelAlpha((rgb: rgb, w: 320, h: 320));
    final ref = [
      for (final v
          in (jsonDecode(await File('integration_test/cutter_reference.json').readAsString()) as Map)['grid']
              as List)
        (v as num).toDouble(),
    ];
    for (var by = 0; by < 16; by++) {
      for (var bx = 0; bx < 16; bx++) {
        var s = 0;
        for (var y = by * 20; y < by * 20 + 20; y++) {
          for (var x = bx * 20; x < bx * 20 + 20; x++) {
            s += alpha[y * 320 + x];
          }
        }
        expect(s / 400 / 255, closeTo(ref[by * 16 + bx], 0.02), reason: 'block $bx, $by');
      }
    }
    if (glasses.isNotEmpty) {
      final watch = Stopwatch()..start();
      final (cut, problem) = await cutter.cut(await File(glasses).readAsBytes());
      printTiming('cut-out (${cut == null ? problem : '${cut.width}×${cut.height}'})', watch);
      // A picture from the side is refused rather than drawn wrong; one from
      // the front is cut out.
      expect(cut != null || problem == CutoutProblem.notFront, isTrue, reason: '$problem');
    }
    await cutter.close();
  });
}

void printTiming(String what, Stopwatch w) {
  // ignore: avoid_print
  print('$what: ${w.elapsedMilliseconds} ms');
}
