import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Text shared to Chanda from another app (Android's share sheet): usually
// a product link with some words around it. MainActivity keeps the share
// that started the app until Dart asks for it, and sends later ones as
// they come.

const _channel = MethodChannel('dev.brahma.chanda/share');

/// Calls [onShared] with each shared text, starting with the one that
/// opened the app.
void listenForShares(void Function(String text) onShared) {
  if (kIsWeb || !Platform.isAndroid) return;
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'shared' && call.arguments is String) onShared(call.arguments as String);
  });
  _channel.invokeMethod<String>('takeShared').then((text) {
    if (text != null && text.isNotEmpty) onShared(text);
  }, onError: (_) {});
}
