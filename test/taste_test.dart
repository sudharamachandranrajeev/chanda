import 'dart:math';
import 'dart:typed_data';

import 'package:chanda/domain/taste.dart';
import 'package:flutter_test/flutter_test.dart';

TasteInput thing(
  String key, {
  String colour = '',
  String category = 'shirt',
  Float32List? picture,
  double? price,
}) => TasteInput(key: key, title: key, colour: colour, category: category, picture: picture, price: price);

Float32List pic(int hot) => Float32List(768)..[hot] = 1;

void main() {
  test('learns a liked colour from ratings and says so', () {
    final signals = [
      for (var i = 0; i < 10; i++) TasteSignal(thing('navy$i', colour: 'navy'), 5),
      for (var i = 0; i < 10; i++) TasteSignal(thing('red$i', colour: 'red'), 1),
    ];
    final ranked = rank(
      [thing('a', colour: 'red'), thing('b', colour: 'navy')],
      signals,
      random: Random(1),
    );
    expect(ranked.first.input.key, 'b');
    expect(ranked.first.liked, 'colour:navy');
    expect(ranked.first.because?.colour, 'navy');
    final model = TasteModel.fit([for (final s in signals) (featuresOf(s.input), s)]);
    expect(model.count, 20);
    expect(model.weightOf('colour:navy'), greaterThan(0.3));
    expect(model.weightOf('colour:red'), lessThan(-0.3));
  });

  test('posterior draws centre on the mean', () {
    final signals = [
      for (var i = 0; i < 20; i++) TasteSignal(thing('n$i', colour: 'navy'), i.isEven ? 5 : 4),
    ];
    final model = TasteModel.fit([for (final s in signals) (featuresOf(s.input), s)]);
    final r = Random(3);
    final x = featuresOf(thing('x', colour: 'navy'));
    var sum = 0.0;
    for (var i = 0; i < 400; i++) {
      final w = model.sample(r);
      var s = 0.0;
      for (var d = 0; d < tasteDims; d++) {
        s += w[d] * x[d];
      }
      sum += s;
    }
    expect(sum / 400, closeTo(model.score(x), 0.1));
  });

  test('few ratings: ranks by likeness to what was rated well, and names it', () {
    final loved = thing('loved', picture: pic(3), category: 'lamp');
    final hated = thing('hated', picture: pic(9), category: 'mug');
    final ranked = rank(
      [thing('far', picture: pic(9), category: 'mug'), thing('near', picture: pic(3), category: 'lamp')],
      [TasteSignal(loved, 5), TasteSignal(hated, 1)],
    );
    expect(ranked.map((s) => s.input.key), ['near', 'far']);
    expect(ranked.first.because?.key, 'loved');
    expect(ranked.last.because, isNull);
  });

  test('a muted attribute stops counting', () {
    final signals = [for (var i = 0; i < 20; i++) TasteSignal(thing('n$i', colour: 'navy', category: ''), 5)];
    final ranked = rank(
      [thing('b', colour: 'navy', category: '')],
      signals,
      muted: {'colour:navy'},
    );
    expect(ranked.single.liked, isNull);
    expect(featuresOf(thing('x', colour: 'navy'), muted: {'colour:navy'}), featuresOf(thing('x')));
  });

  test('every fifth place explores; nothing is shown twice', () {
    final signals = [
      for (var i = 0; i < 20; i++)
        TasteSignal(thing('s$i', colour: i.isEven ? 'navy' : 'red', price: 10.0 + i), 1 + i % 5),
    ];
    final cands = [
      for (var i = 0; i < 12; i++) thing('c$i', colour: ['navy', 'red', 'green'][i % 3], price: 5.0 * i),
    ];
    final ranked = rank(cands, signals, random: Random(9));
    expect(ranked, hasLength(12));
    expect(ranked.map((s) => s.input.key).toSet(), hasLength(12));
    expect(ranked[4].explore, isTrue);
    expect(ranked[9].explore, isTrue);
    expect(ranked.where((s) => s.explore), hasLength(2));
  });

  test('features are stable: fixed projections and hashes', () {
    expect(fnv1a('colour:navy'), fnv1a('colour:navy'));
    expect(fnv1a(''), 0x811c9dc5);
    final a = featuresOf(thing('x', picture: pic(5)));
    final b = featuresOf(thing('y', picture: pic(5)));
    expect(a, b);
    expect(attributeWords('colour:navy'), 'navy');
  });
}
