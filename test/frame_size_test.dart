import 'dart:convert';

import 'package:chanda/domain/frame_size.dart';
import 'package:chanda/domain/reading.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('JSON-LD measurements by name, with units', () {
    // Shaped like real optician pages: camel-case names with UN/CEFACT units,
    // or plain names.
    final camel = jsonEncode({
      '@context': 'https://schema.org',
      '@type': 'Product',
      'name': 'Round frame',
      'additionalProperty': [
        {'@type': 'PropertyValue', 'name': 'frameWidth', 'value': 127, 'unitCode': 'MMT'},
        {'@type': 'PropertyValue', 'name': 'bridgeWidth', 'value': '19', 'unitCode': 'MMT'},
        {'@type': 'PropertyValue', 'name': 'lensHeight', 'value': 42, 'unitCode': 'MMT'},
        {'@type': 'PropertyValue', 'name': 'lensWidth', 'value': 51, 'unitCode': 'MMT'},
        {'@type': 'PropertyValue', 'name': 'templeArmLength', 'value': 140, 'unitCode': 'MMT'},
        {'@type': 'PropertyValue', 'name': 'frameShape', 'value': 'Square'},
      ],
    });
    final s = frameSizeInLd([camel])!;
    expect((s.total, s.lens, s.bridge, s.temple), (127.0, 51.0, 19.0, 140.0));
    expect(s.estimated, isFalse);
    expect(s.width, 127);
    expect(s.source, FrameSource.productData);
    expect(s.describe, "Frame 127 mm wide, from the shop's product data (size 51-19-140).");

    final plain = jsonEncode({
      '@graph': [
        {
          '@type': 'Product',
          'name': 'Adam',
          'size': '46-19-140',
          'additionalProperty': [
            {'name': 'Lens width', 'value': '4.6 cm'},
            {'name': 'Bridge width', 'value': '19 mm'},
            {'name': 'Temple length', 'value': 140, 'unitCode': 'MMT'},
          ],
        },
      ],
    });
    final p = frameSizeInLd([plain])!;
    expect((p.lens, p.bridge, p.temple, p.total), (46.0, 19.0, 140.0, null));
    expect(p.estimated, isTrue);
    expect(p.width, 2 * 46 + 19 + frameExtraMm);
    expect(p.describe, startsWith('Frame about 121 mm wide, estimated'));
  });

  test('the JSON-LD size marking when there are no measurements', () {
    final s = frameSizeInLd(['{"@type":"Product","name":"Adam","size":"46-19-140"}', 'not json'])!;
    expect((s.lens, s.bridge, s.temple), (46.0, 19.0, 140.0));
    expect(frameSizeInLd(['{"@type":"Product","size":"M"}']), isNull);
  });

  test('size markings in titles, and ordinary numbers left alone', () {
    for (final (t, want) in [
      ('Titanium frame 52□18 140 black', (52.0, 18.0, 140.0)),
      ('Round glasses 46-19-140', (46.0, 19.0, 140.0)),
      ('Square frame 54 17 145mm', (54.0, 17.0, 145.0)),
      ('Cat-eye 50[]20-135', (50.0, 20.0, 135.0)),
      ('Small frame 49□21', (49.0, 21.0, null)),
    ]) {
      final s = frameSizeInMarking(t, FrameSource.title);
      expect((s?.lens, s?.bridge, s?.temple), want, reason: t);
    }
    for (final t in [
      'Pack of 52 18 inch cables',
      'Model 2024-12-145',
      'Price 52.18 140',
      'Lens 90-18-140',
      'Size 52 18',
    ]) {
      expect(frameSizeInMarking(t, FrameSource.title), isNull, reason: t);
    }
  });

  test('a measurements table on the page, and the page order of trust', () {
    final t = frameSizeInTable(
      'Measurements\nLens width: 52 mm\nBridge 18mm\nTemple length 145 mm\nFrame width 138 mm',
    )!;
    expect((t.total, t.lens, t.bridge, t.temple), (138.0, 52.0, 18.0, 145.0));
    expect(t.source, FrameSource.page);

    final page = Evidence(
      url: 'https://shop.example/frame',
      h1: 'Round frame 48-20-145',
      ld: const [
        '{"@type":"Product","name":"Round frame","additionalProperty":[{"name":"Frame width","value":"132 mm"}]}',
      ],
      text: 'Lens width 50 mm',
    );
    expect(frameSizeOnPage(page)!.total, 132);
    expect(frameSizeOnPage(Evidence(url: '', h1: 'Round frame 48-20-145'))!.source, FrameSource.title);
    expect(frameSizeOnPage(const Evidence(url: '', text: 'Lens width 50 mm Bridge 20 mm'))!.width, 130);
    expect(frameSizeOnPage(const Evidence(url: '', h1: 'Gift card')), isNull);
  });

  test('the item\'s own words, typed sizes, and kept sizes', () {
    expect(frameSizeInItem('Aviator 58□14 135', '')!.source, FrameSource.title);
    expect(frameSizeInItem('Aviator', 'Lens width 58 mm, bridge 14 mm')!.width, 140);
    expect(frameSizeInItem('Aviator', 'Lovely'), isNull);

    expect(typedFrameSize(total: '136')!.width, 136);
    expect(typedFrameSize(marking: '52-18-140')!.width, 2 * 52 + 18 + frameExtraMm);
    expect(typedFrameSize(marking: '52/18')!.bridge, 18);
    expect(typedFrameSize(total: '136 mm', marking: '52-18')!.estimated, isFalse);
    expect(typedFrameSize(total: '13'), isNull);
    expect(typedFrameSize(), isNull);

    final s = typedFrameSize(total: '136', marking: '52-18-140')!;
    final back = FrameSize.fromJson(jsonDecode(jsonEncode(s.toJson())))!;
    expect(
      (back.total, back.lens, back.bridge, back.temple, back.source),
      (136.0, 52.0, 18.0, 140.0, FrameSource.typed),
    );
    expect(FrameSize.fromJson('x'), isNull);
  });

  test('which saved things are glasses', () {
    expect(isGlasses(title: 'Round blue-light glasses'), isTrue);
    expect(isGlasses(title: 'Tortoiseshell frame 50□20 140'), isTrue);
    expect(isGlasses(title: 'Oak picture frame', list: 'Home'), isFalse);
    expect(isGlasses(title: 'Frame Alfred', list: 'Glasses'), isTrue);
    expect(isGlasses(title: 'Pleated midi skirt'), isFalse);
  });
}
