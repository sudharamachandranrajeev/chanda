import 'dart:async';

import '../db/database.dart';
import 'html_evidence.dart';
import 'reading.dart';
import 'shops.dart';
import 'vault.dart';
import 'watch.dart';
import 'web_reader.dart';

/// Tells the user about alerts (lib/domain/notify.dart); tests use a fake.
abstract class AlertSender {
  Future<void> send(VaultItem item, List<AlertEvent> alerts);
}

/// What one check of an item came to.
enum CheckResult { ok, alerted, needsYou, gone, failed, skipped }

/// What a run of checks did.
class CheckReport {
  final results = <String, CheckResult>{};
  int get checked => results.values.where((r) => r != CheckResult.skipped).length;
  int get alerted => results.values.where((r) => r == CheckResult.alerted).length;
  int get trouble => results.values.where((r) => r == CheckResult.needsYou || r == CheckResult.failed).length;
}

/// Re-reads saved items' prices and raises alerts. Before any alert it
/// reads the page again: an alert fires only when both reads agree, so a
/// glitch on the page never sends the user to a price that is not there.
class Checker {
  Checker(
    this.vault, {
    required this.reader,
    required this.notifier,
    required this.present,
    this.gap = const Duration(seconds: 10),
    this.confirmAfter = const Duration(seconds: 8),
  });

  final Vault vault;
  final PageReader reader;
  final AlertSender notifier;

  /// The user has the app open: shops that turn away unattended loads can
  /// be read now.
  final bool present;

  /// The least time between two loads from the same shop.
  final Duration gap;
  final Duration confirmAfter;

  final _lastLoad = <String, DateTime>{};

  /// Checks every item that is due, at most [limit], one page at a time.
  /// A shop that answers with a check page is left alone for the rest of
  /// the run.
  Future<CheckReport> run({int limit = 40, DateTime? now}) async {
    final report = CheckReport();
    final t = now ?? DateTime.now().toUtc();
    final due = (await vault.items()).where((i) => isDue(i, t, present: present)).toList()
      ..sort((a, b) => nextCheck(a).compareTo(nextCheck(b)));
    final walled = <String>{};
    for (final item in due.take(limit)) {
      if (walled.contains(item.shop)) {
        report.results[item.id] = CheckResult.skipped;
        continue;
      }
      final r = await check(item);
      report.results[item.id] = r;
      if (r == CheckResult.needsYou) walled.add(item.shop);
    }
    return report;
  }

  /// Checks one item now.
  Future<CheckResult> check(VaultItem item) async {
    final dropPercent = await vault.dropPercent();
    final Reading first;
    try {
      first = await _read(item);
    } on PageGone {
      await vault.recordTrouble(item, 'gone');
      return CheckResult.gone;
    } on Object {
      await vault.recordTrouble(item, 'failed');
      return CheckResult.failed;
    }
    if (first.check) {
      await vault.recordTrouble(item, 'needs-you');
      return CheckResult.needsYou;
    }
    if (!first.usable) {
      // A shop that hides its prices from unattended loads needs the user.
      final status = shopOf(item.shop).userPresent && !present ? 'needs-you' : 'failed';
      await vault.recordTrouble(item, status);
      return status == 'needs-you' ? CheckResult.needsYou : CheckResult.failed;
    }
    var reading = first;
    var alerts = alertsFor(
      item,
      first,
      before: item.price,
      beforeStock: item.inStock,
      dropPercent: dropPercent,
    );
    if (alerts.isNotEmpty) {
      await Future<void>.delayed(confirmAfter);
      Reading? second;
      try {
        second = await _read(item);
      } on Object {
        second = null;
      }
      if (second == null || !second.usable || !sameReading(first, second)) {
        // The page changed under us: keep what it shows now, alert later if
        // it holds.
        alerts = const [];
        if (second != null && second.usable) reading = second;
      }
    }
    final events = await vault.recordCheck(item, reading, alerts);
    if (events.isNotEmpty) {
      final fresh = await vault.item(item.id) ?? item;
      await notifier.send(fresh, events);
      return CheckResult.alerted;
    }
    return CheckResult.ok;
  }

  Future<Reading> _read(VaultItem item) async {
    final url = Uri.parse(item.url);
    final host = url.host;
    final last = _lastLoad[host];
    if (last != null) {
      final wait = gap - DateTime.now().difference(last);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
    }
    _lastLoad[host] = DateTime.now();
    final e = await reader.read(url);
    return readProduct(e, hint: item.currency);
  }
}
