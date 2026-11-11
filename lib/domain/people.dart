import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:brahma_core/brahma_core.dart' show newId;
import 'package:drift/drift.dart' show Variable;
import 'package:image/image.dart' as img;

import '../db/database.dart';
import 'vault.dart' show nowIso;

// Saved people for try-on: a face photo, a full-body photo, body
// measurements and the pupil distance. They stay on this device, inside the
// encrypted database, in two tables that are never synced. Photos are kept
// as resized JPEGs with no metadata (no location, no camera details) and are
// only ever decoded in memory. Deleting a person deletes the rows and then
// compacts the database file; secure_delete (lib/db/database.dart) has
// already overwritten the freed pages.
//
// The tables allow several people; the app shows one for now.

/// Which of a person's photos.
enum PhotoKind {
  /// Head and shoulders, looking at the camera: for glasses.
  face,

  /// Full body from the front, arms a little away from the sides: for
  /// clothes.
  body,
}

/// One saved person.
class Person {
  const Person({
    required this.id,
    required this.consent,
    this.name = '',
    this.chest,
    this.waist,
    this.hip,
    this.insideLeg,
    this.shoulder,
    this.pd,
    this.pupils,
  });

  final String id;
  final String name;

  /// When the person agreed to keep their photos and sizes on this device.
  final DateTime consent;

  /// Body measurements in centimetres.
  final double? chest, waist, hip, insideLeg, shoulder;

  /// Pupil distance in millimetres, as typed.
  final double? pd;

  /// The pupils on the face photo where the person put them (image pixels:
  /// right-eye x, y, then left-eye x, y), or null to use the found ones.
  final List<double>? pupils;

  Person copyWith({
    String? name,
    double? Function()? chest,
    double? Function()? waist,
    double? Function()? hip,
    double? Function()? insideLeg,
    double? Function()? shoulder,
    double? Function()? pd,
    List<double>? Function()? pupils,
  }) => Person(
    id: id,
    consent: consent,
    name: name ?? this.name,
    chest: chest == null ? this.chest : chest(),
    waist: waist == null ? this.waist : waist(),
    hip: hip == null ? this.hip : hip(),
    insideLeg: insideLeg == null ? this.insideLeg : insideLeg(),
    shoulder: shoulder == null ? this.shoulder : shoulder(),
    pd: pd == null ? this.pd : pd(),
    pupils: pupils == null ? this.pupils : pupils(),
  );
}

/// A stored photo: the JPEG, a small copy for lists, and its size.
class PersonPhoto {
  const PersonPhoto(this.jpeg, this.thumb, this.width, this.height);
  final Uint8List jpeg;
  final Uint8List thumb;
  final int width;
  final int height;
}

/// The saved people, in the app's database.
class People {
  People(this.db);
  final AppDatabase db;

  Future<List<Person>> all() async => [
    for (final r in await db.customSelect('SELECT * FROM chanda_people ORDER BY created').get())
      _person(r.data),
  ];

  /// The one person the app shows today.
  Future<Person?> first() async => (await all()).firstOrNull;

  Future<Person?> byId(String id) async {
    final r = await db
        .customSelect('SELECT * FROM chanda_people WHERE id = ?', variables: [Variable(id)])
        .getSingleOrNull();
    return r == null ? null : _person(r.data);
  }

  /// Adds a person once they have agreed, at [consent], to keep their
  /// photos and sizes here.
  Future<Person> add({required DateTime consent, String name = ''}) async {
    final p = Person(id: newId(), consent: consent.toUtc(), name: name);
    final now = nowIso();
    await db.customStatement(
      'INSERT INTO chanda_people (id, name, consent, created, updated) VALUES (?, ?, ?, ?, ?)',
      [p.id, p.name, p.consent.toIso8601String(), now, now],
    );
    return p;
  }

  /// Saves [p]'s name, sizes, pupil distance and pupil marks.
  Future<void> save(Person p) => db.customStatement(
    'UPDATE chanda_people SET name = ?, chest = ?, waist = ?, hip = ?, inside_leg = ?, shoulder = ?, pd = ?, '
    'pupils = ?, updated = ? WHERE id = ?',
    [
      p.name,
      p.chest,
      p.waist,
      p.hip,
      p.insideLeg,
      p.shoulder,
      p.pd,
      p.pupils == null ? null : jsonEncode(p.pupils),
      nowIso(),
      p.id,
    ],
  );

  /// Keeps [photo] as [person]'s [kind] photo, replacing any before. A new
  /// face photo clears the pupil marks made on the old one.
  Future<void> setPhoto(String person, PhotoKind kind, PersonPhoto photo) => db.transaction(() async {
    await db.customStatement(
      'INSERT INTO chanda_person_photos (person_id, kind, jpeg, thumb, width, height, added) '
      'VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT(person_id, kind) DO UPDATE SET jpeg = excluded.jpeg, '
      'thumb = excluded.thumb, width = excluded.width, height = excluded.height, added = excluded.added',
      [person, kind.name, photo.jpeg, photo.thumb, photo.width, photo.height, nowIso()],
    );
    if (kind == PhotoKind.face) {
      await db.customStatement('UPDATE chanda_people SET pupils = NULL WHERE id = ?', [person]);
    }
  });

  Future<PersonPhoto?> photo(String person, PhotoKind kind) async {
    final r = await db
        .customSelect(
          'SELECT jpeg, thumb, width, height FROM chanda_person_photos WHERE person_id = ? AND kind = ?',
          variables: [Variable(person), Variable(kind.name)],
        )
        .getSingleOrNull();
    return r == null
        ? null
        : PersonPhoto(
            r.read<Uint8List>('jpeg'),
            r.read<Uint8List>('thumb'),
            r.read<int>('width'),
            r.read<int>('height'),
          );
  }

  /// The small copies of [person]'s photos, by kind.
  Future<Map<PhotoKind, Uint8List>> thumbs(String person) async => {
    for (final r
        in await db
            .customSelect(
              'SELECT kind, thumb FROM chanda_person_photos WHERE person_id = ?',
              variables: [Variable(person)],
            )
            .get())
      PhotoKind.values.byName(r.read<String>('kind')): r.read<Uint8List>('thumb'),
  };

  Future<void> removePhoto(String person, PhotoKind kind) => db.customStatement(
    'DELETE FROM chanda_person_photos WHERE person_id = ? AND kind = ?',
    [person, kind.name],
  );

  /// Deletes [person], their photos and sizes, then compacts the database
  /// file so nothing of them is left in it.
  Future<void> delete(String person) async {
    await db.transaction(() async {
      await db.customStatement('DELETE FROM chanda_person_photos WHERE person_id = ?', [person]);
      await db.customStatement('DELETE FROM chanda_people WHERE id = ?', [person]);
    });
    await db.customStatement('VACUUM');
  }

  static Person _person(Map<String, Object?> r) {
    double? d(String k) => (r[k] as num?)?.toDouble();
    final pupils = r['pupils'] as String?;
    return Person(
      id: r['id']! as String,
      name: r['name'] as String? ?? '',
      consent: DateTime.parse(r['consent']! as String),
      chest: d('chest'),
      waist: d('waist'),
      hip: d('hip'),
      insideLeg: d('inside_leg'),
      shoulder: d('shoulder'),
      pd: d('pd'),
      pupils: pupils == null ? null : [for (final v in jsonDecode(pupils) as List) (v as num).toDouble()],
    );
  }
}

/// The longest side a kept photo may have, in pixels.
const photoSide = 1536;

/// [bytes] (a photo as picked) made ready to keep: turned upright, at most
/// [maxSide] pixels on its long side, JPEG with no metadata at all, plus a
/// 256-pixel copy. Never retouched: only scaled. Null when it is not a
/// picture or is too small to be any use. Pure: run it off the main thread.
PersonPhoto? preparePhoto(Uint8List bytes, {int maxSide = photoSide}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null || min(decoded.width, decoded.height) < 200) return null;
  // Apply the camera's rotation, then drop every bit of metadata.
  final upright = img.bakeOrientation(decoded).convert(numChannels: 3, format: img.Format.uint8);
  img.Image fit(int side) {
    final long = max(upright.width, upright.height);
    final out = long <= side
        ? upright.clone()
        : img.copyResize(
            upright,
            width: upright.width >= upright.height ? side : null,
            height: upright.height > upright.width ? side : null,
            interpolation: img.Interpolation.average,
          );
    out.exif = img.ExifData();
    out.iccProfile = null;
    out.textData = null;
    return out;
  }

  final full = fit(maxSide);
  return PersonPhoto(
    img.encodeJpg(full, quality: 90),
    img.encodeJpg(fit(256), quality: 80),
    full.width,
    full.height,
  );
}

/// Whether [path] is a copy the photo picker made in the app's temporary
/// folder [temp] (Android copies every pick there), which must be deleted
/// once read. A file the user chose from their own folders is never one.
bool isPickerCopy(String path, String temp) {
  if (temp.isEmpty) return false;
  final dir = temp.endsWith(Platform.pathSeparator) ? temp : '$temp${Platform.pathSeparator}';
  return path.startsWith(dir) && !path.contains('..');
}

/// A body measurement typed as [text], in inches when [inches], as
/// centimetres. Accepts "86", "86.5", "34 in", "34\"" and "86 cm" (a unit
/// typed wins). Null when it is not a number or not a believable size
/// (10 to 250 cm).
double? parseLength(String text, {bool inches = false}) {
  final t = text.trim().toLowerCase().replaceAll(',', '.');
  final m = RegExp(r'^(\d+(?:\.\d+)?)\s*(cm|in|inch|inches|"|”)?$').firstMatch(t);
  if (m == null) return null;
  final n = double.parse(m.group(1)!);
  final unit = m.group(2);
  final cm = (unit == null ? inches : unit != 'cm') ? n * 2.54 : n;
  return cm >= 10 && cm <= 250 ? cm : null;
}

/// A typed pupil distance in millimetres: "63", "63.5", or the two
/// half-distances an optician writes as "31.5/32". Null outside 45-80 mm.
double? parsePd(String text) {
  final t = text.trim().toLowerCase().replaceAll(',', '.').replaceAll('mm', '').trim();
  final parts = t.split(RegExp(r'\s*[/+]\s*'));
  if (parts.length > 2) return null;
  var sum = 0.0;
  for (final p in parts) {
    final n = double.tryParse(p);
    if (n == null) return null;
    sum += n;
  }
  if (parts.length == 2 && (sum / 2 < 22 || sum / 2 > 40)) return null;
  return sum >= 45 && sum <= 80 ? sum : null;
}

/// [cm] for showing: "86 cm" or, in inches, "33.9 in".
String showLength(double cm, {bool inches = false}) {
  final v = inches ? cm / 2.54 : cm;
  final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  return '$s ${inches ? 'in' : 'cm'}';
}
