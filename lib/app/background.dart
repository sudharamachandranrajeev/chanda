import 'dart:io';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

import '../domain/checker.dart';
import '../domain/notify.dart';
import '../domain/vault.dart';
import '../domain/web_reader.dart';
import 'session.dart';

// Background price checks, while Chanda is closed. They read plain HTML as
// "Chanda" (no web view, no pretending to be a browser) and only from
// shops that allow it; shops that need the user present wait until the
// app is open. Each run checks only the items that are due, so an hourly
// wake-up costs most shops one page a day per item.
//
//   Android: WorkManager, about hourly, on any network.
//   Linux:   a systemd user timer running `chanda --check`.
//   Windows: a Task Scheduler task running `chanda.exe --check`.

const _task = 'chanda-price-check';

/// Opens the vault, checks what is due and notifies. Returns the report, or
/// null when the app itself is open (it checks while open).
Future<CheckReport?> runBackgroundCheck() async {
  if (await appIsOpen()) return null;
  final session = await AppSession.open(KeyVault(const DeviceSecretStore(), chandaIdentity));
  try {
    final vault = session.vault;
    final notify = await session.db.localSetting(notifySetting) != 'off';
    final checker = Checker(
      vault,
      reader: const HtmlPageReader(),
      notifier: AlertNotifier(ntfy: await vault.pref(ntfyPref), local: notify),
      present: false,
    );
    return await checker.run(limit: 30);
  } finally {
    await session.db.close();
  }
}

/// Android's entry point for WorkManager.
@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await runBackgroundCheck();
      return true;
    } on Object catch (e) {
      debugPrint('Chanda background check failed: $e');
      return false;
    }
  });
}

/// Whether background checks can be set up on this platform.
bool get canCheckInBackground => Platform.isAndroid || Platform.isLinux || Platform.isWindows;

/// Turns background checks on or off. Throws with the system's words when
/// it refuses.
Future<void> setBackgroundChecks(bool on) async {
  if (Platform.isAndroid) {
    final wm = Workmanager();
    await wm.initialize(backgroundDispatcher);
    if (on) {
      await wm.registerPeriodicTask(
        _task,
        _task,
        frequency: const Duration(hours: 1),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } else {
      await wm.cancelByUniqueName(_task);
    }
  } else if (Platform.isLinux) {
    await _systemdTimer(on);
  } else if (Platform.isWindows) {
    await _scheduledTask(on);
  }
}

Future<void> _systemdTimer(bool on) async {
  final home = Platform.environment['HOME']!;
  final dir = Directory('${Platform.environment['XDG_CONFIG_HOME'] ?? '$home/.config'}/systemd/user');
  final service = File('${dir.path}/chanda-check.service');
  final timer = File('${dir.path}/chanda-check.timer');
  if (on) {
    await dir.create(recursive: true);
    final exe = Platform.environment['APPIMAGE'] ?? Platform.resolvedExecutable;
    await service.writeAsString('''
[Unit]
Description=Chanda price check (items that are due)

[Service]
Type=oneshot
ExecStart="$exe" --check
''');
    await timer.writeAsString('''
[Unit]
Description=Chanda price checks, about hourly

[Timer]
OnBootSec=10min
OnUnitActiveSec=1h
RandomizedDelaySec=15min
Persistent=true

[Install]
WantedBy=timers.target
''');
    await _run('systemctl', ['--user', 'daemon-reload']);
    await _run('systemctl', ['--user', 'enable', '--now', 'chanda-check.timer']);
  } else {
    if (timer.existsSync()) await _run('systemctl', ['--user', 'disable', '--now', 'chanda-check.timer']);
    for (final f in [service, timer]) {
      if (f.existsSync()) await f.delete();
    }
    await _run('systemctl', ['--user', 'daemon-reload']);
  }
}

Future<void> _scheduledTask(bool on) async {
  if (on) {
    await _run('schtasks', [
      '/Create', '/F', '/SC', 'HOURLY', '/TN', 'Chanda price check', //
      '/TR', '"${Platform.resolvedExecutable}" --check',
    ]);
  } else {
    await _run('schtasks', ['/Delete', '/F', '/TN', 'Chanda price check']);
  }
}

Future<void> _run(String cmd, List<String> args) async {
  final r = await Process.run(cmd, args);
  if (r.exitCode != 0) throw ProcessException(cmd, args, '${r.stderr}'.trim(), r.exitCode);
}

// ---- the app being open ----

Future<File> _pidFile() async => File('${(await getApplicationSupportDirectory()).path}/app.pid');

/// Marks the desktop app as open, so background runs leave checking to it.
Future<void> markAppOpen() async {
  if (Platform.isAndroid) return;
  final f = await _pidFile();
  await f.parent.create(recursive: true);
  await f.writeAsString('$pid');
}

Future<bool> appIsOpen() async {
  if (Platform.isAndroid) return false;
  final f = await _pidFile();
  if (!f.existsSync()) return false;
  final other = int.tryParse((await f.readAsString()).trim());
  if (other == null || other == pid) return false;
  if (Platform.isLinux) return Directory('/proc/$other').existsSync();
  if (Platform.isWindows) {
    final r = await Process.run('tasklist', ['/FI', 'PID eq $other', '/NH']);
    return '${r.stdout}'.contains('$other');
  }
  return false;
}
