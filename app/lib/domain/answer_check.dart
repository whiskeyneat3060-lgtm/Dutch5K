import '../models/deck_entry.dart';

/// A cloze prompt: the sentence split around the blanked headword.
class ClozePrompt {
  const ClozePrompt({
    required this.pre,
    required this.answer,
    required this.post,
    required this.english,
    required this.full,
  });
  final String pre;
  final String answer;
  final String post;
  final String english;
  final String full;
}

/// Typed-answer grading (BUILD-SPEC 7.12).
class AnswerCheck {
  const AnswerCheck._();

  static final RegExp _combining = RegExp(r'[̀-ͯ]');
  static final RegExp _whitespace = RegExp(r'\s+');
  static final RegExp _leadingArticle = RegExp(r'^(de|het|een)\s+');
  static final RegExp _trailingPunct = RegExp(r'[.!?,;:]+$');

  /// Loose match: case- and accent-insensitive, ignores a leading article and
  /// trailing punctuation, so "Huis", "huis" and "het huis" all normalise to
  /// "huis".
  static String normalize(String? s) {
    String v = (s ?? '').toLowerCase();
    // NFD decompose then strip combining marks. Dart's String has no NFD, so we
    // map the Latin-1/Latin-Extended letters the deck actually uses.
    v = _stripDiacritics(v);
    v = v.replaceAll(_whitespace, ' ').trim();
    v = v.replaceFirst(_leadingArticle, '');
    v = v.replaceFirst(_trailingPunct, '').trim();
    return v;
  }

  static const Map<String, String> _foldMap = <String, String>{
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', 'ă': 'a', 'ą': 'a',
    'ç': 'c', 'ć': 'c', 'č': 'c', 'ĉ': 'c', 'ċ': 'c',
    'ď': 'd', 'đ': 'd',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ĕ': 'e', 'ė': 'e', 'ę': 'e', 'ě': 'e',
    'ĝ': 'g', 'ğ': 'g', 'ġ': 'g', 'ģ': 'g',
    'ĥ': 'h', 'ħ': 'h',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ĩ': 'i', 'ī': 'i', 'ĭ': 'i', 'į': 'i', 'ı': 'i',
    'ĵ': 'j', 'ķ': 'k',
    'ĺ': 'l', 'ļ': 'l', 'ľ': 'l', 'ł': 'l',
    'ñ': 'n', 'ń': 'n', 'ņ': 'n', 'ň': 'n',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o', 'ŏ': 'o', 'ő': 'o',
    'ŕ': 'r', 'ŗ': 'r', 'ř': 'r',
    'ś': 's', 'ŝ': 's', 'ş': 's', 'š': 's', 'ș': 's',
    'ţ': 't', 'ť': 't', 'ŧ': 't', 'ț': 't',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ũ': 'u', 'ū': 'u', 'ŭ': 'u', 'ů': 'u', 'ű': 'u',
    'ų': 'u',
    'ŵ': 'w', 'ý': 'y', 'ÿ': 'y', 'ŷ': 'y',
    'ź': 'z', 'ż': 'z', 'ž': 'z',
    'æ': 'ae', 'œ': 'oe', 'ß': 'ss',
  };

  static String _stripDiacritics(String input) {
    final StringBuffer out = StringBuffer();
    for (final int rune in input.runes) {
      final String ch = String.fromCharCode(rune);
      if (_combining.hasMatch(ch)) continue;
      out.write(_foldMap[ch] ?? ch);
    }
    return out.toString();
  }

  /// True when the typed answer counts as correct. An empty answer is always
  /// wrong, even against an empty expected answer.
  static bool isCorrect(String given, String expected) {
    final String g = normalize(given);
    return g.isNotEmpty && g == normalize(expected);
  }

  /// Matches the headword as a whole word, using Unicode letter boundaries.
  static RegExp clozeRegExp(String word) {
    final String escaped = RegExp.escape(word);
    return RegExp(
      r'(^|[^\p{L}])(' + escaped + r')($|[^\p{L}])',
      caseSensitive: false,
      unicode: true,
    );
  }

  /// Finds an example sentence that literally contains the headword and blanks
  /// it out. Returns null when no example contains the word as a whole word —
  /// which is why the cloze pool is smaller than the deck (a conjugated verb
  /// rarely contains its own infinitive).
  static ClozePrompt? pickCloze(DeckEntry e) {
    if (e.examples.isEmpty) return null;
    final RegExp re = clozeRegExp(e.word);
    for (final Example sn in e.examples) {
      if (sn.nl.isEmpty) continue;
      final RegExpMatch? m = re.firstMatch(sn.nl);
      if (m == null) continue;
      final int start = m.start + (m.group(1) ?? '').length;
      final int end = start + (m.group(2) ?? '').length;
      return ClozePrompt(
        pre: sn.nl.substring(0, start),
        answer: sn.nl.substring(start, end),
        post: sn.nl.substring(end),
        english: sn.en,
        full: sn.nl,
      );
    }
    return null;
  }
}
