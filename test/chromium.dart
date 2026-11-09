import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The installed Chromium or Chrome, if any; tests that need it skip without.
final chromium = [
  'chromium',
  'chromium-browser',
  'google-chrome-stable',
  'google-chrome',
].where((c) => Process.runSync('which', [c]).exitCode == 0).firstOrNull;

/// Loads [page] (or [url], when the page is served) in headless Chromium
/// and returns the text its script put in `<pre id="out">`.
Future<String> dumpOut(String chromium, Directory dir, File page, {Uri? url}) async {
  // A fresh profile and a virtual-time budget keep CI's Chrome from waiting
  // on first-run work; the timeout stops a browser that hangs anyway.
  final p = await Process.start(chromium, [
    '--headless',
    '--disable-gpu',
    '--no-sandbox',
    '--disable-dev-shm-usage',
    '--no-first-run',
    '--user-data-dir=${dir.path}/profile',
    '--virtual-time-budget=8000',
    '--dump-dom',
    (url ?? page.uri).toString(),
  ]);
  final stdout = p.stdout.transform(const SystemEncoding().decoder).join();
  final stderr = p.stderr.transform(const SystemEncoding().decoder).join();
  await p.exitCode.timeout(const Duration(seconds: 45), onTimeout: () => (p..kill()).pid);
  final out = RegExp(r'<pre id="out">(.*?)</pre>', dotAll: true).firstMatch(await stdout)?[1];
  expect(out, isNotNull, reason: await stderr);
  return out!
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}
