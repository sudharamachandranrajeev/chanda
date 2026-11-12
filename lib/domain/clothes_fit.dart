import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'body_mask.dart';
import 'garment_fit.dart';
import 'glasses_fit.dart' show Cutout;
import 'pose_fit.dart';
import 'tryon.dart';

// Clothes on the saved body photo, start to finish, with the try-on
// models: find the body, check the garment's picture, cut it out, read its
// shape, draw it, and check the outline afterwards. Every step that is not
// sure says why in plain words and nothing is drawn. Also the same checks
// for a picture made by a cloud try-on service.

/// The picture shown, or why there is none.
class ClothesFit {
  const ClothesFit.picture(Uint8List this.jpeg, this.cut) : problem = null;
  const ClothesFit.problem(String this.problem) : jpeg = null, cut = null;

  /// The body photo with the garment on it (JPEG).
  final Uint8List? jpeg;

  /// The garment as cut out of its picture.
  final Cutout? cut;
  final String? problem;
}

/// The body on [photo] for a garment of kind [kind], or why it cannot be
/// used.
Future<(BodyReading?, String?)> findBody(TryOnModels m, Rgb photo, GarmentKind kind) async {
  final bodies = await m.bodies!.find(photo);
  final problem = bodyProblem(bodies, photo.w, photo.h, bodyNeeds(kind));
  if (problem != null) return (null, bodyProblemText(problem));
  return (bodies.single, null);
}

/// Whether a product picture shows a person: a face, or a body whose head
/// and shoulders the model is sure of.
Future<bool> showsPerson(TryOnModels m, Rgb picture) async {
  if ((await m.faces.find(picture)).isNotEmpty) return true;
  for (final b in await m.bodies!.find(picture)) {
    if ([Body.nose, Body.rightShoulder, Body.leftShoulder].every((i) => b.visibility(i) >= 0.8)) return true;
  }
  return false;
}

/// The garment on [picture] (a product picture) drawn on the body [photo];
/// or why it cannot be.
Future<ClothesFit> fitClothes(TryOnModels m, Rgb photo, Uint8List picture, GarmentKind kind) async {
  if (kind == GarmentKind.onePiece) return ClothesFit.problem(garmentProblemText(GarmentProblem.unsupported));
  final (body, bodyWhy) = await findBody(m, photo, kind);
  if (body == null) return ClothesFit.problem(bodyWhy!);

  final (cut, cutWhy, decoded) = await m.garments!.cut(picture);
  if (cut == null) return ClothesFit.problem(garmentProblemText(cutWhy ?? GarmentProblem.empty));
  if (decoded != null && await showsPerson(m, decoded)) {
    return ClothesFit.problem(garmentProblemText(GarmentProblem.person));
  }
  final read = await Isolate.run(() {
    if (garmentMirrored(cut) < minGarmentMirror) return (null, GarmentProblem.notFront);
    return readGarmentShape(cutoutAlpha(cut), cut.width, cut.height, kind);
  });
  final shape = read.$1;
  if (shape == null) return ClothesFit.problem(garmentProblemText(read.$2!));

  final raw = await m.segmenter!.parts(photo, body);
  final fitted = await Isolate.run(() {
    final parts = splitArms(raw, photo.w, photo.h, body);
    return fitGarment(
      rgb: photo.rgb,
      w: photo.w,
      h: photo.h,
      parts: parts,
      body: body,
      cut: cut,
      shape: shape,
    );
  });
  final (fit, fitWhy) = fitted;
  if (fit == null) return ClothesFit.problem(fitProblemText(fitWhy!));
  final after = (rgb: fit.rgb, w: photo.w, h: photo.h);
  final why = await outlineCheck(m, photo, after, body, before: raw, legs: onLegs(kind));
  if (why != null) return ClothesFit.problem(why);
  return ClothesFit.picture(await encodeJpeg(after), cut);
}

/// Why [after] (a picture made from [photo]) cannot be shown: the body's
/// outline came out narrower at the shoulders, waist or hips (and, with
/// [legs], the thighs, knees or calves); null when it is kept. [before] is
/// the photo's parts, when already known.
Future<String?> outlineCheck(
  TryOnModels m,
  Rgb photo,
  Rgb after,
  BodyReading body, {
  Uint8List? before,
  bool legs = false,
}) async {
  final b = before ?? await m.segmenter!.parts(photo, body);
  final a = await m.segmenter!.parts(after, body);
  final shrunk = await Isolate.run(() {
    final rows = outlineRows(body);
    final leg = legs ? legRows(body, photo.w, photo.h) : const <(String, int, int)>[];
    return outlineShrunk(
      measureOutline(b, photo.w, photo.h, rows, leg),
      measureOutline(a, after.w, after.h, rows, leg),
      leg,
    );
  });
  return shrunk.isEmpty ? null : outlineProblemText(shrunk);
}

/// [p] as a JPEG.
Future<Uint8List> encodeJpeg(Rgb p) => Isolate.run(
  () => img.encodeJpg(
    img.Image.fromBytes(width: p.w, height: p.h, bytes: p.rgb.buffer, numChannels: 3),
    quality: 90,
  ),
);

/// A cloud try-on's [result] (any picture) made from the body [photo]:
/// scaled to the photo, taken only where there are clothes (hair, face,
/// hands and everything else stay as on the photo), and checked that the
/// outline is kept; or why it cannot be shown.
Future<ClothesFit> checkCloudResult(TryOnModels m, Rgb photo, Uint8List result, GarmentKind kind) async {
  final (body, bodyWhy) = await findBody(m, photo, kind);
  if (body == null) return ClothesFit.problem(bodyWhy!);
  final made = await Isolate.run(() {
    final d = img.decodeImage(result);
    if (d == null) return null;
    final sized = img.copyResize(
      img.bakeOrientation(d),
      width: photo.w,
      height: photo.h,
      interpolation: img.Interpolation.average,
    );
    final rgb = sized.convert(numChannels: 3, format: img.Format.uint8).getBytes(order: img.ChannelOrder.rgb);
    return (rgb: rgb, w: photo.w, h: photo.h);
  });
  if (made == null) {
    return const ClothesFit.problem('The try-on service sent back something that is not a picture.');
  }
  final raw = await m.segmenter!.parts(photo, body);
  final madeParts = await m.segmenter!.parts(made, body);
  final pasted = await Isolate.run(
    () => pasteBack(photo.rgb, made.rgb, splitArms(raw, photo.w, photo.h, body), madeParts),
  );
  final after = (rgb: pasted, w: photo.w, h: photo.h);
  final why = await outlineCheck(m, photo, after, body, before: raw, legs: onLegs(kind));
  if (why != null) return ClothesFit.problem(why);
  return ClothesFit.picture(await encodeJpeg(after), null);
}
