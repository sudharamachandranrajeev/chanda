import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Text shared to Chanda from another app (Android's share sheet): usually
// a product link with some words around it; or a photo, to search by.
// MainActivity keeps the share that started the app until Dart asks for
// it, and sends later ones as they come. A photo arrives as the path of a
// copy in the app's cache.

const _channel = MethodChannel('dev.brahma.chanda/share');

/// Calls [onShared] with each shared text and [onPhoto] with each shared
/// photo's path, starting with the one that opened the app.
void listenForShares(void Function(String text) onShared, {void Function(String path)? onPhoto}) {
  if (kIsWeb || !Platform.isAndroid) return;
  _channel.setMethodCallHandler((call) async {
    if (call.arguments is! String) return;
    if (call.method == 'shared') onShared(call.arguments as String);
    if (call.method == 'photo') onPhoto?.call(call.arguments as String);
  });
  _channel.invokeMethod<String>('takeShared').then((text) {
    if (text != null && text.isNotEmpty) onShared(text);
  }, onError: (_) {});
  _channel.invokeMethod<String>('takePhoto').then((path) {
    if (path != null && path.isNotEmpty) onPhoto?.call(path);
  }, onError: (_) {});
}
