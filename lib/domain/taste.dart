import 'dart:math';
import 'dart:typed_data';

// The taste model: learns what the user likes from their star ratings, on
// the device. A Bayesian linear regression over a fixed set of features,
// rebuilt from the ratings whenever they change (a few hundred ratings
// take milliseconds). Its uncertainty is used to try something new now and
// then (Thompson sampling), and every suggestion can say why.
//
// No age, gender or other personal details are features, ever: only what
// the user rated, saved and bought.

/// Feature layout: 32 from the picture vector, 32 from the meaning (text)
/// vector, 30 hashed attributes, log price, and a constant.
const tasteDims = 96;
const _pictureAt = 0, _textAt = 32, _attrAt = 64, _attrDims = 30, _priceAt = 94, _biasAt = 95;

/// The seeds of the fixed random projections. Changing either changes every
/// feature, so it is part of the export format.
const pictureSeed = 7, textSeed = 11;

/// What the model knows about one thing the user could buy.
class TasteInput {
  const TasteInput({
    required this.key,
    required this.title,
    this.shop = '',
    this.brand = '',
    this.category = '',
    this.colour = '',
    this.material = '',
    this.price,
    this.picture,
    this.text,
  });

  /// The product page address: what ratings are kept against.
  final String key;
  final String title;
  final String shop;
  final String brand;
  final String category;
  final String colour;
  final String material;

  /// In major units (pounds, euros) of whatever currency.
  final double? price;
  final Float32List? picture;
  final Float32List? text;

  /// The attributes as "kind:value" tokens.
  List<String> get attributes => [
    if (category.isNotEmpty) 'category:$category',
    if (colour.isNotEmpty) 'colour:$colour',
    if (material.isNotEmpty) 'material:$material',
    if (brand.isNotEmpty) 'brand:${brand.toLowerCase()}',
    if (shop.isNotEmpty) 'shop:$shop',
  ];
}

/// One piece of evidence: a star rating, or a weaker signal such as a save.
class TasteSignal {
  const TasteSignal(this.input, this.stars, {this.weight = 1});
  final TasteInput input;

  /// 1-5. Implicit signals use a fraction (a save counts as 3.6).
  final double stars;
  final double weight;
}

final _projections = <(int, int), Float64List>{};

/// A fixed Gaussian projection from [from] dimensions to 32, scaled so a
/// unit vector stays about unit length.
Float64List _projection(int seed, int from) => _projections.putIfAbsent((seed, from), () {
  final r = Random(seed);
  final m = Float64List(32 * from);
  for (var i = 0; i < m.length; i++) {
    // Box-Muller.
    final u = 1 - r.nextDouble(), v = r.nextDouble();
    m[i] = sqrt(-2 * log(u)) * cos(2 * pi * v) / sqrt(32);
  }
  return m;
});

/// FNV-1a, 32 bits: a stable hash for attribute tokens.
int fnv1a(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h;
}

/// The feature vector of [x], leaving out [muted] attribute tokens.
Float64List featuresOf(TasteInput x, {Set<String> muted = const {}}) {
  final f = Float64List(tasteDims);
  void project(Float32List? v, int at, int seed) {
    if (v == null || v.isEmpty) return;
    final m = _projection(seed, v.length);
    for (var o = 0; o < 32; o++) {
      var s = 0.0;
      for (var i = 0; i < v.length; i++) {
        s += m[o * v.length + i] * v[i];
      }
      f[at + o] = s;
    }
  }

  project(x.picture, _pictureAt, pictureSeed);
  project(x.text, _textAt, textSeed);
  for (final a in x.attributes) {
    if (muted.contains(a)) continue;
    final h = fnv1a(a);
    f[_attrAt + h % _attrDims] += (h & 0x80000000) != 0 ? -0.5 : 0.5;
  }
  if (x.price case final p? when p > 0) f[_priceAt] = (log(p + 1) - 3) / 2;
  f[_biasAt] = 1;
  return f;
}

/// Bayesian linear regression on centred stars (stars − 3), prior
/// w ~ N(0, I/λ).
class TasteModel {
  TasteModel._(this.mean, this._chol, this.count);

  /// The posterior mean of the weights.
  final Float64List mean;

  /// Lower Cholesky factor L of the posterior precision (L·Lᵀ).
  final Float64List _chol;

  /// Explicit ratings behind it.
  final int count;

  static TasteModel fit(List<(Float64List, TasteSignal)> data, {double lambda = 1}) {
    const d = tasteDims;
    final p = Float64List(d * d);
    final b = Float64List(d);
    for (var i = 0; i < d; i++) {
      p[i * d + i] = lambda;
    }
    var count = 0;
    for (final (x, s) in data) {
      if (s.weight >= 1) count++;
      final y = s.stars - 3;
      for (var i = 0; i < d; i++) {
        if (x[i] == 0) continue;
        b[i] += s.weight * y * x[i];
        for (var j = 0; j < d; j++) {
          p[i * d + j] += s.weight * x[i] * x[j];
        }
      }
    }
    final l = _cholesky(p, d);
    return TasteModel._(_solveUpper(l, _solveLower(l, b, d), d), l, count);
  }

  /// Expected centred stars for [x] (−2 dislike … +2 love).
  double score(Float64List x) => _dot(mean, x);

  /// Weights drawn from the posterior: mean + L⁻ᵀ·z. Ranking by a draw
  /// tries out things the model is unsure of in proportion to its doubt.
  Float64List sample(Random r) {
    final z = Float64List(tasteDims);
    for (var i = 0; i < tasteDims; i++) {
      final u = 1 - r.nextDouble(), v = r.nextDouble();
      z[i] = sqrt(-2 * log(u)) * cos(2 * pi * v);
    }
    final dev = _solveUpper(_chol, z, tasteDims);
    return Float64List.fromList([for (var i = 0; i < tasteDims; i++) mean[i] + dev[i]]);
  }

  /// How much the attribute token [a] adds to a score.
  double weightOf(String a) {
    final h = fnv1a(a);
    return mean[_attrAt + h % _attrDims] * ((h & 0x80000000) != 0 ? -0.5 : 0.5);
  }
}

double _dot(List<double> a, List<double> b) {
  var s = 0.0;
  for (var i = 0; i < a.length; i++) {
    s += a[i] * b[i];
  }
  return s;
}

Float64List _cholesky(Float64List a, int d) {
  final l = Float64List(d * d);
  for (var i = 0; i < d; i++) {
    for (var j = 0; j <= i; j++) {
      var s = a[i * d + j];
      for (var k = 0; k < j; k++) {
        s -= l[i * d + k] * l[j * d + k];
      }
      l[i * d + j] = i == j ? sqrt(max(s, 1e-12)) : s / l[j * d + j];
    }
  }
  return l;
}

Float64List _solveLower(Float64List l, List<double> b, int d) {
  final y = Float64List(d);
  for (var i = 0; i < d; i++) {
    var s = b[i];
    for (var k = 0; k < i; k++) {
      s -= l[i * d + k] * y[k];
    }
    y[i] = s / l[i * d + i];
  }
  return y;
}

/// Solves Lᵀ·x = y.
Float64List _solveUpper(Float64List l, List<double> y, int d) {
  final x = Float64List(d);
  for (var i = d - 1; i >= 0; i--) {
    var s = y[i];
    for (var k = i + 1; k < d; k++) {
      s -= l[k * d + i] * x[k];
    }
    x[i] = s / l[i * d + i];
  }
  return x;
}

/// Cosine of two feature vectors, leaving out the constant.
double likeness(Float64List a, Float64List b) {
  var s = 0.0, na = 0.0, nb = 0.0;
  for (var i = 0; i < _biasAt; i++) {
    s += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  return na == 0 || nb == 0 ? 0 : s / sqrt(na * nb);
}

/// A suggestion and why it is there.
class Suggestion {
  const Suggestion(this.input, this.score, {this.because, this.liked, this.explore = false});
  final TasteInput input;
  final double score;

  /// The liked thing it is most like: rated 4★ or more, saved or bought.
  final TasteInput? because;

  /// The attribute that counts most for it ("colour:navy").
  final String? liked;

  /// Picked to try something new rather than for its expected score.
  final bool explore;
}

/// Below this many explicit ratings, suggestions rank by likeness to what
/// the user rated well instead of by the fitted model.
const coldStart = 15;

/// Ranks [candidates] for the user, best first, from [signals]. With enough
/// ratings, every fifth place goes to the best of a posterior draw not
/// already shown (Thompson sampling); before that, ranks by likeness to the
/// things liked (rated 4★ or more, saved or bought), less likeness to those
/// rated 2★ or less.
List<Suggestion> rank(
  List<TasteInput> candidates,
  List<TasteSignal> signals, {
  Set<String> muted = const {},
  Random? random,
}) {
  if (candidates.isEmpty) return const [];
  final data = [for (final s in signals) (featuresOf(s.input, muted: muted), s)];
  final liked = [
    for (final (f, s) in data)
      if (s.stars >= 3.5) (f, s.input),
  ];
  final disliked = [
    for (final (f, s) in data)
      if (s.weight >= 1 && s.stars <= 2) f,
  ];
  final model = TasteModel.fit(data);
  final feats = {for (final c in candidates) c.key: featuresOf(c, muted: muted)};

  (TasteInput?, double) nearestLiked(Float64List f) {
    TasteInput? best;
    var top = -1.0;
    for (final (g, i) in liked) {
      final s = likeness(f, g);
      if (s > top) {
        top = s;
        best = i;
      }
    }
    return (best, top);
  }

  String? strongest(TasteInput c) {
    String? best;
    var top = 0.05;
    for (final a in c.attributes) {
      if (muted.contains(a)) continue;
      final w = model.weightOf(a);
      if (w > top) {
        top = w;
        best = a;
      }
    }
    return best;
  }

  Suggestion make(TasteInput c, double score, {bool explore = false}) {
    final (because, sim) = nearestLiked(feats[c.key]!);
    return Suggestion(c, score, because: sim > 0.3 ? because : null, liked: strongest(c), explore: explore);
  }

  if (model.count < coldStart) {
    double cold(Float64List f) {
      final (_, up) = nearestLiked(f);
      var down = 0.0;
      for (final g in disliked) {
        down = max(down, likeness(f, g));
      }
      return (liked.isEmpty ? 0 : up) - 0.5 * down;
    }

    return [for (final c in candidates) make(c, cold(feats[c.key]!))]
      ..sort((a, b) => b.score.compareTo(a.score));
  }

  final byMean = [for (final c in candidates) (c, model.score(feats[c.key]!))]
    ..sort((a, b) => b.$2.compareTo(a.$2));
  final draw = model.sample(random ?? Random());
  final byDraw = [for (final c in candidates) (c, _dot(draw, feats[c.key]!))]
    ..sort((a, b) => b.$2.compareTo(a.$2));
  final out = <Suggestion>[];
  final used = <String>{};
  var m = 0, t = 0;
  while (out.length < candidates.length) {
    final exploreSlot = out.length % 5 == 4;
    final list = exploreSlot ? byDraw : byMean;
    var i = exploreSlot ? t : m;
    while (i < list.length && used.contains(list[i].$1.key)) {
      i++;
    }
    if (i >= list.length) {
      // The other list still has some.
      final rest = (exploreSlot ? byMean : byDraw).where((e) => !used.contains(e.$1.key)).first;
      used.add(rest.$1.key);
      out.add(make(rest.$1, model.score(feats[rest.$1.key]!)));
      continue;
    }
    final (c, _) = list[i];
    used.add(c.key);
    out.add(make(c, model.score(feats[c.key]!), explore: exploreSlot));
    if (exploreSlot) {
      t = i + 1;
    } else {
      m = i + 1;
    }
  }
  return out;
}

/// Plain words for an attribute token: "colour:navy" → "navy".
String attributeWords(String a) {
  final i = a.indexOf(':');
  return i < 0 ? a : a.substring(i + 1);
}
