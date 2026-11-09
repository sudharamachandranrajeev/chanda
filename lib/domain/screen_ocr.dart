import 'dart:typed_data';

import 'pp_ocr.dart';
import 'screen_text.dart';

/// The lines of text in [png] and its height, read on this device by the
/// built-in models (lib/domain/pp_ocr.dart), on every platform. Nothing is sent anywhere.
Future<(List<ScreenLine>, double)> readScreen(Uint8List png) async => (await PpOcr.instance()).read(png);
