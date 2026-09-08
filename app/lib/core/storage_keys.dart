/// Preference keys.
///
/// These deliberately keep the web app's `dutch5k-` prefix so a future import
/// path from an exported web backup stays a one-to-one mapping
/// (BUILD-SPEC 10.2).
library;

class PrefKeys {
  const PrefKeys._();

  static const String plan = 'dutch5k-plan';
  static const String wordGoal = 'dutch5k-wordgoal';
  static const String goalMode = 'dutch5k-goalmode';
  static const String goalSources = 'dutch5k-goalsources';
  static const String remindOn = 'dutch5k-remind';
  static const String remindTime = 'dutch5k-remindtime';
  static const String theme = 'dutch5k-theme';
  static const String lang = 'dutch5k-lang';
  static const String shuffle = 'dutch5k-shuffle';
  static const String newOnly = 'dutch5k-newonly';
  static const String mode = 'dutch5k-mode';
  static const String deviceId = 'dutch5k-device';

  /// Milliseconds-since-epoch of the last successful push to Firestore.
  static const String lastSyncedAt = 'dutch5k-lastsync';

  /// Set when local study data has changed since the last successful push.
  static const String syncDirty = 'dutch5k-syncdirty';

  /// Downloaded content-pack version per language, keyed `<prefix><lang>`.
  static const String packVersionPrefix = 'dutch5k-packver-';
}
