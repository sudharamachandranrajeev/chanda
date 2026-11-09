import 'dart:io';

import 'package:chanda/domain/embeddings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Runs the real "Smarter search" model on this device. Needs the model
// downloaded to a folder, passed in:
//   flutter test integration_test/embedder_test.dart -d linux --dart-define=MODEL_DIR=/path
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const dir = String.fromEnvironment('MODEL_DIR');

  testWidgets('the model finds by meaning', (_) async {
    expect(modelPresent(Directory(dir)), isTrue, reason: 'model files in $dir');
    final e = await OnnxEmbedder.load(Directory(dir));
    final v = await e.embed(['reading glasses', 'Lesebrille +2.0', 'brass desk lamp', 'light for my desk']);
    // Reference values from the same files run by the ONNX Runtime Python
    // package with Hugging Face's tokenizer.
    void near(List<double> got, List<double> want) {
      for (var i = 0; i < want.length; i++) {
        expect(got[i], closeTo(want[i], 2e-4));
      }
    }

    near(v[0], [0.0131, -0.0529, -0.0066, 0.0728]);
    near(v[1], [-0.1166, -0.0538, 0.0147, 0.0431]);
    expect(cosine(v[3], v[2]), greaterThan(cosine(v[3], v[0])));
    await e.close();
  });
}
