import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/i18n/content_pack_repository.dart';
import '../data/i18n/ui_strings.dart';
import '../data/settings_store.dart';
import '../models/enums.dart';
import '../models/study_plan.dart';
import '../services/notification_service.dart';
import 'app_state.dart';
import 'providers.dart';

/// Owns every persisted preference and writes each change straight through.
class SettingsController extends StateNotifier<SettingsState> {
  SettingsController(this._ref, SettingsStore store)
      : _store = store,
        super(SettingsState(
          theme: store.theme,
          language: store.language,
          studyMode: store.studyMode,
          shuffle: store.shuffle,
          newOnly: store.newOnly,
          remindOn: store.remindOn,
          remindTime: store.remindTime,
          wordGoal: store.wordGoal,
          goalMode: store.goalMode,
          goalSources: store.goalSources,
          plan: store.plan,
        ));

  final Ref _ref;
  final SettingsStore _store;

  Future<void> setTheme(AppThemeId v) async {
    state = state.copyWith(theme: v);
    await _store.setTheme(v);
  }

  /// Switches the app language, downloading the content pack if needed.
  ///
  /// The language only changes once the pack is available, so a failed
  /// download leaves the user on their previous language instead of silently
  /// degrading every meaning to English.
  Future<String?> setLanguage(String id) async {
    final UiStrings ui = _ref.read(uiStringsProvider);
    final ContentPackRepository packs = _ref.read(contentPackProvider);

    if (id == 'en') {
      await packs.activate('en');
      ui.language = 'en';
      state = state.copyWith(language: 'en');
      await _store.setLanguage('en');
      return null;
    }

    state = state.copyWith(packDownloading: true);
    try {
      await packs.activate(id);
      ui.language = id;
      state = state.copyWith(language: id, packDownloading: false);
      await _store.setLanguage(id);
      return null;
    } on ContentPackException catch (e) {
      state = state.copyWith(packDownloading: false);
      return e.message;
    } catch (_) {
      state = state.copyWith(packDownloading: false);
      return 'Could not switch language — check your connection and try again.';
    }
  }

  Future<void> setStudyMode(StudyMode v) async {
    state = state.copyWith(studyMode: v);
    await _store.setStudyMode(v);
  }

  Future<void> setShuffle(bool v) async {
    state = state.copyWith(shuffle: v);
    await _store.setShuffle(v);
  }

  Future<void> setNewOnly(bool v) async {
    state = state.copyWith(newOnly: v);
    await _store.setNewOnly(v);
  }

  Future<void> setWordGoal(int? v) async {
    state = state.copyWith(wordGoal: v, clearWordGoal: v == null);
    await _store.setWordGoal(v);
  }

  Future<void> setGoalMode(GoalMode v) async {
    state = state.copyWith(goalMode: v);
    await _store.setGoalMode(v);
  }

  Future<void> toggleGoalSource(String src) async {
    final List<String> next = List<String>.of(state.goalSources);
    next.contains(src) ? next.remove(src) : next.add(src);
    state = state.copyWith(goalSources: next);
    await _store.setGoalSources(next);
  }

  Future<void> setPlan(StudyPlan? v) async {
    state = state.copyWith(plan: v, clearPlan: v == null);
    await _store.setPlan(v);
  }

  /// Turns reminders on, requesting permission first. Returns an error message
  /// when permission was refused, so the caller can leave the toggle off.
  Future<String?> enableReminders() async {
    final NotificationService n = _ref.read(notificationsProvider);
    final bool granted = await n.requestPermission();
    if (!granted) return 'Reminder permission denied';
    state = state.copyWith(remindOn: true);
    await _store.setRemindOn(true);
    await rescheduleReminder();
    return null;
  }

  Future<void> disableReminders() async {
    state = state.copyWith(remindOn: false);
    await _store.setRemindOn(false);
    await _ref.read(notificationsProvider).cancel();
  }

  Future<void> setRemindTime(String hhmm) async {
    if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(hhmm)) return;
    state = state.copyWith(remindTime: hhmm);
    await _store.setRemindTime(hhmm);
    await rescheduleReminder();
  }

  /// (Re)arms the daily notification from the current setting.
  Future<void> rescheduleReminder() async {
    final NotificationService n = _ref.read(notificationsProvider);
    if (!state.remindOn) {
      await n.cancel();
      return;
    }
    final List<String> parts = state.remindTime.split(':');
    final UiStrings t = _ref.read(uiStringsProvider);
    await n.scheduleDaily(
      hour: int.tryParse(parts[0]) ?? 19,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      title: 'Dutch To Go',
      body: t("Time for today's words! Keep your streak going."),
    );
  }
}

final StateNotifierProvider<SettingsController, SettingsState> settingsProvider =
    StateNotifierProvider<SettingsController, SettingsState>(
  (Ref ref) => SettingsController(ref, ref.watch(settingsStoreProvider)),
);
