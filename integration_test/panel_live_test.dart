import 'dart:io';
import 'dart:math';

import 'package:chanda/domain/attributes.dart';
import 'package:chanda/domain/offers.dart';
import 'package:chanda/domain/query.dart';
import 'package:chanda/domain/shop_search.dart';
import 'package:chanda/domain/shops.dart';
import 'package:chanda/ui/shop_panels.dart';
import 'package:flutter/gestures.dart' show HitTestResult;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nithya/nithya.dart';

// The live panels and hidden searches on this device's real web engine (WPE
// WebKit on Linux), with memory figures. Each shop's public search page is
// loaded like a browser and nothing more: nothing is clicked or typed, no
// check is passed, no sign-in. A shop that shows a check must show it in the
// panel, and nothing may be read from it. Needs a network. Run it with the
// web engine's data in a scratch folder, never the real one. Its window is a
// test window: the test binding ignores real mouse clicks there by design.
//
//   XDG_DATA_HOME=/tmp/x/data XDG_CACHE_HOME=/tmp/x/cache \
//     flutter test integration_test/panel_live_test.dart -d linux
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const text = String.fromEnvironment('QUERY', defaultValue: 'walking shoes for all terrains, easy slip in');
  // The shop whose results page the screen-reading test uses (it must load hidden).
  const panelShop = String.fromEnvironment('SHOP', defaultValue: 'amazon-uk');

  // ignore: avoid_print
  void log(String s) => print('LIVE $s');

  Widget host(PanelRequest r) => ProviderScope(
    child: MaterialApp(
      theme: nithyaTheme(),
      home: Scaffold(body: LiveShopPanel(r)),
    ),
  );

  Future<void> wait(WidgetTester tester, Duration d) async {
    final end = DateTime.now().add(d);
    while (DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await tester.pump();
    }
  }

  testWidgets('hidden searches free their web views when done', (tester) async {
    await loadLexicon();
    final q = readQuery(text);
    final before = Memory.now();
    log('memory before: $before');
    var peak = before;
    final sampler = Stream.periodic(const Duration(milliseconds: 500)).listen((_) {
      final m = Memory.now();
      if (m.total > peak.total) peak = m;
    });
    final searcher = WebShopSearcher();
    final watch = Stopwatch()..start();
    // Two at once, the desktop limit.
    final found = await Future.wait([
      for (final id in ['amazon-uk', 'aliexpress'])
        searcher.search(shopById(id)!, q).then((o) => (id, o), onError: (Object e) => (id, <Offer>[])),
    ]);
    await sampler.cancel();
    for (final (id, offers) in found) {
      log('hidden $id: ${offers.length} tiles, ${rankScored(q, offers).length} match');
    }
    log('hidden searches took ${watch.elapsed.inSeconds}s; peak: $peak');
    final gone = await settled(before.webProcesses);
    final after = Memory.now();
    log('memory ${gone.inMilliseconds} ms after dispose: $after');
    expect(found.any((f) => f.$2.isNotEmpty), isTrue);
    // The web processes of both views are gone or idle again.
    expect(after.webProcesses, lessThanOrEqualTo(before.webProcesses + 1));
  }, timeout: const Timeout(Duration(minutes: 4)));

  for (final id in ['temu', 'shein']) {
    testWidgets('$id panel shows its check and reads nothing from it', (tester) async {
      await loadLexicon();
      final q = readQuery(text);
      final shop = shopById(id)!;
      final got = <List<Offer>>[];
      await tester.pumpWidget(
        host(PanelRequest(shop: shop, url: shop.searchFor(q.shopWords())!, onOffers: got.add)),
      );
      await wait(tester, const Duration(seconds: 35));
      final status = [
        for (final e in find.byType(Text).evaluate())
          if ((e.widget as Text).data case final s?)
            if (s.contains('check') || s.contains('Sign-in') || s.contains('read') || s.contains('Waiting'))
              s,
      ];
      log('panel $id: status ${status.join(' | ')}; reports ${got.length}; memory ${Memory.now()}');
      // A check or sign-in page is never read.
      if (status.any((s) => s.startsWith('Pass the check') || s.startsWith('Sign-in'))) {
        expect(got, isEmpty);
      }
      final open = Memory.now();
      await tester.pumpWidget(const SizedBox());
      final gone = await settled(0);
      log('panel $id closed: ${gone.inMilliseconds} ms to free; open $open; after ${Memory.now()}');
      // WebKit may keep one spare web process for the next page; no more.
      expect(Memory.now().webProcesses, lessThanOrEqualTo(1));
    }, timeout: const Timeout(Duration(minutes: 2)));
  }

  testWidgets('a panel reads tiles as they appear, and from the screen', (tester) async {
    await loadLexicon();
    final q = readQuery(text);
    final shop = shopById(panelShop)!;
    final got = <List<Offer>>[];
    final before = Memory.now();
    await tester.pumpWidget(
      host(PanelRequest(shop: shop, url: shop.searchFor(q.shopWords())!, onOffers: got.add)),
    );
    final watch = Stopwatch()..start();
    while (got.isEmpty && watch.elapsed < const Duration(seconds: 40)) {
      await wait(tester, const Duration(seconds: 1));
    }
    log(
      'panel $panelShop: first report after ${watch.elapsed.inSeconds}s, '
      '${got.isEmpty ? 0 : got.last.length} offers, ${got.length} reports; memory ${Memory.now()}',
    );
    expect(got, isNotEmpty, reason: 'the tiles handler never reported');
    expect(got.last.every((o) => o.source == OfferSource.page), isTrue);

    // The read-from-screen fallback, on the real page as it is drawn.
    await tester.tap(find.byTooltip('More'));
    // The menu grows in over a few frames; tap its item once it takes taps.
    final item = find.text('Read the results from the screen');
    final shown = Stopwatch()..start();
    do {
      await wait(tester, const Duration(milliseconds: 250));
    } while (!takesTaps(tester, item) && shown.elapsed < const Duration(seconds: 10));
    await tester.tap(item);
    final ocr = Stopwatch()..start();
    final reports = got.length;
    // The page script may report again meanwhile; the screen's report is the
    // one whose offers say so.
    bool fromScreen(List<Offer> r) => r.isNotEmpty && r.first.source == OfferSource.screen;
    // A debug build reads text several times slower than a release build.
    while (!got.skip(reports).any(fromScreen) && ocr.elapsed < const Duration(seconds: 150)) {
      await wait(tester, const Duration(milliseconds: 500));
    }
    final screen = got.skip(reports).where(fromScreen).firstOrNull ?? const <Offer>[];
    log(
      'panel $panelShop from the screen: ${screen.length} offers in ${ocr.elapsed.inMilliseconds} ms'
      '${[for (final o in screen.take(4)) '\n  ${o.price} ${o.currency} ${o.url.isEmpty ? '(no link)' : 'link'} ${o.title.length > 60 ? o.title.substring(0, 60) : o.title}'].join()}',
    );
    expect(screen, isNotEmpty, reason: 'nothing read from the screen');
    expect(screen.every((o) => o.source == OfferSource.screen), isTrue);

    final open = Memory.now();
    await tester.pumpWidget(const SizedBox());
    final gone = await settled(before.webProcesses);
    final after = Memory.now();
    log('panel memory: before $before; open $open; ${gone.inMilliseconds} ms after closing $after');
    expect(after.webProcesses, lessThanOrEqualTo(max(before.webProcesses, 1)));
  }, timeout: const Timeout(Duration(minutes: 5)));
}

/// Whether a tap at the middle of [f] reaches it (a menu still growing in
/// does not take taps yet).
bool takesTaps(WidgetTester tester, Finder f) {
  if (f.evaluate().isEmpty) return false;
  final box = tester.renderObject(f.first) as RenderBox;
  final result = HitTestResult();
  tester.binding.hitTestInView(result, box.localToGlobal(box.size.center(Offset.zero)), tester.view.viewId);
  return result.path.any((e) => e.target == box);
}

/// Waits up to 20 s for the web processes to drop back to [count] (or the one
/// spare WebKit may keep); how long it took.
Future<Duration> settled(int count) async {
  final watch = Stopwatch()..start();
  while (Memory.now().webProcesses > max(count, 1) && watch.elapsed < const Duration(seconds: 20)) {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  return watch.elapsed;
}

/// Resident memory of this process and the web engine's helper processes
/// (its children), from /proc. Linux only.
class Memory {
  Memory(this.self, this.children, this.webProcesses);
  final int self, children, webProcesses;
  int get total => self + children;

  static Memory now() {
    final me = pid;
    var kids = 0, web = 0;
    for (final d in Directory('/proc').listSync().whereType<Directory>()) {
      final p = int.tryParse(d.uri.pathSegments.where((s) => s.isNotEmpty).last);
      if (p == null || p == me || !_descends(p, me)) continue;
      kids += _rss(p);
      if (_name(p).startsWith('WPEWebProcess')) web++;
    }
    return Memory(_rss(me), kids, web);
  }

  static bool _descends(int p, int root) {
    for (var i = 0; i < 6 && p > 1; i++) {
      p = _parent(p);
      if (p == root) return true;
    }
    return false;
  }

  static int _parent(int p) {
    try {
      final stat = File('/proc/$p/stat').readAsStringSync();
      return int.parse(stat.substring(stat.lastIndexOf(')') + 2).split(' ')[1]);
    } on Object {
      return 0;
    }
  }

  static String _name(int p) {
    try {
      return File('/proc/$p/comm').readAsStringSync().trim();
    } on Object {
      return '';
    }
  }

  static int _rss(int p) {
    try {
      final m = RegExp(r'VmRSS:\s+(\d+)').firstMatch(File('/proc/$p/status').readAsStringSync());
      return m == null ? 0 : int.parse(m.group(1)!) ~/ 1024;
    } on Object {
      return 0;
    }
  }

  @override
  String toString() => 'app $self MB + helpers $children MB ($webProcesses web processes)';
}
