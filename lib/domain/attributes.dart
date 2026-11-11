import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

// What a search asks for besides the product itself: "easy slip in" is the
// attribute Slip-on, which shops write as "slip on", "slip-ins" or "hands
// free". The list (assets/search/attributes.json) is built by
// tool/attribute_lexicon.py from a hand list and the Shopify Standard
// Product Taxonomy (MIT).

/// Small words that say nothing about the product. They are left out of
/// the words a search looks for ("walking shoes for all terrains" looks for
/// walking and shoes).
final stopWords =
    ('a an the for to of and or with in on at by from my me i im all some something anything any easy very really '
            'that this which is are be it its can will want need looking good nice great best pair pairs please like also so '
            'too just get buy cheap')
        .split(' ')
        .toSet();

/// Words that turn the next word into something not wanted ("not apple").
const negations = {'not', 'no', 'without', 'except', 'nothing'};

/// A word as Chanda compares it: lower case, and a plural made singular
/// ("terrains" is "terrain", "batteries" is "battery").
String stem(String w) {
  final s = w.toLowerCase();
  if (s.length > 4 && s.endsWith('ies')) return '${s.substring(0, s.length - 3)}y';
  if (s.length > 4 && (s.endsWith('ches') || s.endsWith('shes') || s.endsWith('sses') || s.endsWith('xes'))) {
    return s.substring(0, s.length - 2);
  }
  if (s.length > 3 && s.endsWith('s') && !s.endsWith('ss') && !s.endsWith('us') && !s.endsWith('is')) {
    return s.substring(0, s.length - 1);
  }
  return s;
}

/// The words of [text], stemmed, without punctuation. Zero-width and other
/// invisible characters some shops put in their text are dropped first.
List<String> wordsOf(String text) =>
    withoutInvisible(text)
        .toLowerCase()
        .replaceAll('\'', '')
        .replaceAll('’', '')
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((w) => w.isNotEmpty)
        .map(stem)
        .toList();

/// [text] without zero-width spaces, joiners, direction marks and the
/// byte-order mark (U+200B-U+200F, U+2060, U+FEFF).
String withoutInvisible(String text) => text.replaceAll(RegExp('[​-‏⁠﻿]'), '');

/// One thing a product can be: how people ask for it and how shops write it.
class Attribute {
  const Attribute(this.id, this.label, this.say, this.title);

  factory Attribute.fromJson(Map j) => Attribute(
    '${j['id']}',
    '${j['label']}',
    [for (final p in (j['say'] as List?) ?? const []) wordsOf('$p')],
    [for (final p in (j['title'] as List?) ?? const []) wordsOf('$p')],
  );

  final String id;
  final String label;

  /// The phrases a search may use, as stemmed words.
  final List<List<String>> say;

  /// The phrases a shop's title may use, as stemmed words.
  final List<List<String>> title;

  /// What to send to shops for it: its first title phrase.
  String get shopWords => title.isEmpty ? label.toLowerCase() : title.first.join(' ');

  /// Whether [titleWords] (from [wordsOf]) hold one of its title phrases.
  bool inTitle(List<String> titleWords) => title.any((p) => _at(titleWords, p) >= 0);
}

/// Where [phrase] starts in [words], or -1.
int _at(List<String> words, List<String> phrase) {
  if (phrase.isEmpty) return -1;
  for (var i = 0; i + phrase.length <= words.length; i++) {
    var ok = true;
    for (var j = 0; j < phrase.length && ok; j++) {
      ok = words[i + j] == phrase[j];
    }
    if (ok) return i;
  }
  return -1;
}

/// A phrase found in a search: the attribute and the words it covered
/// ([start] inclusive, [end] exclusive).
typedef FoundAttribute = ({Attribute attribute, int start, int end});

/// The attributes Chanda knows.
class Lexicon {
  Lexicon(this.attributes) : _byId = {for (final a in attributes) a.id: a};

  factory Lexicon.fromJson(Map j) => Lexicon([
    for (final a in (j['attributes'] as List?) ?? const [])
      if (a is Map) Attribute.fromJson(a),
  ]);

  static final empty = Lexicon(const []);

  final List<Attribute> attributes;
  final Map<String, Attribute> _byId;

  Attribute? byId(String id) => _byId[id];

  /// The attributes [words] (stemmed) ask for, longest phrase first, each
  /// word used once. An attribute said twice is found twice.
  List<FoundAttribute> find(List<String> words) {
    final phrases = [
      for (final a in attributes)
        for (final p in a.say)
          if (p.isNotEmpty) (a, p),
    ]..sort((x, y) => y.$2.length.compareTo(x.$2.length));
    final used = List.filled(words.length, false);
    final out = <FoundAttribute>[];
    for (final (a, p) in phrases) {
      for (var i = 0; i + p.length <= words.length; i++) {
        var ok = true;
        for (var j = 0; j < p.length && ok; j++) {
          ok = !used[i + j] && words[i + j] == p[j];
        }
        if (!ok) continue;
        for (var j = 0; j < p.length; j++) {
          used[i + j] = true;
        }
        // Said twice ("blue light glasses for screens"): one attribute,
        // both phrases taken out of the words.
        out.add((attribute: a, start: i, end: i + p.length));
      }
    }
    out.sort((x, y) => x.start.compareTo(y.start));
    return out;
  }
}

/// The attribute list in use: empty until [loadLexicon] has run.
Lexicon lexicon = Lexicon.empty;

Future<void>? _loading;

/// Loads the attribute list from the app's assets, once.
Future<void> loadLexicon() => _loading ??= () async {
  try {
    lexicon = Lexicon.fromJson(jsonDecode(await rootBundle.loadString(lexiconAsset)) as Map);
  } on Object {
    // Without the list a search still works by its words alone.
    _loading = null;
  }
}();

const lexiconAsset = 'assets/search/attributes.json';
