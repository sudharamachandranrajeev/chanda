import 'dart:math';
import 'dart:typed_data';

import 'body_mask.dart';
import 'face_fit.dart' show Px;
import 'glasses_fit.dart' show Cutout;
import 'pose_fit.dart';

// Clothes on a body photo, in 2D: the garment cut out of its product
// picture, its key points read from its outline, and the picture bent onto
// the person's body points. The photo itself is never changed: the garment
// is drawn over it, behind hair, face, arms and hands, and every other pixel
// stays exactly as it was. The garment is only ever widened to cover the
// body, never the body narrowed to fit the garment.
//
// No garment-landmark model is used (the ones available are not licensed
// for this). The points come from the shape of the cut-out alone, so they
// are only reliable on a plain picture of the garment laid flat or hung
// straight, from the front. Anything else is refused ("cannot fit"), never
// drawn badly.
//
//   Tops and dresses: the shoulder seams sit just outside the shoulder
//   joints and set the scale; the garment keeps its own proportions down
//   from there, each row at least as wide as the body under it.
//   Sleeves follow the arm from the shoulder through the elbow.
//   Skirts: the waistband sits at the waist, as wide as the body there.
//   Trousers and shorts: the seat (waistband to crotch) hangs from the
//   waist like a skirt; below the crotch each leg is cut into slices that
//   follow the body's leg from the hip through the knee to the ankle, each
//   at least as wide as the leg under it. Only what is below the waist is
//   ever drawn.

/// What a garment is, for how it is placed on the body.
enum GarmentKind {
  /// Shirts, tees, blouses, jumpers: from the shoulders to near the hips.
  top,

  /// Dresses: from the shoulders down, past the hips.
  dress,

  /// Skirts: from the waist down.
  skirt,

  /// Trousers, jeans, leggings: from the waist down two legs, to the
  /// ankles or above.
  trousers,

  /// Shorts: from the waist down two short legs, above the knees.
  shorts,

  /// Jumpsuits, playsuits, dungarees: top and legs in one. Not drawn on a
  /// photo yet; Chanda says so.
  onePiece,
}

bool _has(String text, String words) => RegExp('\\b($words)\\b', caseSensitive: false).hasMatch(text);

/// What kind of clothes a saved thing is, from its title, the shop's
/// category for it (JSON-LD), tags or list name; null when it is not
/// clothes.
GarmentKind? garmentKind({required String title, String category = '', String tags = '', String list = ''}) {
  // The title decides when it names a garment, then the shop's category;
  // tags and list name only when neither does ("Linen shirt" in a list
  // called "Dresses" is a top).
  for (final t in [title, category, '$tags $list']) {
    if (_has(t, 'jumpsuits?|playsuits?|dungarees|overalls|boilersuits?|rompers?|catsuits?|unitards?')) {
      return GarmentKind.onePiece;
    }
    if (_has(t, 'skirts?|skorts?')) return GarmentKind.skirt;
    if (_has(t, 'shorts|bermudas?|hot ?pants')) return GarmentKind.shorts;
    if (_has(
      t,
      'trousers?|pants|jeans|jeggings|leggings|chinos|joggers|sweatpants|track ?pants|slacks|culottes|'
      'cargos|capris?|palazzos?|flares',
    )) {
      return GarmentKind.trousers;
    }
    if (_has(t, 'dress(es)?|gowns?|frocks?|sundress(es)?|kaftans?|abayas?') &&
        !_has(t, 'dress (shirts?|shoes|socks|pants|trousers)')) {
      return GarmentKind.dress;
    }
    if (_has(
      t,
      't-?shirts?|tees?|shirts?|blouses?|tops?|jumpers?|sweaters?|sweatshirts?|hoodies?|cardigans?|polos?|'
      'vests?|tank tops?|camisoles?|tunics?|pullovers?|kurtas?|kurtis?',
    )) {
      return GarmentKind.top;
    }
  }
  return null;
}

/// The tag a saved thing gets so that it can be tried on: the garment word
/// the shop's [category] (from its JSON-LD) names, when the [title] names
/// no garment; else empty.
String garmentTag({required String title, required String category}) {
  if (garmentKind(title: title) != null) return '';
  final kind = garmentKind(title: '', category: category);
  if (kind == null) return '';
  // The category's own word for it, as the shop wrote it.
  final words = category.toLowerCase().split(RegExp(r'[^a-z-]+')).where((w) => w.isNotEmpty);
  for (final w in words.toList().reversed) {
    if (garmentKind(title: w) == kind) return w;
  }
  return kind.name;
}

/// Which body points a garment of kind [k] needs.
BodyNeeds bodyNeeds(GarmentKind k) => switch (k) {
  GarmentKind.top => BodyNeeds.torso,
  GarmentKind.dress || GarmentKind.skirt || GarmentKind.shorts => BodyNeeds.knees,
  GarmentKind.trousers || GarmentKind.onePiece => BodyNeeds.legs,
};

/// Whether a garment of kind [k] is worn on the legs: its fit is checked
/// at the thighs, knees and calves too.
bool onLegs(GarmentKind k) =>
    k == GarmentKind.trousers || k == GarmentKind.shorts || k == GarmentKind.onePiece;

/// Why a product picture cannot be used for a fit.
enum GarmentProblem {
  /// Nothing stood out from the background.
  empty,

  /// The cut-out fills the picture: the background did not come away.
  whole,

  /// A person is wearing it.
  person,

  /// The shape is not a garment seen from the front.
  notFront,

  /// The neckline could not be found.
  neck,

  /// The outline is not clear enough: sleeves, armholes or hem.
  shape,

  /// The two legs or the waistband of trousers or shorts cannot be read.
  legs,

  /// This kind of garment is not drawn yet.
  unsupported,
}

String garmentProblemText(GarmentProblem p) => switch (p) {
  GarmentProblem.empty => 'Chanda cannot find the garment on this picture. Try another picture of it.',
  GarmentProblem.whole =>
    'Chanda cannot separate the garment from the background on this picture. Try another picture of it.',
  GarmentProblem.person =>
    'This picture shows the garment on a person. Chanda needs a picture of the garment on its own, laid flat '
        'or hung straight.',
  GarmentProblem.notFront =>
    'This picture does not show the garment from the front, laid flat or hung straight. Pick a picture of the '
        'garment facing you.',
  GarmentProblem.neck =>
    'Chanda cannot find the neckline on this picture, so it cannot place the garment on your shoulders. Try '
        'another picture, from the front.',
  GarmentProblem.shape =>
    'Chanda cannot read the sleeves, armholes or hem on this picture. Try another picture of the garment on '
        'its own, from the front.',
  GarmentProblem.legs =>
    'Chanda cannot read the waistband and the two legs on this picture. Try another picture of the garment on '
        'its own, laid flat or hung straight, from the front, with the legs apart.',
  GarmentProblem.unsupported =>
    'Chanda does not draw jumpsuits, playsuits or dungarees on a photo yet. Tops, dresses, skirts, trousers '
        'and shorts it does.',
};

/// The cut-out of the largest connected piece of [alpha] (128 and over) on
/// [rgb] ([w]×[h]), with holes inside it filled (a print the cutting took
/// for background) and cropped to it; or the reason it cannot be used.
(Cutout?, GarmentProblem?) cutGarment(Uint8List rgb, int w, int h, Uint8List alpha) {
  final n = w * h;
  final label = Int32List(n);
  var best = 0, bestSize = 0, next = 0;
  final stack = <int>[];
  void fill(int s, bool Function(int) inside, void Function(int) mark) {
    mark(s);
    stack.add(s);
    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      final x = i % w;
      for (final j in [if (x > 0) i - 1, if (x < w - 1) i + 1, if (i >= w) i - w, if (i < n - w) i + w]) {
        if (inside(j)) {
          mark(j);
          stack.add(j);
        }
      }
    }
  }

  for (var s = 0; s < n; s++) {
    if (alpha[s] < 128 || label[s] != 0) continue;
    next++;
    var size = 0;
    fill(s, (j) => alpha[j] >= 128 && label[j] == 0, (j) {
      label[j] = next;
      size++;
    });
    if (size > bestSize) {
      bestSize = size;
      best = next;
    }
  }
  if (best == 0 || bestSize < n * 0.02) return (null, GarmentProblem.empty);
  // In pieces (a striped garment the background fill ran into): not one
  // garment.
  var solid = 0;
  for (var i = 0; i < n; i++) {
    if (alpha[i] >= 128) solid++;
  }
  if (bestSize < solid * 0.8) return (null, GarmentProblem.empty);
  var x0 = w, y0 = h, x1 = -1, y1 = -1;
  for (var i = 0; i < n; i++) {
    if (label[i] != best) continue;
    final x = i % w, y = i ~/ w;
    x0 = min(x0, x);
    x1 = max(x1, x);
    y0 = min(y0, y);
    y1 = max(y1, y);
  }
  final cw = x1 - x0 + 1, ch = y1 - y0 + 1;
  if (cw < 32 || ch < 32) return (null, GarmentProblem.empty);
  if (cw >= w * 0.98 && ch >= h * 0.98) return (null, GarmentProblem.whole);
  // What the outside reaches, from the crop's border.
  final outside = Uint8List(n);
  bool open(int j) {
    final x = j % w, y = j ~/ w;
    return x >= x0 && x <= x1 && y >= y0 && y <= y1 && label[j] != best && outside[j] == 0;
  }

  for (var x = x0; x <= x1; x++) {
    for (final y in [y0, y1]) {
      if (open(y * w + x)) fill(y * w + x, open, (j) => outside[j] = 1);
    }
  }
  for (var y = y0; y <= y1; y++) {
    for (final x in [x0, x1]) {
      if (open(y * w + x)) fill(y * w + x, open, (j) => outside[j] = 1);
    }
  }
  final out = Uint8List(cw * ch * 4);
  for (var y = 0; y < ch; y++) {
    for (var x = 0; x < cw; x++) {
      final s = (y + y0) * w + x + x0, o = (y * cw + x) * 4;
      out[o] = rgb[s * 3];
      out[o + 1] = rgb[s * 3 + 1];
      out[o + 2] = rgb[s * 3 + 2];
      // The piece keeps its soft rim; holes in it become solid; the rest
      // (other pieces, the background) clear.
      out[o + 3] = label[s] == best ? alpha[s] : (outside[s] == 1 ? 0 : 255);
    }
  }
  return (Cutout(out, cw, ch), null);
}

/// The alpha channel of [c], one byte per pixel.
Uint8List cutoutAlpha(Cutout c) {
  final out = Uint8List(c.width * c.height);
  for (var i = 0; i < out.length; i++) {
    out[i] = c.rgba[i * 4 + 3];
  }
  return out;
}

/// The share of the garment's solid pixels whose mirror image across the
/// middle of the cut-out is solid too.
double garmentMirrored(Cutout c) {
  var solid = 0, both = 0;
  for (var y = 0; y < c.height; y++) {
    for (var x = 0; x < c.width; x++) {
      if (c.rgba[(y * c.width + x) * 4 + 3] < 128) continue;
      solid++;
      if (c.rgba[(y * c.width + c.width - 1 - x) * 4 + 3] >= 128) both++;
    }
  }
  return solid == 0 ? 0 : both / solid;
}

/// The least a garment seen from the front mirrors itself.
const minGarmentMirror = 0.8;

/// The key points on a garment's outline, in the cut-out's pixels. Left and
/// right are as the picture shows them: the garment's left side is worn on
/// the person's right.
class GarmentShape {
  const GarmentShape({
    required this.kind,
    required this.width,
    required this.height,
    required this.left,
    required this.right,
    required this.topLeft,
    required this.topRight,
    required this.hemLeft,
    required this.hemRight,
    this.notch,
    this.armpitLeft,
    this.armpitRight,
    this.sleeveLeft,
    this.sleeveRight,
    this.legs,
  });

  final GarmentKind kind;
  final int width, height;

  /// First and last solid column of each row (−1 on an empty row).
  final List<int> left, right;

  /// The shoulder seams (tops, dresses) or the waistband's ends (skirts,
  /// trousers, shorts).
  final Px topLeft, topRight;
  final Px hemLeft, hemRight;

  /// The bottom of the neckline; null for skirts.
  final Px? notch;

  /// Where each side meets the sleeve or armhole; null for skirts.
  final Px? armpitLeft, armpitRight;

  /// The sleeves; null without.
  final Sleeve? sleeveLeft, sleeveRight;

  /// The legs of trousers and shorts; null for everything else.
  final Legs? legs;

  double get topY => (topLeft.y + topRight.y) / 2;
  double get centreX => (topLeft.x + topRight.x) / 2;

  /// The row where the sides start (the armpits; the top for skirts).
  int get bodyRow => armpitLeft == null ? topY.round() : max(armpitLeft!.y, armpitRight!.y).round();
}

/// The two legs of trousers or shorts laid flat: where they part, and on
/// each row below that the inner edge of each leg. The outer edges are the
/// garment's sides ([GarmentShape.left], [GarmentShape.right]).
class Legs {
  const Legs({
    required this.crotch,
    required this.innerLeft,
    required this.innerRight,
    required this.endLeft,
    required this.endRight,
  });

  /// The top of the gap between the legs.
  final Px crotch;

  /// Per row: the last solid column of the picture's left leg and the first
  /// of its right leg; −1 above the crotch and past the leg's end.
  final List<int> innerLeft, innerRight;

  /// The last row of each leg.
  final int endLeft, endRight;

  /// The middle of the gap between the legs on row [y].
  double gapMiddle(int y) {
    final l = innerLeft[y], r = innerRight[y];
    return l < 0 || r < 0 ? crotch.x : (l + r) / 2;
  }
}

/// The top edge of each column of [alpha] ([w]×[h]): the first solid row,
/// or [h] when the column is empty.
List<int> _topEdge(Uint8List alpha, int w, int h) {
  final top = List<int>.filled(w, h);
  for (var x = 0; x < w; x++) {
    for (var y = 0; y < h; y++) {
      if (alpha[y * w + x] >= 128) {
        top[x] = y;
        break;
      }
    }
  }
  return top;
}

(List<int>, List<int>) _sides(Uint8List alpha, int w, int h) {
  final left = List<int>.filled(h, -1), right = List<int>.filled(h, -1);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (alpha[y * w + x] >= 128) {
        left[y] = x;
        break;
      }
    }
    for (var x = w - 1; x >= 0; x--) {
      if (alpha[y * w + x] >= 128) {
        right[y] = x;
        break;
      }
    }
  }
  return (left, right);
}

double _median(Iterable<int> v) {
  final l = v.toList()..sort();
  return l.isEmpty ? 0 : l[l.length ~/ 2].toDouble();
}

/// The key points of a garment of kind [kind] from its cut-out [alpha]
/// ([w]×[h]), or why they cannot be found.
(GarmentShape?, GarmentProblem?) readGarmentShape(Uint8List alpha, int w, int h, GarmentKind kind) {
  if (kind == GarmentKind.onePiece) return (null, GarmentProblem.unsupported);
  final (left, right) = _sides(alpha, w, h);
  if (kind == GarmentKind.trousers || kind == GarmentKind.shorts) {
    return _readLegs(alpha, w, h, left, right, kind);
  }
  int wd(int y) => left[y] < 0 ? 0 : right[y] - left[y] + 1;
  final ratio = h / w;
  final hemRow = (h - 1 - max(1, 0.015 * h)).round();
  if (left[hemRow] < 0) return (null, GarmentProblem.shape);
  final hemL = Point(left[hemRow].toDouble(), hemRow.toDouble());
  final hemR = Point(right[hemRow].toDouble(), hemRow.toDouble());

  if (kind == GarmentKind.skirt) {
    if (ratio < 0.5 || ratio > 2.5) return (null, GarmentProblem.notFront);
    final band = max(1, (0.02 * h).round());
    // The waistband is the narrowest part; the skirt only widens below it.
    if (wd(band) < 0.4 * w || wd(hemRow) < 0.95 * wd(band)) return (null, GarmentProblem.notFront);
    return (
      GarmentShape(
        kind: kind,
        width: w,
        height: h,
        left: left,
        right: right,
        topLeft: Point(left[band].toDouble(), band.toDouble()),
        topRight: Point(right[band].toDouble(), band.toDouble()),
        hemLeft: hemL,
        hemRight: hemR,
      ),
      null,
    );
  }

  final fits = kind == GarmentKind.dress ? ratio >= 0.9 && ratio <= 4.0 : ratio >= 0.55 && ratio <= 2.2;
  if (!fits) return (null, GarmentProblem.notFront);
  final top = _topEdge(alpha, w, h);

  // Neckline: the lowest stretch of the top edge near the middle, against
  // the shoulders either side of it.
  int topMin(double a, double b) =>
      [for (var x = (a * w).round(); x <= (b * w).round(); x++) top[x]].reduce(min);
  final lo = (0.35 * w).round(), hi = (0.65 * w).round();
  final deepest = [for (var x = lo; x <= hi; x++) top[x]].reduce(max);
  final plateau = [
    for (var x = lo; x <= hi; x++)
      if (top[x] >= deepest - max(1, 0.01 * h)) x,
  ];
  final nx = plateau.reduce((a, b) => a + b) / plateau.length;
  // The shoulders (or straps): the highest top edge either side.
  final shoulders = min(topMin(0.05, 0.35), topMin(0.65, 0.95));
  final depth = deepest - shoulders;
  if (depth < 0.025 * h) return (null, GarmentProblem.neck);
  final rim = shoulders + 0.15 * depth;
  var nl = nx.round(), nr = nx.round();
  while (nl > 0 && top[nl] > rim) {
    nl--;
  }
  while (nr < w - 1 && top[nr] > rim) {
    nr++;
  }
  final neckWidth = (nr - nl) / w;
  if (neckWidth < 0.08 || neckWidth > 0.55) return (null, GarmentProblem.neck);

  // The body of the garment, below any sleeves, and whether there are any:
  // rows near the top much wider than it.
  final (bandA, bandB) = kind == GarmentKind.dress ? (0.35, 0.6) : (0.6, 0.85);
  final torsoW = _median([
    for (var y = (bandA * h).round(); y <= (bandB * h).round(); y++)
      if (wd(y) > 0) wd(y),
  ]);
  if (torsoW <= 0) return (null, GarmentProblem.shape);
  var widest = 0;
  for (var y = (0.03 * h).round(); y <= (0.45 * h).round(); y++) {
    widest = max(widest, wd(y));
  }
  final sleeves = widest >= 1.2 * torsoW;
  var armRow = (0.04 * h).round();
  if (sleeves) {
    for (var y = armRow; y <= (0.6 * h).round(); y++) {
      if (wd(y) > 1.15 * torsoW) armRow = y;
    }
    armRow += max(1, (0.02 * h).round());
  } else {
    while (armRow < h - 2 && wd(armRow) < 0.92 * torsoW) {
      armRow++;
    }
  }
  if (armRow < 0.08 * h || armRow > 0.6 * h || hemRow - armRow < 0.2 * h) return (null, GarmentProblem.shape);
  final armL = Point(left[armRow].toDouble(), armRow.toDouble());
  final armR = Point(right[armRow].toDouble(), armRow.toDouble());

  // Shoulder seams: straight above the armpits on a sleeved garment; the
  // top of the strap (between armhole and neck) on a sleeveless one.
  Px seam(bool leftSide) {
    if (sleeves) {
      final x = leftSide ? left[armRow] : right[armRow];
      return Point(x.toDouble(), top[x].toDouble());
    }
    // The middle of the strap's top.
    final a = leftSide ? left[armRow] : nr, b = leftSide ? nl : right[armRow];
    final high = [for (var x = a; x <= b; x++) top[x]].reduce(min);
    final xs = [
      for (var x = a; x <= b; x++)
        if (top[x] <= high + 1) x,
    ];
    final mx = xs.reduce((p, q) => p + q) / xs.length;
    return Point(mx, high.toDouble());
  }

  final seamL = seam(true), seamR = seam(false);
  if (seamR.x - seamL.x < 0.35 * torsoW || seamL.y >= armRow || seamR.y >= armRow) {
    return (null, GarmentProblem.shape);
  }

  Sleeve? sleeveL, sleeveR;
  if (sleeves) {
    sleeveL = _readSleeve(alpha, w, top, armRow, seamL, armL, true);
    sleeveR = _readSleeve(alpha, w, top, armRow, seamR, armR, false);
    if (sleeveL == null || sleeveR == null) return (null, GarmentProblem.shape);
  }
  return (
    GarmentShape(
      kind: kind,
      width: w,
      height: h,
      left: left,
      right: right,
      topLeft: seamL,
      topRight: seamR,
      hemLeft: hemL,
      hemRight: hemR,
      notch: Point(nx, deepest.toDouble()),
      armpitLeft: armL,
      armpitRight: armR,
      sleeveLeft: sleeveL,
      sleeveRight: sleeveR,
    ),
    null,
  );
}

/// The waistband and the two legs of trousers or shorts ([kind]) from
/// their cut-out [alpha] ([w]×[h], with its sides [left] and [right]).
(GarmentShape?, GarmentProblem?) _readLegs(
  Uint8List alpha,
  int w,
  int h,
  List<int> left,
  List<int> right,
  GarmentKind kind,
) {
  int wd(int y) => left[y] < 0 ? 0 : right[y] - left[y] + 1;
  bool solid(int x, int y) => x >= 0 && x < w && alpha[y * w + x] >= 128;
  final ratio = h / w;
  final shorts = kind == GarmentKind.shorts;
  final (least, most) = shorts ? (0.4, 1.6) : (0.9, 3.6);
  if (ratio < least || ratio > most) return (null, GarmentProblem.notFront);
  // The waistband: across the top, the full width of the seat.
  final band = max(1, (0.02 * h).round());
  if (wd(band) < 0.45 * w) return (null, GarmentProblem.legs);
  final mid = (left[band] + right[band]) / 2;
  final mx = mid.round();
  // The crotch: up the middle from the bottom, through the gap between the
  // legs, to where the fabric joins.
  if (solid(mx, h - 1)) return (null, GarmentProblem.legs);
  var crotch = h - 1;
  while (crotch > band && !solid(mx, crotch - 1)) {
    crotch--;
  }
  final (riseLeast, riseMost) = shorts ? (0.25, 0.85) : (0.12, 0.6);
  if (crotch < riseLeast * h || crotch > riseMost * h) return (null, GarmentProblem.legs);
  // Each leg's inner edge, row by row, until the leg ends.
  final innerL = List<int>.filled(h, -1), innerR = List<int>.filled(h, -1);
  var endL = crotch - 1, endR = crotch - 1;
  for (var y = crotch; y < h; y++) {
    if (endL == y - 1) {
      var x = mx;
      while (x >= 0 && !solid(x, y)) {
        x--;
      }
      if (x >= 0) {
        innerL[y] = x;
        endL = y;
      }
    }
    if (endR == y - 1) {
      var x = mx;
      while (x < w && !solid(x, y)) {
        x++;
      }
      if (x < w) {
        innerR[y] = x;
        endR = y;
      }
    }
  }
  final legL = endL - crotch, legR = endR - crotch;
  if (min(legL, legR) < 0.08 * h || (legL - legR).abs() > 0.1 * h) return (null, GarmentProblem.legs);
  // Each leg a real width near its top, and hanging down, not out.
  final y = crotch + (0.1 * min(legL, legR)).round();
  if (innerL[y] - left[y] < 0.12 * w || right[y] - innerR[y] < 0.12 * w) return (null, GarmentProblem.legs);
  for (final (top, bottom, end) in [
    ((left[y] + innerL[y]) / 2, (left[endL] + innerL[endL]) / 2, legL),
    ((right[y] + innerR[y]) / 2, (right[endR] + innerR[endR]) / 2, legR),
  ]) {
    if ((bottom - top).abs() > 0.6 * end) return (null, GarmentProblem.legs);
  }
  return (
    GarmentShape(
      kind: kind,
      width: w,
      height: h,
      left: left,
      right: right,
      topLeft: Point(left[band].toDouble(), band.toDouble()),
      topRight: Point(right[band].toDouble(), band.toDouble()),
      hemLeft: Point(left[endL].toDouble(), endL.toDouble()),
      hemRight: Point(right[endR].toDouble(), endR.toDouble()),
      legs: Legs(
        crotch: Point(mid, crotch.toDouble()),
        innerLeft: innerL,
        innerRight: innerR,
        endLeft: endL,
        endRight: endR,
      ),
    ),
    null,
  );
}

/// The x of the armhole line (from [seam] down to [armpit]) at row [y]:
/// straight up from the seam above it, straight down from the armpit below.
double _armholeX(Px seam, Px armpit, double y) {
  if (y <= seam.y) return seam.x;
  if (y >= armpit.y) return armpit.x;
  return seam.x + (armpit.x - seam.x) * (y - seam.y) / (armpit.y - seam.y);
}

/// Whether garment point ([x], [y]) is on the sleeve's side of the armhole
/// on the picture's left ([leftSide]) or right.
bool _onSleeve(Px seam, Px armpit, double x, double y, bool leftSide) =>
    y <= armpit.y && (leftSide ? x < _armholeX(seam, armpit, y) : x > _armholeX(seam, armpit, y));

/// A sleeve of a garment laid flat: cross-sections from the shoulder seam
/// out to its end. [along] runs down the sleeve's top edge from the [seam];
/// [inward] points from that edge into the sleeve. Each section, [t] along,
/// spans [from] to [to] inward (the top edge is near 0).
class Sleeve {
  const Sleeve({
    required this.seam,
    required this.armpit,
    required this.along,
    required this.inward,
    required this.t,
    required this.from,
    required this.to,
  });

  /// The armhole's ends: the sleeve is what lies beyond the line between.
  final Px seam, armpit;
  final Px along, inward;
  final List<double> t, from, to;

  Px edge(int i, {required bool top}) => seam + along * t[i] + inward * (top ? from[i] : to[i]);
}

/// How many slices a sleeve is cut into.
const sleeveSlices = 8;

/// The sleeve beyond [seam]–[armpit] on the picture's left ([leftSide]) or
/// right of the cut-out [alpha] ([w] wide; [top] is each column's top
/// edge; sleeves above [armRow]).
Sleeve? _readSleeve(Uint8List alpha, int w, List<int> top, int armRow, Px seam, Px armpit, bool leftSide) {
  final pts = <Px>[];
  var outer = seam.x;
  for (var y = 0; y <= armRow; y++) {
    for (var x = 0; x < w; x++) {
      if (alpha[y * w + x] >= 128 && _onSleeve(seam, armpit, x + 0.5, y + 0.5, leftSide)) {
        pts.add(Point(x + 0.5, y + 0.5));
        outer = leftSide ? min(outer, x.toDouble()) : max(outer, x.toDouble());
      }
    }
  }
  if (pts.length < 50 || (outer - seam.x).abs() < 0.04 * w) return null;
  // The top edge: a straight line fitted to the top of the columns between
  // the seam and the sleeve's far end (the ends left out).
  final a = min(seam.x, outer), b = max(seam.x, outer);
  final span = b - a;
  var n = 0, sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
  for (var x = (a + span * 0.1).round(); x <= (b - span * 0.1).round(); x++) {
    if (top[x] >= armRow) continue;
    n++;
    sx += x;
    sy += top[x];
    sxx += x * x;
    sxy += x * top[x].toDouble();
  }
  if (n < 3) return null;
  final slope = (n * sxy - sx * sy) / max(1e-9, n * sxx - sx * sx);
  var d = Point(1.0, slope);
  d = d * ((leftSide ? -1 : 1) / d.magnitude);
  var inward = Point(-d.y, d.x);
  if ((armpit.x - seam.x) * inward.x + (armpit.y - seam.y) * inward.y < 0) {
    inward = Point(-inward.x, -inward.y);
  }
  final ts = [for (final p in pts) (p.x - seam.x) * d.x + (p.y - seam.y) * d.y];
  final qs = [for (final p in pts) (p.x - seam.x) * inward.x + (p.y - seam.y) * inward.y];
  final far = ts.reduce(max);
  if (far < 0.06 * w) return null;
  final step = far / sleeveSlices;
  final t = <double>[], from = <double>[], to = <double>[];
  for (var i = 0; i <= sleeveSlices; i++) {
    final at = step * i;
    var lo = double.infinity, hi = -double.infinity;
    for (var k = 0; k < ts.length; k++) {
      if ((ts[k] - at).abs() > step / 2) continue;
      lo = min(lo, qs[k]);
      hi = max(hi, qs[k]);
    }
    if (hi < lo) continue;
    t.add(at);
    from.add(lo - 0.5);
    to.add(hi + 0.5);
  }
  if (t.length < 3) return null;
  return Sleeve(seam: seam, armpit: armpit, along: d, inward: inward, t: t, from: from, to: to);
}

/// How much wider a garment is laid flat than it looks worn, seen from the
/// front: flat, it shows half its way round; worn, the sides turn away.
const flatToWorn = 1.3;

/// How far outside each shoulder joint a shoulder seam sits, and how far
/// above it, as shares of the shoulder span.
const seamOut = 0.04, seamUp = 0.08;

/// Room left between the body's outline and the garment's, each side, as a
/// share of the shoulder span.
const fitEase = 0.02;

/// Where a skirt's waistband sits, and where a sleeveless garment's
/// armholes end, from the shoulders (0) to the hips (1).
const skirtWaistAt = 0.75, chestAt = 0.25;

/// The narrowest and widest a body is seen from the front at the chest and
/// at the waist, as shares of the span between the shoulder joints.
const chestToShoulders = (0.6, 1.15), waistToShoulders = (0.55, 1.3);

/// The least share of the clothes the person is wearing (between the
/// shoulders, or the waist for skirts, and the garment's hem or the hips)
/// that the garment must cover.
const minCover = 0.8;

/// Why a garment cannot be fitted to a body photo.
enum FitProblem {
  /// The sleeves cannot follow the arms: elbows (or wrists) hidden, or the
  /// arms are across the body.
  arms,

  /// The garment would leave much of the clothes underneath showing.
  cover,

  /// The garment would land mostly off the photo.
  place,

  /// The trouser legs cannot follow the legs: knees (or ankles) hidden, the
  /// legs raised or crossed.
  legs,
}

String fitProblemText(FitProblem p) => switch (p) {
  FitProblem.arms =>
    'Chanda cannot follow your arms on your body photo to draw the sleeves. Use a photo with your arms a little '
        'away from your sides and both elbows showing.',
  FitProblem.cover =>
    'This garment would leave much of what you are wearing on your body photo showing, so the preview would '
        'mix the two. A body photo in close-fitting clothes works best.',
  FitProblem.place => 'This garment would land mostly outside your body photo. Use a photo of all of you.',
  FitProblem.legs =>
    'Chanda cannot follow your legs on your body photo to draw the legs of this garment, and it does not '
        'guess. Use a photo standing straight, facing the camera, with both knees and ankles showing.',
};

/// The reason shown when a preview changed the body's outline at [places].
String outlineProblemText(List<String> places) =>
    'The preview came out narrower than you at the ${places.join(' and ')}, so Chanda does not show it. It '
    'never shows anyone thinner than they are.';

/// A garment drawn on a body photo: the new picture (RGB, the photo's size)
/// and how solid the garment is at each pixel where it shows (0-255).
class FitPicture {
  const FitPicture(this.rgb, this.drawn);
  final Uint8List rgb;
  final Uint8List drawn;
}

/// [cut] (with its key points [shape]) drawn on the photo [rgb] ([w]×[h])
/// over [body], whose [parts] (from [splitArms]) say what is in front; or
/// why it cannot be.
(FitPicture?, FitProblem?) fitGarment({
  required Uint8List rgb,
  required int w,
  required int h,
  required Uint8List parts,
  required BodyReading body,
  required Cutout cut,
  required GarmentShape shape,
}) {
  if (shape.legs != null) {
    return _fitLegs(rgb: rgb, w: w, h: h, parts: parts, body: body, cut: cut, shape: shape);
  }
  final rs = body.point(Body.rightShoulder), ls = body.point(Body.leftShoulder);
  final span = body.shoulderSpan;
  // The body's own frame: across the shoulders (left to right on the photo)
  final across = Point((ls.x - rs.x) / span, (ls.y - rs.y) / span);
  // and down the body from the middle of the shoulders to the middle of the
  // hips (square to the shoulders unless the body leans).
  final toHips = body.hips - body.shoulders;
  final down = toHips * (1 / max(1e-9, toHips.magnitude));
  final det = across.x * down.y - across.y * down.x;
  if (det.abs() < 0.5) return (null, FitProblem.place);
  final ease = fitEase * span;

  // Where the garment's top goes, and its scale (photo pixels per garment
  // pixel). Tops and dresses hang from their shoulder seams, just outside
  // the shoulder joints (a sleeveless one from the tops of its straps). A
  // sleeved garment takes its scale from the seams; anything else from the
  // body under it: a sleeveless garment at the chest, below the armpits; a
  // skirt at the waist, where it also hangs from. The body's width there
  // is kept to what a body can be for its shoulders, so loose clothes on
  // the photo do not blow the garment up (they are still covered: see the
  // widening below).
  final gc = shape.centreX, gy0 = shape.topY;
  final skirt = shape.kind == GarmentKind.skirt;
  final tl = rs - across * (seamOut * span) - down * (seamUp * span);
  final tr = ls + across * (seamOut * span) - down * (seamUp * span);
  Px origin = (tl + tr) * 0.5;
  double scale = tl.distanceTo(tr) / (shape.topRight.x - shape.topLeft.x);
  if (shape.sleeveLeft == null) {
    final anchor = body.shoulders + toHips * (skirt ? skirtWaistAt : chestAt);
    final o = outlineAt(parts, w, anchor.y.round(), anchor.x.round(), of: isTorso, through: isLimb);
    if (o == null) return (null, FitProblem.place);
    final (least, most) = skirt ? waistToShoulders : chestToShoulders;
    final wide = (o.$2 - o.$1 + 1.0).clamp(least * span, most * span);
    final row = skirt ? gy0.round() : shape.bodyRow;
    final flat = shape.right[row] - shape.left[row] + 1;
    scale = (wide + 2 * ease) * flatToWorn / flat;
    if (skirt) origin = anchor;
  }
  Px toPhoto(double gx, double gy, double ka, double kb) {
    final u = gx - gc, v = gy - gy0;
    return origin + across * (scale * u * (u < 0 ? ka : kb)) + down * (scale * v);
  }

  // How much each garment row is widened, per side: rows from the armpits
  // down are at least as wide as the body under them (plus ease), and the
  // garment's flat width is brought to its worn width where that is wider.
  final ch = shape.height, cw = shape.width;
  final kl = Float64List(ch)..fillRange(0, ch, 1);
  final kr = Float64List(ch)..fillRange(0, ch, 1);
  final from = shape.bodyRow;
  final step = max(1, ch ~/ 32);
  final rows = [for (var y = from; y < ch; y += step) y];
  final sl = <double>[], sr = <double>[];
  for (final gy in rows) {
    final hl = max(1.0, gc - shape.left[gy]), hr = max(1.0, shape.right[gy] + 1 - gc);
    var wantL = scale * hl / flatToWorn, wantR = scale * hr / flatToWorn;
    final p = origin + down * (scale * (gy - gy0));
    final y = p.y.round(), x = p.x.round();
    if (y >= 0 && y < h && x >= 0 && x < w) {
      final o = outlineAt(parts, w, y, x, of: isTorso, through: isLimb);
      if (o != null) {
        wantL = max(wantL, p.x - o.$1 + ease);
        wantR = max(wantR, o.$2 + 1 - p.x + ease);
      }
    }
    sl.add(wantL / (scale * hl));
    sr.add(wantR / (scale * hr));
  }
  // Smooth: each sample the widest of itself and its neighbours.
  List<double> widest(List<double> v) => [
    for (var i = 0; i < v.length; i++) [v[max(0, i - 1)], v[i], v[min(v.length - 1, i + 1)]].reduce(max),
  ];
  final wl = widest(sl), wr = widest(sr);
  double at(List<double> s, int y) {
    if (y >= from) {
      final f = (y - from) / step;
      final i = min(f.floor(), s.length - 1), j = min(i + 1, s.length - 1);
      return s[i] + (s[j] - s[i]) * (f - i).clamp(0.0, 1.0);
    }
    // Between the seams and the armpits, eased in from 1 at the seams.
    if (y <= gy0) return 1;
    return 1 + (s.first - 1) * (y - gy0) / max(1.0, from - gy0);
  }

  for (var y = 0; y < ch; y++) {
    kl[y] = at(wl, y);
    kr[y] = at(wr, y);
  }

  final paint = _Painter(rgb, w, parts, cut);
  final sampleAt = paint.sampleAt, put = paint.put;

  // The body of the garment: every photo pixel in its reach, mapped back.
  final kmax = max(kl.reduce(max), kr.reduce(max));
  final corners = [
    for (final (gx, gy) in [(0.0, 0.0), (cw - 1.0, 0.0), (0.0, ch - 1.0), (cw - 1.0, ch - 1.0)])
      toPhoto(gx, gy, kmax, kmax),
  ];
  final bx0 = max(0, corners.map((p) => p.x).reduce(min).floor() - 2);
  final bx1 = min(w - 1, corners.map((p) => p.x).reduce(max).ceil() + 2);
  final by0 = max(0, corners.map((p) => p.y).reduce(min).floor() - 2);
  final by1 = min(h - 1, corners.map((p) => p.y).reduce(max).ceil() + 2);
  if (bx0 >= bx1 || by0 >= by1) return (null, FitProblem.place);
  final aL = shape.armpitLeft, aR = shape.armpitRight;
  final sleeved = shape.sleeveLeft != null;
  for (var y = by0; y <= by1; y++) {
    for (var x = bx0; x <= bx1; x++) {
      final dx = x + 0.5 - origin.x, dy = y + 0.5 - origin.y;
      final a = (dx * down.y - dy * down.x) / det, b = (across.x * dy - across.y * dx) / det;
      final gy = gy0 + b / scale;
      if (gy < 0 || gy > ch - 1) continue;
      final row = gy.round().clamp(0, ch - 1);
      final gx = gc + a / (scale * (a < 0 ? kl[row] : kr[row]));
      if (sleeved &&
          (_onSleeve(shape.topLeft, aL!, gx, gy, true) || _onSleeve(shape.topRight, aR!, gx, gy, false))) {
        continue;
      }
      if (sampleAt(gx - 0.5, gy - 0.5)) put(y * w + x, false);
    }
  }

  // The sleeves, along the arms, hanging off their top edges towards the
  // body's middle line.
  if (sleeved) {
    for (final leftSide in [true, false]) {
      final sleeve = leftSide ? shape.sleeveLeft! : shape.sleeveRight!;
      final row = sleeve.seam.y.round().clamp(0, ch - 1);
      final ok = _drawSleeve(
        sleeve: sleeve,
        body: body,
        arm: leftSide
            ? const [Body.rightShoulder, Body.rightElbow, Body.rightWrist]
            : const [Body.leftShoulder, Body.leftElbow, Body.leftWrist],
        w: w,
        h: h,
        seam: toPhoto(sleeve.seam.x, sleeve.seam.y, kl[row], kr[row]),
        inward: across * (leftSide ? 1.0 : -1.0) + down,
        scale: scale,
        sample: sampleAt,
        put: (i) => put(i, true),
        inSleeve: (gx, gy) => _onSleeve(sleeve.seam, sleeve.armpit, gx, gy, leftSide),
      );
      if (!ok) return (null, FitProblem.arms);
    }
  }

  // The clothes the person is wearing must be mostly covered.
  final hem = origin + down * (scale * (ch - 1 - gy0));
  final top = skirt ? origin.y : outlineRows(body)[0].$1.toDouble();
  final bottom = min(skirt ? body.mid(Body.rightKnee, Body.leftKnee).y : body.hips.y, hem.y);
  if (!paint.covers(top, bottom)) return (null, FitProblem.cover);
  return (FitPicture(paint.out, paint.drawn), null);
}

/// Where the waistband of trousers and shorts sits, from the shoulders (0)
/// to the hips (1).
const legsWaistAt = 0.8;

/// How many slices each leg of trousers or shorts is cut into.
const legSlices = 12;

/// How far past the ankle a trouser leg may reach (to the heel), as a share
/// of the leg from hip to ankle.
const pastAnkle = 0.05;

/// Whether photo point [p] is in the body's lower half: at or below the
/// middle between the shoulders and the hips. Trousers and shorts are never
/// drawn above it.
bool lowerHalf(BodyReading body, Px p) {
  final toHips = body.hips - body.shoulders;
  final len = max(1e-9, toHips.magnitude);
  final along = ((p.x - body.shoulders.x) * toHips.x + (p.y - body.shoulders.y) * toHips.y) / len;
  return along >= 0.5 * len;
}

/// Trousers or shorts ([shape] has its legs) drawn on [body]: the seat from
/// the waist to the crotch hangs like a skirt; each leg is cut into slices
/// that follow the body's leg (hip, knee, ankle), each at least as wide as
/// the leg under it. Only the lower half of the body is drawn on.
(FitPicture?, FitProblem?) _fitLegs({
  required Uint8List rgb,
  required int w,
  required int h,
  required Uint8List parts,
  required BodyReading body,
  required Cutout cut,
  required GarmentShape shape,
}) {
  final legs = shape.legs!;
  final rs = body.point(Body.rightShoulder), ls = body.point(Body.leftShoulder);
  final span = body.shoulderSpan;
  final across = Point((ls.x - rs.x) / span, (ls.y - rs.y) / span);
  final toHips = body.hips - body.shoulders;
  final down = toHips * (1 / max(1e-9, toHips.magnitude));
  final det = across.x * down.y - across.y * down.x;
  if (det.abs() < 0.5) return (null, FitProblem.place);
  final ease = fitEase * span;
  final gc = shape.centreX, gy0 = shape.topY;
  final ch = shape.height;
  final crotchRow = legs.crotch.y.round();

  // The waistband at the waist, as wide as the body there (kept to what a
  // body can be for its shoulders); that sets the scale.
  final origin = body.shoulders + toHips * legsWaistAt;
  final o = outlineAt(parts, w, origin.y.round(), origin.x.round(), of: isTorso, through: isLimb);
  if (o == null) return (null, FitProblem.place);
  final (least, most) = waistToShoulders;
  final wide = (o.$2 - o.$1 + 1.0).clamp(least * span, most * span);
  final band = gy0.round();
  final scale = (wide + 2 * ease) * flatToWorn / (shape.right[band] - shape.left[band] + 1);

  // The seat, row by row down to the crotch: each side at least as wide as
  // the body under it.
  final kl = Float64List(ch)..fillRange(0, ch, 1);
  final kr = Float64List(ch)..fillRange(0, ch, 1);
  final step = max(1, crotchRow ~/ 8);
  final rows = [for (var y = 0; y < crotchRow; y += step) y, crotchRow];
  final sl = <double>[], sr = <double>[];
  for (final gy in rows) {
    final hl = max(1.0, gc - shape.left[gy]), hr = max(1.0, shape.right[gy] + 1 - gc);
    var wantL = scale * hl / flatToWorn, wantR = scale * hr / flatToWorn;
    final p = origin + down * (scale * (gy - gy0));
    final y = p.y.round(), x = p.x.round();
    if (y >= 0 && y < h && x >= 0 && x < w) {
      final at = outlineAt(parts, w, y, x, of: isTorso, through: isLimb);
      if (at != null) {
        wantL = max(wantL, p.x - at.$1 + ease);
        wantR = max(wantR, at.$2 + 1 - p.x + ease);
      }
    }
    sl.add(wantL / (scale * hl));
    sr.add(wantR / (scale * hr));
  }
  List<double> widest(List<double> v) => [
    for (var i = 0; i < v.length; i++) [v[max(0, i - 1)], v[i], v[min(v.length - 1, i + 1)]].reduce(max),
  ];
  final wl = widest(sl), wr = widest(sr);
  for (var y = 0; y < ch; y++) {
    final f = min(y, crotchRow) / step;
    final i = min(f.floor(), rows.length - 1), j = min(i + 1, rows.length - 1);
    final t = ((min(y, crotchRow) - rows[i]) / max(1, rows[j] - rows[i])).clamp(0.0, 1.0);
    kl[y] = wl[i] + (wl[j] - wl[i]) * t;
    kr[y] = wr[i] + (wr[j] - wr[i]) * t;
  }
  Px toPhoto(double gx, double gy) {
    final u = gx - gc, v = gy - gy0;
    final row = gy.round().clamp(0, crotchRow);
    return origin + across * (scale * u * (u < 0 ? kl[row] : kr[row])) + down * (scale * v);
  }

  final paint = _Painter(rgb, w, parts, cut);
  // Never over the arms or hands in front, nor above the lower half.
  void put(int i) {
    if (lowerHalf(body, Point(i % w + 0.5, i ~/ w + 0.5))) paint.put(i, false);
  }

  // The seat: every photo pixel in its reach, mapped back.
  final kmax = max(kl.reduce(max), kr.reduce(max));
  final corners = [
    for (final (gx, gy) in [
      (0.0, 0.0),
      (shape.width - 1.0, 0.0),
      (0.0, legs.crotch.y),
      (shape.width - 1.0, legs.crotch.y),
    ])
      origin + across * (scale * (gx - gc) * kmax) + down * (scale * (gy - gy0)),
  ];
  final bx0 = max(0, corners.map((p) => p.x).reduce(min).floor() - 2);
  final bx1 = min(w - 1, corners.map((p) => p.x).reduce(max).ceil() + 2);
  final by0 = max(0, corners.map((p) => p.y).reduce(min).floor() - 2);
  final by1 = min(h - 1, corners.map((p) => p.y).reduce(max).ceil() + 2);
  if (bx0 >= bx1 || by0 >= by1) return (null, FitProblem.place);
  for (var y = by0; y <= by1; y++) {
    for (var x = bx0; x <= bx1; x++) {
      final dx = x + 0.5 - origin.x, dy = y + 0.5 - origin.y;
      final a = (dx * down.y - dy * down.x) / det, b = (across.x * dy - across.y * dx) / det;
      final gy = gy0 + b / scale;
      if (gy < 0 || gy > legs.crotch.y + 0.5) continue;
      final row = gy.round().clamp(0, crotchRow);
      final gx = gc + a / (scale * (a < 0 ? kl[row] : kr[row]));
      if (paint.sampleAt(gx - 0.5, gy - 0.5)) put(y * w + x);
    }
  }

  // The legs. The picture's left leg is worn on the person's right.
  final chains = [
    for (final side in const [
      [Body.rightHip, Body.rightKnee, Body.rightAnkle],
      [Body.leftHip, Body.leftKnee, Body.leftAnkle],
    ])
      [for (final i in side) body.point(i)],
  ];
  // The point [d] pixels down [chain] from the hip joint, and the leg's
  // direction there; past the ankle, straight on.
  (Px, Px) along(List<Px> chain, double d) {
    var rest = d;
    for (var i = 0; ; i++) {
      final a = chain[i], b = chain[i + 1];
      final len = a.distanceTo(b);
      final dir = (b - a) * (1 / len);
      if (rest <= len || i == chain.length - 2) return (a + dir * rest, dir);
      rest -= len;
    }
  }

  double cross(Px a, Px b, Px c) => (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
  // The person's right knee and ankle stay on their right: legs crossed
  // cannot carry two trouser legs.
  for (var j = 1; j < 3; j++) {
    final gap = chains[1][j] - chains[0][j];
    if (gap.x * across.x + gap.y * across.y <= 0) return (null, FitProblem.legs);
  }
  final crotch = toPhoto(legs.crotch.x, legs.crotch.y);
  var lowest = crotch.y;
  for (final leftSide in [true, false]) {
    final chain = chains[leftSide ? 0 : 1], other = chains[leftSide ? 1 : 0];
    final (knee, ankle) = leftSide ? (Body.rightKnee, Body.rightAnkle) : (Body.leftKnee, Body.leftAnkle);
    final thigh = chain[0].distanceTo(chain[1]), shin = chain[1].distanceTo(chain[2]);
    if (!body.sees(knee, w, h) || thigh < 1 || shin < 1) return (null, FitProblem.legs);
    // The leg must hang down the body: not raised, not folded up.
    double downward(Px a, Px b) => ((b.x - a.x) * down.x + (b.y - a.y) * down.y) / a.distanceTo(b);
    if (downward(chain[0], chain[1]) < 0.5 || downward(chain[1], chain[2]) < 0.5) {
      return (null, FitProblem.legs);
    }
    final end = leftSide ? legs.endLeft : legs.endRight;
    final dir0 = (chain[1] - chain[0]) * (1 / thigh);
    // Where the crotch's level is down the thigh.
    final d0 = ((crotch.x - chain[0].x) * dir0.x + (crotch.y - chain[0].y) * dir0.y).clamp(0.0, 0.8 * thigh);
    var legScale = scale;
    final reach = d0 + scale * (end - crotchRow);
    if (reach > 0.9 * thigh && !body.sees(ankle, w, h)) return (null, FitProblem.legs);
    if (body.sees(ankle, w, h)) {
      final most = (thigh + shin) * (1 + pastAnkle);
      if (reach > most) legScale = (most - d0) / max(1, end - crotchRow);
    }
    final shift0 =
        toPhoto(
          leftSide
              ? (shape.left[crotchRow] + legs.innerLeft[crotchRow] + 1) / 2
              : (legs.innerRight[crotchRow] + shape.right[crotchRow] + 1) / 2,
          legs.crotch.y,
        ) -
        along(chain, d0).$1;

    // The slices: on the garment, across the leg from its outer edge to its
    // inner one, a little wider so none of it is cut off; on the photo,
    // across the body's leg, as wide as the leg is worn and at least as wide
    // as the body's leg there.
    const margin = 0.08;
    final src = <(Px, Px)>[], dst = <(Px, Px)>[];
    final outs = <double>[], ins = <double>[];
    final centres = <Px>[], normals = <Px>[];
    for (var i = 0; i <= legSlices; i++) {
      final y = crotchRow + ((end - crotchRow) * i / legSlices).round();
      final outer = leftSide ? shape.left[y].toDouble() : shape.right[y] + 1.0;
      final inner = leftSide ? legs.innerLeft[y] + 1.0 : legs.innerRight[y].toDouble();
      final half = (inner - outer).abs() / 2;
      final m = 2 * half * margin * (leftSide ? 1 : -1);
      src.add((Point(outer - m, y.toDouble()), Point(inner + m, y.toDouble())));
      final d = d0 + legScale * (y - crotchRow);
      final (c, dir) = along(chain, d);
      final centre = c + shift0 * max(0.0, 1 - (d - d0) / max(1.0, thigh - d0));
      var n = Point(-dir.y, dir.x);
      if (n.x * across.x + n.y * across.y < 0) n = Point(-n.x, -n.y);
      centres.add(centre);
      normals.add(n);
      var wantOut = scale * half / flatToWorn, wantIn = wantOut;
      final cy = centre.y.round(), cx = centre.x.round();
      if (cy >= 0 && cy < h && cx >= 0 && cx < w) {
        final at = outlineAt(parts, w, cy, cx, of: isTorso, through: isLimb);
        if (at != null) {
          // Legs together read as one stretch: each leg takes its own side
          // of the middle between them.
          final mid = (c.x + along(other, d).$1.x) / 2;
          if (leftSide) {
            wantOut = max(wantOut, centre.x - at.$1 + ease);
            wantIn = max(wantIn, max(0.0, min(at.$2 + 1.0, mid) - centre.x) + ease);
          } else {
            wantOut = max(wantOut, at.$2 + 1 - centre.x + ease);
            wantIn = max(wantIn, max(0.0, centre.x - max(at.$1.toDouble(), mid)) + ease);
          }
        }
      }
      outs.add(wantOut * (1 + margin * 2));
      ins.add(wantIn * (1 + margin * 2));
    }
    final wo = widest(outs), wi = widest(ins);
    for (var i = 0; i <= legSlices; i++) {
      if (i == 0) {
        // The top slice is the seat's bottom row, so the two meet.
        dst.add((toPhoto(src[0].$1.x, src[0].$1.y), toPhoto(src[0].$2.x, src[0].$2.y)));
        continue;
      }
      final c = centres[i], n = normals[i] * (leftSide ? -1.0 : 1.0);
      dst.add((c + n * wo[i], c - n * wi[i]));
      lowest = max(lowest, c.y);
    }
    final tris = <(List<Px>, List<Px>)>[];
    for (var i = 0; i < legSlices; i++) {
      final (s0o, s0i) = src[i];
      final (s1o, s1i) = src[i + 1];
      final (d0o, d0i) = dst[i];
      final (d1o, d1i) = dst[i + 1];
      tris
        ..add(([s0o, s0i, s1o], [d0o, d0i, d1o]))
        ..add(([s0i, s1i, s1o], [d0i, d1i, d1o]));
    }
    // A slice turned inside out means the legs cross or fold.
    for (final (s, d) in tris) {
      final a = cross(s[0], s[1], s[2]), b = cross(d[0], d[1], d[2]);
      if (a.abs() > 1e-6 && b.abs() > 1e-6 && (a > 0) != (b > 0)) return (null, FitProblem.legs);
    }
    for (final (s, d) in tris) {
      _fillTriangle(d, s, w, h, (i, gx, gy) {
        final row = gy.round().clamp(crotchRow, ch - 1);
        final mine = leftSide ? gx < legs.gapMiddle(row) : gx > legs.gapMiddle(row);
        if (mine && gy >= legs.crotch.y - 0.5 && paint.sampleAt(gx - 0.5, gy - 0.5)) put(i);
      });
    }
  }

  // The clothes the person is wearing from the waist to the hem (or the
  // ankles, or the knees for shorts) must be mostly covered.
  final legEnd = body.sees(Body.rightAnkle, w, h) && body.sees(Body.leftAnkle, w, h)
      ? body.mid(Body.rightAnkle, Body.leftAnkle).y
      : body.mid(Body.rightKnee, Body.leftKnee).y;
  if (!paint.covers(origin.y, min(lowest, legEnd))) return (null, FitProblem.cover);
  return (FitPicture(paint.out, paint.drawn), null);
}

/// A garment's cut-out drawn onto a body photo: samples the cut-out and
/// paints the photo's pixels, keeping what is in front.
class _Painter {
  _Painter(this.rgb, this.w, this.parts, this.cut)
    : out = Uint8List.fromList(rgb),
      drawn = Uint8List(parts.length);

  final Uint8List rgb, parts;
  final int w;
  final Cutout cut;

  /// The new picture, and how solid the garment is at each pixel.
  final Uint8List out, drawn;

  /// The last sample: RGB weighted by alpha, and alpha.
  final sample = Float64List(4);

  /// Samples the cut-out at (gx, gy) into [sample]. False where there is
  /// nothing.
  bool sampleAt(double gx, double gy) {
    final cw = cut.width, ch = cut.height, src = cut.rgba;
    if (gx < 0 || gy < 0 || gx > cw - 1 || gy > ch - 1) return false;
    final x0 = gx.floor(), y0 = gy.floor();
    final x1 = min(x0 + 1, cw - 1), y1 = min(y0 + 1, ch - 1);
    final fx = gx - x0, fy = gy - y0;
    sample.fillRange(0, 4, 0);
    for (final (x, y, wt) in [
      (x0, y0, (1 - fx) * (1 - fy)),
      (x1, y0, fx * (1 - fy)),
      (x0, y1, (1 - fx) * fy),
      (x1, y1, fx * fy),
    ]) {
      final o = (y * cw + x) * 4;
      final a = src[o + 3] * wt;
      sample[0] += src[o] * a;
      sample[1] += src[o + 1] * a;
      sample[2] += src[o + 2] * a;
      sample[3] += a;
    }
    return sample[3] >= 1;
  }

  /// Draws [sample] at photo pixel [i], unless hair, face or a hand (or,
  /// unless [sleeve], an arm) is in front. Always blended with the photo's
  /// own pixel, so drawing a pixel twice is the same as once.
  void put(int i, bool sleeve) {
    final part = parts[i];
    final behind = part == Part.hair || part == Part.faceSkin || part == Part.hand;
    if (behind || (!sleeve && part == Part.arm)) return;
    final a = sample[3] / 255;
    for (var c = 0; c < 3; c++) {
      out[i * 3 + c] = (rgb[i * 3 + c] * (1 - a) + sample[c] / sample[3] * a).round().clamp(0, 255);
    }
    drawn[i] = max(drawn[i], sample[3].round().clamp(0, 255));
  }

  /// Whether the clothes the person is wearing between rows [top] and
  /// [bottom] are mostly covered (or there are few of them).
  bool covers(double top, double bottom) {
    final h = parts.length ~/ w;
    var clothes = 0, covered = 0, area = 0;
    for (var y = max(0, top.round()); y < min(h, bottom.round()); y++) {
      for (var x = 0; x < w; x++) {
        final p = parts[y * w + x];
        if (isPerson(p)) area++;
        if (p != Part.clothes) continue;
        clothes++;
        if (drawn[y * w + x] >= 128) covered++;
      }
    }
    return clothes <= area * 0.1 || covered >= clothes * minCover;
  }
}

/// Draws [sleeve] along the arm ([arm]: shoulder, elbow, wrist joints):
/// its top edge starts at [seam] (the seam's place on the photo) and runs
/// alongside the arm's bones, bending with them; its sections hang off that
/// edge on the [inward] side, as wide as they are worn. False when the arm
/// cannot carry it: elbow (or, for a long sleeve, wrist) hidden, or bent
/// back across it.
bool _drawSleeve({
  required Sleeve sleeve,
  required BodyReading body,
  required List<int> arm,
  required int w,
  required int h,
  required Px seam,
  required Px inward,
  required double scale,
  required bool Function(double, double) sample,
  required void Function(int) put,
  required bool Function(double, double) inSleeve,
}) {
  final chain = [for (final i in arm) body.point(i)];
  final upper = chain[0].distanceTo(chain[1]);
  final length = sleeve.t.last * scale;
  if (!body.sees(arm[1], w, h) || (length > upper * 0.9 && !body.sees(arm[2], w, h))) return false;
  if (upper < 1 || chain[1].distanceTo(chain[2]) < 1) return false;

  // The point [d] pixels down the arm from the shoulder joint, and the
  // arm's direction there; past the wrist, straight on.
  (Px, Px) along(double d) {
    var rest = d;
    for (var i = 0; ; i++) {
      final a = chain[i], b = chain[i + 1];
      final len = a.distanceTo(b);
      final dir = (b - a) * (1 / len);
      if (rest <= len || i == chain.length - 2) return (a + dir * rest, dir);
      rest -= len;
    }
  }

  // Each section a little wider than the sleeve, so none of it is cut off
  // (the cut-out is clear there).
  const margin = 0.08;
  final shift = seam - chain[0];
  final src = <(Px, Px)>[], dst = <(Px, Px)>[];
  for (var i = 0; i < sleeve.t.length; i++) {
    final m = (sleeve.to[i] - sleeve.from[i]) * margin;
    final a = sleeve.from[i] - m, b = sleeve.to[i] + m;
    final base = sleeve.seam + sleeve.along * sleeve.t[i];
    src.add((base + sleeve.inward * a, base + sleeve.inward * b));
    final (c, dir) = along(sleeve.t[i] * scale);
    var n = Point(-dir.y, dir.x);
    if (n.x * inward.x + n.y * inward.y < 0) n = Point(-n.x, -n.y);
    final edge = c + shift;
    final k = scale / flatToWorn;
    dst.add((edge + n * (a * k), edge + n * (b * k)));
  }
  double cross(Px a, Px b, Px c) => (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
  final tris = <(List<Px>, List<Px>)>[];
  for (var i = 0; i < src.length - 1; i++) {
    final (s0t, s0l) = src[i];
    final (s1t, s1l) = src[i + 1];
    final (d0t, d0l) = dst[i];
    final (d1t, d1l) = dst[i + 1];
    tris
      ..add(([s0t, s0l, s1t], [d0t, d0l, d1t]))
      ..add(([s0l, s1l, s1t], [d0l, d1l, d1t]));
  }
  // A slice turned inside out means the arm bends back across the sleeve.
  for (final (s, d) in tris) {
    final a = cross(s[0], s[1], s[2]), b = cross(d[0], d[1], d[2]);
    if (a.abs() > 1e-6 && b.abs() > 1e-6 && (a > 0) != (b > 0)) return false;
  }
  for (final (s, d) in tris) {
    _fillTriangle(d, s, w, h, (i, gx, gy) {
      if (inSleeve(gx, gy) && sample(gx - 0.5, gy - 0.5)) put(i);
    });
  }
  return true;
}

/// Calls [paint] with each photo pixel inside triangle [dst] (on a [w]×[h]
/// photo) and the matching point in triangle [src].
void _fillTriangle(List<Px> dst, List<Px> src, int w, int h, void Function(int, double, double) paint) {
  final [a, b, c] = dst;
  final det = (b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y);
  if (det.abs() < 1e-9) return;
  final x0 = max(0, [a.x, b.x, c.x].reduce(min).floor()), x1 = min(w - 1, [a.x, b.x, c.x].reduce(max).ceil());
  final y0 = max(0, [a.y, b.y, c.y].reduce(min).floor()), y1 = min(h - 1, [a.y, b.y, c.y].reduce(max).ceil());
  for (var y = y0; y <= y1; y++) {
    for (var x = x0; x <= x1; x++) {
      final px = x + 0.5, py = y + 0.5;
      final l1 = ((px - a.x) * (c.y - a.y) - (c.x - a.x) * (py - a.y)) / det;
      final l2 = ((b.x - a.x) * (py - a.y) - (px - a.x) * (b.y - a.y)) / det;
      final l0 = 1 - l1 - l2;
      if (l0 < -1e-9 || l1 < -1e-9 || l2 < -1e-9) continue;
      paint(
        y * w + x,
        l0 * src[0].x + l1 * src[1].x + l2 * src[2].x,
        l0 * src[0].y + l1 * src[1].y + l2 * src[2].y,
      );
    }
  }
}

/// A cloud try-on's [result] (RGB, already the photo's size) put back onto
/// the photo [rgb]: taken only where either picture shows clothes, never
/// over hair, face or hands, which stay as on the photo, and nowhere else.
/// [before] is the photo's parts (from [splitArms]); [after] the result's,
/// as the model gives them.
Uint8List pasteBack(Uint8List rgb, Uint8List result, Uint8List before, Uint8List after) {
  final out = Uint8List.fromList(rgb);
  for (var i = 0; i < before.length; i++) {
    final b = before[i], a = after[i];
    if (b == Part.hair || b == Part.faceSkin || b == Part.hand) continue;
    if (b != Part.clothes && a != Part.clothes && a != Part.others) continue;
    out[i * 3] = result[i * 3];
    out[i * 3 + 1] = result[i * 3 + 1];
    out[i * 3 + 2] = result[i * 3 + 2];
  }
  return out;
}
