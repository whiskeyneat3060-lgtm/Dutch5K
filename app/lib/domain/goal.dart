import 'dart:math' as math;

import '../models/deck_entry.dart';
import '../models/enums.dart';
import 'counts.dart';
import 'study_state.dart';

/// Distinct total/learned across the sources selected for a source-completion
/// goal. A word belonging to two selected sources is counted **once**.
class GoalSourceCounts {
  const GoalSourceCounts(this.total, this.learned);
  final int total;
  final int learned;
}

/// Learning-goal maths (BUILD-SPEC 7.10).
class Goal {
  const Goal._();

  /// Selected sources that actually exist in this deck.
  static List<String> sourceList(Deck deck, List<String> goalSources) => goalSources
      .where((String s) => s == 'general' || s == 'essential' || deck.chaptersFor(s).isNotEmpty)
      .toList();

  static GoalSourceCounts sourceCounts(
    Deck deck,
    StudyState state,
    List<String> goalSources,
  ) {
    final List<String> srcs = sourceList(deck, goalSources);
    if (srcs.isEmpty) return const GoalSourceCounts(0, 0);
    int total = 0;
    int learned = 0;
    for (final DeckEntry e in deck.entries) {
      if (!srcs.any(e.inSource)) continue;
      total++;
      if (state.statusOf(e.id) == WordStatus.learned) learned++;
    }
    return GoalSourceCounts(total, learned);
  }

  /// The denominator of the progress percentage.
  static int total({
    required Deck deck,
    required StudyState state,
    required GoalMode mode,
    required int? wordGoal,
    required List<String> goalSources,
  }) {
    final int d = deck.length == 0 ? 5000 : deck.length;
    if (mode == GoalMode.source) {
      final int t = sourceCounts(deck, state, goalSources).total;
      return t == 0 ? d : t;
    }
    return (wordGoal != null && wordGoal > 0) ? math.min(wordGoal, d) : d;
  }

  /// The numerator: all learned in count mode, in-source learned in source mode.
  static int learned({
    required Deck deck,
    required StudyState state,
    required GoalMode mode,
    required List<String> goalSources,
    required DeckCounts counts,
  }) =>
      mode == GoalMode.source
          ? sourceCounts(deck, state, goalSources).learned
          : counts.learned;

  /// Percentage complete, capped at 100, to one decimal place.
  static double percent(int learnedCount, int totalCount) {
    if (totalCount <= 0) return 0;
    final double p = learnedCount / totalCount * 100;
    return p > 100 ? 100 : p;
  }
}
