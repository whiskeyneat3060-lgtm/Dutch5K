import '../core/constants.dart';
import '../models/deck_entry.dart';
import '../models/enums.dart';
import 'study_state.dart';

/// Learned / learning / not-started totals.
class DeckCounts {
  const DeckCounts({
    required this.learned,
    required this.learning,
    required this.fresh,
    required this.total,
  });
  final int learned;
  final int learning;
  final int fresh;
  final int total;

  static DeckCounts of(Deck deck, StudyState state) {
    int learned = 0;
    int learning = 0;
    for (final DeckEntry e in deck.entries) {
      switch (state.statusOf(e.id)) {
        case WordStatus.learned:
          learned++;
        case WordStatus.learning:
          learning++;
        case WordStatus.fresh:
          break;
      }
    }
    return DeckCounts(
      learned: learned,
      learning: learning,
      fresh: deck.length - learned - learning,
      total: deck.length,
    );
  }
}

/// One row of the "By word type" breakdown.
class PosBucket {
  PosBucket();
  int total = 0;
  int learned = 0;

  /// Learned words attributed to exactly one source, so the stacked segments
  /// sum precisely to [learned].
  final Map<String, int> bySource = <String, int>{};
}

/// One slice of the "By source" donut.
class SourceBucket {
  SourceBucket();
  int total = 0;
  int learned = 0;
}

class Breakdowns {
  const Breakdowns._();

  static Map<String, PosBucket> byPos(Deck deck, StudyState state) {
    final Map<String, PosBucket> out = <String, PosBucket>{};
    for (final DeckEntry e in deck.entries) {
      final String p = (e.pos ?? '').toLowerCase().isEmpty ? 'other' : e.pos!.toLowerCase();
      final PosBucket b = out.putIfAbsent(p, PosBucket.new);
      b.total++;
      if (state.statusOf(e.id) == WordStatus.learned) {
        b.learned++;
        final String s = e.primarySource;
        b.bySource[s] = (b.bySource[s] ?? 0) + 1;
      }
    }
    return out;
  }

  /// Learned/total per source.
  ///
  /// A word shared between two books counts under **each**, matching how the
  /// source filter presents them — so slice sums can exceed the distinct
  /// learned total. That is intentional.
  static Map<String, SourceBucket> bySource(Deck deck, StudyState state) {
    final List<String> present = deck.presentSources;
    final Map<String, SourceBucket> out = <String, SourceBucket>{
      for (final String s in present) s: SourceBucket(),
    };
    for (final DeckEntry e in deck.entries) {
      final bool learned = state.statusOf(e.id) == WordStatus.learned;
      for (final String s in present) {
        if (!e.inSource(s)) continue;
        final SourceBucket b = out[s]!;
        b.total++;
        if (learned) b.learned++;
      }
    }
    return out;
  }

  /// Rows of the breakdown in the fixed display order, skipping empty types.
  static List<MapEntry<String, PosBucket>> posRows(Map<String, PosBucket> buckets) =>
      kPosBreakdownOrder
          .where((String p) => buckets.containsKey(p))
          .map((String p) => MapEntry<String, PosBucket>(p, buckets[p]!))
          .toList();
}
