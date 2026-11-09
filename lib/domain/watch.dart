import 'dart:math';

import '../db/database.dart';
import 'reading.dart';
import 'shops.dart';

/// An alert worth raising after a price check.
class Alert {
  const Alert(this.kind, {this.before, this.after, required this.currency});

  /// target | drop | stock | test
  final String kind;
  final int? before;
  final int? after;
  final String currency;
}

/// What a fresh reading [r] means for [item], given its last confirmed price
/// [before] and stock. A price at or under the target beats a plain drop;
/// small drops under [dropPercent] are left quiet.
List<Alert> alertsFor(
  VaultItem item,
  Reading r, {
  int? before,
  bool beforeStock = true,
  double dropPercent = 5,
}) {
  final out = <Alert>[];
  final price = r.price;
  if (price == null || r.currency != item.currency) return out;
  if (item.alertStock && !beforeStock && r.inStock) {
    out.add(Alert('stock', before: before, after: price, currency: r.currency));
  }
  if (!r.inStock) return out;
  final target = item.target;
  if (target != null && price <= target && (before == null || before > target)) {
    out.add(Alert('target', before: before, after: price, currency: r.currency));
  } else if (item.alertDrop &&
      before != null &&
      price < before &&
      (before - price) * 100 >= dropPercent * before) {
    out.add(Alert('drop', before: before, after: price, currency: r.currency));
  }
  return out;
}

/// Whether two readings agree on what an alert depends on.
bool sameReading(Reading a, Reading b) =>
    a.price == b.price && a.currency == b.currency && a.inStock == b.inStock;

/// How often an item is checked: once a day, or four times when the user
/// watches it closely. After failures the wait doubles, up to four days.
Duration checkEvery(VaultItem i) {
  final base = i.watchClose ? const Duration(hours: 6) : const Duration(hours: 24);
  if (i.failures <= 0) return base;
  final backoff = base * pow(2, min(i.failures, 4)).toInt();
  return backoff > const Duration(days: 4) ? const Duration(days: 4) : backoff;
}

/// When [i] is next due: [checkEvery] after its last check, moved by up to
/// an hour either way (the same each day for an item, so checks spread out
/// instead of all hitting a shop on the hour).
DateTime nextCheck(VaultItem i) {
  final last = i.checked == null ? null : DateTime.tryParse(i.checked!);
  if (last == null) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  final day = last.toUtc().toIso8601String().substring(0, 10);
  final jitter = (_fnv('${i.id}$day') % 120) - 60;
  return last.add(checkEvery(i)).add(Duration(minutes: jitter));
}

/// FNV-1a: a hash that is the same on every run and device.
int _fnv(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h;
}

/// Whether [i] should be checked now. Shops that turn away unattended loads
/// are checked only while the user is [present] (the app is open).
bool isDue(VaultItem i, DateTime now, {required bool present}) {
  if (i.bought || i.deleted || i.status == 'gone') return false;
  final shop = shopOf(i.shop);
  if (!present && (shop.userPresent || i.status == 'needs-you')) return false;
  return !now.isBefore(nextCheck(i));
}

/// "just now", "5 min ago", "3 h ago", "2 days ago".
String ago(String? iso, DateTime now) {
  final t = iso == null ? null : DateTime.tryParse(iso);
  if (t == null) return 'never';
  final d = now.difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} ${d.inDays == 1 ? 'day' : 'days'} ago';
}

/// How fresh a price is: fresh (under a day), stale, or never read.
enum Freshness { fresh, stale, never }

Freshness freshness(String? iso, DateTime now) {
  final t = iso == null ? null : DateTime.tryParse(iso);
  if (t == null) return Freshness.never;
  return now.difference(t) <= const Duration(hours: 26) ? Freshness.fresh : Freshness.stale;
}
