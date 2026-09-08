import 'dart:math' as math;

import '../models/deck_entry.dart';
import '../models/enums.dart';
import '../models/srs_record.dart';
import 'answer_check.dart';
import 'free_plan.dart';
import 'srs.dart';
import 'study_state.dart';

/// Everything the queue builder needs, so it stays a pure function and is
/// directly unit-testable.
class QueueRequest {
  const QueueRequest({
    required this.deck,
    required this.state,
    required this.mode,
    required this.today,
    this.posFilter = const <String>[],
    this.sourceFilter = const <String>[],
    this.shuffle = false,
    this.newOnly = false,
    this.leechOnly = false,
    this.isPro = true,
    this.freeIds = const <String>{},
    this.skipped = const <int>{},
    this.random,
  });

  final Deck deck;
  final StudyState state;
  final StudyMode mode;
  final String today;

  /// Empty means "all".
  final List<String> posFilter;
  final List<String> sourceFilter;

  final bool shuffle;
  final bool newOnly;
  final bool leechOnly;
  final bool isPro;
  final Set<String> freeIds;

  /// Deck indices skipped this session; they get pushed to the back.
  final Set<int> skipped;

  /// Injectable for deterministic tests.
  final math.Random? random;
}

/// Builds the study queue (BUILD-SPEC 7.7).
class QueueBuilder {
  const QueueBuilder._();

  /// Which words a given study mode can use.
  static bool modeEligible(DeckEntry e, StudyMode mode) {
    switch (mode) {
      case StudyMode.reverse:
      case StudyMode.type:
      case StudyMode.listen:
        return (e.meaning?.isNotEmpty ?? false) && e.showsMeaning;
      case StudyMode.cloze:
        return AnswerCheck.pickCloze(e) != null;
      case StudyMode.dehet:
        return e.article == 'de' || e.article == 'het';
      case StudyMode.cards:
        return true;
    }
  }

  /// Deck indices of leeches (>= 2 lapses), hardest first.
  static List<int> leeches(Deck deck, StudyState state) {
    final List<int> out = <int>[];
    for (final (int i, DeckEntry e) in deck.entries.indexed) {
      final SrsRecord? s = state.srsOf(e.id);
      if (s != null && s.lapses >= Srs.leechLapseThreshold) out.add(i);
    }
    out.sort((int a, int b) {
      final int la = state.srsOf(deck[a].id)?.lapses ?? 0;
      final int lb = state.srsOf(deck[b].id)?.lapses ?? 0;
      return lb.compareTo(la);
    });
    return out;
  }

  /// Number of started words scheduled to come back today.
  static int dueCount(Deck deck, StudyState state, String today) {
    int n = 0;
    for (final DeckEntry e in deck.entries) {
      final WordStatus s = state.statusOf(e.id);
      if (s == WordStatus.fresh) continue;
      if (Srs.isDue(record: state.srsOf(e.id), status: s, today: today)) n++;
    }
    return n;
  }

  static List<int> build(QueueRequest r) {
    final List<int> due = <int>[];
    final List<int> notDue = <int>[];
    List<int> fresh = <int>[];

    final Set<String>? leechIds = r.leechOnly
        ? leeches(r.deck, r.state).map((int i) => r.deck[i].id).toSet()
        : null;

    for (final (int i, DeckEntry e) in r.deck.entries.indexed) {
      if (r.posFilter.isNotEmpty && !r.posFilter.contains((e.pos ?? '').toLowerCase())) {
        continue;
      }
      if (r.sourceFilter.isNotEmpty && !r.sourceFilter.any(e.inSource)) continue;
      if (!modeEligible(e, r.mode)) continue;
      if (leechIds != null && !leechIds.contains(e.id)) continue;

      final WordStatus s = r.state.statusOf(e.id);
      if (s == WordStatus.learning || s == WordStatus.learned) {
        if (Srs.isDue(record: r.state.srsOf(e.id), status: s, today: r.today)) {
          due.add(i);
        } else {
          notDue.add(i);
        }
      } else if (!r.leechOnly) {
        // Never introduce brand-new words during a leech drill.
        fresh.add(i);
      }
    }

    // Due reviews first, most overdue leading.
    due.sort((int a, int b) {
      final String da = r.state.srsOf(r.deck[a].id)?.due ?? '0000-00-00';
      final String db = r.state.srsOf(r.deck[b].id)?.due ?? '0000-00-00';
      return da.compareTo(db);
    });

    if (r.shuffle) {
      fresh = _weightedShuffle(fresh, r.deck, r.random ?? math.Random());
    } else {
      fresh.sort((int a, int b) => r.deck[a].sortRank.compareTo(r.deck[b].sortRank));
      fresh = FreePlan.freeFirst(
        fresh,
        isPro: r.isPro,
        freeIds: r.freeIds,
        entries: r.deck.entries,
      );
    }

    List<int> queue;
    if (r.newOnly) {
      // Hold back every due review. An empty deck here means "no new words
      // left", which is the honest intended state — there is no fallback.
      queue = fresh;
    } else {
      queue = <int>[...due, ...fresh];
      if (queue.isEmpty) queue = notDue;
    }

    if (r.skipped.isNotEmpty) {
      final List<int> kept = <int>[];
      final List<int> pushed = <int>[];
      for (final int i in queue) {
        (r.skipped.contains(i) ? pushed : kept).add(i);
      }
      queue = <int>[...kept, ...pushed];
    }
    return queue;
  }

  /// Frequency-weighted randomisation (Efraimidis–Spirakis).
  ///
  /// Each fresh word gets `key = random^log2(rank + 2)`, sorted descending.
  /// Common words still surface first on average, but every rebuild draws a
  /// different set, and rare corpus words stay unlikely to jump the front.
  static List<int> _weightedShuffle(List<int> fresh, Deck deck, math.Random rng) {
    final List<({int index, double key})> keyed = fresh.map((int i) {
      final int rank = deck[i].rank == 0 ? 6000 : deck[i].rank;
      final double exponent = math.log(rank + 2) / math.ln2;
      return (index: i, key: math.pow(rng.nextDouble(), exponent).toDouble());
    }).toList();
    keyed.sort((({int index, double key}) a, ({int index, double key}) b) =>
        b.key.compareTo(a.key));
    return keyed.map((({int index, double key}) k) => k.index).toList();
  }
}
