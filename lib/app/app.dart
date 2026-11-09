import 'dart:io';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/look.dart';
import '../ui/photo_search.dart';
import '../ui/save_flow.dart';
import 'modules.dart';
import 'providers.dart';
import 'share.dart';

class ChandaApp extends ConsumerWidget {
  const ChandaApp({super.key, this.home = const _Root()});
  final Widget home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(themeProvider);
    return MaterialApp(
      title: 'Chanda',
      debugShowCheckedModeBanner: false,
      theme: chandaTheme(paletteFor(choice, Brightness.light)),
      darkTheme: chandaTheme(paletteFor(choice, Brightness.dark)),
      themeMode: choice == 'system' ? ThemeMode.system : ThemeMode.light,
      themeAnimationDuration: Motion.medium,
      builder: (context, child) => AppLockGate(child: Backdrop(child: child ?? const SizedBox.shrink())),
      home: home,
    );
  }
}

/// The app, opening the links the platform hands over: a scanned pairing
/// code, or a product link shared to Chanda from another app.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) => const LinkHandler(child: SharedLinks(child: ChandaHome()));
}

/// Chanda's screens. [onHome] leads back to the Brahma suite's home screen
/// when the suite hosts Chanda.
class ChandaHome extends StatelessWidget {
  const ChandaHome({super.key, this.onHome});
  final VoidCallback? onHome;

  @override
  Widget build(BuildContext context) => AppShell(
    destinations: allDestinations,
    floating: true,
    railPanel: true,
    onHome: onHome,
    onStart: (ref) {
      ref.read(liveChecksProvider.notifier).start();
      ref.read(myShopsProvider);
    },
  );
}

/// Hands links shared to Chanda to the save flow, and photos to search by
/// photo.
class SharedLinks extends ConsumerStatefulWidget {
  const SharedLinks({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<SharedLinks> createState() => _SharedLinksState();
}

class _SharedLinksState extends ConsumerState<SharedLinks> {
  @override
  void initState() {
    super.initState();
    listenForShares(
      (text) {
        if (mounted) saveFromText(context, text);
      },
      onPhoto: (path) async {
        final bytes = await File(path).readAsBytes();
        if (!mounted) return;
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PhotoSearchPage(bytes)));
      },
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
