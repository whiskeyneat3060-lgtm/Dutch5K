import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase/sync_repository.dart';
import '../data/local_db.dart';
import '../data/settings_store.dart';
import '../domain/counts.dart';
import '../domain/dates.dart';
import '../domain/free_plan.dart';
import '../domain/queue_builder.dart';
import '../domain/srs.dart';
import '../domain/streak_logic.dart';
import '../domain/study_state.dart';
import '../models/deck_entry.dart';
import '../models/enums.dart';
import '../models/srs_record.dart';
import '../models/streak.dart';
import 'app_state.dart';
import 'providers.dart';
import 'settings_controller.dart';

/// The live Learn session.
class StudySession {
  const StudySession({
    required this.queue,
    required this.position,
    required this.flipped,
    required this.result,
    required this.filters,
  });

  /// Deck indices, in study order.
  final List<int> queue;
  final int position;
  final bool flipped;
  final ObjectiveResult? result;
  final LearnFilters filters;

  int? get currentIndex =>
      (position >= 0 && position < queue.length) ? queue[position] : null;
  bool get isEmpty => queue.isEmpty;

  StudySession copyWith({
    List<int>? queue,
    int? position,
    bool? flipped,
    ObjectiveResult? result,
    bool clearResult = false,
    LearnFilters? filters,
  }) =>
      StudySession(
        queue: queue ?? this.queue,
        position: position ?? this.position,
        flipped: flipped ?? this.flipped,
        result: clearResult ? null : (result ?? this.result),
        filters: filters ?? this.filters,
      );
}

/// Owns the study record and the Learn queue.
///
/// Every grade writes to SQLite immediately — studying never waits on the
/// network — and marks the state dirty so a debounced background push mirrors
/// it to Firestore.
class StudyController extends StateNotifier<StudySession> {
  StudyController(this._ref)
      : super(const StudySession(
          queue: <int>[],
          position: 0,
          flipped: false,
          result: null,
          filters: LearnFilters(),
        ));

  final Ref _ref;

  late final Deck _deck = _ref.read(deckProvider);
  late final LocalDb _db = _ref.read(localDbProvider);
  late final SettingsStore _settingsStore = _ref.read(settingsStoreProvider);

  StudyState _study = StudyState();
  StreakData _streak = const StreakData();
  Set<String> _freeIds = <String>{};
  final Set<int> _skipped = <int>{};
  Timer? _syncDebounce;

  StudyState get study => _study;
  StreakData get streak => _streak;
  Set<String> get freeIds => _freeIds;

  /// Bumped whenever counts change without the queue changing, so stats-only
  /// widgets can rebuild without the session object being replaced.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  Future<void> load() async {
    _study = await _db.loadStudyState();
    _streak = await _db.loadStreak();
    _freeIds = FreePlan.computeFreeIds(_deck.entries);
    rebuildQueue();
  }

  // ------------------------------------------------------------- queueing ---

  void rebuildQueue() {
    final SettingsState s = _ref.read(settingsProvider);
    final List<int> queue = QueueBuilder.build(QueueRequest(
      deck: _deck,
      state: _study,
      mode: s.studyMode,
      today: todayStr(),
      posFilter: state.filters.pos,
      sourceFilter: state.filters.source,
      shuffle: s.shuffle,
      newOnly: s.newOnly,
      leechOnly: state.filters.leechOnly,
      isPro: _ref.read(isProProvider),
      freeIds: _freeIds,
      skipped: _skipped,
    ));
    state = state.copyWith(
      queue: queue,
      position: 0,
      flipped: false,
      clearResult: true,
    );
  }

  void setFilters(LearnFilters f) {
    _skipped.clear();
    state = state.copyWith(filters: f);
    rebuildQueue();
  }

  void flip() => state = state.copyWith(flipped: !state.flipped, clearResult: true);

  void setResult(ObjectiveResult r) => state = state.copyWith(result: r);

  /// Pushes the current card to the back of the queue for this session.
  void skip() {
    final int? idx = state.currentIndex;
    if (idx == null) return;
    _skipped.add(idx);
    final List<int> q = List<int>.of(state.queue)..removeAt(state.position);
    q.add(idx);
    state = state.copyWith(
      queue: q,
      position: state.position >= q.length ? 0 : state.position,
      flipped: false,
      clearResult: true,
    );
  }

  /// Enters the hardest-words drill.
  Future<void> startLeechDrill() async {
    await _ref.read(settingsProvider.notifier).setNewOnly(false);
    await _ref.read(settingsProvider.notifier).setStudyMode(StudyMode.cards);
    _skipped.clear();
    state = state.copyWith(filters: state.filters.copyWith(leechOnly: true));
    rebuildQueue();
  }

  void exitLeechDrill() {
    _skipped.clear();
    state = state.copyWith(filters: state.filters.copyWith(leechOnly: false));
    rebuildQueue();
  }

  /// Starts a review session: reviews only, in a mode that can show any word.
  Future<void> startReview() async {
    final SettingsController sc = _ref.read(settingsProvider.notifier);
    await sc.setNewOnly(false);
    final StudyMode m = _ref.read(settingsProvider).studyMode;
    if (m == StudyMode.dehet || m == StudyMode.cloze) {
      await sc.setStudyMode(StudyMode.cards);
    }
    _skipped.clear();
    state = state.copyWith(filters: state.filters.copyWith(leechOnly: false));
    rebuildQueue();
  }

  // -------------------------------------------------------------- grading ---

  /// Grades the current card and advances.
  Future<void> gradeCurrent(Grade grade) async {
    final int? idx = state.currentIndex;
    if (idx == null) return;
    await _grade(_deck[idx].id, grade, advance: true);
  }

  /// Grades a word from the Words detail card, staying where the user is.
  Future<void> gradeWord(String id, Grade grade) =>
      _grade(id, grade, advance: false);

  Future<void> _grade(String id, Grade grade, {required bool advance}) async {
    final String today = todayStr();
    final WordStatus previous = _study.statusOf(id);
    final WordStatus next = grade.status;

    final SrsRecord updated = Srs.schedule(
      existing: _study.srsOf(id),
      grade: grade.value,
      today: today,
    );

    if (next == WordStatus.fresh) {
      _study.progress.remove(id);
    } else {
      _study.progress[id] = next;
    }
    _study.srs[id] = updated;

    await _db.upsertGrade(id: id, status: next, srs: updated);

    // Only a *newly* learned word counts toward the streak, so re-grading an
    // already-learned word never inflates today's total.
    bool goalJustReached = false;
    if (next == WordStatus.learned && previous != WordStatus.learned) {
      final int before = _streak.countFor(today);
      _streak = StreakLogic.recordLearned(_streak, today);
      await _db.saveStreak(_streak);

      // The first word of the day means the reminder is no longer needed.
      if (before == 0) {
        unawaited(_ref.read(notificationsProvider).cancel());
      }
      final int perDay = _ref.read(settingsProvider).plan?.perDay ?? 0;
      goalJustReached = perDay > 0 && _streak.countFor(today) == perDay;
    }

    if (advance) {
      final int p = state.position + 1;
      if (p >= state.queue.length) {
        rebuildQueue();
      } else {
        state = state.copyWith(position: p, flipped: false, clearResult: true);
      }
    } else {
      rebuildQueue();
    }

    revision.value++;
    _markDirty();
    if (goalJustReached) _goalReached.value = DateTime.now();
  }

  /// Pulses when the daily goal is reached, so the UI can celebrate once.
  final ValueNotifier<DateTime?> _goalReached = ValueNotifier<DateTime?>(null);
  ValueListenable<DateTime?> get goalReached => _goalReached;

  // ----------------------------------------------------------------- sync ---

  void _markDirty() {
    unawaited(_settingsStore.setSyncDirty(true));
    _syncDebounce?.cancel();
    // Batch a burst of grading into one write rather than one per card.
    _syncDebounce = Timer(const Duration(seconds: 20), () => unawaited(pushSync()));
  }

  /// Mirrors local state to Firestore. Safe to call when signed out (no-op).
  Future<void> pushSync() async {
    final String? uid = _ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    try {
      await _ref.read(syncRepositoryProvider).push(
            uid: uid,
            state: _study,
            streak: _streak,
            deviceId: _settingsStore.deviceId,
          );
      await _settingsStore.setSyncDirty(false);
      await _settingsStore.setLastSyncedAt(DateTime.now());
    } catch (_) {
      // Stay dirty and retry on the next trigger; local data is untouched.
    }
  }

  /// Pulls the cloud snapshot and merges it into local state. Called after
  /// sign-in so a reinstall or a second device recovers progress.
  Future<void> pullAndMerge() async {
    final String? uid = _ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    try {
      final RemoteSnapshot? remote = await _ref.read(syncRepositoryProvider).pull(uid);
      if (remote == null) {
        // Nothing in the cloud yet: seed it from this device.
        await pushSync();
        return;
      }
      final ({StudyState state, StreakData streak}) merged = SyncRepository.merge(
        local: _study,
        localStreak: _streak,
        remote: remote,
      );
      _study = merged.state;
      _streak = merged.streak;
      await _db.replaceAll(state: _study, streak: _streak);
      rebuildQueue();
      revision.value++;
      await pushSync();
    } catch (_) {
      // Keep local data; the next sync attempt will retry.
    }
  }

  /// Clears device study data. Offered explicitly on sign-out.
  Future<void> clearLocal() async {
    await _db.clearAll();
    _study = StudyState();
    _streak = const StreakData();
    _skipped.clear();
    rebuildQueue();
    revision.value++;
  }

  // ------------------------------------------------------------- readouts ---

  DeckCounts get counts => DeckCounts.of(_deck, _study);
  int get dueCount => QueueBuilder.dueCount(_deck, _study, todayStr());
  List<int> get leeches => QueueBuilder.leeches(_deck, _study);
  int get todayCount => _streak.countFor(todayStr());
  int get currentStreak => StreakLogic.current(_streak, todayStr());

  WordStatus statusOf(String id) => _study.statusOf(id);
  SrsRecord? srsOf(String id) => _study.srsOf(id);
  bool isLocked(DeckEntry e) =>
      !_ref.read(isProProvider) && !_freeIds.contains(e.id);

  @override
  void dispose() {
    _syncDebounce?.cancel();
    _goalReached.dispose();
    revision.dispose();
    super.dispose();
  }
}

final StateNotifierProvider<StudyController, StudySession> studyProvider =
    StateNotifierProvider<StudyController, StudySession>(
  (Ref ref) => StudyController(ref),
);
