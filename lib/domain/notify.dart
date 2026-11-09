import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../db/database.dart';
import 'checker.dart';
import 'money.dart';
import 'shops.dart';

/// The words of an alert: a title and a line.
(String, String) alertText(VaultItem item, AlertEvent a) {
  final shop = shopOf(item.shop).name;
  final after = a.after == null ? '' : showPrice(a.after!, a.currency);
  final before = a.before == null ? '' : showPrice(a.before!, a.currency);
  return switch (a.kind) {
    'target' => ('At your price: $after', '${item.title} at $shop${before.isEmpty ? '' : ' (was $before)'}'),
    'drop' => ('Price drop: $after', '${item.title} at $shop, down from $before'),
    'stock' => ('Back in stock', '${item.title} at $shop${after.isEmpty ? '' : ', $after'}'),
    _ => ('Chanda test alert', 'Alerts reach you here. ${item.title}'),
  };
}

/// Alerts on the device itself, and to the user's ntfy topic when one is
/// set (ntfy.sh or their own ntfy server; Chanda sends only the alert
/// text).
class AlertNotifier implements AlertSender {
  AlertNotifier({this.ntfy, this.local = true});

  /// The full topic URL, e.g. https://ntfy.sh/my-secret-topic.
  final String? ntfy;
  final bool local;

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    _ready = true;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        linux: LinuxInitializationSettings(defaultActionName: 'Open Chanda'),
        windows: WindowsInitializationSettings(
          appName: 'Chanda',
          appUserModelId: 'Brahma.Chanda',
          guid: '5f0c2b61-3c0e-4c4a-9b5e-6d2a3e0c7a41',
        ),
      ),
    );
  }

  /// Asks Android 13+ for permission to notify; true elsewhere.
  static Future<bool> askPermission() async {
    await init();
    if (!Platform.isAndroid) return true;
    return await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission() ??
        false;
  }

  @override
  Future<void> send(VaultItem item, List<AlertEvent> alerts) async {
    for (final a in alerts) {
      final (title, body) = alertText(item, a);
      await _deliver(a.id.hashCode & 0x7fffffff, title, body, payload: item.id, link: item.url);
    }
  }

  /// Sends a test alert the way real ones go, so the user can see where
  /// they arrive. Throws when ntfy refuses.
  Future<void> test() => _deliver(1, 'Chanda test alert', 'Price alerts reach you here.', strict: true);

  Future<void> _deliver(int id, String title, String body, {String? payload, String? link, bool strict = false}) async {
    if (local) {
      try {
        await init();
        await _plugin.show(
          id: id,
          title: title,
          body: body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'prices',
              'Price alerts',
              channelDescription: 'Price drops, your target prices and items back in stock',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          payload: payload,
        );
      } on Object {
        // A desktop without a notification service still gets ntfy and
        // the Alerts page.
        if (strict && (ntfy == null || ntfy!.isEmpty)) rethrow;
      }
    }
    if (ntfy != null && ntfy!.isNotEmpty) await sendNtfy(ntfy!, title, body, link: link);
  }
}

/// Posts one alert to an ntfy topic URL. Throws when the server refuses.
Future<void> sendNtfy(String topicUrl, String title, String body, {String? link, http.Client? client}) async {
  final uri = Uri.parse(topicUrl);
  if (uri.scheme != 'https' && uri.host != 'localhost' && !uri.host.endsWith('.local')) {
    throw ArgumentError('Use an https:// ntfy address');
  }
  final topic = uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull;
  if (topic == null) throw ArgumentError('The ntfy address needs a topic: https://ntfy.sh/your-topic');
  final c = client ?? http.Client();
  try {
    // JSON publishing keeps £ and € intact (headers would need encoding).
    final r = await c
        .post(
          Uri(scheme: uri.scheme, host: uri.host, port: uri.hasPort ? uri.port : null, path: '/'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'topic': topic,
            'title': title,
            'message': body,
            'tags': ['shopping'],
            'click': ?link,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (r.statusCode >= 300) throw http.ClientException('ntfy answered ${r.statusCode}', uri);
  } finally {
    if (client == null) c.close();
  }
}
