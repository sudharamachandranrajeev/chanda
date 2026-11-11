import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../app/providers.dart';
import '../domain/people.dart';
import 'common.dart';
import 'look.dart';

/// Takes or chooses a photo for [kind] and returns it ready to keep. The
/// picker's own copy in the temporary folder (Android makes one for every
/// photo) is deleted as soon as it is read; a file the user chose from
/// their own folders is left alone. Null when the user changes their mind.
Future<PersonPhoto?> pickPersonPhoto({bool camera = false}) async {
  final file = await ImagePicker().pickImage(
    source: camera ? ImageSource.camera : ImageSource.gallery,
    preferredCameraDevice: CameraDevice.front,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  await forgetPickerCopies(file.path);
  final photo = await Isolate.run(() => preparePhoto(bytes));
  if (photo == null) throw const FormatException('That is not a photo Chanda can use. Try another one.');
  return photo;
}

/// On Android, where the picker copies every photo into the app's own
/// temporary folder, deletes [path] if it is such a copy, and any other
/// copies the picker left there. A desktop picker hands back the user's
/// own file (and the temporary folder is shared with other apps), so
/// nothing is deleted there.
Future<void> forgetPickerCopies(String path) async {
  if (!Platform.isAndroid) return;
  try {
    final temp = (await getTemporaryDirectory()).path;
    if (isPickerCopy(path, temp)) {
      await File(path).delete();
      // Newer pickers put each copy in a folder of its own.
      final folder = File(path).parent;
      if (folder.path != Directory(temp).path && folder.listSync().isEmpty) await folder.delete();
    }
    for (final f in Directory(temp).listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      if (name.startsWith('image_picker') || name.startsWith('scaled_')) await f.delete();
    }
  } on Object catch (e) {
    debugPrint('Chanda: could not clear the photo picker copies: $e');
  }
}

/// The person kept for try-on: consent first, then their face and body
/// photos, sizes and pupil distance, and the way to delete it all.
class PersonPage extends ConsumerWidget {
  const PersonPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(personProvider);
    return PageScaffold(
      title: 'You, for try-on',
      body: AsyncView(person, builder: (p) => p == null ? const _Consent() : _Person(p)),
    );
  }
}

/// What keeping photos here means, asked before any photo is taken.
class _Consent extends ConsumerWidget {
  const _Consent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    Widget point(IconData icon, String s) =>
        ListTile(contentPadding: EdgeInsets.zero, leading: Icon(icon), title: Text(s));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Readable(
          child: SectionCard(
            title: 'Before you add photos',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Try-on shows glasses on a photo of your face, at their real size, and clothes on a photo of '
                  'your whole body, keeping your shape. Your sizes are set against a shop\'s size chart.',
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 8),
                point(
                  Icons.phone_android_outlined,
                  'Your photos and sizes stay on this device, in Chanda\'s locked database. They are never '
                  'synced to your other devices and never sent anywhere.',
                ),
                point(
                  Icons.memory_outlined,
                  'Try-on runs on this device. Nothing about your face or body leaves it.',
                ),
                point(
                  Icons.photo_outlined,
                  'Chanda never slims, smooths or changes your photo. It draws the product on top, at its '
                  'real size.',
                ),
                point(
                  Icons.delete_outline,
                  'You can delete your photos and sizes at any time. Deleting removes them from the database '
                  'file too.',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('I agree, add my photos'),
                      onPressed: () async {
                        await ref.read(peopleProvider).add(consent: DateTime.now());
                        ref.read(peopleRevisionProvider.notifier).bump();
                      },
                    ),
                    TextButton(onPressed: () => Navigator.maybePop(context), child: const Text('Not now')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Person extends ConsumerStatefulWidget {
  const _Person(this.person);
  final Person person;

  @override
  ConsumerState<_Person> createState() => _PersonState();
}

class _PersonState extends ConsumerState<_Person> {
  var _inches = false;
  var _busy = false;
  late final _fields = {
    for (final k in _sizes.keys) k: TextEditingController(text: _show(_sizes[k]!(widget.person))),
  };
  late final _pd = TextEditingController(text: widget.person.pd?.toString() ?? '');

  static final _sizes = <String, double? Function(Person)>{
    'Chest': (p) => p.chest,
    'Waist': (p) => p.waist,
    'Hip': (p) => p.hip,
    'Inside leg': (p) => p.insideLeg,
    'Shoulder width': (p) => p.shoulder,
  };

  String _show(double? cm) => cm == null ? '' : showLength(cm, inches: _inches).split(' ').first;

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    _pd.dispose();
    super.dispose();
  }

  void _changed() => ref.read(peopleRevisionProvider.notifier).bump();

  Future<void> _photo(PhotoKind kind, {bool camera = false}) async {
    setState(() => _busy = true);
    try {
      final photo = await pickPersonPhoto(camera: camera);
      if (photo == null) return;
      await ref.read(peopleProvider).setPhoto(widget.person.id, kind, photo);
      _changed();
    } on Object catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _units(bool inches) {
    // Re-show what is typed in the other unit.
    final typed = {for (final e in _fields.entries) e.key: parseLength(e.value.text, inches: _inches)};
    setState(() {
      _inches = inches;
      for (final e in _fields.entries) {
        e.value.text = _show(typed[e.key]);
      }
    });
  }

  Future<void> _saveSizes() async {
    // A new answer replaces the last one instead of queueing behind it.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final got = <String, double?>{};
    for (final e in _fields.entries) {
      final t = e.value.text.trim();
      got[e.key] = t.isEmpty ? null : parseLength(t, inches: _inches);
      if (t.isNotEmpty && got[e.key] == null) {
        return showMessage(context, '${e.key}: type a size in ${_inches ? 'inches' : 'centimetres'}.');
      }
    }
    final pdText = _pd.text.trim();
    final pd = pdText.isEmpty ? null : parsePd(pdText);
    if (pdText.isNotEmpty && pd == null) {
      return showMessage(context, 'Pupil distance: type it in millimetres, for example 63 or 31.5/32.');
    }
    final p = (await ref.read(peopleProvider).byId(widget.person.id))!;
    await ref
        .read(peopleProvider)
        .save(
          p.copyWith(
            chest: () => got['Chest'],
            waist: () => got['Waist'],
            hip: () => got['Hip'],
            insideLeg: () => got['Inside leg'],
            shoulder: () => got['Shoulder width'],
            pd: () => pd,
          ),
        );
    _changed();
    if (mounted) showMessage(context, 'Sizes saved.');
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Delete your photos and sizes?',
      message: 'Your face and body photos, sizes and pupil distance are deleted from this device.',
      action: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(peopleProvider).delete(widget.person.id);
    _changed();
    if (mounted) showMessage(context, 'Deleted.');
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.person;
    final thumbs = ref.watch(personThumbsProvider(p.id)).value ?? const {};
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Readable(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PhotoCard(
                title: 'Face photo',
                guide:
                    'Look straight at the camera with your head level, in even light. Take glasses off and keep '
                    'hair away from your eyes. Hold the camera at eye level, about an arm\'s length away.',
                thumb: thumbs[PhotoKind.face],
                busy: _busy,
                onPick: (camera) => _photo(PhotoKind.face, camera: camera),
                onRemove: () async {
                  await ref.read(peopleProvider).removePhoto(p.id, PhotoKind.face);
                  _changed();
                },
              ),
              _PhotoCard(
                title: 'Body photo',
                guide:
                    'Stand straight, facing the camera, with your arms a little away from your sides. Wear '
                    'fitted clothes and stand against a plain wall, the whole of you in the picture. Have the '
                    'camera at waist height, two to three metres away. Used to show clothes on you.',
                figure: true,
                thumb: thumbs[PhotoKind.body],
                busy: _busy,
                onPick: (camera) => _photo(PhotoKind.body, camera: camera),
                onRemove: () async {
                  await ref.read(peopleProvider).removePhoto(p.id, PhotoKind.body);
                  _changed();
                },
              ),
              SectionCard(
                title: 'Your sizes',
                trailing: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('cm')),
                    ButtonSegment(value: true, label: Text('in')),
                  ],
                  selected: {_inches},
                  onSelectionChanged: (s) => _units(s.single),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Measure your body, not your clothes. Leave out any you do not know.',
                      style: text.bodyMedium?.copyWith(color: muted(context)),
                    ),
                    const SizedBox(height: 12),
                    for (final e in _fields.entries)
                      Field(e.value, '${e.key} (${_inches ? 'in' : 'cm'})', number: true),
                    Field(_pd, 'Pupil distance (mm)', hint: 'From your glasses prescription: 63, or 31.5/32'),
                    Text(
                      'With your pupil distance, glasses are sized from it instead of from your iris, which is '
                      'a little more exact.',
                      style: text.bodySmall?.copyWith(color: muted(context)),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(onPressed: _saveSizes, child: const Text('Save sizes')),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'You agreed to keep these on this device on '
                  '${DateFormat.yMMMd().format(p.consent.toLocal())}.',
                  style: text.bodySmall?.copyWith(color: muted(context)),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete my photos and sizes'),
                  style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                  onPressed: _delete,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One of the person's photos: how to take it, the photo, and buttons.
class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.title,
    required this.guide,
    required this.thumb,
    required this.busy,
    required this.onPick,
    required this.onRemove,
    this.figure = false,
  });
  final String title;
  final String guide;
  final Uint8List? thumb;
  final bool busy;
  final bool figure;
  final void Function(bool camera) onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final picture = SizedBox(
      width: 96,
      height: 128,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: thumb != null
            ? Image.memory(thumb!, fit: BoxFit.cover, gaplessPlayback: true)
            : ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: figure
                    ? CustomPaint(painter: _FigurePainter(muted(context)))
                    : Icon(Icons.face_outlined, size: 48, color: muted(context)),
              ),
      ),
    );
    return SectionCard(
      title: title,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          picture,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(guide, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (Platform.isAndroid)
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Take a photo'),
                        onPressed: busy ? null : () => onPick(true),
                      ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(thumb == null ? 'Choose a photo' : 'Choose another'),
                      onPressed: busy ? null : () => onPick(false),
                    ),
                    if (thumb != null)
                      TextButton(onPressed: busy ? null : onRemove, child: const Text('Remove')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// An outline of a person standing with arms a little out: how to stand
/// for the body photo.
class _FigurePainter extends CustomPainter {
  const _FigurePainter(this.colour);
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final pen = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(w / 2, h * 0.14), h * 0.07, pen);
    final body = Path()
      ..moveTo(w / 2, h * 0.21)
      ..lineTo(w / 2, h * 0.55)
      // Arms, a little away from the sides.
      ..moveTo(w / 2, h * 0.27)
      ..lineTo(w * 0.27, h * 0.5)
      ..moveTo(w / 2, h * 0.27)
      ..lineTo(w * 0.73, h * 0.5)
      // Legs.
      ..moveTo(w / 2, h * 0.55)
      ..lineTo(w * 0.38, h * 0.9)
      ..moveTo(w / 2, h * 0.55)
      ..lineTo(w * 0.62, h * 0.9);
    canvas.drawPath(body, pen);
  }

  @override
  bool shouldRepaint(_FigurePainter old) => old.colour != colour;
}
