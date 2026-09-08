import '../models/enums.dart';
import '../models/srs_record.dart';

/// The user's study record: word status plus SRS scheduling, both keyed by
/// [DeckEntry.id]. Held in memory during a session and mirrored to SQLite.
class StudyState {
  StudyState({
    Map<String, WordStatus>? progress,
    Map<String, SrsRecord>? srs,
  })  : progress = progress ?? <String, WordStatus>{},
        srs = srs ?? <String, SrsRecord>{};

  /// Only `learning` and `learned` are stored; a word graded "again" has its
  /// entry removed, so absence means fresh.
  final Map<String, WordStatus> progress;
  final Map<String, SrsRecord> srs;

  WordStatus statusOf(String id) => progress[id] ?? WordStatus.fresh;
  SrsRecord? srsOf(String id) => srs[id];

  int get learnedCount =>
      progress.values.where((WordStatus s) => s == WordStatus.learned).length;
  int get learningCount =>
      progress.values.where((WordStatus s) => s == WordStatus.learning).length;
}
