import '../models/enums.dart';
import '../models/study_plan.dart';

/// Everything the UI needs that is not the deck or the study record.
class SettingsState {
  const SettingsState({
    required this.theme,
    required this.language,
    required this.studyMode,
    required this.shuffle,
    required this.newOnly,
    required this.remindOn,
    required this.remindTime,
    required this.wordGoal,
    required this.goalMode,
    required this.goalSources,
    required this.plan,
    this.packDownloading = false,
  });

  final AppThemeId theme;
  final String language;
  final StudyMode studyMode;
  final bool shuffle;
  final bool newOnly;
  final bool remindOn;
  final String remindTime;
  final int? wordGoal;
  final GoalMode goalMode;
  final List<String> goalSources;
  final StudyPlan? plan;

  /// True while a content pack download is in flight.
  final bool packDownloading;

  SettingsState copyWith({
    AppThemeId? theme,
    String? language,
    StudyMode? studyMode,
    bool? shuffle,
    bool? newOnly,
    bool? remindOn,
    String? remindTime,
    int? wordGoal,
    bool clearWordGoal = false,
    GoalMode? goalMode,
    List<String>? goalSources,
    StudyPlan? plan,
    bool clearPlan = false,
    bool? packDownloading,
  }) =>
      SettingsState(
        theme: theme ?? this.theme,
        language: language ?? this.language,
        studyMode: studyMode ?? this.studyMode,
        shuffle: shuffle ?? this.shuffle,
        newOnly: newOnly ?? this.newOnly,
        remindOn: remindOn ?? this.remindOn,
        remindTime: remindTime ?? this.remindTime,
        wordGoal: clearWordGoal ? null : (wordGoal ?? this.wordGoal),
        goalMode: goalMode ?? this.goalMode,
        goalSources: goalSources ?? this.goalSources,
        plan: clearPlan ? null : (plan ?? this.plan),
        packDownloading: packDownloading ?? this.packDownloading,
      );
}

/// Learn-tab filters and session flags. None of these persist across launches
/// except the study mode, shuffle and new-only, matching the web build.
class LearnFilters {
  const LearnFilters({
    this.pos = const <String>[],
    this.source = const <String>[],
    this.leechOnly = false,
  });

  final List<String> pos;
  final List<String> source;
  final bool leechOnly;

  LearnFilters copyWith({
    List<String>? pos,
    List<String>? source,
    bool? leechOnly,
  }) =>
      LearnFilters(
        pos: pos ?? this.pos,
        source: source ?? this.source,
        leechOnly: leechOnly ?? this.leechOnly,
      );
}

/// Words-tab filters and search.
class WordsFilters {
  const WordsFilters({
    this.status = const <String>[],
    this.pos = const <String>[],
    this.source = const <String>[],
    this.query = '',
    this.limit = 100,
  });

  final List<String> status;
  final List<String> pos;
  final List<String> source;
  final String query;
  final int limit;

  WordsFilters copyWith({
    List<String>? status,
    List<String>? pos,
    List<String>? source,
    String? query,
    int? limit,
  }) =>
      WordsFilters(
        status: status ?? this.status,
        pos: pos ?? this.pos,
        source: source ?? this.source,
        query: query ?? this.query,
        limit: limit ?? this.limit,
      );
}

/// The result of an auto-graded answer, held until the user advances.
class ObjectiveResult {
  const ObjectiveResult({
    required this.correct,
    required this.given,
    required this.answer,
  });
  final bool correct;
  final String given;
  final String answer;
}
