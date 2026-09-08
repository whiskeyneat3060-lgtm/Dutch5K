/// A daily study plan: either a words-per-day pace or a target date.
class StudyPlan {
  const StudyPlan({required this.perDay, this.endDate, required this.startDate});

  /// Words per day. `0` when the plan is date-driven instead.
  final int perDay;

  /// `YYYY-MM-DD` target date, or null.
  final String? endDate;
  final String startDate;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'perDay': perDay,
        'endDate': endDate,
        'startDate': startDate,
      };

  factory StudyPlan.fromJson(Map<String, dynamic> j) => StudyPlan(
        perDay: (j['perDay'] as num?)?.toInt() ?? 0,
        endDate: j['endDate'] as String?,
        startDate: j['startDate'] as String? ?? '',
      );
}
