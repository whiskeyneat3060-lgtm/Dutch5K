import 'dart:math' as math;

import 'package:dutch_to_go/domain/free_plan.dart';
import 'package:dutch_to_go/domain/queue_builder.dart';
import 'package:dutch_to_go/domain/srs.dart';
import 'package:dutch_to_go/domain/study_state.dart';
import 'package:dutch_to_go/models/deck_entry.dart';
import 'package:dutch_to_go/models/enums.dart';
import 'package:dutch_to_go/models/srs_record.dart';
import 'package:flutter_test/flutter_test.dart';

import 'deck_fixture.dart';

void main() {
  late Deck deck;
  late Set<String> freeIds;
  const String today = '2026-03-10';

  setUpAll(() {
    deck = loadRealDeck();
    freeIds = FreePlan.computeFreeIds(deck.entries);
  });

  QueueRequest req({
    StudyState? state,
    StudyMode mode = StudyMode.cards,
    List<String> pos = const <String>[],
    List<String> src = const <String>[],
    bool shuffle = false,
    bool newOnly = false,
    bool leechOnly = false,
    bool isPro = true,
    Set<int> skipped = const <int>{},
    math.Random? random,
  }) =>
      QueueRequest(
        deck: deck,
        state: state ?? StudyState(),
        mode: mode,
        today: today,
        posFilter: pos,
        sourceFilter: src,
        shuffle: shuffle,
        newOnly: newOnly,
        leechOnly: leechOnly,
        isPro: isPro,
        freeIds: freeIds,
        skipped: skipped,
        random: random,
      );

  group('buildQueue — BUILD-SPEC 7.7', () {
    test('AC-13 with no progress the first card is rank 1', () {
      final List<int> q = QueueBuilder.build(req());
      expect(q.length, deck.length);
      expect(deck[q.first].rank, 1);
    });

    test('AC-21 due reviews lead, sorted by ascending due date, then fresh', () {
      final StudyState st = StudyState();
      // Three learned words with different due dates, deliberately out of order.
      final List<String> ids = <String>[
        deck[500].id,
        deck[100].id,
        deck[900].id,
      ];
      final List<String> dues = <String>['2026-03-09', '2026-03-01', '2026-03-10'];
      for (int i = 0; i < ids.length; i++) {
        st.progress[ids[i]] = WordStatus.learned;
        st.srs[ids[i]] = SrsRecord(
            due: dues[i], interval: 3, ease: 2.5, reps: 2, lapses: 0, last: '2026-03-01');
      }
      final List<int> q = QueueBuilder.build(req(state: st));
      expect(deck[q[0]].id, ids[1]); // 2026-03-01, most overdue
      expect(deck[q[1]].id, ids[0]); // 2026-03-09
      expect(deck[q[2]].id, ids[2]); // 2026-03-10
      expect(st.statusOf(deck[q[3]].id), WordStatus.fresh);
    });

    test('not-yet-due words are held back', () {
      final StudyState st = StudyState();
      final String id = deck[10].id;
      st.progress[id] = WordStatus.learned;
      st.srs[id] = const SrsRecord(
          due: '2026-04-01', interval: 20, ease: 2.5, reps: 4, lapses: 0, last: '2026-03-10');
      final List<int> q = QueueBuilder.build(req(state: st));
      expect(q, isNot(contains(10)));
    });

    test('AC-24 falls back to not-due words when nothing is due or fresh', () {
      final StudyState st = StudyState();
      for (final DeckEntry e in deck.entries) {
        st.progress[e.id] = WordStatus.learned;
        st.srs[e.id] = const SrsRecord(
            due: '2026-04-01', interval: 20, ease: 2.5, reps: 4, lapses: 0, last: '2026-03-10');
      }
      final List<int> q = QueueBuilder.build(req(state: st));
      expect(q.length, deck.length, reason: 'never needlessly empty');
    });

    test('AC-22 newOnly holds back every review and may be empty', () {
      final StudyState st = StudyState();
      final String id = deck[0].id;
      st.progress[id] = WordStatus.learned;
      st.srs[id] = const SrsRecord(
          due: '2026-01-01', interval: 1, ease: 2.5, reps: 1, lapses: 0, last: '2026-01-01');

      final List<int> q = QueueBuilder.build(req(state: st, newOnly: true));
      expect(q, isNot(contains(0)));
      expect(q.length, deck.length - 1);

      // Everything started -> genuinely empty, with no fallback.
      final StudyState all = StudyState();
      for (final DeckEntry e in deck.entries) {
        all.progress[e.id] = WordStatus.learned;
      }
      expect(QueueBuilder.build(req(state: all, newOnly: true)), isEmpty);
    });

    test('AC-23 leechOnly drills only leeches and introduces no fresh words', () {
      final StudyState st = StudyState();
      final String hard = deck[300].id;
      final String mild = deck[301].id;
      st.progress[hard] = WordStatus.learning;
      st.srs[hard] = const SrsRecord(
          due: '2026-03-01', interval: 0, ease: 1.9, reps: 0, lapses: 3, last: '2026-03-01');
      st.progress[mild] = WordStatus.learning;
      st.srs[mild] = const SrsRecord(
          due: '2026-03-01', interval: 0, ease: 2.3, reps: 0, lapses: 1, last: '2026-03-01');

      final List<int> q = QueueBuilder.build(req(state: st, leechOnly: true));
      expect(q, <int>[300]);
    });

    test('leeches are ordered hardest first', () {
      final StudyState st = StudyState();
      void lapse(int idx, int n) {
        st.progress[deck[idx].id] = WordStatus.learning;
        st.srs[deck[idx].id] = SrsRecord(
            due: '2026-03-01', interval: 0, ease: 2.0, reps: 0, lapses: n, last: '2026-03-01');
      }

      lapse(10, 2);
      lapse(20, 5);
      lapse(30, 3);
      expect(QueueBuilder.leeches(deck, st), <int>[20, 30, 10]);
    });

    test('AC-25 skipped indices move to the back preserving order', () {
      final List<int> q = QueueBuilder.build(req(skipped: <int>{0, 1}));
      expect(q.sublist(q.length - 2), <int>[0, 1]);
      expect(q.first, isNot(0));
    });

    test('filters narrow the pool; combined filters intersect', () {
      final List<int> verbs = QueueBuilder.build(req(pos: <String>['verb']));
      expect(verbs, isNotEmpty);
      expect(verbs.every((int i) => deck[i].pos == 'verb'), isTrue);

      final List<int> gang = QueueBuilder.build(req(src: <String>['gang']));
      expect(gang.every((int i) => deck[i].srcTags.contains('gang')), isTrue);

      final List<int> both =
          QueueBuilder.build(req(pos: <String>['verb'], src: <String>['gang']));
      expect(
        both.every((int i) => deck[i].pos == 'verb' && deck[i].srcTags.contains('gang')),
        isTrue,
      );
      expect(both.length, lessThan(gang.length));
    });

    test('multi-select source filter is a union', () {
      final List<int> two = QueueBuilder.build(req(src: <String>['gang', 'niveau']));
      expect(
        two.every((int i) =>
            deck[i].srcTags.contains('gang') || deck[i].srcTags.contains('niveau')),
        isTrue,
      );
    });

    test('AC-26 mode eligibility restricts the pool correctly', () {
      for (final StudyMode m in <StudyMode>[
        StudyMode.reverse,
        StudyMode.type,
        StudyMode.listen
      ]) {
        final List<int> q = QueueBuilder.build(req(mode: m));
        expect(q.every((int i) => deck[i].meaning != null && deck[i].showsMeaning), isTrue);
      }

      final List<int> dehet = QueueBuilder.build(req(mode: StudyMode.dehet));
      expect(dehet.every((int i) => deck[i].article == 'de' || deck[i].article == 'het'),
          isTrue);
      expect(dehet.length, 1176);

      final List<int> cloze = QueueBuilder.build(req(mode: StudyMode.cloze));
      expect(cloze.length, lessThan(deck.length),
          reason: 'not every example contains its own headword');
      expect(cloze, isNotEmpty);
    });

    test('AC-34 free-first ordering applies with shuffle off', () {
      final List<int> q = QueueBuilder.build(req(isPro: false));
      final int firstLocked = q.indexWhere((int i) => !freeIds.contains(deck[i].id));
      final int lastFree = q.lastIndexWhere((int i) => freeIds.contains(deck[i].id));
      expect(lastFree, lessThan(firstLocked));
      expect(firstLocked, 850);
    });

    test('AC-35 free-first is deliberately NOT applied with shuffle on', () {
      final List<int> q =
          QueueBuilder.build(req(isPro: false, shuffle: true, random: math.Random(7)));
      final int firstLocked = q.indexWhere((int i) => !freeIds.contains(deck[i].id));
      expect(firstLocked, lessThan(850));
    });

    test('weighted shuffle keeps every word and favours common words', () {
      final List<int> q =
          QueueBuilder.build(req(shuffle: true, random: math.Random(42)));
      expect(q.length, deck.length);
      expect(q.toSet().length, deck.length, reason: 'no duplicates or drops');

      final double meanRankFront = q
              .take(200)
              .map((int i) => deck[i].sortRank)
              .reduce((int a, int b) => a + b) /
          200;
      final double meanRankAll =
          deck.entries.map((DeckEntry e) => e.sortRank).reduce((int a, int b) => a + b) /
              deck.length;
      expect(meanRankFront, lessThan(meanRankAll),
          reason: 'common words still surface first on average');
    });

    test('shuffle draws a different order each rebuild', () {
      final List<int> a =
          QueueBuilder.build(req(shuffle: true, random: math.Random(1))).take(50).toList();
      final List<int> b =
          QueueBuilder.build(req(shuffle: true, random: math.Random(2))).take(50).toList();
      expect(a, isNot(equals(b)));
    });

    test('AC-28 dueCount only counts started, due words', () {
      final StudyState st = StudyState();
      expect(QueueBuilder.dueCount(deck, st, today), 0);
      st.progress[deck[5].id] = WordStatus.learned;
      st.srs[deck[5].id] = const SrsRecord(
          due: '2026-03-10', interval: 1, ease: 2.5, reps: 1, lapses: 0, last: '2026-03-09');
      st.progress[deck[6].id] = WordStatus.learned;
      st.srs[deck[6].id] = const SrsRecord(
          due: '2026-12-01', interval: 90, ease: 2.5, reps: 6, lapses: 0, last: '2026-03-09');
      expect(QueueBuilder.dueCount(deck, st, today), 1);
    });

    test('a legacy word with no SRS record counts as due', () {
      final StudyState st = StudyState();
      st.progress[deck[7].id] = WordStatus.learning;
      expect(QueueBuilder.dueCount(deck, st, today), 1);
      expect(Srs.isDue(record: null, status: WordStatus.learning, today: today), isTrue);
    });
  });
}
