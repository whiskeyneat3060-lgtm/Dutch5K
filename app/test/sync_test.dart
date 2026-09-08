import 'package:dutch_to_go/data/firebase/sync_repository.dart';
import 'package:dutch_to_go/domain/study_state.dart';
import 'package:dutch_to_go/models/enums.dart';
import 'package:dutch_to_go/models/srs_record.dart';
import 'package:dutch_to_go/models/streak.dart';
import 'package:flutter_test/flutter_test.dart';

import 'deck_fixture.dart';

void main() {
  group('chunking', () {
    test('the chunk index is deterministic and stable across runs', () {
      expect(SyncRepository.chunkFor('bereiken'), SyncRepository.chunkFor('bereiken'));
      expect(SyncRepository.chunkFor('book:actie:huis'),
          SyncRepository.chunkFor('book:actie:huis'));
    });

    test('every chunk index is in range', () {
      final List<String> ids =
          loadRealDeck().entries.map((dynamic e) => e.id as String).toList();
      for (final String id in ids) {
        final int c = SyncRepository.chunkFor(id);
        expect(c, greaterThanOrEqualTo(0));
        expect(c, lessThan(SyncRepository.maxChunks));
      }
    });

    test('the full deck spreads reasonably evenly across chunks', () {
      final List<int> counts = List<int>.filled(SyncRepository.maxChunks, 0);
      for (final dynamic e in loadRealDeck().entries) {
        counts[SyncRepository.chunkFor(e.id as String)]++;
      }
      final int total = counts.reduce((int a, int b) => a + b);
      expect(total, 6752);
      final double ideal = total / SyncRepository.maxChunks;
      for (final int c in counts) {
        expect(c, greaterThan(ideal * 0.7));
        expect(c, lessThan(ideal * 1.3),
            reason: 'no chunk should approach the 1 MiB document limit');
      }
    });
  });

  group('merge — offline work must never be lost', () {
    StudyState state(Map<String, (WordStatus, String)> rows) {
      final StudyState s = StudyState();
      rows.forEach((String id, (WordStatus, String) v) {
        s.progress[id] = v.$1;
        s.srs[id] = SrsRecord(
            due: v.$2, interval: 1, ease: 2.5, reps: 1, lapses: 0, last: v.$2);
      });
      return s;
    }

    test('the more recently graded record wins per word', () {
      final StudyState local = state(<String, (WordStatus, String)>{
        'a': (WordStatus.learning, '2026-03-10'),
        'b': (WordStatus.learned, '2026-03-01'),
      });
      final RemoteSnapshot remote = RemoteSnapshot(
        state: state(<String, (WordStatus, String)>{
          'a': (WordStatus.learned, '2026-03-05'),
          'b': (WordStatus.learning, '2026-03-09'),
          'c': (WordStatus.learned, '2026-03-08'),
        }),
        streak: const StreakData(),
        updatedAt: DateTime(2026, 3, 9),
        deviceId: 'other',
      );

      final ({StudyState state, StreakData streak}) m = SyncRepository.merge(
        local: local,
        localStreak: const StreakData(),
        remote: remote,
      );

      expect(m.state.progress['a'], WordStatus.learning,
          reason: 'local graded later, so local wins');
      expect(m.state.progress['b'], WordStatus.learning,
          reason: 'remote graded later, so remote wins');
      expect(m.state.progress['c'], WordStatus.learned,
          reason: 'remote-only words are adopted');
    });

    test('a tie keeps the local record', () {
      final StudyState local =
          state(<String, (WordStatus, String)>{'a': (WordStatus.learning, '2026-03-10')});
      final RemoteSnapshot remote = RemoteSnapshot(
        state: state(<String, (WordStatus, String)>{'a': (WordStatus.learned, '2026-03-10')}),
        streak: const StreakData(),
        updatedAt: DateTime(2026, 3, 10),
        deviceId: 'other',
      );
      final ({StudyState state, StreakData streak}) m = SyncRepository.merge(
          local: local, localStreak: const StreakData(), remote: remote);
      expect(m.state.progress['a'], WordStatus.learning);
    });

    test('streak history takes the higher count per day', () {
      const StreakData localStreak = StreakData(
        count: 3,
        lastStudied: '2026-03-10',
        history: <String, int>{'2026-03-09': 5, '2026-03-10': 2},
      );
      final RemoteSnapshot remote = RemoteSnapshot(
        state: StudyState(),
        streak: const StreakData(
          count: 5,
          lastStudied: '2026-03-08',
          history: <String, int>{'2026-03-08': 4, '2026-03-09': 1},
        ),
        updatedAt: DateTime(2026, 3, 8),
        deviceId: 'other',
      );
      final ({StudyState state, StreakData streak}) m = SyncRepository.merge(
          local: StudyState(), localStreak: localStreak, remote: remote);

      expect(m.streak.history['2026-03-09'], 5, reason: 'local was higher');
      expect(m.streak.history['2026-03-08'], 4, reason: 'remote-only day is adopted');
      expect(m.streak.history['2026-03-10'], 2);
      expect(m.streak.count, 5, reason: 'the longer streak survives');
      expect(m.streak.lastStudied, '2026-03-10', reason: 'the later study day wins');
    });

    test('merging an empty remote leaves local untouched', () {
      final StudyState local =
          state(<String, (WordStatus, String)>{'a': (WordStatus.learned, '2026-03-10')});
      final ({StudyState state, StreakData streak}) m = SyncRepository.merge(
        local: local,
        localStreak: const StreakData(count: 2, lastStudied: '2026-03-10'),
        remote: RemoteSnapshot(
          state: StudyState(),
          streak: const StreakData(),
          updatedAt: null,
          deviceId: null,
        ),
      );
      expect(m.state.progress['a'], WordStatus.learned);
      expect(m.streak.count, 2);
    });
  });
}
