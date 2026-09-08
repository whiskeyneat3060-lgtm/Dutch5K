import 'package:dutch_to_go/domain/dates.dart';
import 'package:dutch_to_go/domain/srs.dart';
import 'package:dutch_to_go/models/enums.dart';
import 'package:dutch_to_go/models/srs_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const String today = '2026-03-10';

  group('scheduleSrs — BUILD-SPEC 7.6', () {
    test('AC-14 first "Know it" on a fresh word', () {
      final SrsRecord s = Srs.schedule(existing: null, grade: 2, today: today);
      expect(s.interval, 1);
      expect(s.reps, 1);
      expect(s.ease, 2.5);
      expect(s.lapses, 0);
      expect(s.due, addDays(today, 1));
      expect(s.last, today);
    });

    test('AC-15 second "Know it" gives a 4-day interval', () {
      final SrsRecord first = Srs.schedule(existing: null, grade: 2, today: today);
      final SrsRecord second =
          Srs.schedule(existing: first, grade: 2, today: addDays(today, 1));
      expect(second.interval, 4);
      expect(second.reps, 2);
      expect(second.ease, 2.5);
    });

    test('AC-16 "Learning" on a fresh word drops ease by 0.14', () {
      final SrsRecord s = Srs.schedule(existing: null, grade: 1, today: today);
      expect(s.interval, 1);
      expect(s.reps, 1);
      expect(s.ease, closeTo(2.36, 1e-9));
    });

    test('second "Learning" gives a 2-day interval', () {
      final SrsRecord first = Srs.schedule(existing: null, grade: 1, today: today);
      final SrsRecord second = Srs.schedule(existing: first, grade: 1, today: today);
      expect(second.interval, 2);
    });

    test('"Easy" raises ease by 0.10', () {
      final SrsRecord s = Srs.schedule(existing: null, grade: 3, today: today);
      expect(s.ease, closeTo(2.6, 1e-9));
    });

    test('AC-17 "Again" is a lapse that resets and re-dues today', () {
      final SrsRecord grown = Srs.schedule(
        existing: Srs.schedule(existing: null, grade: 2, today: today),
        grade: 2,
        today: today,
      );
      final SrsRecord lapsed = Srs.schedule(existing: grown, grade: 0, today: today);
      expect(lapsed.lapses, 1);
      expect(lapsed.reps, 0);
      expect(lapsed.interval, 0);
      expect(lapsed.ease, closeTo(grown.ease - 0.2, 1e-9));
      expect(lapsed.due, today);
    });

    test('AC-18 ease never falls below 1.3', () {
      SrsRecord s = SrsRecord.initial(today);
      for (int i = 0; i < 40; i++) {
        s = Srs.schedule(existing: s, grade: 0, today: today);
      }
      expect(s.ease, 1.3);
      s = Srs.schedule(existing: s, grade: 1, today: today);
      expect(s.ease, greaterThanOrEqualTo(1.3));
    });

    test('mature interval grows by the ease factor and never drops below 1', () {
      const SrsRecord mature = SrsRecord(
        due: '2026-03-10',
        interval: 10,
        ease: 2.5,
        reps: 5,
        lapses: 0,
        last: '2026-03-10',
      );
      expect(Srs.schedule(existing: mature, grade: 2, today: today).interval, 25);
      expect(Srs.schedule(existing: mature, grade: 1, today: today).interval, 13);
      expect(Srs.schedule(existing: mature, grade: 3, today: today).interval, 33);

      const SrsRecord tiny = SrsRecord(
        due: '2026-03-10',
        interval: 1,
        ease: 1.3,
        reps: 5,
        lapses: 9,
        last: '2026-03-10',
      );
      expect(Srs.schedule(existing: tiny, grade: 1, today: today).interval,
          greaterThanOrEqualTo(1));
    });
  });

  group('isDue — BUILD-SPEC 7.6', () {
    test('AC-19 a scheduled word is due on and after its due date', () {
      const SrsRecord r = SrsRecord(
          due: '2026-03-10', interval: 3, ease: 2.5, reps: 2, lapses: 0, last: '2026-03-07');
      expect(Srs.isDue(record: r, status: WordStatus.learned, today: '2026-03-09'), isFalse);
      expect(Srs.isDue(record: r, status: WordStatus.learned, today: '2026-03-10'), isTrue);
      expect(Srs.isDue(record: r, status: WordStatus.learned, today: '2026-03-11'), isTrue);
    });

    test('AC-19 a never-started word is never due', () {
      expect(Srs.isDue(record: null, status: WordStatus.fresh, today: today), isFalse);
    });

    test('AC-20 a legacy word with status but no record is due immediately', () {
      expect(Srs.isDue(record: null, status: WordStatus.learning, today: today), isTrue);
      expect(Srs.isDue(record: null, status: WordStatus.learned, today: today), isTrue);
    });
  });

  group('date helpers', () {
    test('addDays rolls over months and years', () {
      expect(addDays('2026-01-31', 1), '2026-02-01');
      expect(addDays('2026-12-31', 1), '2027-01-01');
      expect(addDays('2024-02-28', 1), '2024-02-29');
    });

    test('daysBetween', () {
      expect(daysBetween('2026-03-01', '2026-03-02'), 1);
      expect(daysBetween('2026-03-02', '2026-03-01'), -1);
      expect(daysBetween('2026-03-01', '2026-03-01'), 0);
    });

    test('due dates compare correctly as plain strings', () {
      expect('2026-03-09'.compareTo('2026-03-10') < 0, isTrue);
      expect('2026-09-01'.compareTo('2026-10-01') < 0, isTrue);
    });
  });
}
