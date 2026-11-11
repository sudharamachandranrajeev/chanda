import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'app_harness.dart';

void main() {
  Future<void> openSettings(AppHarness app) async {
    await app.go('Settings');
    await app.tester.scrollUntilVisible(
      find.text('Home currency'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await app.settle();
  }

  testWidgets('exchange rates are fetched for the home currency and dated', (t) async {
    final asked = <Uri>[];
    final app = AppHarness(t)..desktop();
    await app.open();
    await app.run(fx: fakeRates(asked: asked));
    await openSettings(app);
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    expect(find.text('Exchange rates of $today'), findsOneWidget);
    expect(asked, isNotEmpty);
    expect(asked.every((u) => u.queryParameters['base'] == 'GBP'), isTrue);
    await app.close();
  });

  testWidgets('without the rate service, Settings says prices are not converted', (t) async {
    final app = AppHarness(t)..desktop();
    await app.open();
    await app.run(fx: MockClient((_) async => http.Response('{"message":"not found"}', 404)));
    await openSettings(app);
    expect(find.textContaining('Exchange rates not fetched yet'), findsOneWidget);
    expect(t.takeException(), isNull);
    await app.close();
  });
}
