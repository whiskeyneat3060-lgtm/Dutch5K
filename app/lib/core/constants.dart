/// Literal constants ported from the web build. Every value here is verbatim
/// from BUILD-SPEC; changing one changes app behaviour or user-visible counts.
library;

/// Free-plan caps per source (BUILD-SPEC 7.4). Produces exactly 850 free ids
/// against the shipped deck.
const Map<String, int> kFreeLimits = <String, int>{
  'essential': 150,
  'general': 500,
  'gang': 200,
  'actie': 0,
  'niveau': 0,
  'perfectie': 0,
};

/// Canonical source order used by the donut, legends and stacked bars.
const List<String> kSrcOrder = <String>[
  'essential',
  'general',
  'gang',
  'actie',
  'niveau',
  'perfectie',
];

/// Short display labels. Note the *en dash* — the filter dropdown uses an arrow
/// form instead (BUILD-SPEC 12.3.1, preserved deliberately).
const Map<String, String> kSrcShort = <String, String>{
  'essential': 'Essential',
  'general': 'General',
  'gang': 'A0–A2',
  'actie': 'A2–B1',
  'niveau': 'B1–B2',
  'perfectie': 'B2–C1',
};

/// Arrow-form labels used by the source filter dropdown.
const Map<String, String> kSrcFilterLabel = <String, String>{
  'essential': 'Essential',
  'general': 'General 5K',
  'gang': 'A0 → A2',
  'actie': 'A2 → B1',
  'niveau': 'B1 → B2',
  'perfectie': 'B2 → C1',
};

/// One-or-two character badge shown on word rows. `general` gets no badge.
const Map<String, String> kSrcBadge = <String, String>{
  'essential': '★',
  'gang': 'A2',
  'actie': 'B1',
  'niveau': 'B2',
  'perfectie': 'C1',
};

/// Book sources in the order `primarySource` resolves them (BUILD-SPEC 7.3).
const List<String> kBookSources = <String>['gang', 'actie', 'niveau', 'perfectie'];

/// Part-of-speech filter options, minus the leading "all".
const List<String> kPosFilter = <String>[
  'verb',
  'noun',
  'adjective',
  'adverb',
  'pronoun',
  'preposition',
  'conjunction',
  'number',
  'expression',
];

/// Display labels for parts of speech.
const Map<String, String> kPosLabels = <String, String>{
  'verb': 'Verbs',
  'noun': 'Nouns',
  'adjective': 'Adjectives',
  'adverb': 'Adverbs',
  'pronoun': 'Pronouns',
  'preposition': 'Prepositions',
  'conjunction': 'Conjunctions',
  'number': 'Numbers',
  'expression': 'Expressions',
  'article': 'Articles',
};

/// Row order for the "By word type" breakdown.
const List<String> kPosBreakdownOrder = <String>[
  'verb',
  'noun',
  'adjective',
  'adverb',
  'pronoun',
  'preposition',
  'conjunction',
  'number',
  'expression',
  'article',
];

/// Word-count goal presets. Rendered compactly (1000 -> "1K").
const List<int> kGoalPresets = <int>[500, 1000, 3000, 5000];

/// Words-per-day presets in the study plan.
const List<int> kPlanPresets = <int>[5, 10, 15, 20, 30];

/// Initial Words-list page size, and the increment added by "Show more".
const int kListLimitInitial = 100;
const int kListLimitIncrement = 300;

/// Toast visibility, matching the web app's 2600 ms.
const Duration kToastDuration = Duration(milliseconds: 2600);

/// Card flip timings (BUILD-SPEC 8.2).
const Duration kFlipOutDuration = Duration(milliseconds: 150);
const Duration kFlipInDuration = Duration(milliseconds: 200);

/// Default reminder time.
const String kDefaultRemindTime = '19:00';

/// Supported app languages. `en` needs no dictionary or content pack.
class AppLanguage {
  const AppLanguage(this.id, this.name, this.code);
  final String id;
  final String name;
  final String code;
}

const List<AppLanguage> kLanguages = <AppLanguage>[
  AppLanguage('en', 'English', 'EN'),
  AppLanguage('fr', 'Français', 'FR'),
  AppLanguage('it', 'Italiano', 'IT'),
  AppLanguage('es', 'Español', 'ES'),
  AppLanguage('de', 'Deutsch', 'DE'),
  AppLanguage('pt', 'Português', 'PT'),
  AppLanguage('pl', 'Polski', 'PL'),
  AppLanguage('tr', 'Türkçe', 'TR'),
  AppLanguage('uk', 'Українська', 'UK'),
  AppLanguage('ru', 'Русский', 'RU'),
  AppLanguage('bg', 'Български', 'BG'),
];

/// Generic contact-form subject categories.
const List<String> kContactSubjects = <String>[
  'General feedback',
  'Report a problem',
  'Word or translation error',
  'Feature request',
  'Question',
  'Other',
];

/// Store product id for the Pro entitlement. Must match App Store Connect and
/// the Play Console product configuration.
const String kProProductId = 'dutch_to_go_pro';
