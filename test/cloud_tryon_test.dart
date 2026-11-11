import 'dart:convert';
import 'dart:typed_data';

import 'package:chanda/domain/cloud_tryon.dart';
import 'package:chanda/domain/garment_fit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;

// The cloud try-on services against fake HTTP clients: no real calls, no
// money spent.
void main() {
  final photo = Uint8List.fromList(img.encodeJpg(img.Image(width: 40, height: 80)));
  final garment = Uint8List.fromList(img.encodeJpg(img.Image(width: 30, height: 30)));
  final result = Uint8List.fromList(img.encodePng(img.Image(width: 40, height: 80)));
  final resultUri = 'data:image/png;base64,${base64Encode(result)}';
  Future<void> noWait(Duration _) async {}

  test('FASHN: starts a run with both pictures inline, checks its status, and takes the result', () async {
    final calls = <http.Request>[];
    var polls = 0;
    final client = MockClient((r) async {
      calls.add(r);
      expect(r.headers['authorization'], 'Bearer fa-key');
      if (r.method == 'POST' && r.url.toString() == 'https://api.fashn.ai/v1/run') {
        final body = jsonDecode(r.body) as Map;
        expect(body['model_name'], 'tryon-v1.6');
        final inputs = body['inputs'] as Map;
        expect(inputs['model_image'], startsWith('data:image/jpeg;base64,'));
        expect(base64Decode((inputs['garment_image'] as String).split(',').last), garment);
        expect(inputs['category'], 'one-pieces');
        expect(inputs['return_base64'], isTrue);
        return http.Response(jsonEncode({'id': 'run1', 'error': null}), 200);
      }
      if (r.url.toString() == 'https://api.fashn.ai/v1/status/run1') {
        polls++;
        return http.Response(
          jsonEncode(
            polls < 3
                ? {'id': 'run1', 'status': 'processing'}
                : {
                    'id': 'run1',
                    'status': 'completed',
                    'output': [resultUri],
                  },
          ),
          200,
        );
      }
      return http.Response('not found', 404);
    });
    final got = await CloudTryOn(
      CloudProvider.fashn,
      'fa-key',
      client: client,
      wait: noWait,
    ).run(photo: photo, garment: garment, kind: GarmentKind.dress);
    expect(got, result);
    expect(polls, 3);
  });

  test('FASHN: a failed run and a refused key are said in plain words', () async {
    Future<String> error(MockClient c) async {
      try {
        await CloudTryOn(
          CloudProvider.fashn,
          'k',
          client: c,
          wait: noWait,
        ).run(photo: photo, garment: garment, kind: GarmentKind.top);
      } on CloudTryOnError catch (e) {
        return e.message;
      }
      return 'no error';
    }

    expect(
      await error(MockClient((r) async => http.Response('{"error":"Unauthorized"}', 401))),
      'FASHN did not accept the key. Check it in Settings.',
    );
    expect(
      await error(
        MockClient(
          (r) async => r.method == 'POST'
              ? http.Response('{"id":"x"}', 200)
              : http.Response(
                  jsonEncode({
                    'id': 'x',
                    'status': 'failed',
                    'error': {'name': 'PoseError', 'message': 'No person found'},
                  }),
                  200,
                ),
        ),
      ),
      'FASHN could not make the picture: No person found',
    );
    expect(
      await error(MockClient((r) async => throw http.ClientException('offline'))),
      'Could not reach FASHN. Check the connection and try again.',
    );
    // A run that never finishes gives up.
    expect(
      await error(
        MockClient(
          (r) async => http.Response(r.method == 'POST' ? '{"id":"x"}' : '{"status":"in_queue"}', 200),
        ),
      ),
      'FASHN did not answer in time. Try again later.',
    );
  });

  test('fal: asks it not to store the pictures, follows only its own queue', () async {
    final seen = <String>[];
    final client = MockClient((r) async {
      seen.add('${r.method} ${r.url}');
      expect(r.headers['authorization'], 'Key fal-key');
      expect(r.headers['x-fal-store-io'], '0');
      if (r.method == 'POST') {
        final body = jsonDecode(r.body) as Map;
        expect(body['sync_mode'], isTrue);
        expect(body['category'], 'tops');
        expect(body['model_image'], startsWith('data:image/jpeg;base64,'));
        return http.Response(
          jsonEncode({
            'request_id': 'r1',
            'status_url': 'https://queue.fal.run/fal-ai/fashn/requests/r1/status',
            'response_url': 'https://queue.fal.run/fal-ai/fashn/requests/r1',
          }),
          200,
        );
      }
      if (r.url.path.endsWith('/status')) {
        return http.Response(jsonEncode({'status': seen.length < 4 ? 'IN_PROGRESS' : 'COMPLETED'}), 200);
      }
      return http.Response(
        jsonEncode({
          'images': [
            {'url': resultUri},
          ],
        }),
        200,
      );
    });
    final got = await CloudTryOn(
      CloudProvider.fal,
      'fal-key',
      client: client,
      wait: noWait,
    ).run(photo: photo, garment: garment, kind: GarmentKind.top);
    expect(got, result);
    expect(seen.first, 'POST https://queue.fal.run/fal-ai/fashn/tryon/v1.6');
    expect(seen.last, 'GET https://queue.fal.run/fal-ai/fashn/requests/r1');

    // Addresses elsewhere are not followed.
    final elsewhere = MockClient(
      (r) async => http.Response(
        jsonEncode({'status_url': 'https://evil.example/s', 'response_url': 'https://evil.example/r'}),
        200,
      ),
    );
    expect(
      () => CloudTryOn(
        CloudProvider.fal,
        'k',
        client: elsewhere,
        wait: noWait,
      ).run(photo: photo, garment: garment, kind: GarmentKind.top),
      throwsA(
        isA<CloudTryOnError>().having(
          (e) => e.message,
          'message',
          'fal sent an answer Chanda could not read.',
        ),
      ),
    );
  });

  test('Gemini: sends the keep-your-shape instruction and both pictures, reads the image back', () async {
    final client = MockClient((r) async {
      expect(r.url.toString(), 'https://generativelanguage.googleapis.com/v1beta/interactions');
      expect(r.headers['x-goog-api-key'], 'g-key');
      final body = jsonDecode(r.body) as Map;
      expect(body['model'], geminiModel);
      final input = body['input'] as List;
      expect((input[0] as Map)['text'], contains('Do not slim'));
      expect(base64Decode((input[1] as Map)['data'] as String), photo);
      return http.Response(
        jsonEncode({
          'steps': [
            {
              'type': 'model_output',
              'content': [
                {'type': 'text', 'text': 'Here it is.'},
                {'type': 'image', 'mime_type': 'image/png', 'data': base64Encode(result)},
              ],
            },
          ],
        }),
        200,
      );
    });
    expect(
      await CloudTryOn(
        CloudProvider.gemini,
        'g-key',
        client: client,
      ).run(photo: photo, garment: garment, kind: GarmentKind.top),
      result,
    );
    final declined = MockClient((r) async => http.Response('{"steps": []}', 200));
    expect(
      () => CloudTryOn(
        CloudProvider.gemini,
        'g',
        client: declined,
      ).run(photo: photo, garment: garment, kind: GarmentKind.top),
      throwsA(isA<CloudTryOnError>()),
    );
  });

  test('the service used is the first with a key; Gemini only on a paid key', () {
    expect(pickProvider({}), isNull);
    expect(pickProvider({CloudProvider.fal: 'a', CloudProvider.fashn: 'b'}), CloudProvider.fashn);
    expect(pickProvider({CloudProvider.fashn: ' ', CloudProvider.fal: 'a'}), CloudProvider.fal);
    expect(pickProvider({CloudProvider.gemini: 'g'}), isNull);
    expect(pickProvider({CloudProvider.gemini: 'g'}, geminiPaid: true), CloudProvider.gemini);
  });

  test('agreeing again when the key, the plan or the terms change', () {
    final a = consentFingerprint(CloudProvider.fal, 'key1');
    expect(consentFingerprint(CloudProvider.fal, ' key1 '), a);
    expect(consentFingerprint(CloudProvider.fal, 'key2'), isNot(a));
    expect(consentFingerprint(CloudProvider.fashn, 'key1'), isNot(a));
    expect(
      consentFingerprint(CloudProvider.gemini, 'k', paid: true),
      isNot(consentFingerprint(CloudProvider.gemini, 'k')),
    );
    // The key itself is not kept in it.
    expect(a, isNot(contains('key1')));
    for (final p in CloudProvider.values) {
      final t = providerTerms(p);
      expect([t.sent, t.kept, t.price], everyElement(isNotEmpty));
    }
  });

  test('pictures are made smaller before they are sent', () {
    final big = Uint8List.fromList(img.encodePng(img.Image(width: 3000, height: 2000)));
    final small = img.decodeJpg(cloudPicture(big))!;
    expect((small.width, small.height), (cloudSide, 864));
    expect(() => cloudPicture(Uint8List(10)), throwsA(isA<CloudTryOnError>()));
  });
}
