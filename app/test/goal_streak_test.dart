import 'package:dutch_to_go/domain/counts.dart';
import 'package:dutch_to_go/domain/goal.dart';
import 'package:dutch_to_go/domain/streak_logic.dart';
import 'package:dutch_to_go/domain/study_state.dart';
import 'package:dutch_to_go/models/deck_entry.dart';
import 'package:dutch_to_go/models/enums.dart';
import 'package:dutch_to_go/models/streak.dart';
import 'package:flutter_test/flutter_test.dart';

import 'deck_fixture.dart';

void main() {
  late Deck deck;
  setUpAll(() => deck = loadRealDeck());

  group('learning goal — BUILD-SPEC 7.10', () {
    test('AC-41 no custom goal means the whole deck', () {
      expect(
        Goal.total(
          deck: deck,
          state: StudyState(),
          mode: GoalMode.count,
          wordGoal: null,
          goalSources: const <String>[],
        ),
        6752,
      );
    });

    test('a custom goal is honoured and capped at the deck size', () {
      int t(int? g) => Goal.total(
            deck: deck,
            state: StudyState(),
            mode: GoalMode.count,
            wordGoal: g,
            goalSources: const <String>[],
          );
      expect(t(1000), 1000);
      expect(t(99999), 6752);
      expect(t(0), 6752);
    });

    test('AC-43 overlapping sources count a shared word only once', () {
      final StudyState st = StudyState();
      // A word tagged both actie and niveau.
      final DeckEntry shared = deck.byId['book:actie:een hekel hebben aan iets']!;
      expect(shared.srcTags, containsAll(<String>['actie', 'niveau']));
      st.progress[shared.id] = WordStatus.learned;

      final GoalSourceCounts both =
          Goal.sourceCounts(deck, st, const <String>['actie', 'niveau']);
      final GoalSourceCounts actie = Goal.sourceCounts(deck, st, const <String>['actie']);
      final GoalSourceCounts niveau = Goal.sourceCounts(deck, st, const <String>['niveau']);

      expect(both.total, lessThan(actie.total + niveau.total));
      expect(both.learned, 1, reason: 'the shared word is counted once');
    });

    test('AC-44 source mode with nothing selected falls back to the deck size', () {
      expect(
        Goal.total(
          deck: deck,
          state: StudyState(),
          mode: GoalMode.source,
          wordGoal: null,
          goalSources: const <String>[],
        ),
        6752,
      );
    });

    test('source mode rescopes numerator and denominator together', () {
      final StudyState st = StudyState();
      final List<DeckEntry> gang =
          deck.entries.where((DeckEntry e) => e.srcTags.contains('gang')).toList();
      for (final DeckEntry e in gang.take(10)) {
        st.progress[e.id] = WordStatus.learned;
      }
      // Learn something outside the goal source too.
      final DeckEntry outside = deck.entries
          .firstWhere((DeckEntry e) => e.srcTags.contains('general'));
      st.progress[outside.id] = WordStatus.learned;

      final DeckCounts counts = DeckCounts.of(deck, st);
      expect(counts.learned, 11);

      final int scoped = Goal.learned(
        deck: deck,
        state: st,
        mode: GoalMode.source,
        goalSources: const <String>['gang'],
        counts: counts,
      );
      expect(scoped, 10, reason: 'the general word does not count toward a gang goal');
      expect(
        Goal.total(
          deck: deck,
          state: st,
          mode: GoalMode.source,
          wordGoal: null,
          goalSources: const <String>['gang'],
        ),
        946,
      );
    });

    test('AC-42 percentage is capped at 100', () {
      expect(Goal.percent(50, 100), 50);
      expect(Goal.percent(150, 100), 100);
      expect(Goal.percent(0, 0), 0);
      expect(Goal.percent(1, 3).toStringAsFixed(1), '33.3');
    });
  });

  group('streak — BUILD-SPEC 7.9', () {
    test('AC-45 the first word of the first day starts a streak of 1', () {
      final StreakData s = StreakLogic.recordLearned(const StreakData(), '2026-03-10');
      expect(s.count, 1);
      expect(s.lastStudied, '2026-03-10');
      expect(s.countFor('2026-03-10'), 1);
    });

    test('AC-46 consecutive days increment by exactly one', () {
      StreakData s = const StreakData();
      s = StreakLogic.recordLearned(s, '2026-03-10');
      s = StreakLogic.recordLearned(s, '2026-03-11');
      s = StreakLogic.recordLearned(s, '2026-03-12');
      expect(s.count, 3);
    });

    test('more words on the same day do not increment the streak', () {
      StreakData s = StreakLogic.recordLearned(const StreakData(), '2026-03-10');
      s = StreakLogic.recordLearned(s, '2026-03-10');
      s = StreakLogic.recordLearned(s, '2026-03-10');
      expect(s.count, 1);
      expect(s.countFor('2026-03-10'), 3);
    });

    test('a gap resets the streak to 1', () {
      StreakData s = StreakLogic.recordLearned(const StreakData(), '2026-03-10');
      s = StreakLogic.recordLearned(s, '2026-03-11');
      expect(s.count, 2);
      s = StreakLogic.recordLearned(s, '2026-03-15');
      expect(s.count, 1);
    });

    test('AC-47 the displayed streak survives one missed day, not two', () {
      StreakData s = const StreakData();
      s = StreakLogic.recordLearned(s, '2026-03-09');
      s = StreakLogic.recordLearned(s, '2026-03-10');
      expect(StreakLogic.current(s, '2026-03-10'), 2, reason: 'studied today');
      expect(StreakLogic.current(s, '2026-03-11'), 2, reason: 'studied yesterday');
      expect(StreakLogic.current(s, '2026-03-12'), 0, reason: 'two days idle');
    });

    test('current is 0 when nothing has ever been studied', () {
      expect(StreakLogic.current(const StreakData(), '2026-03-10'), 0);
    });

    test('AC-49 the history grid is 14 cells, oldest first, with the right levels', () {
      final StreakData s = StreakData(history: <String, int>{
        '2026-03-10': 0,
        '2026-03-09': 3,
        '2026-03-08': 7,
        '2026-03-07': 25,
      });
      final List<({int count, String day})> cells =
          StreakLogic.last14Days(s, DateTime(2026, 3, 10));
      expect(cells.length, 14);
      expect(cells.first.day, '2026-02-25');
      expect(cells.last.day, '2026-03-10');
      expect(StreakLogic.level(cells.last.count), 0);
      expect(StreakLogic.level(3), 1);
      expect(StreakLogic.level(7), 2);
      expect(StreakLogic.level(25), 3);
      expect(StreakLogic.level(4), 1);
      expect(StreakLogic.level(5), 2);
      expect(StreakLogic.level(9), 2);
      expect(StreakLogic.level(10), 3);
    });
  });

  group('counts', () {
    test('learned + learning + fresh always equals the deck size', () {
      final StudyState st = StudyState();
      st.progress[deck[0].id] = WordStatus.learned;
      st.progress[deck[1].id] = WordStatus.learning;
      final DeckCounts c = DeckCounts.of(deck, st);
      expect(c.learned, 1);
      expect(c.learning, 1);
      expect(c.learned + c.learning + c.fresh, deck.length);
    });

    test('stacked by-type segments sum exactly to the row learned total', () {
      final StudyState st = StudyState();
      for (final DeckEntry e in deck.entries.take(1200)) {
        st.progress[e.id] = WordStatus.learned;
      }
      final Map<String, PosBucket> buckets = Breakdowns.byPos(deck, st);
      for (final PosBucket b in buckets.values) {
        final int segSum =
            b.bySource.values.fold(0, (int a, int v) => a + v);
        expect(segSum, b.learned);
      }
    });

    test('by-source buckets exist for every present source', () {
      final Map<String, SourceBucket> byS = Breakdowns.bySource(deck, StudyState());
      expect(byS.keys.toSet(), deck.presentSources.toSet());
      expect(byS['gang']!.total, 946);
      expect(byS['essential']!.total, 1484);
    });
  });
}
