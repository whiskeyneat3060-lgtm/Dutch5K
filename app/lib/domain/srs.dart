import '../models/enums.dart';
import '../models/srs_record.dart';
import 'dates.dart';

/// SM-2-lite spaced repetition (BUILD-SPEC 7.6).
///
/// Grade 0 (Again) is a lapse: reset the interval and make the word due today.
/// Grades 1 (Learning), 2 (Know it) and 3 (Easy) grow the interval by the ease
/// factor. The ease factor is floored at 1.3 and has no ceiling.
class Srs {
  const Srs._();

  /// Returns the updated record for [existing] after [grade] on [today].
  /// [existing] may be null for a word graded for the first time.
  static SrsRecord schedule({
    required SrsRecord? existing,
    required int grade,
    required String today,
  }) {
    final SrsRecord s = existing ??
        const SrsRecord(
          due: '',
          interval: 0,
          ease: SrsRecord.defaultEase,
          reps: 0,
          lapses: 0,
          last: '',
        );

    if (grade <= 0) {
      return s.copyWith(
        lapses: s.lapses + 1,
        reps: 0,
        interval: 0,
        ease: _floor(s.ease - 0.2),
        due: today,
        last: today,
      );
    }

    final int interval;
    if (s.reps == 0) {
      interval = 1; // first correct recall -> tomorrow
    } else if (s.reps == 1) {
      interval = grade >= 2 ? 4 : 2;
    } else {
      final double factor = grade == 1
          ? 0.5
          : grade >= 3
              ? 1.3
              : 1.0;
      final int grown = (s.interval * s.ease * factor).round();
      interval = grown < 1 ? 1 : grown;
    }

    // Map grades 1..3 onto SM-2 quality 3..5.
    final int q = grade + 2;
    final double ease = _floor(s.ease + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)));

    return s.copyWith(
      interval: interval,
      reps: s.reps + 1,
      ease: ease,
      due: addDays(today, interval),
      last: today,
    );
  }

  static double _floor(double ef) => ef < SrsRecord.minEase ? SrsRecord.minEase : ef;

  /// A started word is due when its scheduled date has arrived.
  ///
  /// A word with a progress status but **no** SRS record is a legacy record and
  /// is treated as due, so it enters the rotation the first time. A word that
  /// has never been started is never due.
  static bool isDue({
    required SrsRecord? record,
    required WordStatus status,
    required String today,
  }) {
    if (record != null) return record.due.compareTo(today) <= 0;
    return status == WordStatus.learning || status == WordStatus.learned;
  }

  /// Leech threshold: words missed this many times or more.
  static const int leechLapseThreshold = 2;
}
