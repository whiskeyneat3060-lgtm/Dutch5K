import '../models/streak.dart';
import 'dates.dart';

/// Streak rules (BUILD-SPEC 7.9).
class StreakLogic {
  const StreakLogic._();

  /// Records one newly learned word on [today] and returns the updated data.
  ///
  /// The consecutive-day count increments only on the first word of a new day,
  /// and only when the previous study day was exactly one day earlier.
  static StreakData recordLearned(StreakData s, String today) {
    final Map<String, int> history = Map<String, int>.of(s.history);
    history[today] = (history[today] ?? 0) + 1;

    int count = s.count;
    String? lastStudied = s.lastStudied;

    if (lastStudied != today) {
      if (lastStudied != null && daysBetween(lastStudied, today) == 1) {
        count += 1;
      } else if (lastStudied == null || daysBetween(lastStudied, today) > 1) {
        count = 1;
      }
      lastStudied = today;
    } else if (count == 0) {
      count = 1;
      lastStudied = today;
    }

    return StreakData(count: count, lastStudied: lastStudied, history: history);
  }

  /// The streak as displayed: intact when the last study day was today or
  /// yesterday, otherwise 0.
  static int current(StreakData s, String today) {
    final String? last = s.lastStudied;
    if (last == null) return 0;
    final int d = daysBetween(last, today);
    return (d == 0 || d == 1) ? s.count : 0;
  }

  /// The last 14 calendar days, oldest first, as (dateString, count) pairs.
  static List<({String day, int count})> last14Days(StreakData s, DateTime now) {
    final List<({String day, int count})> out = <({String day, int count})>[];
    for (int k = 13; k >= 0; k--) {
      final DateTime d = DateTime(now.year, now.month, now.day - k);
      final String ds = dateStr(d);
      out.add((day: ds, count: s.history[ds] ?? 0));
    }
    return out;
  }

  /// Intensity level for the history grid: 0, 1-4, 5-9, 10+.
  static int level(int n) => n == 0
      ? 0
      : n < 5
          ? 1
          : n < 10
              ? 2
              : 3;
}
