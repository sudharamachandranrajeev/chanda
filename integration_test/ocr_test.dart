import 'package:chanda/domain/reading.dart';
import 'package:chanda/domain/screen_ocr.dart';
import 'package:chanda/domain/screen_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';

// Runs the built-in text recognition on a drawn product card:
//   flutter test integration_test/ocr_test.dart -d linux
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reads the price and the name off a picture', (_) async {
    final card = img.Image(width: 900, height: 600)..clear(img.ColorRgb8(255, 255, 255));
    final ink = img.ColorRgb8(20, 20, 20);
    img.drawString(card, 'Brass desk lamp with dimmer', font: img.arial24, x: 40, y: 60, color: ink);
    img.drawString(card, r'$45.99', font: img.arial48, x: 40, y: 140, color: ink);
    img.drawString(card, r'Delivery $3.99', font: img.arial14, x: 40, y: 230, color: ink);
    img.drawString(card, 'Add to basket', font: img.arial24, x: 40, y: 300, color: ink);
    final (lines, height) = await readScreen(img.encodePng(card));
    expect(height, 600);
    final texts = [for (final l in lines) l.text];
    expect(texts, contains(r'$45.99'));
    expect(texts, contains('Brass desk lamp with dimmer'));
    const blank = Reading(url: 'https://shop.example/p/1', title: '', currency: 'USD');
    final r = withScreenText(blank, lines, screenHeight: height);
    expect(r.price, 4599);
    expect(r.title, 'Brass desk lamp with dimmer');
  });
}
