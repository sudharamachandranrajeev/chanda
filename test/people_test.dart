import 'dart:io';
import 'dart:typed_data';

import 'package:chanda/db/database.dart';
import 'package:chanda/domain/people.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'support.dart';

/// A plain test picture with a camera's metadata, location included.
Uint8List cameraJpeg({int w = 800, int h = 600, int orientation = 1}) {
  final p = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      p.setPixelRgb(x, y, x * 255 ~/ w, y * 255 ~/ h, 90);
    }
  }
  p.exif.imageIfd['Make'] = img.IfdValueAscii('TestCam');
  p.exif.imageIfd['Orientation'] = img.IfdValueShort(orientation);
  p.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(51, 1);
  return img.encodeJpg(p);
}

bool hasMeta(Uint8List jpeg) {
  final s = String.fromCharCodes(jpeg.take(4096));
  return s.contains('Exif') || s.contains('TestCam');
}

void main() {
  test('a picked photo is kept upright, smaller, with no metadata, and a small copy', () {
    final raw = cameraJpeg(w: 3000, h: 2000, orientation: 6);
    expect(hasMeta(raw), isTrue);
    final p = preparePhoto(raw)!;
    // Orientation 6: the camera was turned, so the kept photo stands up.
    expect((p.width, p.height), (1024, 1536));
    expect(hasMeta(p.jpeg), isFalse);
    expect(hasMeta(p.thumb), isFalse);
    final back = img.decodeJpg(p.jpeg)!;
    expect(back.hasExif && !back.exif.isEmpty, isFalse);
    expect(img.decodeJpg(p.thumb)!.height, 256);
    // A small photo is not made bigger.
    expect(preparePhoto(cameraJpeg())!.width, 800);
    expect(preparePhoto(Uint8List.fromList([1, 2, 3])), isNull);
    expect(preparePhoto(cameraJpeg(w: 120, h: 90)), isNull);
  });

  test('only the picker\'s own copies in the temporary folder are deleted', () {
    final sep = Platform.pathSeparator;
    final temp = '${sep}data${sep}cache';
    expect(isPickerCopy('$temp${sep}image_picker123.jpg', temp), isTrue);
    expect(isPickerCopy('${sep}home${sep}me${sep}Pictures${sep}me.jpg', temp), isFalse);
    expect(isPickerCopy('${temp}2${sep}x.jpg', temp), isFalse);
    expect(isPickerCopy('$temp$sep..${sep}x.jpg', temp), isFalse);
    expect(isPickerCopy('$temp${sep}x.jpg', ''), isFalse);
  });

  test('sizes typed in centimetres or inches, and the pupil distance', () {
    expect(parseLength('86'), 86);
    expect(parseLength('86,5'), 86.5);
    expect(parseLength('34', inches: true), closeTo(86.36, 1e-9));
    expect(parseLength('34"'), closeTo(86.36, 1e-9));
    expect(parseLength('34 in'), closeTo(86.36, 1e-9));
    expect(parseLength('86 cm', inches: true), 86);
    expect(parseLength('tall'), isNull);
    expect(parseLength('3'), isNull);
    expect(parseLength('400'), isNull);
    expect(showLength(86.36, inches: true), '34 in');
    expect(showLength(86.5), '86.5 cm');
    expect(parsePd('63'), 63);
    expect(parsePd('63.5 mm'), 63.5);
    expect(parsePd('31.5/32'), 63.5);
    expect(parsePd('63/64'), isNull);
    expect(parsePd('120'), isNull);
    expect(parsePd('six'), isNull);
  });

  test('a person is kept with photos and sizes, never synced, and deleting removes every row', () async {
    final db = memoryDatabase();
    final people = People(db);
    final consent = DateTime.utc(2026, 11, 11, 9);
    final p = await people.add(consent: consent);
    expect((await people.first())!.consent, consent);
    await people.save(p.copyWith(chest: () => 96, pd: () => 63, pupils: () => [10, 20, 70, 21]));
    final face = preparePhoto(cameraJpeg())!;
    await people.setPhoto(p.id, PhotoKind.body, preparePhoto(cameraJpeg(w: 600, h: 900))!);
    await people.setPhoto(p.id, PhotoKind.face, face);
    var got = (await people.byId(p.id))!;
    expect(got.chest, 96);
    expect(got.pd, 63);
    // A new face photo clears the pupil marks made on the old one.
    expect(got.pupils, isNull);
    await people.save(got.copyWith(pupils: () => [10, 20, 70, 21]));
    got = (await people.byId(p.id))!;
    expect(got.pupils, [10, 20, 70, 21]);
    expect((await people.photo(p.id, PhotoKind.face))!.jpeg, face.jpeg);
    expect((await people.thumbs(p.id)).keys, unorderedEquals(PhotoKind.values));

    // Local only: not a synced table, and nothing waits in the outbox.
    expect(db.syncedTables, isNot(contains('chanda_people')));
    expect(db.syncedTables, isNot(contains('chanda_person_photos')));
    expect((await db.customSelect('SELECT COUNT(*) AS n FROM outbox').getSingle()).read<int>('n'), 0);

    await people.delete(p.id);
    expect(await people.all(), isEmpty);
    expect(
      (await db.customSelect('SELECT COUNT(*) AS n FROM chanda_person_photos').getSingle()).read<int>('n'),
      0,
    );
    await db.close();
  });

  test('secure_delete is on for the database', () async {
    final db = memoryDatabase();
    expect((await db.customSelect('PRAGMA secure_delete').getSingle()).data.values.single, 1);
    await db.close();
  });

  test('a schema-3 database gains the people tables and keeps its data', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final dir = await Directory.systemTemp.createTemp('chanda-migrate');
    final file = File('${dir.path}/db.sqlite');
    try {
      // Make a schema-3 file: today's schema without the people tables.
      var db = AppDatabase(NativeDatabase(file));
      await db.setLocalSetting('kept', 'yes');
      await db.customStatement('DROP TABLE chanda_person_photos');
      await db.customStatement('DROP TABLE chanda_people');
      await db.customStatement('PRAGMA user_version = 3');
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      expect(await db.localSetting('kept'), 'yes');
      final p = await People(db).add(consent: DateTime.utc(2026));
      expect((await People(db).first())!.id, p.id);
      expect((await db.customSelect('PRAGMA user_version').getSingle()).data.values.single, 4);
      await db.close();
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
