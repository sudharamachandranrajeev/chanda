import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/clothes_fit.dart';
import '../domain/cloud_tryon.dart';
import '../domain/garment_fit.dart';
import '../domain/people.dart';
import '../domain/size_chart.dart';
import '../domain/tryon.dart';
import '../domain/vault.dart';
import 'item_bits.dart';
import 'look.dart';
import 'tryon_bits.dart';

// Kept outside the page's classes so the work sent to another isolate
// carries only the bytes, not the page.
Future<Rgb?> _decode(Uint8List jpeg) => Isolate.run(() => decodeRgb(jpeg));
Future<Uint8List> _forCloud(Uint8List picture) => Isolate.run(() => cloudPicture(picture));

/// A garment from the vault drawn on the person's body photo, keeping
/// their shape; the shop's size chart set against their sizes; and, with
/// the user's own key, a picture from a cloud try-on service.
class ClothesPage extends StatelessWidget {
  const ClothesPage(this.item, this.kind, {super.key});
  final VaultItem item;
  final GarmentKind kind;

  @override
  Widget build(BuildContext context) => PageScaffold(
    title: 'Try on',
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Readable(
          child: TryOnGate(
            kind: PhotoKind.body,
            needPhoto: 'Add a photo of your whole body',
            needPhotoText:
                'Try-on draws the clothes on a photo of all of you, standing and facing the camera, kept only '
                'on this device.',
            // A new body photo starts the fit again.
            builder: (m, p, thumb) =>
                _Fit(key: ValueKey(Object.hashAll(thumb)), models: m, person: p, item: item, kind: kind),
          ),
        ),
      ],
    ),
  );
}

class _Fit extends ConsumerStatefulWidget {
  const _Fit({super.key, required this.models, required this.person, required this.item, required this.kind});
  final TryOnModels models;
  final Person person;
  final VaultItem item;
  final GarmentKind kind;

  @override
  ConsumerState<_Fit> createState() => _FitState();
}

class _FitState extends ConsumerState<_Fit> {
  String? _step = 'Finding you on your photo…';
  PersonPhoto? _photo;
  Rgb? _rgb;
  int? _picture;
  ClothesFit? _fit;
  final _problems = <int, String>{};
  SizeNote? _size;
  String? _cloudStep;
  ClothesFit? _cloud;

  VaultItem get _item => widget.item;
  int get _pictures => min(imagesOf(_item).length, 5);

  @override
  void initState() {
    super.initState();
    _start();
    _sizeNote();
  }

  Future<void> _start() async {
    try {
      final photo = await ref.read(peopleProvider).photo(widget.person.id, PhotoKind.body);
      if (photo == null) return;
      final rgb = await _decode(photo.jpeg);
      if (!mounted) return;
      setState(() {
        _photo = photo;
        _rgb = rgb;
      });
      if (rgb == null || widget.models.bodies == null) return;
      // Shops often show a garment worn first: try each picture until one
      // shows it on its own, from the front.
      for (var n = 0; n < _pictures; n++) {
        if (await _fitPicture(n)) break;
        // The same answer for every picture is about the body photo or the
        // kind of garment: no use trying the rest.
        if (n == 0 && _isAboutPhoto(_problems[0])) break;
      }
    } on Object catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _step = null);
    }
  }

  bool _isAboutPhoto(String? why) =>
      why != null &&
      (why == garmentProblemText(GarmentProblem.unsupported) || why.contains('your body photo'));

  /// The garment in picture [n] on the photo; whether it worked.
  Future<bool> _fitPicture(int n) async {
    final rgb = _rgb;
    if (rgb == null) return false;
    setState(() {
      _picture = n;
      _step = 'Fitting the garment to you…';
    });
    try {
      final bytes = await ref.read(itemPictureProvider)(_item.id, n, imagesOf(_item)[n]);
      final fit = bytes == null
          ? const ClothesFit.problem('This picture could not be loaded.')
          : await fitClothes(widget.models, rgb, bytes, widget.kind);
      if (!mounted) return false;
      setState(() {
        _fit = fit;
        if (fit.problem == null) {
          _problems.remove(n);
        } else {
          _problems[n] = fit.problem!;
        }
      });
      return fit.problem == null;
    } finally {
      if (mounted) setState(() => _step = null);
    }
  }

  /// The size chart: kept from before, else read from the item's page and
  /// kept (or "none") for next time.
  Future<void> _sizeNote() async {
    final db = ref.read(sessionProvider).db;
    final key = sizeChartSetting(_item.id);
    final kept = await db.localSetting(key);
    SizeChart? chart;
    if (kept != null) {
      chart = SizeChart.fromJson(kept);
    } else {
      try {
        chart = findSizeChart(await ref.read(readerProvider).read(Uri.parse(_item.url)));
        await db.setLocalSetting(key, chart?.toJson() ?? 'none');
      } on Object catch (e) {
        debugPrint('Chanda: could not read the size chart from the page: $e');
      }
    }
    if (mounted) setState(() => _size = sizeNote(chart, widget.person, widget.kind));
  }

  Future<void> _tryCloud(CloudProvider p, String key, bool paid) async {
    final rgb = _rgb, photo = _photo, n = _picture;
    if (rgb == null || photo == null || n == null) return;
    final db = ref.read(sessionProvider).db;
    final agreed = consentFingerprint(p, key, paid: paid);
    if (await db.localSetting(cloudConsentSetting(p)) != agreed) {
      if (!mounted || !await _consent(p)) return;
      await db.setLocalSetting(cloudConsentSetting(p), agreed);
    }
    setState(() {
      _cloud = null;
      _cloudStep = 'Asking ${providerName(p)} for a picture…';
    });
    try {
      final garment = await ref.read(itemPictureProvider)(_item.id, n, imagesOf(_item)[n]);
      if (garment == null) throw const CloudTryOnError('This picture could not be loaded.');
      final made = await CloudTryOn(
        p,
        key,
        client: ref.read(cloudClientProvider),
      ).run(photo: await _forCloud(photo.jpeg), garment: await _forCloud(garment), kind: widget.kind);
      if (!mounted) return;
      setState(() => _cloudStep = 'Checking the picture against your photo…');
      final checked = await checkCloudResult(widget.models, rgb, made, widget.kind);
      if (mounted) setState(() => _cloud = checked);
    } on CloudTryOnError catch (e) {
      if (mounted) setState(() => _cloud = ClothesFit.problem(e.message));
    } on Object catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _cloudStep = null);
    }
  }

  /// Asks before the first picture goes to [p], and again after anything
  /// about it changes.
  Future<bool> _consent(CloudProvider p) async {
    final t = providerTerms(p);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Send your photo to ${providerName(p)}?'),
        scrollable: true,
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (label, text) in [
                ('What is sent', t.sent),
                ('Who gets it', '${providerName(p)} (${t.model}), with your own key.'),
                ('How long it is kept', t.kept),
                ('What it costs', t.price),
                (
                  'What you see',
                  'Only the clothes are taken from the picture it sends back. If it makes you narrower '
                      'anywhere, Chanda does not show it.',
                ),
              ]) ...[
                Text(label, style: Theme.of(context).textTheme.titleSmall),
                Padding(padding: const EdgeInsets.only(top: 2, bottom: 10), child: Text(text)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Agree and send')),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final note = text.bodyMedium?.copyWith(color: muted(context));
    final children = <Widget>[];
    final photo = _photo;
    if (photo != null && _rgb == null) {
      children.add(const TryOnProblem('Your body photo could not be read.', action: 'Change my photo'));
    } else if (photo != null && widget.models.bodies == null) {
      children.add(
        const TryOnProblem('Try-on for clothes needs the latest download. Download it again in Settings.'),
      );
    }
    final fit = _fit;
    if (fit?.jpeg case final jpeg?) {
      children.add(_Result(jpeg, label: 'Fit preview, approximate'));
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Drawn on your own photo: the garment is stretched to your outline, never you to the garment. '
            'Folds, light and fabric are not real; the size note below is the better guide to fit.',
            style: note,
          ),
        ),
      );
    } else if (fit?.problem case final why?) {
      children.add(_CannotFit(why, photoAction: _isAboutPhoto(why)));
    }
    if (_pictures > 0) {
      children.add(const SizedBox(height: 16));
      children.add(Text('Product picture', style: text.titleSmall));
      children.add(const SizedBox(height: 8));
      children.add(
        PictureStrip(
          count: _pictures,
          chosen: _picture,
          picture: (n) => ItemImage(_item, index: n, fit: BoxFit.contain),
          onTap: _step != null || _cloudStep != null ? null : _fitPicture,
        ),
      );
    } else if (_photo != null && _step == null) {
      children.add(const TryOnProblem('This item has no product picture to try on.'));
    }
    if (_step != null) children.insert(0, TryOnStep(_step!));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: _item.title,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
        _SizeCard(_size),
        _cloudCard(context),
      ],
    );
  }

  Widget _cloudCard(BuildContext context) {
    final state = ref.watch(cloudKeysProvider).value;
    final p = state == null ? null : pickProvider(state.keys, geminiPaid: state.geminiPaid);
    final cloud = _cloud;
    return SectionCard(
      title: 'AI preview',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (p == null)
            const Text(
              'Off. With your own key for an AI try-on service, added in Settings, Chanda can ask it for a more '
              'lifelike picture. Your photo is sent only when you press the button, after you agree.',
            )
          else ...[
            if (_cloudStep != null) TryOnStep(_cloudStep!),
            if (cloud?.jpeg case final jpeg?) _Result(jpeg, label: 'AI preview'),
            if (cloud?.problem case final why?) _CannotFit(why),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.auto_awesome_outlined),
                label: Text('Try with AI (${providerName(p)})'),
                onPressed: _cloudStep != null || _step != null || _picture == null || _rgb == null
                    ? null
                    : () => _tryCloud(p, state!.keys[p]!, state.geminiPaid),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Sends your body photo and the chosen product picture to ${providerName(p)}. '
                '${providerTerms(p).price}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted(context)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A finished picture with what it is written on it.
class _Result extends StatelessWidget {
  const _Result(this.jpeg, {required this.label});
  final Uint8List jpeg;
  final String label;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 640),
      child: Stack(
        alignment: Alignment.topLeft,
        children: [
          Center(child: Image.memory(jpeg, gaplessPlayback: true, semanticLabel: label)),
          Padding(
            padding: const EdgeInsets.all(8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Nothing is drawn; why.
class _CannotFit extends StatelessWidget {
  const _CannotFit(this.why, {this.photoAction = false});
  final String why;
  final bool photoAction;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Cannot fit this photo', style: Theme.of(context).textTheme.titleMedium),
      TryOnProblem(why, action: photoAction ? 'Change my photo' : null),
    ],
  );
}

/// The shop's size chart set against the person's sizes.
class _SizeCard extends StatelessWidget {
  const _SizeCard(this.note);
  final SizeNote? note;

  @override
  Widget build(BuildContext context) {
    final n = note;
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(color: muted(context));
    return SectionCard(
      title: n == null ? 'Size note' : 'Size note: ${n.summary.toLowerCase()}',
      child: n == null
          ? const TryOnStep('Looking for the shop\'s size chart…')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (n.noChart)
                  const Text(
                    'No size chart was found on the shop\'s page. Look for a size guide link there, and '
                    'compare it with your sizes.',
                  ),
                for (final l in n.lines)
                  Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(l.text)),
                if (n.missing.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'The chart also gives ${n.missing.map((m) => measureName(m).toLowerCase()).join(' and ')}. '
                      'Add yours under your photos and sizes to compare.',
                    ),
                  ),
                if (!n.noChart) ...[
                  const SizedBox(height: 4),
                  Text(n.source, style: small),
                  Text(
                    'A size chart is the shop\'s guide; cuts differ, so check the shop\'s fit notes too.',
                    style: small,
                  ),
                ],
              ],
            ),
    );
  }
}
