/// Search relevance scoring (BUILD-SPEC 7.11).
///
/// Filtering itself is a plain case-insensitive substring match over the Dutch
/// word, the English meaning and the translated meaning. This only re-orders
/// the matches: every match still appears, so an exact hit ("tell") surfaces
/// above words that merely contain it ("teller", "vertellen").
class SearchScore {
  const SearchScore._();

  /// Lower is better. 9 means "no match in any field".
  static int score({
    required String word,
    required String? meaning,
    required String? translatedMeaning,
    required String query,
  }) {
    if (query.isEmpty) return 0;
    final RegExp boundary = _boundary(query);
    int best = 9;
    for (final String? raw in <String?>[word, meaning, translatedMeaning]) {
      final String f = (raw ?? '').toLowerCase();
      if (f.isEmpty || !f.contains(query)) continue;
      final int sc;
      if (f == query) {
        sc = 0; // exact field match
      } else if (f.startsWith(query)) {
        sc = boundary.hasMatch(f) ? 1 : 3; // whole word vs prefix-of-word
      } else if (boundary.hasMatch(f)) {
        sc = 2; // whole word somewhere inside
      } else {
        sc = 4; // mid-word substring
      }
      if (sc < best) best = sc;
    }
    return best;
  }

  /// Latin plus diacritics, matching the web app's `[^a-zÀ-ɏ]` class.
  static RegExp _boundary(String q) => RegExp(
        '(^|[^a-zÀ-ɏ])${RegExp.escape(q)}(\$|[^a-zÀ-ɏ])',
        caseSensitive: false,
      );
}
