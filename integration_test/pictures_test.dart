import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chanda/domain/embeddings.dart';
import 'package:chanda/domain/pictures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';

// Runs the real picture model on this device. Needs the model downloaded to
// a folder, and optionally a photo of glasses:
//   flutter test integration_test/pictures_test.dart -d linux \
//     --dart-define=PICTURE_DIR=/path --dart-define=GLASSES=/path/photo.jpg
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const dir = String.fromEnvironment('PICTURE_DIR');
  const glasses = String.fromEnvironment('GLASSES');

  testWidgets('the picture model matches the reference and names a photo', (_) async {
    expect(modelPresent(Directory(dir), pictureFiles), isTrue, reason: 'model in $dir');
    final m = await OnnxPictureEmbedder.load(Directory(dir));
    // A 224×224 pattern, so no resizing differs from the reference.
    final pattern = img.Image(width: 224, height: 224);
    for (var y = 0; y < 224; y++) {
      for (var x = 0; x < 224; x++) {
        pattern.setPixelRgb(x, y, (x * 7 + y * 3) % 256, (x * x + y) % 256, (x ^ y) % 256);
      }
    }
    final [v, bad] = await m.embed([
      img.encodePng(pattern),
      Uint8List.fromList([1, 2, 3]),
    ]);
    // Reference: the full-precision model run by the ONNX Runtime Python
    // package. The int8 model differs a little by build, so compare the
    // direction, not each number.
    final ref = [
      for (final x
          in jsonDecode(await File('integration_test/picture_reference.json').readAsString()) as List)
        (x as num).toDouble(),
    ];
    expect(cosine(v!, Float32List.fromList(ref)), greaterThan(0.99));
    expect(bad, isNull);
    if (glasses.isNotEmpty) {
      final [photo] = await m.embed([await File(glasses).readAsBytes()]);
      expect(pictureTags(photo!, await loadLabels()).category, 'glasses');
    }
    await m.close();
  });
}
