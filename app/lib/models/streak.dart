/// Study streak plus the per-day learned counts that drive the 14-day grid.
class StreakData {
  const StreakData({
    this.count = 0,
    this.lastStudied,
    this.history = const <String, int>{},
  });

  /// Consecutive-day count as last recorded.
  final int count;

  /// `YYYY-MM-DD` of the most recent day a word was learned, or null.
  final String? lastStudied;

  /// `YYYY-MM-DD` -> words learned that day.
  final Map<String, int> history;

  int countFor(String day) => history[day] ?? 0;

  StreakData copyWith({
    int? count,
    String? lastStudied,
    bool clearLastStudied = false,
    Map<String, int>? history,
  }) =>
      StreakData(
        count: count ?? this.count,
        lastStudied: clearLastStudied ? null : (lastStudied ?? this.lastStudied),
        history: history ?? this.history,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'count': count,
        'lastStudied': lastStudied,
        'history': history,
      };

  factory StreakData.fromJson(Map<String, dynamic> j) => StreakData(
        count: (j['count'] as num?)?.toInt() ?? 0,
        lastStudied: j['lastStudied'] as String?,
        history: (j['history'] as Map<String, dynamic>? ?? <String, dynamic>{})
            .map((String k, dynamic v) => MapEntry<String, int>(k, (v as num).toInt())),
      );
}
