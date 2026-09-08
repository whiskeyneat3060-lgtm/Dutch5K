import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../core/storage_keys.dart';
import '../models/enums.dart';
import '../models/study_plan.dart';

/// All user settings, loaded once at startup and written through on change.
///
/// Every getter falls back to a documented default, so a missing or malformed
/// value reads as a fresh install and never throws (BUILD-SPEC 6.2).
class SettingsStore {
  SettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<SettingsStore> create() async =>
      SettingsStore(await SharedPreferences.getInstance());

  // ------------------------------------------------------------- reading ---

  AppThemeId get theme => AppThemeId.fromId(_prefs.getString(PrefKeys.theme));
  String get language {
    final String id = _prefs.getString(PrefKeys.lang) ?? 'en';
    return kLanguages.any((AppLanguage l) => l.id == id) ? id : 'en';
  }

  StudyMode get studyMode => StudyMode.fromId(_prefs.getString(PrefKeys.mode));
  bool get shuffle => _prefs.getBool(PrefKeys.shuffle) ?? false;
  bool get newOnly => _prefs.getBool(PrefKeys.newOnly) ?? false;
  bool get remindOn => _prefs.getBool(PrefKeys.remindOn) ?? false;

  String get remindTime {
    final String v = _prefs.getString(PrefKeys.remindTime) ?? kDefaultRemindTime;
    return RegExp(r'^\d{2}:\d{2}$').hasMatch(v) ? v : kDefaultRemindTime;
  }

  int? get wordGoal {
    final int? v = _prefs.getInt(PrefKeys.wordGoal);
    return (v != null && v > 0) ? v : null;
  }

  GoalMode get goalMode => GoalMode.fromId(_prefs.getString(PrefKeys.goalMode));
  List<String> get goalSources => _prefs.getStringList(PrefKeys.goalSources) ?? <String>[];

  StudyPlan? get plan {
    final String? raw = _prefs.getString(PrefKeys.plan);
    if (raw == null || raw.isEmpty) return null;
    try {
      return StudyPlan.fromJson(json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  bool get syncDirty => _prefs.getBool(PrefKeys.syncDirty) ?? false;
  DateTime? get lastSyncedAt {
    final int? ms = _prefs.getInt(PrefKeys.lastSyncedAt);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Stable per-install id, generated once. Used to label sync writes so a
  /// device can tell its own push apart from another device's.
  String get deviceId {
    final String? existing = _prefs.getString(PrefKeys.deviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final String id = 'd_${Random().nextInt(1 << 32).toRadixString(36)}'
        '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    _prefs.setString(PrefKeys.deviceId, id);
    return id;
  }

  /// Version tag of the content pack cached for [lang], or null.
  String? packVersion(String lang) =>
      _prefs.getString('${PrefKeys.packVersionPrefix}$lang');

  // ------------------------------------------------------------- writing ---

  Future<void> setTheme(AppThemeId v) => _prefs.setString(PrefKeys.theme, v.id);
  Future<void> setLanguage(String v) => _prefs.setString(PrefKeys.lang, v);
  Future<void> setStudyMode(StudyMode v) => _prefs.setString(PrefKeys.mode, v.id);
  Future<void> setShuffle(bool v) => _prefs.setBool(PrefKeys.shuffle, v);
  Future<void> setNewOnly(bool v) => _prefs.setBool(PrefKeys.newOnly, v);
  Future<void> setRemindOn(bool v) => _prefs.setBool(PrefKeys.remindOn, v);
  Future<void> setRemindTime(String v) => _prefs.setString(PrefKeys.remindTime, v);
  Future<void> setGoalMode(GoalMode v) => _prefs.setString(PrefKeys.goalMode, v.id);
  Future<void> setGoalSources(List<String> v) =>
      _prefs.setStringList(PrefKeys.goalSources, v);
  Future<void> setSyncDirty(bool v) => _prefs.setBool(PrefKeys.syncDirty, v);
  Future<void> setLastSyncedAt(DateTime v) =>
      _prefs.setInt(PrefKeys.lastSyncedAt, v.millisecondsSinceEpoch);
  Future<void> setPackVersion(String lang, String version) =>
      _prefs.setString('${PrefKeys.packVersionPrefix}$lang', version);

  Future<void> setWordGoal(int? v) async {
    if (v == null) {
      await _prefs.remove(PrefKeys.wordGoal);
    } else {
      await _prefs.setInt(PrefKeys.wordGoal, v);
    }
  }

  Future<void> setPlan(StudyPlan? v) async {
    if (v == null) {
      await _prefs.remove(PrefKeys.plan);
    } else {
      await _prefs.setString(PrefKeys.plan, json.encode(v.toJson()));
    }
  }
}
