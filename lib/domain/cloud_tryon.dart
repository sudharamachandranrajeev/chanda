import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'garment_fit.dart';

// Try-on by a cloud service, with the user's own key. Off until the user
// adds a key in Settings and agrees, per service, to what is sent, how long
// the service keeps it and what it costs; asked again whenever any of that
// changes. Sent: the body photo and the garment's picture, nothing else.
//
// The services, in the order Chanda uses them:
//   1. FASHN (its own API), try-on model v1.6;
//   2. fal, the same model, asked not to store the pictures;
//   3. Gemini image generation, only with a key the user marks as paid:
//      Google may use what is sent on a free key to improve its products,
//      and people may read it.
//
// The picture that comes back is not shown as it is: lib/domain/
// clothes_fit.dart takes only the clothes from it, keeps the photo
// everywhere else and refuses it if the body came out narrower.

/// The cloud try-on services Chanda can use.
enum CloudProvider { fashn, fal, gemini }

/// The service's name as its maker writes it.
String providerName(CloudProvider p) => switch (p) {
  CloudProvider.fashn => 'FASHN',
  CloudProvider.fal => 'fal',
  CloudProvider.gemini => 'Gemini',
};

/// Where the user gets a key.
String providerKeyPage(CloudProvider p) => switch (p) {
  CloudProvider.fashn => 'https://app.fashn.ai/api',
  CloudProvider.fal => 'https://fal.ai/dashboard/keys',
  CloudProvider.gemini => 'https://aistudio.google.com/apikey',
};

/// The local setting (never synced) that keeps the user's key for [p].
String cloudKeySetting(CloudProvider p) => 'chanda.cloud.${p.name}.key';

/// Set to "on" when the user says their Gemini key is on a paid plan.
const geminiPaidSetting = 'chanda.cloud.gemini.paid';

/// The local setting that keeps what the user agreed to for [p] (a
/// [consentFingerprint]).
String cloudConsentSetting(CloudProvider p) => 'chanda.cloud.consent.${p.name}';

/// What the user is told before the first picture goes to [p].
class ProviderTerms {
  const ProviderTerms({required this.sent, required this.kept, required this.price, required this.model});

  /// What is sent.
  final String sent;

  /// How long the service keeps it, and whether it learns from it.
  final String kept;

  /// What one picture costs, on the user's own account.
  final String price;

  /// The model or endpoint used; part of what the user agrees to.
  final String model;
}

/// Bumped when the terms text below changes, so the user is asked again.
const cloudTermsVersion = 1;

ProviderTerms providerTerms(CloudProvider p) {
  const sent =
      'Your body photo and the garment picture, made smaller (at most 1296 pixels). Nothing else: no name, '
      'no measurements, no list.';
  return switch (p) {
    CloudProvider.fashn => const ProviderTerms(
      sent: sent,
      kept:
          'FASHN says it deletes the pictures you send once the try-on is made, keeps the result for up '
          'to an hour, and does not train on them.',
      price: 'About US\$0.075 a picture, charged to your FASHN account.',
      model: 'tryon-v1.6',
    ),
    CloudProvider.fal => const ProviderTerms(
      sent: sent,
      kept:
          'fal keeps what is sent for up to 90 days unless asked not to; Chanda asks it not to store the '
          'pictures or the result.',
      price: 'About US\$0.075 a picture, charged to your fal account.',
      model: 'fal-ai/fashn/tryon/v1.6',
    ),
    CloudProvider.gemini => const ProviderTerms(
      sent: '$sent Also a short instruction to keep your shape and change only the clothes.',
      kept:
          'On a paid plan Google says it does not use what you send to improve its products; it keeps it '
          'for a limited time to look for abuse.',
      price: 'About US\$0.07 a picture, charged to your Google account.',
      model: geminiModel,
    ),
  };
}

/// Free Gemini keys: why Chanda does not use them.
const geminiFreeWarning =
    'Chanda only uses a Gemini key on a paid plan. On a free key Google may use your photos to improve its '
    'products, and people may read them.';

/// What the user agreed to for [p] with [key]: the terms, the model and
/// the key (hashed), so a change to any of them asks again.
String consentFingerprint(CloudProvider p, String key, {bool paid = false}) {
  final k = sha256.convert(utf8.encode(key.trim())).toString().substring(0, 12);
  return '${p.name}|v$cloudTermsVersion|${providerTerms(p).model}|paid=$paid|$k';
}

/// The service to use: the first with a key, in order (Gemini only when
/// marked paid); null when none.
CloudProvider? pickProvider(Map<CloudProvider, String> keys, {bool geminiPaid = false}) {
  for (final p in CloudProvider.values) {
    if ((keys[p] ?? '').trim().isEmpty) continue;
    if (p == CloudProvider.gemini && !geminiPaid) continue;
    return p;
  }
  return null;
}

const geminiModel = 'gemini-3.1-flash-image';

/// The instruction sent with the pictures to Gemini.
const geminiPrompt =
    'Dress the person in the first picture in the garment shown in the second picture. Change only the '
    'clothing. Keep the person exactly as they are: the same body shape, size and proportions, the same '
    'face, hair, skin, pose, lighting and background. Do not slim, reshape, retouch or beautify anything. '
    'Return one picture the same size as the first.';

/// A cloud try-on that did not work, in plain words.
class CloudTryOnError implements Exception {
  const CloudTryOnError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The longest side sent.
const cloudSide = 1296;

/// [jpegOrPng] as a JPEG at most [cloudSide] on its long side.
Uint8List cloudPicture(Uint8List jpegOrPng) {
  final d = img.decodeImage(jpegOrPng);
  if (d == null) throw const CloudTryOnError('A picture could not be read.');
  var up = img.bakeOrientation(d);
  if (max(up.width, up.height) > cloudSide) {
    up = img.copyResize(
      up,
      width: up.width >= up.height ? cloudSide : null,
      height: up.height > up.width ? cloudSide : null,
      interpolation: img.Interpolation.average,
    );
  }
  return img.encodeJpg(up.convert(numChannels: 3), quality: 90);
}

String _dataUri(Uint8List jpeg) => 'data:image/jpeg;base64,${base64Encode(jpeg)}';

/// The picture in a data URI.
Uint8List? _fromDataUri(String s) {
  final at = s.indexOf('base64,');
  if (!s.startsWith('data:') || at < 0) return null;
  try {
    return base64Decode(s.substring(at + 7));
  } on FormatException {
    return null;
  }
}

/// Runs one try-on with a service. The HTTP client and the wait between
/// status checks can be swapped (tests use fakes).
class CloudTryOn {
  CloudTryOn(
    this.provider,
    this.key, {
    http.Client? client,
    Future<void> Function(Duration)? wait,
    this.every = const Duration(seconds: 2),
    this.limit = const Duration(minutes: 3),
  }) : _client = client ?? http.Client(),
       _ownClient = client == null,
       _wait = wait ?? Future<void>.delayed;

  final CloudProvider provider;
  final String key;
  final http.Client _client;
  final bool _ownClient;
  final Future<void> Function(Duration) _wait;
  final Duration every, limit;

  String get _name => providerName(provider);

  /// The person in [photo] wearing the garment in [garment] (both JPEGs at
  /// most [cloudSide]); the service's picture, not yet checked.
  Future<Uint8List> run({
    required Uint8List photo,
    required Uint8List garment,
    required GarmentKind kind,
  }) async {
    try {
      return await switch (provider) {
        CloudProvider.fashn => _fashn(photo, garment, kind),
        CloudProvider.fal => _fal(photo, garment, kind),
        CloudProvider.gemini => _gemini(photo, garment),
      };
    } on CloudTryOnError {
      rethrow;
    } on TimeoutException {
      throw CloudTryOnError('$_name did not answer in time. Try again later.');
    } on http.ClientException {
      throw CloudTryOnError('Could not reach $_name. Check the connection and try again.');
    } on FormatException {
      throw CloudTryOnError('$_name sent an answer Chanda could not read.');
    } finally {
      if (_ownClient) _client.close();
    }
  }

  static String _category(GarmentKind k) => switch (k) {
    GarmentKind.top => 'tops',
    GarmentKind.dress => 'one-pieces',
    GarmentKind.skirt || GarmentKind.trousers => 'bottoms',
  };

  /// Throws the plain-words error for a failed HTTP answer.
  void _check(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    final why = switch (r.statusCode) {
      401 || 403 => '$_name did not accept the key. Check it in Settings.',
      402 => '$_name says your account is out of credit.',
      429 => '$_name is busy or your key is over its limit. Try again later.',
      400 || 422 => '$_name could not take these pictures: ${_message(r.body)}',
      _ => '$_name had a problem (${r.statusCode}). Try again later.',
    };
    throw CloudTryOnError(why);
  }

  static String _message(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map) {
        final e = j['error'] ?? j['detail'] ?? j['message'];
        if (e is Map) return '${e['message'] ?? e}';
        if (e is List && e.isNotEmpty) return '${e.first is Map ? (e.first as Map)['msg'] : e.first}';
        if (e != null) return '$e';
      }
    } on FormatException {
      // Not JSON.
    }
    return body.length > 200 ? body.substring(0, 200) : body;
  }

  Future<Map> _json(Future<http.Response> call) async {
    final r = await call.timeout(const Duration(seconds: 90));
    _check(r);
    final j = jsonDecode(r.body);
    if (j is! Map) throw const FormatException('not an object');
    return j;
  }

  /// A result picture given as a data URI or a web address.
  Future<Uint8List> _picture(String s) async {
    final inline = _fromDataUri(s);
    if (inline != null) return inline;
    final u = Uri.tryParse(s);
    if (u == null || u.scheme != 'https') throw FormatException('result $s');
    final r = await _client.get(u).timeout(const Duration(seconds: 60));
    _check(r);
    return r.bodyBytes;
  }

  /// Checks status with [poll] every [every] until it says done (returns
  /// its answer) or failed, or [limit] passes.
  Future<Map> _until(
    Future<Map> Function() poll,
    bool Function(Map) done,
    String? Function(Map) failed,
  ) async {
    final end = limit.inMilliseconds ~/ max(1, every.inMilliseconds);
    for (var i = 0; i <= end; i++) {
      final s = await poll();
      final why = failed(s);
      if (why != null) throw CloudTryOnError('$_name could not make the picture: $why');
      if (done(s)) return s;
      await _wait(every);
    }
    throw TimeoutException('status');
  }

  // ---- FASHN ----

  static final _fashnApi = Uri.parse('https://api.fashn.ai/v1/');

  Future<Uint8List> _fashn(Uint8List photo, Uint8List garment, GarmentKind kind) async {
    final headers = {'authorization': 'Bearer $key', 'content-type': 'application/json'};
    final started = await _json(
      _client.post(
        _fashnApi.resolve('run'),
        headers: headers,
        body: jsonEncode({
          'model_name': 'tryon-v1.6',
          'inputs': {
            'model_image': _dataUri(photo),
            'garment_image': _dataUri(garment),
            'category': _category(kind),
            'segmentation_free': true,
            'garment_photo_type': 'auto',
            'mode': 'balanced',
            'num_samples': 1,
            'output_format': 'jpeg',
            'return_base64': true,
          },
        }),
      ),
    );
    if (started['error'] != null) {
      throw CloudTryOnError('$_name could not start: ${_message(jsonEncode(started))}');
    }
    final id = '${started['id'] ?? ''}';
    if (id.isEmpty) throw const FormatException('no id');
    final done = await _until(
      () => _json(_client.get(_fashnApi.resolve('status/$id'), headers: headers)),
      (s) => s['status'] == 'completed',
      (s) => s['status'] == 'failed' ? _message(jsonEncode(s)) : null,
    );
    final out = done['output'];
    if (out is! List || out.isEmpty) throw const FormatException('no output');
    return _picture('${out.first}');
  }

  // ---- fal ----

  static final _falQueue = Uri.parse('https://queue.fal.run/fal-ai/fashn/tryon/v1.6');

  Future<Uint8List> _fal(Uint8List photo, Uint8List garment, GarmentKind kind) async {
    // X-Fal-Store-IO: 0 asks fal not to keep the pictures sent or made.
    final headers = {'authorization': 'Key $key', 'content-type': 'application/json', 'x-fal-store-io': '0'};
    final queued = await _json(
      _client.post(
        _falQueue,
        headers: headers,
        body: jsonEncode({
          'model_image': _dataUri(photo),
          'garment_image': _dataUri(garment),
          'category': _category(kind),
          'segmentation_free': true,
          'garment_photo_type': 'auto',
          'mode': 'balanced',
          'num_samples': 1,
          'output_format': 'jpeg',
          'sync_mode': true,
        }),
      ),
    );
    final status = Uri.tryParse('${queued['status_url'] ?? ''}');
    final result = Uri.tryParse('${queued['response_url'] ?? ''}');
    // Only follow addresses on fal's own queue.
    bool own(Uri? u) => u != null && u.scheme == 'https' && u.host == _falQueue.host;
    if (!own(status) || !own(result)) throw const FormatException('no queue addresses');
    await _until(
      () => _json(_client.get(status!, headers: headers)),
      (s) => s['status'] == 'COMPLETED',
      (s) => s['error'] != null ? _message(jsonEncode(s)) : null,
    );
    final done = await _json(_client.get(result!, headers: headers));
    final images = done['images'];
    if (images is! List || images.isEmpty || images.first is! Map) throw const FormatException('no images');
    return _picture('${(images.first as Map)['url']}');
  }

  // ---- Gemini ----

  static final _geminiApi = Uri.parse('https://generativelanguage.googleapis.com/v1beta/interactions');

  Future<Uint8List> _gemini(Uint8List photo, Uint8List garment) async {
    final j = await _json(
      _client.post(
        _geminiApi,
        headers: {'x-goog-api-key': key, 'api-revision': '2026-05-20', 'content-type': 'application/json'},
        body: jsonEncode({
          'model': geminiModel,
          'input': [
            {'type': 'text', 'text': geminiPrompt},
            {'type': 'image', 'mime_type': 'image/jpeg', 'data': base64Encode(photo)},
            {'type': 'image', 'mime_type': 'image/jpeg', 'data': base64Encode(garment)},
          ],
        }),
      ),
    );
    for (final step in (j['steps'] as List?) ?? const []) {
      if (step is! Map || step['type'] != 'model_output') continue;
      for (final c in (step['content'] as List?) ?? const []) {
        if (c is Map && c['type'] == 'image' && c['data'] is String) return base64Decode(c['data'] as String);
      }
    }
    throw const CloudTryOnError('Gemini did not send back a picture. It may have declined this one.');
  }
}
