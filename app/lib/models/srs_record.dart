/// One spaced-repetition record per graded word (BUILD-SPEC 6.3.2).
///
/// [due] and [last] are plain `YYYY-MM-DD` strings compared lexicographically —
/// safe because the format is fixed width and zero padded, and it keeps the
/// value identical to what the web app stores.
class SrsRecord {
  const SrsRecord({
    required this.due,
    required this.interval,
    required this.ease,
    required this.reps,
    required this.lapses,
    required this.last,
  });

  final String due;

  /// Current interval in days.
  final int interval;

  /// SM-2 ease factor, floored at 1.3.
  final double ease;

  /// Consecutive successful recalls; reset to 0 on a lapse.
  final int reps;

  /// Lifetime count of "Again" grades. >= 2 makes the word a leech.
  final int lapses;
  final String last;

  static const double defaultEase = 2.5;
  static const double minEase = 1.3;

  /// The starting record for a word that has never been graded.
  static SrsRecord initial(String today) => SrsRecord(
        due: today,
        interval: 0,
        ease: defaultEase,
        reps: 0,
        lapses: 0,
        last: today,
      );

  SrsRecord copyWith({
    String? due,
    int? interval,
    double? ease,
    int? reps,
    int? lapses,
    String? last,
  }) =>
      SrsRecord(
        due: due ?? this.due,
        interval: interval ?? this.interval,
        ease: ease ?? this.ease,
        reps: reps ?? this.reps,
        lapses: lapses ?? this.lapses,
        last: last ?? this.last,
      );

  /// Compact wire form used by both SQLite and the Firestore sync documents.
  /// Field names match the web app's `srs` records exactly.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'due': due,
        'iv': interval,
        'ef': ease,
        'reps': reps,
        'lapses': lapses,
        'last': last,
      };

  factory SrsRecord.fromJson(Map<String, dynamic> j) => SrsRecord(
        due: j['due'] as String? ?? '0000-00-00',
        interval: (j['iv'] as num?)?.toInt() ?? 0,
        ease: (j['ef'] as num?)?.toDouble() ?? defaultEase,
        reps: (j['reps'] as num?)?.toInt() ?? 0,
        lapses: (j['lapses'] as num?)?.toInt() ?? 0,
        last: j['last'] as String? ?? '0000-00-00',
      );
}
