import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:chanda/app/providers.dart';
import 'package:chanda/domain/face_fit.dart';
import 'package:chanda/domain/glasses_fit.dart';
import 'package:chanda/domain/people.dart';
import 'package:chanda/domain/tryon.dart';
import 'package:chanda/ui/vault_page.dart' show ItemCard;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'app_harness.dart';

/// Faces as the test sets them.
class FakeFaces implements FaceFinding {
  List<FaceReading> faces = [];

  @override
  Future<List<FaceReading>> find(Rgb photo) async => faces;
}

/// A frame 200 by 80 pixels, or a refusal.
class FakeFrames implements FrameCutting {
  CutoutProblem? problem;
  final pictures = <Uint8List>[];

  @override
  Future<(Cutout?, CutoutProblem?)> cut(Uint8List picture) async {
    pictures.add(picture);
    if (problem != null) return (null, problem);
    return (Cutout(Uint8List(200 * 80 * 4)..fillRange(0, 200 * 80 * 4, 200), 200, 80), null);
  }
}

class _Downloaded extends DownloadedModel {
  _Downloaded() : super(tryOnSetting, tryOnFiles, 'tryon-test');

  @override
  Future<ModelState> build() async => const ModelState(present: true, on: true);
}

List<double> _nums(Object? l) => [for (final v in l! as List) (v as num).toDouble()];

/// The reference face (from test/fixtures/face_reference.json), and a plain
/// grey photo of the same size to stand for it: no real face is stored.
(FaceReading, PersonPhoto) _face() {
  final face =
      (jsonDecode(File('test/fixtures/face_reference.json').readAsStringSync()) as Map)['face'] as Map;
  final r = _nums(face['region']);
  final reading = FaceReading(meshOnPhoto(_nums(face['crop']), FaceRegion(r[0], r[1], r[2], r[3])));
  final grey = img.Image(width: face['w'] as int, height: face['h'] as int)
    ..clear(img.ColorRgb8(128, 128, 128));
  return (reading, preparePhoto(img.encodeJpg(grey))!);
}

Future<void> _openTryOn(AppHarness app, WidgetTester tester) async {
  await app.tap(find.descendant(of: find.byType(ItemCard), matching: find.text('Round blue-light glasses')));
  await app.waitFor(find.text('Try on'));
  await app.tapText('Try on');
}

void main() {
  testWidgets('the person page asks first, keeps sizes, and deletes everything', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open(seed: seedVault);
    await app.run();
    final people = People(app.session.db);

    await app.go('Settings');
    await tester.scrollUntilVisible(find.text('Try-on'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Download (51 MB)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Your photos and sizes'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('None kept'), findsOneWidget);
    await app.tapText('Your photos and sizes');

    // Nothing is kept before the person agrees.
    expect(find.text('Before you add photos'), findsOneWidget);
    expect(await tester.runAsync(people.first), isNull);
    await app.tapText('I agree, add my photos');
    await app.waitFor(find.text('Face photo'));
    final person = (await tester.runAsync(people.first))!;
    expect(DateTime.now().difference(person.consent).inMinutes, lessThan(5));
    expect(find.textContaining('You agreed to keep these on this device on'), findsOneWidget);

    // Sizes in inches, kept in centimetres; a prescription's two halves.
    await app.tap(find.text('in'));
    await tester.enterText(find.widgetWithText(TextField, 'Chest (in)'), '34');
    await tester.enterText(find.widgetWithText(TextField, 'Pupil distance (mm)'), '31.5/32');
    await app.tapText('Save sizes');
    var saved = (await tester.runAsync<Person?>(people.first))!;
    expect(saved.chest, closeTo(86.36, 0.01));
    expect(saved.waist, isNull);
    expect(saved.pd, 63.5);

    // A typo is not saved.
    await tester.enterText(find.widgetWithText(TextField, 'Waist (in)'), 'thirty');
    await app.tapText('Save sizes');
    expect(find.text('Waist: type a size in inches.'), findsOneWidget);
    saved = (await tester.runAsync<Person?>(people.first))!;
    expect(saved.waist, isNull);

    // A photo shows; deleting removes the person, photos and all.
    await tester.runAsync(() => people.setPhoto(person.id, PhotoKind.face, _face().$2));
    final container = ProviderScope.containerOf(tester.element(find.text('Face photo')));
    container.read(peopleRevisionProvider.notifier).bump();
    await app.waitFor(find.text('Choose another'));
    expect(find.text('Remove'), findsOneWidget);
    // The last message would cover the button.
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first).removeCurrentSnackBar();
    await app.settle();
    await app.tapText('Delete my photos and sizes');
    await app.tapText('Delete');
    await app.waitFor(find.text('Before you add photos'));
    expect(await tester.runAsync(people.all), isEmpty);
    final rows = await tester.runAsync(
      () => app.session.db.customSelect('SELECT count(*) AS n FROM chanda_person_photos').getSingle(),
    );
    expect(rows!.read<int>('n'), 0);

    // Try-on before its download asks for it; things that are not glasses
    // have no Try on.
    await tester.pageBack();
    await app.settle();
    await app.go('Vault');
    await app.tap(find.descendant(of: find.byType(ItemCard), matching: find.text('Pleated midi skirt')));
    expect(find.text('Try on'), findsNothing);
    await tester.pageBack();
    await app.settle();
    await _openTryOn(app, tester);
    expect(find.text('Try-on needs a download'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('glasses are drawn at their size on the face, or Chanda says why not', (tester) async {
    final faces = FakeFaces(), frames = FakeFrames();
    final (reading, photo) = _face();
    final app = AppHarness(tester)..desktop();
    late String personId;
    await app.open(
      seed: (v) async {
        await seedVault(v);
        final glasses = (await v.items()).firstWhere((i) => i.title == 'Round blue-light glasses');
        await v.updateItem(
          glasses.copyWith(
            images: jsonEncode(['https://shop.example/side.jpg', 'https://shop.example/front.jpg']),
            description: 'Lens width 50 mm, bridge 20 mm.',
          ),
        );
        final people = People(app.session.db);
        personId = (await people.add(consent: DateTime.now())).id;
        await people.setPhoto(personId, PhotoKind.face, photo);
      },
    );
    await app.run(
      extra: [
        tryOnProvider.overrideWith(_Downloaded.new),
        tryOnModelsProvider.overrideWith((_) async => TryOnModels(faces, frames)),
        itemPictureProvider.overrideWithValue((_, n, _) async => Uint8List.fromList([n])),
      ],
    );
    await app.go('Vault');

    Iterable<Positioned> drawn(double width) => tester
        .widgetList<Positioned>(find.byType(Positioned))
        .where((p) => p.width != null && (p.width! - width).abs() < 0.01);
    final irisScale = reading.irisWidth / irisMm;

    // One face: the frame is drawn 130 mm wide (2 x 50 + 20 + 10, estimated),
    // narrowed by the head's turn.
    faces.faces = [reading];
    await _openTryOn(app, tester);
    await app.waitFor(find.textContaining('Size from your iris'));
    expect(drawn(130 * irisScale * cos(reading.yaw)), hasLength(1));
    expect(find.textContaining('Frame about 130 mm wide, estimated'), findsOneWidget);
    expect(find.textContaining('turned a little'), findsOneWidget);
    expect(find.textContaining('Your pupil distance measures about'), findsOneWidget);
    expect(find.text('Product picture'), findsOneWidget);
    expect(frames.pictures.single, [0], reason: 'the first picture cuts out, so the second is not tried');
    // The size found is kept for next time.
    final glassesId = (await tester.runAsync(app.vault.items))!
        .firstWhere((i) => i.title == 'Round blue-light glasses')
        .id;
    expect(await tester.runAsync(() => app.session.db.localSetting('chanda.frame.$glassesId')), isNotNull);
    await tester.pageBack();
    await app.settle();

    // A typed pupil distance sets the scale instead.
    await tester.runAsync(() async {
      final people = People(app.session.db);
      await people.save((await people.byId(personId))!.copyWith(pd: () => 64));
    });
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
        .read(peopleRevisionProvider.notifier)
        .bump();
    await app.settle();
    await app.tapText('Try on');
    await app.waitFor(find.textContaining('Size from the pupil distance you typed'));
    final typedScale = reading.rightPupil.distanceTo(reading.leftPupil) / (64 * cos(reading.yaw));
    expect(drawn(130 * typedScale * cos(reading.yaw)), hasLength(1));
    await tester.pageBack();
    await app.settle();

    // A frame seen from the side: no frame drawn, and why.
    frames.problem = CutoutProblem.notFront;
    await app.tapText('Try on');
    await app.waitFor(find.text(cutoutProblemText(CutoutProblem.notFront)));
    expect(drawn(130 * typedScale * cos(reading.yaw)), isEmpty);
    await tester.pageBack();
    await app.settle();
    frames.problem = null;

    // Two faces, or none: nothing drawn, and why.
    for (final (list, problem) in [
      ([reading, reading], FaceProblem.several),
      (<FaceReading>[], FaceProblem.none),
    ]) {
      faces.faces = list;
      await app.tapText('Try on');
      await app.waitFor(find.text(faceProblemText(problem)));
      expect(find.text('Product picture'), findsNothing);
      expect(find.textContaining('Size from'), findsNothing);
      await tester.pageBack();
      await app.settle();
    }
    expect(tester.takeException(), isNull);
    await app.close();
  });
}
