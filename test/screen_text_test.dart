import 'dart:typed_data';

import 'package:chanda/domain/reading.dart';
import 'package:chanda/domain/screen_ocr.dart';
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
    expect(withScreenText(named, const [ScreenLine('€12,99', top: 5, height: 40)], screenHeight: 100).title, 'Lamp');
    expect(identical(withScreenText(named, const [ScreenLine('Add to basket', top: 5, height: 40)], screenHeight: 100), named), isTrue);
  });

  test('png height from the header', () {
    final png = Uint8List(24);
    ByteData.sublistView(png).setUint32(20, 2400);
    expect(pngHeight(png), 2400);
  });
}
