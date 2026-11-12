import 'dart:convert';
import 'dart:io';

import 'package:chanda/domain/body_mask.dart';
import 'package:chanda/domain/clothes_fit.dart';
import 'package:chanda/domain/embeddings.dart';
import 'package:chanda/domain/face_fit.dart';
import 'package:chanda/domain/garment_fit.dart';
import 'package:chanda/domain/tryon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Runs the real body models on this device. Needs the models downloaded to
// a folder; optionally the stock photo the body reference was made from
// (test/fixtures/pose_reference.json), a full-length photo of one person
// facing the camera, a front picture of a garment on a plain background,
// a front picture of trousers laid flat, and pictures that must be refused
// (a garment worn by a model, a crumpled one):
//   flutter test integration_test/clothes_test.dart -d linux \
//     --dart-define=TRYON_DIR=/path --dart-define=POSE=/path/pose.jpg \
//     --dart-define=BODY=/path/person.jpg --dart-define=GARMENT=/path/tee.jpg \
//     --dart-define=TROUSERS=/path/jeans.jpg \
//     --dart-define=REFUSE=/path/worn.jpg,/path/crumpled.png
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const dir = String.fromEnvironment('TRYON_DIR');
  const pose = String.fromEnvironment('POSE');
  const body = String.fromEnvironment('BODY');
  const garment = String.fromEnvironment('GARMENT');
  const trousers = String.fromEnvironment('TROUSERS');
  const refuse = String.fromEnvironment('REFUSE');

  testWidgets('the body models match the reference on its photo', (_) async {
    expect(modelPresent(Directory(dir), tryOnFiles), isTrue, reason: 'models in $dir');
    if (pose.isEmpty) return;
    final fx = jsonDecode(await File('test/fixtures/pose_reference.json').readAsString()) as Map;
    final photo = decodeRgb(await File(pose).readAsBytes())!;
    final finder = await BodyFinder.load(Directory(dir));
    final watch = Stopwatch()..start();
    final found = await finder.find(photo);
    printTiming('body', watch);
    expect(found, hasLength(1));
    final b = found.single;
    // Pictures decode a little differently from the reference's decoder, and
    // the points of a 1000-pixel photo move by a few pixels with that.
    for (final e in ((fx['body'] as Map)['points'] as Map).entries) {
      final i = int.parse(e.key as String);
      final want = [for (final v in e.value as List) (v as num).toDouble()];
      expect(b.point(i).x, closeTo(want[0], 4), reason: 'point $i');
      expect(b.point(i).y, closeTo(want[1], 4), reason: 'point $i');
    }
    await finder.close();

    // The segmenter on the reference's square: how many of its 256×256
    // pixels each class wins, within 2% of the square.
    final seg = fx['seg'] as Map;
    final sq = [for (final v in seg['square'] as List) (v as num).toDouble()];
    final want = [for (final v in seg['counts'] as List) v as int];
    final segmenter = await Segmenter.load(Directory(dir));
    final shares = await segmenter.shares(photo, FaceRegion(sq[0], sq[1], sq[2], 0));
    final counts = List.filled(want.length, 0);
    for (var p = 0; p < segmenterSide * segmenterSide; p++) {
      var best = 0;
      for (var c = 1; c < want.length; c++) {
        if (shares[p * want.length + c] > shares[p * want.length + best]) best = c;
      }
      counts[best]++;
    }
    for (var c = 0; c < want.length; c++) {
      expect(counts[c], closeTo(want[c], 0.02 * segmenterSide * segmenterSide), reason: 'class $c');
    }
    await segmenter.close();
  });

  testWidgets('the whole clothes fit on a body photo, and refusals', (_) async {
    if (body.isEmpty || garment.isEmpty) return;
    final models = await TryOnModels.load(Directory(dir));
    final photo = decodeRgb(await File(body).readAsBytes())!;
    final watch = Stopwatch()..start();
    final fit = await fitClothes(models, photo, await File(garment).readAsBytes(), GarmentKind.top);
    printTiming('clothes fit', watch);
    expect(fit.problem, isNull);
    expect(decodeRgb(fit.jpeg!)!.w, photo.w);

    // A top is not two legs; jumpsuits are not drawn yet.
    final notLegs = await fitClothes(models, photo, await File(garment).readAsBytes(), GarmentKind.trousers);
    expect(notLegs.jpeg, isNull);
    expect(notLegs.problem, isNotNull);
    final onePiece = await fitClothes(models, photo, await File(garment).readAsBytes(), GarmentKind.onePiece);
    expect(onePiece.problem, garmentProblemText(GarmentProblem.unsupported));
    if (trousers.isNotEmpty) {
      final legs = await fitClothes(models, photo, await File(trousers).readAsBytes(), GarmentKind.trousers);
      // ignore: avoid_print
      print('trousers: ${legs.problem ?? 'drawn'}');
      expect(legs.problem, isNull);
    }

    for (final path in refuse.split(',').where((p) => p.isNotEmpty)) {
      final r = await fitClothes(models, photo, await File(path).readAsBytes(), GarmentKind.top);
      // ignore: avoid_print
      print('$path: ${r.problem}');
      expect(r.jpeg, isNull, reason: path);
      expect(r.problem, isNotNull, reason: path);
    }
    await models.close();
  });
}

void printTiming(String what, Stopwatch w) {
  // ignore: avoid_print
  print('$what: ${w.elapsedMilliseconds} ms');
}
