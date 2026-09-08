import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/study_state.dart';
import '../../models/enums.dart';
import '../../models/srs_record.dart';
import '../../models/streak.dart';

/// Result of a pull, so the caller can decide whether to adopt it.
class RemoteSnapshot {
  const RemoteSnapshot({
    required this.state,
    required this.streak,
    required this.updatedAt,
    required this.deviceId,
  });
  final StudyState state;
  final StreakData streak;
  final DateTime? updatedAt;
  final String? deviceId;
}

/// Cloud sync for study data.
///
/// Firestore charges and rate-limits per document, and a user can have up to
/// 6,752 word states. Writing one document per word would mean thousands of
/// reads on first sync and a write storm during a study session, so progress
/// and SRS are packed into **chunked documents** of [chunkSize] words each —
/// seven documents at full deck size.
///
/// Local SQLite stays the source of truth while studying; this pushes a
/// debounced snapshot and pulls on sign-in. Conflicts resolve last-write-wins
/// on the whole snapshot, compared by the server-set `updatedAt`.
class SyncRepository {
  SyncRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Words per sync document. 1,000 keeps each document far below Firestore's
  /// 1 MiB limit (a full chunk serialises to roughly 120 KB).
  static const int chunkSize = 1000;

  CollectionReference<Map<String, dynamic>> _chunks(String uid) =>
      _db.collection('users').doc(uid).collection('progressChunks');

  DocumentReference<Map<String, dynamic>> _meta(String uid) =>
      _db.collection('users').doc(uid).collection('study').doc('meta');

  // ---------------------------------------------------------------- push ---

  /// Writes the whole study state. Chunk membership is derived from a stable
  /// hash of the word id, so a given word always lands in the same chunk and
  /// unchanged chunks produce identical payloads.
  Future<void> push({
    required String uid,
    required StudyState state,
    required StreakData streak,
    required String deviceId,
  }) async {
    final Map<int, Map<String, dynamic>> buckets = <int, Map<String, dynamic>>{};

    state.progress.forEach((String id, WordStatus status) {
      if (status == WordStatus.fresh) return;
      final Map<String, dynamic> bucket =
          buckets.putIfAbsent(chunkFor(id), () => <String, dynamic>{});
      (bucket[id] ??= <String, dynamic>{})['s'] = status.wire;
    });
    state.srs.forEach((String id, SrsRecord r) {
      final Map<String, dynamic> bucket =
          buckets.putIfAbsent(chunkFor(id), () => <String, dynamic>{});
      (bucket[id] ??= <String, dynamic>{})['r'] = r.toJson();
    });

    // One batch: all chunks plus the meta document commit atomically.
    final WriteBatch batch = _db.batch();
    final int chunkCount = (state.progress.length + state.srs.length) == 0 ? 0 : _maxChunks;
    for (int i = 0; i < chunkCount; i++) {
      final Map<String, dynamic> words = buckets[i] ?? <String, dynamic>{};
      batch.set(
        _chunks(uid).doc('c$i'),
        <String, dynamic>{
          'words': words,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    }
    batch.set(
      _meta(uid),
      <String, dynamic>{
        'streak': streak.toJson(),
        'chunkCount': chunkCount,
        'deviceId': deviceId,
        'updatedAt': FieldValue.serverTimestamp(),
        'schemaVersion': 1,
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  // ---------------------------------------------------------------- pull ---

  /// Reads the remote snapshot, or null when the user has never synced.
  Future<RemoteSnapshot?> pull(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> meta = await _meta(uid).get();
    if (!meta.exists) return null;
    final Map<String, dynamic> m = meta.data() ?? <String, dynamic>{};

    final QuerySnapshot<Map<String, dynamic>> chunks = await _chunks(uid).get();
    final Map<String, WordStatus> progress = <String, WordStatus>{};
    final Map<String, SrsRecord> srs = <String, SrsRecord>{};

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in chunks.docs) {
      final Map<String, dynamic> words =
          (doc.data()['words'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      words.forEach((String id, dynamic raw) {
        final Map<String, dynamic> v = raw as Map<String, dynamic>;
        final String? s = v['s'] as String?;
        if (s != null) progress[id] = WordStatusX.fromWire(s);
        final Map<String, dynamic>? r = v['r'] as Map<String, dynamic>?;
        if (r != null) srs[id] = SrsRecord.fromJson(r);
      });
    }

    return RemoteSnapshot(
      state: StudyState(progress: progress, srs: srs),
      streak: StreakData.fromJson(
          (m['streak'] as Map<String, dynamic>?) ?? <String, dynamic>{}),
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
      deviceId: m['deviceId'] as String?,
    );
  }

  /// Merges a remote snapshot into local state without losing work done
  /// offline. Per word, the record with the later `last` grading date wins;
  /// ties keep the local copy. Streak history takes the higher count per day.
  static ({StudyState state, StreakData streak}) merge({
    required StudyState local,
    required StreakData localStreak,
    required RemoteSnapshot remote,
  }) {
    final Map<String, WordStatus> progress = Map<String, WordStatus>.of(local.progress);
    final Map<String, SrsRecord> srs = Map<String, SrsRecord>.of(local.srs);

    remote.state.srs.forEach((String id, SrsRecord remoteRec) {
      final SrsRecord? localRec = srs[id];
      final bool remoteWins =
          localRec == null || remoteRec.last.compareTo(localRec.last) > 0;
      if (remoteWins) {
        srs[id] = remoteRec;
        final WordStatus? rs = remote.state.progress[id];
        if (rs == null) {
          progress.remove(id);
        } else {
          progress[id] = rs;
        }
      }
    });

    // Remote words with a status but no SRS record (legacy or partial writes).
    remote.state.progress.forEach((String id, WordStatus s) {
      if (!srs.containsKey(id) && !progress.containsKey(id)) progress[id] = s;
    });

    final Map<String, int> history = Map<String, int>.of(localStreak.history);
    remote.streak.history.forEach((String day, int n) {
      final int cur = history[day] ?? 0;
      if (n > cur) history[day] = n;
    });

    final String? localLast = localStreak.lastStudied;
    final String? remoteLast = remote.streak.lastStudied;
    final String? lastStudied = (localLast == null)
        ? remoteLast
        : (remoteLast == null)
            ? localLast
            : (localLast.compareTo(remoteLast) >= 0 ? localLast : remoteLast);

    return (
      state: StudyState(progress: progress, srs: srs),
      streak: StreakData(
        count: localStreak.count > remote.streak.count
            ? localStreak.count
            : remote.streak.count,
        lastStudied: lastStudied,
        history: history,
      ),
    );
  }

  /// Deterministic chunk index for a word id.
  @visibleForTesting
  static int chunkFor(String id) {
    // FNV-1a 32-bit: stable across platforms and Dart versions, unlike
    // String.hashCode which is not guaranteed to be consistent.
    int hash = 0x811c9dc5;
    for (final int byte in utf8.encode(id)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash % _maxChunks;
  }

  /// Enough chunks for the full deck at [chunkSize] words each.
  static const int _maxChunks = 8;
  @visibleForTesting
  static int get maxChunks => _maxChunks;
}
