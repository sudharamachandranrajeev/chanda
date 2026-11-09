import 'dart:convert';

import 'package:chanda/domain/ai_reader.dart';
import 'package:chanda/domain/reading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const page = Reading(
  url: 'https://shop.example/p/lamp',
  title: 'Lamp',
  currency: 'GBP',
  text: 'Desk lamp, brass. Now £24.99 Was £30.00. In stock.',
);

String answer(Map out, {String stop = 'end_turn'}) => jsonEncode({
  'stop_reason': stop,
  'content': [
    {'type': 'thinking', 'thinking': ''},
    {'type': 'text', 'text': jsonEncode(out)},
  ],
});

void main() {
  test('request asks for the schema, with the default fallback', () {
    final body = aiRequest(Uri.parse(page.url), page.text);
    expect(body['model'], aiModel);
    expect(body['fallbacks'], 'default');
    final format = (body['output_config'] as Map)['format'] as Map;
    expect(format['type'], 'json_schema');
    expect(
      ((format['schema'] as Map)['required'] as List),
      containsAll(['title', 'price', 'currency', 'in_stock']),
    );
    expect(jsonEncode(body), contains('Desk lamp, brass'));
  });

  test('answer fills the reading and asks to confirm', () {
    final r = applyAiResponse(
      page,
      200,
      answer({'title': 'Brass desk lamp', 'price': '£24.99', 'currency': 'GBP', 'in_stock': true}),
    );
    expect(r.title, 'Brass desk lamp');
    expect(r.price, 2499);
    expect(r.currency, 'GBP');
    expect(r.inStock, isTrue);
    expect(r.layer, 'ai');
    expect(r.warnings.single, contains('please confirm'));
  });

  test('empty values keep what Chanda read', () {
    final r = applyAiResponse(
      page,
      200,
      answer({'title': '', 'price': '', 'currency': '', 'in_stock': false}),
    );
    expect(r.title, 'Lamp');
    expect(r.price, isNull);
    expect(r.inStock, isFalse);
  });

  test('errors become plain words', () {
    expect(() => applyAiResponse(page, 401, '{}'), throwsA(isA<AiReadError>()));
    expect(
      () => applyAiResponse(page, 200, answer({}, stop: 'refusal')),
      throwsA(predicate((e) => '$e'.contains('declined'))),
    );
    expect(
      () => applyAiResponse(page, 200, '{"content":[{"type":"text","text":"no"}]}'),
      throwsA(isA<AiReadError>()),
    );
  });

  test('sends the key and never a payment page', () async {
    late http.Request sent;
    final client = MockClient((req) async {
      sent = req;
      return http.Response(
        answer({'title': 'Lamp', 'price': '£20', 'currency': 'GBP', 'in_stock': true}),
        200,
      );
    });
    final r = await readWithAi(page, ' sk-ant-test ', client: client);
    expect(r.price, 2000);
    expect(sent.headers['x-api-key'], 'sk-ant-test');
    expect(sent.headers['anthropic-version'], isNotEmpty);

    const pay = Reading(
      url: 'https://shop.example/checkout/payment',
      title: 'x',
      currency: 'GBP',
      text: 'card',
    );
    expect(() => readWithAi(pay, 'sk-ant-test', client: client), throwsA(isA<AiReadError>()));
  });

  test('key shape', () {
    expect(looksLikeKey('sk-ant-test-abcdefghijklmnopqrstuvwxyz'), isTrue);
    expect(looksLikeKey('hello'), isFalse);
  });
}
