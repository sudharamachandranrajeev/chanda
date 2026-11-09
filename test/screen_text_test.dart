import 'package:chanda/domain/reading.dart';
import 'package:chanda/domain/pp_ocr.dart';
import 'package:chanda/domain/screen_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const blank = Reading(url: 'https://www.hacoo.com/p/1', title: '', currency: 'GBP', was: 1500);

  test('the biggest price-only line wins; was, delivery and discounts do not', () {
    final r = withScreenText(blank, const [
      ScreenLine('Hacoo', top: 10, height: 30),
      ScreenLine('Summer linen shirt, white', top: 120, height: 40),
      ScreenLine('£8.42', top: 300, height: 56),
      ScreenLine('Was £15.00', top: 360, height: 60),
      ScreenLine('Delivery £1.99', top: 420, height: 70),
      ScreenLine('-44%', top: 300, height: 70),
      ScreenLine('£0.99', top: 1500, height: 20),
    ], screenHeight: 2000);
    expect(r.price, 842);
    expect(r.currency, 'GBP');
    expect(r.title, 'Summer linen shirt, white');
    expect(r.was, isNull);
    expect(r.layer, 'screen');
    expect(r.warnings.single, contains('please confirm'));
  });

  test('a title already read is kept; no price leaves the reading alone', () {
    const named = Reading(url: 'https://shop.example/p', title: 'Lamp', currency: 'GBP');
    expect(
      withScreenText(named, const [ScreenLine('€12,99', top: 5, height: 40)], screenHeight: 100).title,
      'Lamp',
    );
    expect(
      identical(
        withScreenText(named, const [ScreenLine('Add to basket', top: 5, height: 40)], screenHeight: 100),
        named,
      ),
      isTrue,
    );
  });

  test('text boxes: regions over the threshold, grown and scaled to the picture', () {
    // A 20×10 map with one strong 8×3 region and one weak blob.
    final prob = List<double>.filled(200, 0);
    for (var y = 2; y < 5; y++) {
      for (var x = 4; x < 12; x++) {
        prob[y * 20 + x] = 0.9;
      }
    }
    for (var y = 7; y < 10; y++) {
      for (var x = 15; x < 19; x++) {
        prob[y * 20 + x] = 0.4;
      }
    }
    final boxes = boxesFrom(prob, 20, 10, 40, 20);
    expect(boxes, hasLength(1));
    // 8×3 grows by 8·3·1.5 / (2·11) ≈ 1.64 each side, then doubles.
    expect(boxes.single.left, closeTo((4 - 24 * 1.5 / 22) * 2, 1e-9));
    expect(boxes.single.top, closeTo((2 - 24 * 1.5 / 22) * 2, 1e-9));
    expect(boxes.single.right, closeTo((12 + 24 * 1.5 / 22) * 2, 1e-9));
  });

  test('CTC decoding drops blanks and repeats, keeps a doubled letter split by a blank', () {
    const chars = ['£', '4', '5', '.', '9'];
    const classes = 7; // blank, 5 characters, space
    List<double> step(int c) => [for (var i = 0; i < classes; i++) i == c ? 0.9 : 0.01];
    final steps = [1, 1, 2, 3, 0, 4, 5, 5, 0, 5, 6];
    final (text, conf) = ctcDecode([for (final c in steps) ...step(c)], steps.length, classes, chars);
    expect(text, '£45.99');
    expect(conf, closeTo(0.9, 1e-9));
  });
}
