import 'dart:io';
import 'dart:typed_data';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/local_search.dart';
import '../domain/picture_index.dart';
import '../domain/pictures.dart';
import 'item_page.dart';
import 'look.dart';
import 'search_page.dart';
import 'vault_page.dart' show ItemCard;

/// Asks for a photo: the camera or the gallery on Android, a picture file
/// elsewhere. Null when the user changes their mind.
Future<Uint8List?> pickPhoto(BuildContext context) async {
  var source = ImageSource.gallery;
  if (Platform.isAndroid) {
    final picked = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose a photo'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (picked == null) return null;
    source = picked;
  }
  final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600);
  return file?.readAsBytes();
}

/// Search with a photo: what it looks like (as words for a shop search),
/// and saved things and found offers that look like it. Runs on the device
/// with the picture model; the photo is not sent anywhere.
class PhotoSearchPage extends ConsumerStatefulWidget {
  const PhotoSearchPage(this.photo, {super.key});
  final Uint8List photo;

  @override
  ConsumerState<PhotoSearchPage> createState() => _PhotoSearchPageState();
}

class _PhotoSearchPageState extends ConsumerState<PhotoSearchPage> {
  var _busy = true;
  var _needsModel = false;
  String? _error;
  PictureTags? _tags;
  var _useColour = true, _usePattern = true;
  var _items = const <VaultItem>[];
  var _offers = const <ShopOffer>[];

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final e = await ref.read(pictureEmbedderProvider.future);
      if (e == null) {
        if (mounted) setState(() => _needsModel = true);
        return;
      }
      final v = (await e.embed([widget.photo])).single;
      if (v == null) {
        if (mounted) setState(() => _error = 'That picture could not be read. Try another photo.');
        return;
      }
      final labels = await ref.read(pictureLabelsProvider.future);
      final s = ref.read(sessionProvider);
      final index = PictureIndex(s.db);
      await index.fillFromVault(e, s.vault, cap: 64);
      final (items, offers) = await index.lookAlike(v, s.vault);
      if (!mounted) return;
      setState(() {
        _needsModel = false;
        _tags = labels.isEmpty ? null : pictureTags(v, labels);
        _items = items;
        _offers = offers;
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _words {
    final t = _tags!;
    return [if (_useColour) ?t.colour, if (_usePattern) ?t.pattern, t.category].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(picturesProvider, (before, now) {
      if (_needsModel && (now.value?.on ?? false) && !(before?.value?.on ?? false)) _run();
    });
    final tags = _tags;
    return PageScaffold(
      title: 'Search by photo',
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(widget.photo, height: 200, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 16),
        if (_needsModel)
          const _GetModel()
        else if (_busy)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))
        else ...[
          if (tags != null && tags.category.isNotEmpty) ...[
            const ResultHeading('It looks like', ''),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (tags.colour case final c?)
                  FilterChip(
                    label: Text(c),
                    selected: _useColour,
                    onSelected: (v) => setState(() => _useColour = v),
                  ),
                if (tags.pattern case final p?)
                  FilterChip(
                    label: Text(p),
                    selected: _usePattern,
                    onSelected: (v) => setState(() => _usePattern = v),
                  ),
                Chip(label: Text(tags.category)),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                icon: const Icon(Icons.search),
                label: Text('Search the shops for "$_words"'),
                onPressed: () =>
                    Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => SearchPage(initial: _words))),
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (_items.isEmpty && _offers.isEmpty)
            Text(
              'Nothing you saved or found before looks like it yet.',
              style: TextStyle(color: muted(context)),
            ),
          if (_items.isNotEmpty) ...[
            ResultHeading('In your vault', '${_items.length}'),
            ResultGrid(
              children: [
                for (final i in _items)
                  SizedBox(
                    height: 300,
                    child: ItemCard(
                      i,
                      onTap: () =>
                          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ItemPage(i.id))),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (_offers.isNotEmpty) ...[
            ResultHeading('Found before', '${_offers.length}'),
            ResultGrid(
              children: [for (final o in _offers) SizedBox(height: 300, child: OfferCard(offerOf(o)))],
            ),
          ],
        ],
      ],
    );
  }
}

/// Picture search is not on: say what it needs, and get it.
class _GetModel extends ConsumerWidget {
  const _GetModel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(picturesProvider).value ?? const ModelState();
    final n = ref.read(picturesProvider.notifier);
    final mb = (n.bytes / 1e6).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Searching by photo needs the picture model: a $mb MB download, once. It then runs on this device '
          'and your photos are not sent anywhere.',
        ),
        const SizedBox(height: 12),
        if (s.downloading) ...[
          LinearProgressIndicator(value: s.done! / n.bytes),
          const SizedBox(height: 6),
          Text('Downloading… ${(s.done! / 1e6).round()} of $mb MB'),
        ] else ...[
          if (s.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(s.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: s.present
                ? FilledButton.tonal(
                    onPressed: () => n.setOn(true),
                    child: const Text('Turn on picture search'),
                  )
                : FilledButton.tonalIcon(
                    icon: const Icon(Icons.download_outlined),
                    label: Text('Download ($mb MB)'),
                    onPressed: n.download,
                  ),
          ),
        ],
      ],
    );
  }
}
