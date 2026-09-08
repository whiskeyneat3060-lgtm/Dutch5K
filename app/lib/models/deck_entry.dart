import 'package:collection/collection.dart';

import '../core/constants.dart';

/// A textbook membership: which book, which chapter.
class BookRef {
  const BookRef(this.src, this.ch);
  final String src;
  final int ch;

  factory BookRef.fromJson(Map<String, dynamic> j) =>
      BookRef(j['src'] as String, (j['ch'] as num).toInt());
}

/// A `[dutch, english]` example sentence pair.
class Example {
  const Example(this.nl, this.en);
  final String nl;
  final String en;
}

/// A `[label, value]` grammar-form pair, e.g. `["Present", "ik bereik, hij bereikt"]`.
class WordForm {
  const WordForm(this.label, this.value);
  final String label;
  final String value;
}

/// One vocabulary entry. Immutable; the deck is built once and shared.
///
/// [id] is the primary key that all user progress hangs off. Four id schemes
/// exist (BUILD-SPEC 6.4) and must never change without a migration.
class DeckEntry {
  const DeckEntry({
    required this.id,
    required this.word,
    required this.rank,
    required this.srcTags,
    required this.rich,
    required this.hasMeaning,
    this.pos,
    this.article,
    this.meaning,
    this.forms = const <WordForm>[],
    this.synonyms = const <String>[],
    this.antonyms = const <String>[],
    this.examples = const <Example>[],
    this.books = const <BookRef>[],
    this.essentialDict = false,
  });

  final String id;
  final String word;

  /// Corpus frequency position, 1 = most frequent. `0` means "not in the
  /// frequency list" and sorts last everywhere.
  final int rank;
  final List<String> srcTags;

  /// True when the entry carries example sentences (drives the full card).
  final bool rich;

  /// True when [meaning] was populated by a source that set the flag. Note this
  /// is *not* simply `meaning != null`: the 115 curated seed entries carry a
  /// meaning without the flag, which is why the flag is stored explicitly.
  final bool hasMeaning;

  /// Part of speech, lower-case. Null for most frequency stubs.
  final String? pos;

  /// `de` or `het` for nouns.
  final String? article;
  final String? meaning;
  final List<WordForm> forms;
  final List<String> synonyms;
  final List<String> antonyms;
  final List<Example> examples;
  final List<BookRef> books;
  final bool essentialDict;

  /// Effective sort rank: entries outside the frequency list go to the back.
  int get sortRank => rank == 0 ? 99999 : rank;

  bool get isBookWord => books.isNotEmpty;

  /// True when the card can show a meaning at all.
  bool get showsMeaning => rich || hasMeaning;

  /// The single source a learned word is attributed to in the stacked
  /// "By word type" bars, so segments sum exactly to the row total
  /// (BUILD-SPEC 7.3).
  String get primarySource {
    if (books.isEmpty) {
      return srcTags.contains('essential') ? 'essential' : 'general';
    }
    for (final String s in kBookSources) {
      if (srcTags.contains(s)) return s;
    }
    return 'general';
  }

  /// "A0–A2 H3 · B1–B2 H5" — the chapter tag line.
  String get bookTag => books.map((BookRef b) => '${kSrcShort[b.src] ?? b.src} H${b.ch}').join(' · ');

  bool inSource(String src) => src == 'all' || srcTags.contains(src);

  static List<String> _stringList(dynamic v) =>
      v == null ? const <String>[] : (v as List<dynamic>).cast<String>();

  static List<List<String>> _pairList(dynamic v) => v == null
      ? const <List<String>>[]
      : (v as List<dynamic>)
          .map((dynamic p) => (p as List<dynamic>).map((dynamic x) => x as String).toList())
          .toList();

  factory DeckEntry.fromJson(Map<String, dynamic> j) {
    return DeckEntry(
      id: j['id'] as String,
      word: j['w'] as String,
      rank: (j['rank'] as num?)?.toInt() ?? 0,
      srcTags: _stringList(j['srcTags']),
      rich: j['rich'] == true,
      hasMeaning: j['hasMeaning'] == true,
      pos: j['t'] as String?,
      article: j['a'] as String?,
      meaning: j['m'] as String?,
      forms: _pairList(j['f'])
          .map((List<String> p) => WordForm(p[0], p.length > 1 ? p[1] : ''))
          .toList(),
      synonyms: _stringList(j['syn']),
      antonyms: _stringList(j['ant']),
      examples: _pairList(j['ex'])
          .map((List<String> p) => Example(p[0], p.length > 1 ? p[1] : ''))
          .toList(),
      books: j['books'] == null
          ? const <BookRef>[]
          : (j['books'] as List<dynamic>)
              .map((dynamic b) => BookRef.fromJson(b as Map<String, dynamic>))
              .toList(),
      essentialDict: j['essentialDict'] == true,
    );
  }
}

/// The immutable, fully built deck plus the lookup indexes the app needs.
class Deck {
  Deck(this.entries)
      : byId = <String, DeckEntry>{for (final DeckEntry e in entries) e.id: e},
        _indexById = <String, int>{
          for (final (int i, DeckEntry e) in entries.indexed) e.id: i,
        };

  final List<DeckEntry> entries;
  final Map<String, DeckEntry> byId;
  final Map<String, int> _indexById;

  int get length => entries.length;
  DeckEntry operator [](int i) => entries[i];

  int? indexOfId(String id) => _indexById[id];

  /// Chapters present for a book source, ascending.
  List<int> chaptersFor(String src) {
    final Set<int> set = <int>{};
    for (final DeckEntry e in entries) {
      for (final BookRef b in e.books) {
        if (b.src == src) set.add(b.ch);
      }
    }
    final List<int> out = set.toList()..sort();
    return out;
  }

  bool get hasEssential => entries.any((DeckEntry e) => e.srcTags.contains('essential'));

  int countWithTag(String tag) =>
      entries.where((DeckEntry e) => e.srcTags.contains(tag)).length;

  /// Source ids that actually exist in this deck, in canonical order.
  List<String> get presentSources => kSrcOrder
      .where((String s) =>
          s == 'general' || (s == 'essential' && hasEssential) || chaptersFor(s).isNotEmpty)
      .toList();

  /// Deck index for a Dutch word, preferring an entry that has a meaning.
  /// Used to hyperlink synonyms and antonyms (BUILD-SPEC 2.3.3).
  int findWordIndex(String word) {
    final String lw = word.toLowerCase().trim();
    int best = -1;
    for (final (int i, DeckEntry e) in entries.indexed) {
      if (e.word.toLowerCase() == lw) {
        if (e.showsMeaning) return i;
        if (best < 0) best = i;
      }
    }
    return best;
  }

  String? relatedMeaning(String word) {
    final int i = findWordIndex(word);
    if (i >= 0 && entries[i].showsMeaning) return entries[i].meaning;
    return null;
  }

  static Deck fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = json['records'] as List<dynamic>;
    return Deck(raw
        .map((dynamic r) => DeckEntry.fromJson(r as Map<String, dynamic>))
        .toList(growable: false));
  }
}

/// Convenience for tests and callers that need a firstWhereOrNull.
extension DeckEntryListX on List<DeckEntry> {
  DeckEntry? byWord(String w) =>
      firstWhereOrNull((DeckEntry e) => e.word.toLowerCase() == w.toLowerCase());
}
