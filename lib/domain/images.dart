import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Where an item's saved pictures live on this device. They are kept so
/// the vault still shows the product after the shop takes the listing
/// down; they are not synced (each device fetches its own copies).
Future<Directory> imageDir(String itemId) async {
  final base = await getApplicationSupportDirectory();
  return Directory('${base.path}/images/$itemId');
}

/// Downloads up to [max] of [urls] for [itemId], skipping any already kept.
/// Failures, the folder's included, are left for the network picture to
/// cover: this never throws.
Future<void> keepImages(String itemId, List<String> urls, {int max = 5, http.Client? client}) async {
  if (urls.isEmpty) return;
  final Directory dir;
  try {
    dir = await imageDir(itemId);
    await dir.create(recursive: true);
  } on Object {
    return;
  }
  final c = client ?? http.Client();
  try {
    for (final (i, url) in urls.take(max).indexed) {
      final f = File('${dir.path}/$i');
      if (f.existsSync()) continue;
      try {
        final r = await c
            .get(Uri.parse(url), headers: {'user-agent': 'Chanda/0.1'})
            .timeout(const Duration(seconds: 20));
        final type = r.headers['content-type'] ?? '';
        if (r.statusCode == 200 && type.startsWith('image/') && r.bodyBytes.length < 8 << 20) {
          await f.writeAsBytes(r.bodyBytes);
        }
      } on Object {
        continue;
      }
    }
  } finally {
    if (client == null) c.close();
  }
}

/// The kept copy of picture [index], if there is one.
Future<File?> keptImage(String itemId, int index) async {
  final f = File('${(await imageDir(itemId)).path}/$index');
  return f.existsSync() ? f : null;
}

Future<void> forgetImages(String itemId) async {
  final dir = await imageDir(itemId);
  if (dir.existsSync()) await dir.delete(recursive: true);
}
