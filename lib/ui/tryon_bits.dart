import 'dart:typed_data';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../app/settings_page.dart' show ModelCard, tryOnAbout;
import '../domain/people.dart';
import '../domain/tryon.dart';
import 'person_page.dart';

/// What every try-on page needs first: the models downloaded and on, a
/// saved person and their photo of [kind]. Says what is missing; else
/// builds [builder] with the loaded models, the person and the photo's
/// thumbnail (a new photo builds afresh).
class TryOnGate extends ConsumerWidget {
  const TryOnGate({
    super.key,
    required this.kind,
    required this.needPhoto,
    required this.needPhotoText,
    required this.builder,
  });

  final PhotoKind kind;

  /// "Add a photo of your face".
  final String needPhoto;
  final String needPhotoText;
  final Widget Function(TryOnModels models, Person person, Uint8List thumb) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tryOnProvider).value ?? const ModelState();
    if (!state.present || state.downloading) {
      return ModelCard(
        provider: tryOnProvider,
        title: 'Try-on needs a download',
        switchLabel: 'Try things on',
        about: tryOnAbout,
      );
    }
    if (!state.on) {
      return SectionCard(
        title: 'Try-on is off',
        child: Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: () => ref.read(tryOnProvider.notifier).setOn(true),
            child: const Text('Turn try-on on'),
          ),
        ),
      );
    }
    return AsyncView(
      ref.watch(personProvider),
      builder: (p) {
        final photo = p == null ? null : ref.watch(personThumbsProvider(p.id)).value?[kind];
        if (p == null || photo == null) {
          return SectionCard(
            title: needPhoto,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(needPhotoText),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: Icon(kind == PhotoKind.face ? Icons.face_outlined : Icons.accessibility_new),
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
              : builder(m, p, photo),
        );
      },
    );
  }
}

/// A plain-words reason a try-on cannot be shown, with an optional way to
/// change the photo.
class TryOnProblem extends StatelessWidget {
  const TryOnProblem(this.message, {super.key, this.action});
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

/// The product's pictures to choose from, the chosen one outlined.
class PictureStrip extends StatelessWidget {
  const PictureStrip({
    super.key,
    required this.count,
    required this.chosen,
    required this.picture,
    this.onTap,
  });
  final int count;
  final int? chosen;
  final Widget Function(int n) picture;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (var n = 0; n < count; n++)
        InkWell(
          onTap: onTap == null ? null : () => onTap!(n),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                width: 2,
                color: n == chosen ? Theme.of(context).colorScheme.primary : Colors.transparent,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: picture(n),
          ),
        ),
    ],
  );
}

/// A step under way: a small spinner and what is being done.
class TryOnStep extends StatelessWidget {
  const TryOnStep(this.step, {super.key});
  final String step;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 10),
        Expanded(child: Text(step)),
      ],
    ),
  );
}
