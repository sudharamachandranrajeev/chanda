import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../app/providers.dart';
import '../app/settings_page.dart' show ModelCard, tryOnAbout;
import '../db/database.dart';
import '../domain/face_fit.dart';
import '../domain/frame_size.dart';
import '../domain/glasses_fit.dart';
import '../domain/people.dart';
import '../domain/tryon.dart';
import '../domain/vault.dart';
import 'common.dart';
import 'item_bits.dart';
import 'look.dart';
import 'person_page.dart';

// Kept outside the page's classes so the work sent to another isolate
// carries only the bytes, not the page.
Future<Rgb?> _decode(Uint8List jpeg) => Isolate.run(() => decodeRgb(jpeg));

Future<Uint8List> _png(Cutout cut) => Isolate.run(
  () => img.encodePng(
    img.Image.fromBytes(width: cut.width, height: cut.height, bytes: cut.rgba.buffer, numChannels: 4),
  ),
);

/// Glasses from the vault drawn on the person's face photo at their real
/// size. When anything needed for a fair fit is missing it says what, and
/// draws nothing.
class GlassesPage extends ConsumerWidget {
  const GlassesPage(this.item, {super.key});
  final VaultItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tryOnProvider).value ?? const ModelState();
    final person = ref.watch(personProvider);
    Widget body;
    if (!state.present || state.downloading) {
      body = ModelCard(
        provider: tryOnProvider,
        title: 'Try-on needs a download',
        switchLabel: 'Try things on',
        about: tryOnAbout,
      );
    } else if (!state.on) {
      body = SectionCard(
        title: 'Try-on is off',
        child: Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: () => ref.read(tryOnProvider.notifier).setOn(true),
            child: const Text('Turn try-on on'),
          ),
        ),
      );
    } else {
      body = AsyncView(
        person,
        builder: (p) {
          final face = p == null ? null : ref.watch(personThumbsProvider(p.id)).value?[PhotoKind.face];
          if (p == null || face == null) {
            return SectionCard(
              title: 'Add a photo of your face',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Try-on draws the glasses on a photo of your face, kept only on this device.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.face_outlined),
                    label: const Text('Add my photo'),
                    onPressed: () =>
                        Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const PersonPage())),
                  ),
                ],
              ),
            );
          }
          return AsyncView(
            ref.watch(tryOnModelsProvider),
            builder: (m) => m == null
                ? const SectionCard(
                    title: 'Try-on could not start',
                    child: Text(
                      'The try-on download could not be opened. Remove it in Settings and download it again.',
                    ),
                  )
                // A new face photo starts the fit again.
                : _Fit(key: ValueKey(Object.hashAll(face)), models: m, person: p, item: item),
          );
        },
      );
    }
    return PageScaffold(
      title: 'Try on',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [Readable(child: body)],
      ),
    );
  }
}

class _Fit extends ConsumerStatefulWidget {
  const _Fit({super.key, required this.models, required this.person, required this.item});
  final TryOnModels models;
  final Person person;
  final VaultItem item;

  @override
  ConsumerState<_Fit> createState() => _FitState();
}

class _FitState extends ConsumerState<_Fit> {
  String? _step = 'Finding your face…';
  PersonPhoto? _photo;
  FaceReading? _face;
  FaceProblem? _faceProblem;
  FrameSize? _frame;
  var _frameLooked = false;
  int? _picture;
  Cutout? _cut;
  Uint8List? _cutPng;
  final _cutProblems = <int, CutoutProblem>{};

  /// The pupils as placed by hand: right x, y, then left x, y.
  List<double>? _pupils;

  VaultItem get _item => widget.item;

  @override
  void initState() {
    super.initState();
    _pupils = widget.person.pupils;
    _start();
  }

  Future<void> _start() async {
    try {
      final people = ref.read(peopleProvider);
      final photo = await people.photo(widget.person.id, PhotoKind.face);
      if (photo == null) return;
      final rgb = await _decode(photo.jpeg);
      final faces = rgb == null ? const <FaceReading>[] : await widget.models.faces.find(rgb);
      if (!mounted) return;
      final problem = faceProblem(faces);
      setState(() {
        _photo = photo;
        _faceProblem = problem;
        _face = problem == null ? faces.single : null;
        _step = problem == null ? 'Finding the frame\'s size…' : null;
      });
      if (problem != null) return;
      final frame = await _findFrame();
      if (!mounted) return;
      setState(() {
        _frame = frame;
        _frameLooked = true;
        _step = 'Cutting the frame out of its picture…';
      });
      // Shops often show a frame from the side first: try each picture until
      // one shows it from the front.
      for (var n = 0; n < _pictures; n++) {
        if (await _cutOut(n)) break;
      }
    } on Object catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _step = null);
    }
  }

  int get _pictures => min(imagesOf(_item).length, 5);

  /// The frame's size: kept from before, else from the item's own words,
  /// else from its page. Kept for next time when found.
  Future<FrameSize?> _findFrame() async {
    final db = ref.read(sessionProvider).db;
    final kept = await db.localSetting(frameSetting(_item.id));
    if (kept != null) {
      try {
        if (FrameSize.fromJson(jsonDecode(kept)) case final s?) return s;
      } on FormatException {
        // Kept wrongly: look again.
      }
    }
    var found = frameSizeInItem(_item.title, _item.description);
    if (found == null) {
      try {
        found = frameSizeOnPage(await ref.read(readerProvider).read(Uri.parse(_item.url)));
      } on Object catch (e) {
        debugPrint('Chanda: could not read the frame size from the page: $e');
      }
    }
    if (found?.width == null) return null;
    await db.setLocalSetting(frameSetting(_item.id), jsonEncode(found!.toJson()));
    return found;
  }

  /// Cuts picture [n] out; whether it worked.
  Future<bool> _cutOut(int n) async {
    setState(() {
      _picture = n;
      _step = 'Cutting the frame out of its picture…';
    });
    try {
      final bytes = await ref.read(itemPictureProvider)(_item.id, n, imagesOf(_item)[n]);
      final (cut, problem) = bytes == null
          ? (null, CutoutProblem.empty)
          : await widget.models.frames.cut(bytes);
      final png = cut == null ? null : await _png(cut);
      if (!mounted) return false;
      setState(() {
        if (cut != null) {
          _cut = cut;
          _cutPng = png;
          _cutProblems.remove(n);
        } else {
          _cut = null;
          _cutPng = null;
          _cutProblems[n] = problem!;
        }
      });
      return cut != null;
    } finally {
      if (mounted) setState(() => _step = null);
    }
  }

  Future<void> _typeFrame() async {
    final total = TextEditingController(text: _frame?.total?.round().toString() ?? '');
    final marking = TextEditingController(text: _frame?.marking ?? '');
    await showFormDialog(
      context,
      title: 'Frame size',
      fields: (_) => [
        const Text(
          'Type the frame\'s total width from the shop\'s page, or the size printed inside the arm, such as '
          '52-18-140 (lens, bridge and arm, in millimetres).',
        ),
        const SizedBox(height: 12),
        Field(total, 'Total width (mm)', number: true, autofocus: true),
        Field(marking, 'Size inside the arm', hint: '52-18-140'),
      ],
      onSave: () async {
        final s = typedFrameSize(total: total.text, marking: marking.text);
        if (s?.width == null) {
          return 'Type a total width (such as 136) or a size such as 52-18-140.';
        }
        await ref.read(sessionProvider).db.setLocalSetting(frameSetting(_item.id), jsonEncode(s!.toJson()));
        setState(() => _frame = s);
        return null;
      },
    );
  }

  Future<void> _savePupils(List<double>? pupils) async {
    setState(() => _pupils = pupils);
    final people = ref.read(peopleProvider);
    final p = await people.byId(widget.person.id);
    if (p == null) return;
    await people.save(p.copyWith(pupils: () => pupils));
    ref.read(peopleRevisionProvider.notifier).bump();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final note = text.bodyMedium?.copyWith(color: muted(context));
    final photo = _photo;
    final face = _face;
    final children = <Widget>[];

    if (_faceProblem != null) {
      children.add(_Problem(faceProblemText(_faceProblem!), action: 'Change my photo'));
    }
    if (photo != null && face != null) {
      final right = _pupils == null ? face.rightPupil : Point(_pupils![0], _pupils![1]);
      final left = _pupils == null ? face.leftPupil : Point(_pupils![2], _pupils![3]);
      final scale = faceScale(
        right: right,
        left: left,
        irisPx: face.irisWidth,
        yaw: face.yaw,
        typedPd: widget.person.pd,
      );
      final frame = _frame;
      final cut = _cut;
      final place = frame?.width == null || cut == null
          ? null
          : placeGlasses(
              right: right,
              left: left,
              pxPerMm: scale.pxPerMm,
              frameMm: frame!.width!,
              aspect: cut.aspect,
              yaw: face.yaw,
              bridgeOffset: face.bridgeOffset,
            );
      children.add(
        _Picture(
          photo: photo,
          glasses: place == null ? null : (place, _cutPng!),
          right: right,
          left: left,
          onPupils: _savePupils,
        ),
      );
      final lines = <String>[
        if (place != null) scale.describe,
        if (place != null)
          'So the frame drawn is within about ±${(frame!.width! * scale.tolerance).toStringAsFixed(0)} mm '
              'of its real width.',
        if (frame != null) frame.describe,
        if (degrees(face.yaw).abs() > warnYawDegrees)
          'Your head is turned a little on this photo, so the fit is less exact.',
        if (scale.source == ScaleSource.iris)
          'Your pupil distance measures about ${measuredPd(right, left, scale, yaw: face.yaw).toStringAsFixed(0)} '
              'mm on this photo. Typing yours under your photos and sizes makes the fit more exact.',
        'Your face is about ${faceWidthMm(face, scale.pxPerMm).toStringAsFixed(0)} mm wide at the cheekbones'
            '${frame?.width == null ? '' : '; this frame is ${frame!.width!.toStringAsFixed(0)} mm'}.',
        'If the circles are not on the middle of your pupils, drag them there.',
      ];
      children.add(const SizedBox(height: 12));
      for (final l in lines) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(l, style: note),
          ),
        );
      }
      children.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.straighten),
              label: Text(frame == null ? 'Type the frame size' : 'Change the frame size'),
              onPressed: _typeFrame,
            ),
            if (_pupils != null)
              TextButton(onPressed: () => _savePupils(null), child: const Text('Put the circles back')),
          ],
        ),
      );
      if (_frameLooked && frame == null) {
        children.add(
          const _Problem(
            'Chanda could not find this frame\'s size in the listing. Type it to see the glasses at their '
            'real size.',
          ),
        );
      }
      if (_pictures > 0) {
        children.add(const SizedBox(height: 16));
        children.add(Text('Product picture', style: text.titleSmall));
        children.add(const SizedBox(height: 8));
        children.add(
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var n = 0; n < _pictures; n++)
                InkWell(
                  onTap: _step != null ? null : () => _cutOut(n),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        width: 2,
                        color: n == _picture ? Theme.of(context).colorScheme.primary : Colors.transparent,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ItemImage(_item, index: n, fit: BoxFit.contain),
                  ),
                ),
            ],
          ),
        );
        if (_cutProblems[_picture] case final p?) children.add(_Problem(cutoutProblemText(p)));
      } else if (_frameLooked) {
        children.add(const _Problem('This item has no product picture to try on.'));
      }
    }
    if (_step != null) {
      children.insert(
        0,
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 10),
              Expanded(child: Text(_step!)),
            ],
          ),
        ),
      );
    }
    return SectionCard(
      title: _item.title,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

/// A plain-words reason the fit cannot be shown, with an optional way to
/// change the photo.
class _Problem extends StatelessWidget {
  const _Problem(this.message, {this.action});
  final String message;
  final String? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        if (action != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              onPressed: () =>
                  Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const PersonPage())),
              child: Text(action!),
            ),
          ),
      ],
    ),
  );
}

/// The face photo as it is, the frame drawn over it, and the two pupil
/// circles that can be dragged.
class _Picture extends StatefulWidget {
  const _Picture({
    required this.photo,
    required this.glasses,
    required this.right,
    required this.left,
    required this.onPupils,
  });
  final PersonPhoto photo;
  final (GlassesPlacement, Uint8List)? glasses;
  final Px right, left;
  final ValueChanged<List<double>> onPupils;

  @override
  State<_Picture> createState() => _PictureState();
}

class _PictureState extends State<_Picture> {
  /// Which circle is being dragged (0 right, 1 left) and where it is now.
  int? _dragging;
  Px? _at;

  @override
  Widget build(BuildContext context) {
    final w = widget.photo.width.toDouble(), h = widget.photo.height.toDouble();
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final height = min(width * h / w, 560.0);
        final k = min(width / w, height / h);
        final r = 10 / k;
        final right = _dragging == 0 ? _at! : widget.right;
        final left = _dragging == 1 ? _at! : widget.left;
        final g = widget.glasses;
        return SizedBox(
          height: height,
          child: FittedBox(
            child: SizedBox(
              width: w,
              height: h,
              child: GestureDetector(
                onPanStart: (d) {
                  final p = Point(d.localPosition.dx, d.localPosition.dy);
                  final dr = p.distanceTo(widget.right), dl = p.distanceTo(widget.left);
                  if (min(dr, dl) > r * 3) return;
                  setState(() {
                    _dragging = dr <= dl ? 0 : 1;
                    _at = p;
                  });
                },
                onPanUpdate: (d) {
                  if (_dragging == null) return;
                  setState(() => _at = Point(d.localPosition.dx.clamp(0, w), d.localPosition.dy.clamp(0, h)));
                },
                onPanEnd: (_) {
                  if (_dragging == null) return;
                  final (rr, ll) = (right, left);
                  setState(() => _dragging = null);
                  widget.onPupils([rr.x, rr.y, ll.x, ll.y]);
                },
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(child: Image.memory(widget.photo.jpeg, gaplessPlayback: true)),
                    if (g != null)
                      Positioned(
                        left: g.$1.centre.x - g.$1.width / 2,
                        top: g.$1.centre.y - g.$1.height / 2,
                        width: g.$1.width,
                        height: g.$1.height,
                        child: IgnorePointer(
                          child: Transform.rotate(
                            angle: g.$1.angle,
                            child: Image.memory(g.$2, fit: BoxFit.fill, gaplessPlayback: true),
                          ),
                        ),
                      ),
                    for (final p in [right, left])
                      Positioned(
                        left: p.x - r,
                        top: p.y - r,
                        width: r * 2,
                        height: r * 2,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2 / k),
                              boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 2 / k)],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
