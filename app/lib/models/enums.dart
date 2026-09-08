/// Word status. Mirrors the web app's `progress[id]` values.
///
/// The web app *deletes* the key when a word is graded "again", so absence of a
/// record means [WordStatus.fresh]. We keep that shape: the local DB deletes rows.
enum WordStatus { fresh, learning, learned }

extension WordStatusX on WordStatus {
  /// The exact wire value used by the web app and by the sync documents.
  String get wire => switch (this) {
        WordStatus.fresh => 'new',
        WordStatus.learning => 'learning',
        WordStatus.learned => 'learned',
      };

  static WordStatus fromWire(String? v) => switch (v) {
        'learning' => WordStatus.learning,
        'learned' => WordStatus.learned,
        _ => WordStatus.fresh,
      };
}

/// The grade a user gives a card. The integer values feed the SM-2-lite
/// scheduler directly (BUILD-SPEC 7.6).
enum Grade {
  again(0),
  learning(1),
  knowIt(2),
  easy(3);

  const Grade(this.value);
  final int value;

  /// The status a grade implies. `again` clears the record entirely.
  WordStatus get status => switch (this) {
        Grade.again => WordStatus.fresh,
        Grade.learning => WordStatus.learning,
        Grade.knowIt || Grade.easy => WordStatus.learned,
      };
}

/// The six study modes (BUILD-SPEC 2.1.4).
enum StudyMode {
  cards('cards', 'Cards', '\u{1F4C4}'),
  reverse('reverse', 'Reverse', '\u{1F504}'),
  type('type', 'Type', '\u{2328}'),
  listen('listen', 'Listen', '\u{1F50A}'),
  cloze('cloze', 'Cloze', '\u{2702}'),
  dehet('dehet', 'de / het', '\u{1F1F3}\u{1F1F1}');

  const StudyMode(this.id, this.label, this.icon);
  final String id;

  /// English label. `dehet` is Dutch and is never translated.
  final String label;
  final String icon;

  bool get isRecognition =>
      this == StudyMode.cards || this == StudyMode.reverse || this == StudyMode.listen;
  bool get isTyping => this == StudyMode.type || this == StudyMode.cloze;

  static StudyMode fromId(String? id) =>
      StudyMode.values.firstWhere((m) => m.id == id, orElse: () => StudyMode.cards);
}

/// Learning-goal type (BUILD-SPEC 7.10).
enum GoalMode {
  count('count'),
  source('source');

  const GoalMode(this.id);
  final String id;

  static GoalMode fromId(String? id) => id == 'source' ? GoalMode.source : GoalMode.count;
}

/// Visual theme. `minimalistic` is the default (BUILD-SPEC 3.2).
enum AppThemeId {
  minimalistic('minimalistic', 'Minimalistic'),
  midnight('midnight', 'Midnight'),
  sepia('sepia', 'Sepia');

  const AppThemeId(this.id, this.displayName);
  final String id;
  final String displayName;

  static AppThemeId fromId(String? id) =>
      AppThemeId.values.firstWhere((t) => t.id == id, orElse: () => AppThemeId.minimalistic);
}
