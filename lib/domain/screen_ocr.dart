import 'dart:typed_data';

import 'pp_ocr.dart';
import 'screen_text.dart';

/// The lines of text in [png] and its height, read on this device by the
/// built-in models (lib/domain/pp_ocr.dart), on every platform. Nothing is sent anywhere.
/// With [top] and [bottom] (pixels), only that band is read.
Future<(List<ScreenLine>, double)> readScreen(Uint8List png, {double top = 0, double? bottom}) async =>
    (await PpOcr.instance()).read(png, top: top, bottom: bottom);
