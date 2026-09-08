import 'package:dutch_to_go/data/deck_repository.dart';
import 'package:dutch_to_go/data/i18n/ui_strings.dart';
import 'package:dutch_to_go/models/deck_entry.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the assets are actually declared in pubspec and readable through
/// rootBundle — a disk-path test would still pass if the declaration were
/// missing, and the app would then fail only at runtime.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the deck asset is bundled and parses to 6,752 entries', () async {
    final String raw = await rootBundle.loadString(DeckRepository.assetPath);
    final Deck deck = DeckRepository.parse(raw);
    expect(deck.length, 6752);
    expect(deck.byId['bereiken'], isNotNull);
  });

  test('the UI string asset is bundled with all 10 languages', () async {
    final String raw = await rootBundle.loadString(UiStrings.assetPath);
    final Map<String, Map<String, String>> dicts = UiStrings.parse(raw);
    expect(dicts.keys.toSet(),
        <String>{'fr', 'it', 'es', 'de', 'pt', 'pl', 'tr', 'uk', 'ru', 'bg'});
    for (final MapEntry<String, Map<String, String>> e in dicts.entries) {
      expect(e.value.length, 214, reason: '${e.key} should have 214 keys');
    }
  });

  test('English returns the key unchanged and substitutes placeholders',
      () async {
    final String raw = await rootBundle.loadString(UiStrings.assetPath);
    final UiStrings t = UiStringsTestAccess.build(raw);
    expect(t('Learn'), 'Learn');
    expect(t('{n} words', <String, Object?>{'n': 42}), '42 words');

    t.language = 'fr';
    expect(t('Learn'), 'Apprendre');
    expect(t('An untranslated string'), 'An untranslated string',
        reason: 'a missing key must fall back to English, never render blank');
  });
}

/// UiStrings has a private constructor, so tests build one through the same
/// parse path the loader uses.
class UiStringsTestAccess {
  static UiStrings build(String raw) {
    // ignore: invalid_use_of_visible_for_testing_member
    return UiStrings.fromParsed(UiStrings.parse(raw));
  }
}
