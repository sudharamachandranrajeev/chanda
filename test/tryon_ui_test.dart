import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:chanda/app/providers.dart';
import 'package:chanda/domain/cloud_tryon.dart';
import 'package:chanda/domain/face_fit.dart';
import 'package:chanda/domain/garment_fit.dart';
import 'package:chanda/domain/glasses_fit.dart';
import 'package:chanda/domain/people.dart';
import 'package:chanda/domain/pose_fit.dart';
import 'package:chanda/domain/reading.dart';
import 'package:chanda/domain/tryon.dart';
import 'package:chanda/ui/vault_page.dart' show ItemCard;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;

import 'app_harness.dart';
import 'garment_fit_test.dart' show bh, bodyParts, bw, cutoutOf, drawnBody, skirt, trousers;

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

/// The drawn person of test/garment_fit_test.dart.
class FakeBodies implements BodyFinding, BodySegmenting {
  BodyReading body = drawnBody();

  @override
  Future<List<BodyReading>> find(Rgb photo) async => [body];

  @override
  Future<Uint8List> parts(Rgb photo, BodyReading body) async => bodyParts(body);
}

/// Product picture [n]: a small plain picture [n] + 10 pixels wide.
Uint8List productPicture(int n) => img.encodePng(img.Image(width: n + 10, height: 10));

/// Picture 0 shows the garment from the side; picture 1 is a drawn
/// [garment] (a skirt unless set).
class FakeGarments implements GarmentCutting {
  final pictures = <int>[];
  Cutout garment = cutoutOf(280, 280, skirt());

  @override
  Future<(Cutout?, GarmentProblem?, Rgb?)> cut(Uint8List picture) async {
    final n = img.decodePng(picture)!.width - 10;
    pictures.add(n);
    if (n == 0) return (null, GarmentProblem.notFront, null);
    return (garment, null, null);
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
    await app.tap(find.descendant(of: find.byType(ItemCard), matching: find.text('Brass desk lamp')));
    expect(find.text('Try on'), findsNothing);
    await tester.pageBack();
    await app.settle();
    await app.tap(find.descendant(of: find.byType(ItemCard), matching: find.text('Pleated midi skirt')));
    expect(find.text('Try on'), findsOneWidget);
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

  testWidgets('clothes are drawn on the body photo, with a size note and an AI preview on request', (
    tester,
  ) async {
    final bodies = FakeBodies(), garments = FakeGarments();
    final app = AppHarness(tester)..desktop();
    const skirtUrl = 'https://www.shein.co.uk/Skirt-p-123.html';
    final grey = img.Image(width: bw, height: bh)..clear(img.ColorRgb8(128, 128, 128));
    await app.open(
      seed: (v) async {
        await seedVault(v);
        final item = (await v.items()).firstWhere((i) => i.title == 'Pleated midi skirt');
        await v.updateItem(
          item.copyWith(
            images: jsonEncode(['https://shop.example/side.jpg', 'https://shop.example/flat.jpg']),
          ),
        );
        final people = People(app.session.db);
        final p = await people.add(consent: DateTime.now());
        await people.save(p.copyWith(waist: () => 72, hip: () => 99));
        await people.setPhoto(p.id, PhotoKind.body, preparePhoto(img.encodeJpg(grey))!);
        await app.session.db.setLocalSetting(cloudKeySetting(CloudProvider.fashn), 'fa-test-key-0123456789');
      },
    );
    // FASHN, faked: the run is done at once and sends back a plain picture.
    final result = base64Encode(img.encodePng(grey));
    final sent = <String>[];
    final cloud = MockClient((r) async {
      sent.add('${r.method} ${r.url}');
      return r.method == 'POST'
          ? http.Response('{"id":"run1"}', 200)
          : http.Response(
              jsonEncode({
                'status': 'completed',
                'output': ['data:image/png;base64,$result'],
              }),
              200,
            );
    });
    await app.run(
      pages: {
        skirtUrl: const Evidence(
          url: skirtUrl,
          tables: [
            [
              ['Size', 'Waist (cm)', 'Hip (cm)'],
              ['S', '66-70', '92-96'],
              ['M', '74-78', '100-104'],
            ],
          ],
        ),
      },
      extra: [
        tryOnProvider.overrideWith(_Downloaded.new),
        tryOnModelsProvider.overrideWith(
          (_) async =>
              TryOnModels(FakeFaces(), FakeFrames(), bodies: bodies, segmenter: bodies, garments: garments),
        ),
        itemPictureProvider.overrideWithValue((_, n, _) async => productPicture(n)),
        cloudClientProvider.overrideWithValue(cloud),
      ],
    );
    await app.go('Vault');
    await app.tap(find.descendant(of: find.byType(ItemCard), matching: find.text('Pleated midi skirt')));
    await app.tapText('Try on');

    // The side view is passed over; the flat picture is drawn.
    await app.waitFor(find.text('Fit preview, approximate'));
    expect(find.text('Fit preview, approximate'), findsOneWidget);
    expect(garments.pictures, [0, 1]);
    expect(find.text('Cannot fit this photo'), findsNothing);

    // The size note: between sizes at the waist, between at the hip too,
    // and where the chart came from. Kept for next time.
    await app.waitFor(find.text('Size note: between sizes'));
    expect(find.text('Size note: between sizes'), findsOneWidget);
    expect(find.text("Waist 72 cm: between the chart's S (up to 70 cm) and M (from 74 cm)."), findsOneWidget);
    expect(find.text('From the size table on shein.co.uk.'), findsOneWidget);
    expect(find.textContaining('your size is'), findsNothing);
    final id = (await tester.runAsync(app.vault.items))!
        .firstWhere((i) => i.title == 'Pleated midi skirt')
        .id;
    expect(
      await tester.runAsync(() => app.session.db.localSetting('chanda.sizechart.$id')),
      contains('waist'),
    );

    // The side view, chosen: nothing drawn, and why.
    await app.tap(find.descendant(of: find.byType(Wrap), matching: find.byType(InkWell)).first);
    await app.waitFor(find.text('Cannot fit this photo'));
    expect(find.text('Cannot fit this photo'), findsOneWidget);
    expect(find.text(garmentProblemText(GarmentProblem.notFront)), findsOneWidget);
    expect(find.text('Fit preview, approximate'), findsNothing);
    await app.tap(find.descendant(of: find.byType(Wrap), matching: find.byType(InkWell)).last);
    await app.waitFor(find.text('Fit preview, approximate'));
    expect(find.text('Fit preview, approximate'), findsOneWidget);

    // AI preview: asks first, with what is sent, kept and charged.
    final aiPicture = find.byWidgetPredicate((w) => w is Image && w.semanticLabel == 'AI preview');
    await tester.scrollUntilVisible(
      find.text('Try with AI (FASHN)'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await app.tapText('Try with AI (FASHN)');
    expect(find.text('Send your photo to FASHN?'), findsOneWidget);
    expect(find.text(providerTerms(CloudProvider.fashn).price), findsOneWidget);
    await app.tapText('Cancel');
    expect(sent, isEmpty);
    await app.tapText('Try with AI (FASHN)');
    await app.tapText('Agree and send');
    await app.waitFor(aiPicture);
    expect(aiPicture, findsOneWidget);
    expect(sent.first, 'POST https://api.fashn.ai/v1/run');
    // Agreed once: not asked again for the same key.
    sent.clear();
    await app.tapText('Try with AI (FASHN)');
    await app.waitFor(aiPicture);
    expect(find.text('Send your photo to FASHN?'), findsNothing);
    expect(sent, hasLength(2));
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('trousers are drawn on the legs with a waist and inside-leg note, or Chanda says why not', (
    tester,
  ) async {
    final bodies = FakeBodies(), garments = FakeGarments()..garment = cutoutOf(200, 370, trousers());
    final app = AppHarness(tester)..desktop();
    const url = 'https://www.shein.co.uk/Skirt-p-123.html';
    final grey = img.Image(width: bw, height: bh)..clear(img.ColorRgb8(128, 128, 128));
    await app.open(
      seed: (v) async {
        await seedVault(v);
        final item = (await v.items()).firstWhere((i) => i.title == 'Pleated midi skirt');
        await v.updateItem(
          item.copyWith(
            title: 'Slim stretch jeans',
            images: jsonEncode(['https://shop.example/side.jpg', 'https://shop.example/flat.jpg']),
          ),
        );
        final people = People(app.session.db);
        final p = await people.add(consent: DateTime.now());
        await people.save(p.copyWith(waist: () => 81, insideLeg: () => 79));
        await people.setPhoto(p.id, PhotoKind.body, preparePhoto(img.encodeJpg(grey))!);
      },
    );
    await app.run(
      pages: {
        url: const Evidence(
          url: url,
          tables: [
            [
              ['Size', 'Waist (cm)', 'Inside leg (cm)'],
              ['30', '74-78', '79'],
              ['32', '79-83', '79'],
            ],
          ],
        ),
      },
      extra: [
        tryOnProvider.overrideWith(_Downloaded.new),
        tryOnModelsProvider.overrideWith(
          (_) async =>
              TryOnModels(FakeFaces(), FakeFrames(), bodies: bodies, segmenter: bodies, garments: garments),
        ),
        itemPictureProvider.overrideWithValue((_, n, _) async => productPicture(n)),
      ],
    );
    await app.go('Vault');
    await app.tap(find.descendant(of: find.byType(ItemCard), matching: find.text('Slim stretch jeans')));
    await app.tapText('Try on');
    await app.waitFor(find.text('Fit preview, approximate'));
    expect(find.text('Cannot fit this photo'), findsNothing);
    await app.waitFor(find.text("Size note: within the chart's range"));
    expect(find.text("Waist 81 cm: within the chart's range for 32 (79–83 cm)."), findsOneWidget);
    expect(find.textContaining('Inside leg 79 cm: within'), findsOneWidget);
    await tester.pageBack();
    await app.settle();

    // Knees hidden on the body photo: nothing drawn, Chanda says so and
    // offers to change the photo.
    bodies.body = drawnBody(kneesShow: false);
    await app.tapText('Try on');
    await app.waitFor(find.text(bodyProblemText(BodyProblem.legs)));
    expect(find.text('Fit preview, approximate'), findsNothing);
    expect(find.text('Change my photo'), findsOneWidget);
    // No picture was cut again: the body photo is checked first.
    expect(garments.pictures, [0, 1]);
    expect(tester.takeException(), isNull);
    await app.close();
  });
}
