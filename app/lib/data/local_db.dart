import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/enums.dart';
import '../models/srs_record.dart';
import '../models/streak.dart';
import '../domain/study_state.dart';

/// On-device SQLite store — the source of truth for study data.
///
/// Studying never waits on the network: every grade is a local write, and a
/// background job pushes the whole state to Firestore as a handful of chunked
/// documents (see [SyncRepository]). Progress rows mirror the web app's shape:
/// a word graded "again" has its row **deleted**, so absence means fresh.
class LocalDb {
  LocalDb._(this._db);

  final Database _db;

  static const int _schemaVersion = 1;
  static const String _tProgress = 'progress';
  static const String _tSrs = 'srs';
  static const String _tStreakDay = 'streak_day';
  static const String _tMeta = 'meta';

  static Future<LocalDb> open({String? path}) async {
    final String dbPath = path ?? p.join(await getDatabasesPath(), 'dutch_to_go.db');
    final Database db = await openDatabase(
      dbPath,
      version: _schemaVersion,
      onCreate: (Database db, int _) async {
        final Batch b = db.batch();
        b.execute('CREATE TABLE $_tProgress ('
            'id TEXT PRIMARY KEY NOT NULL, '
            'status TEXT NOT NULL)');
        b.execute('CREATE TABLE $_tSrs ('
            'id TEXT PRIMARY KEY NOT NULL, '
            'due TEXT NOT NULL, '
            'iv INTEGER NOT NULL, '
            'ef REAL NOT NULL, '
            'reps INTEGER NOT NULL, '
            'lapses INTEGER NOT NULL, '
            'last TEXT NOT NULL)');
        b.execute('CREATE INDEX idx_srs_due ON $_tSrs(due)');
        b.execute('CREATE TABLE $_tStreakDay ('
            'day TEXT PRIMARY KEY NOT NULL, '
            'count INTEGER NOT NULL)');
        b.execute('CREATE TABLE $_tMeta ('
            'key TEXT PRIMARY KEY NOT NULL, '
            'value TEXT)');
        await b.commit(noResult: true);
      },
    );
    return LocalDb._(db);
  }

  Future<void> close() => _db.close();

  // ---------------------------------------------------------------- read ---

  /// Loads the entire study state in three queries. At full size this is
  /// ~6,752 progress rows and the same number of SRS rows — small enough to
  /// hold in memory, which keeps every filter and count synchronous.
  Future<StudyState> loadStudyState() async {
    final List<Map<String, Object?>> prog = await _db.query(_tProgress);
    final List<Map<String, Object?>> srs = await _db.query(_tSrs);
    return StudyState(
      progress: <String, WordStatus>{
        for (final Map<String, Object?> r in prog)
          r['id']! as String: WordStatusX.fromWire(r['status'] as String?),
      },
      srs: <String, SrsRecord>{
        for (final Map<String, Object?> r in srs) r['id']! as String: _srsFromRow(r),
      },
    );
  }

  Future<StreakData> loadStreak() async {
    final List<Map<String, Object?>> days = await _db.query(_tStreakDay);
    final Map<String, String?> meta = await _loadMeta();
    return StreakData(
      count: int.tryParse(meta['streak_count'] ?? '') ?? 0,
      lastStudied: meta['streak_last'],
      history: <String, int>{
        for (final Map<String, Object?> r in days)
          r['day']! as String: (r['count']! as int),
      },
    );
  }

  Future<Map<String, String?>> _loadMeta() async {
    final List<Map<String, Object?>> rows = await _db.query(_tMeta);
    return <String, String?>{
      for (final Map<String, Object?> r in rows) r['key']! as String: r['value'] as String?,
    };
  }

  static SrsRecord _srsFromRow(Map<String, Object?> r) => SrsRecord(
        due: r['due']! as String,
        interval: r['iv']! as int,
        ease: (r['ef']! as num).toDouble(),
        reps: r['reps']! as int,
        lapses: r['lapses']! as int,
        last: r['last']! as String,
      );

  // --------------------------------------------------------------- write ---

  /// Persists one graded word. `status == null` deletes the progress row,
  /// matching the web app's "again clears the record" behaviour.
  Future<void> upsertGrade({
    required String id,
    required WordStatus status,
    required SrsRecord srs,
  }) async {
    final Batch b = _db.batch();
    if (status == WordStatus.fresh) {
      b.delete(_tProgress, where: 'id = ?', whereArgs: <Object?>[id]);
    } else {
      b.insert(
        _tProgress,
        <String, Object?>{'id': id, 'status': status.wire},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    b.insert(
      _tSrs,
      <String, Object?>{'id': id, ...srs.toJson()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await b.commit(noResult: true);
  }

  Future<void> saveStreak(StreakData s) async {
    final Batch b = _db.batch();
    b.insert(_tMeta, <String, Object?>{'key': 'streak_count', 'value': '${s.count}'},
        conflictAlgorithm: ConflictAlgorithm.replace);
    b.insert(_tMeta, <String, Object?>{'key': 'streak_last', 'value': s.lastStudied},
        conflictAlgorithm: ConflictAlgorithm.replace);
    s.history.forEach((String day, int count) {
      b.insert(_tStreakDay, <String, Object?>{'day': day, 'count': count},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
    await b.commit(noResult: true);
  }

  /// Replaces the entire local study state — used when a remote snapshot wins
  /// during sync, and when restoring on a fresh install after sign-in.
  Future<void> replaceAll({
    required StudyState state,
    required StreakData streak,
  }) async {
    await _db.transaction((Transaction txn) async {
      await txn.delete(_tProgress);
      await txn.delete(_tSrs);
      await txn.delete(_tStreakDay);
      final Batch b = txn.batch();
      state.progress.forEach((String id, WordStatus s) {
        if (s == WordStatus.fresh) return;
        b.insert(_tProgress, <String, Object?>{'id': id, 'status': s.wire});
      });
      state.srs.forEach((String id, SrsRecord r) {
        b.insert(_tSrs, <String, Object?>{'id': id, ...r.toJson()});
      });
      streak.history.forEach((String day, int count) {
        b.insert(_tStreakDay, <String, Object?>{'day': day, 'count': count});
      });
      b.insert(_tMeta, <String, Object?>{'key': 'streak_count', 'value': '${streak.count}'},
          conflictAlgorithm: ConflictAlgorithm.replace);
      b.insert(_tMeta, <String, Object?>{'key': 'streak_last', 'value': streak.lastStudied},
          conflictAlgorithm: ConflictAlgorithm.replace);
      await b.commit(noResult: true);
    });
  }

  /// Wipes study data. Used on sign-out when the user chooses to leave no trace
  /// on a shared device; the default sign-out keeps data (BUILD-SPEC 7.14).
  Future<void> clearAll() async {
    await _db.transaction((Transaction txn) async {
      await txn.delete(_tProgress);
      await txn.delete(_tSrs);
      await txn.delete(_tStreakDay);
      await txn.delete(_tMeta);
    });
  }
}
