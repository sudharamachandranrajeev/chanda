import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import 'screen_text.dart';

/// Text recognition on this device is available (Android, ML Kit).
bool get canReadScreen => Platform.isAndroid;

/// The lines of text in [png], read on the device by ML Kit. Nothing is
/// sent anywhere. The picture is deleted straight after.
Future<(List<ScreenLine>, double)> readScreen(Uint8List png) async {
  final file = File(
    '${(await getTemporaryDirectory()).path}/chanda_screen_${DateTime.now().microsecondsSinceEpoch}.png',
  );
  await file.writeAsBytes(png, flush: true);
  final recognizer = TextRecognizer();
  try {
    final text = await recognizer.processImage(InputImage.fromFilePath(file.path));
    final lines = [
      for (final b in text.blocks)
        for (final l in b.lines) ScreenLine(l.text, top: l.boundingBox.top, height: l.boundingBox.height),
    ];
    return (lines, pngHeight(png));
  } finally {
    await recognizer.close();
    if (file.existsSync()) await file.delete();
  }
}

/// A PNG's height in pixels, from its header.
double pngHeight(Uint8List png) =>
    png.length < 24 ? 0 : ByteData.sublistView(png, 20, 24).getUint32(0).toDouble();
