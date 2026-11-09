import 'dart:io';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/background.dart';
import 'app/providers.dart';
import 'app/session.dart';
import 'domain/vault.dart';
import 'ui/look.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // `chanda --check`: the scheduled background check (a systemd timer or a
  // Windows task). No window is drawn: the desktop runners show theirs on
  // the first frame, and this never asks for one.
  if (args.contains('--check')) exit(await _check());
  await _start();
}

Future<int> _check() async {
  try {
    final report = await runBackgroundCheck();
    stdout.writeln(
      report == null
          ? 'Chanda is open; it checks prices itself.'
          : 'Checked ${report.checked}, alerts ${report.alerted}, need you or failed ${report.trouble}.',
    );
    return 0;
  } on Object catch (e) {
    stderr.writeln('Chanda check failed: ${describeError(e)}');
    return 1;
  }
}

Future<void> _start() async {
  try {
    final session = await AppSession.open(KeyVault(const DeviceSecretStore(), chandaIdentity));
    final theme = await session.db.localSetting(themeSetting) ?? defaultTheme;
    await markAppOpen();
    runApp(
      ProviderScope(
        overrides: chandaOverrides(session, theme: theme),
        // Failures are shown with a retry button; silent retries would hide them.
        retry: (_, _) => null,
        child: const ChandaApp(),
      ),
    );
  } catch (e) {
    // Also in release builds' logs, where smoke tests look for it.
    debugPrint('Chanda startup failed: $e');
    runApp(
      StartupFailure(
        e,
        appName: chandaIdentity.name,
        theme: (b) => chandaTheme(paletteFor('system', b)),
        onRetry: _start,
      ),
    );
  }
}
