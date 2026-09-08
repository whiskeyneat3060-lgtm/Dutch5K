import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;

/// UI string translation.
///
/// Keys are the exact English source string; English needs no dictionary and is
/// returned as-is. `{x}` placeholders are substituted **after** lookup, so a
/// translation may reorder them (BUILD-SPEC 5.0).
class UiStrings {
  UiStrings._(this._dicts);

  final Map<String, Map<String, String>> _dicts;

  /// Active language id. Set by the settings controller on change.
  String language = 'en';

  static const String assetPath = 'assets/data/ui_strings.json';

  /// Builds an instance from already-parsed dictionaries. Lets tests exercise
  /// lookup without going through asset loading twice.
  @visibleForTesting
  factory UiStrings.fromParsed(Map<String, Map<String, String>> dicts) =>
      UiStrings._(dicts);

  static Future<UiStrings> load() async {
    final String raw = await rootBundle.loadString(assetPath);
    return UiStrings._(parse(raw));
  }

  static Map<String, Map<String, String>> parse(String raw) {
    final Map<String, dynamic> j = json.decode(raw) as Map<String, dynamic>;
    final Map<String, dynamic> t = j['translations'] as Map<String, dynamic>;
    return t.map((String lang, dynamic v) => MapEntry<String, Map<String, String>>(
          lang,
          (v as Map<String, dynamic>).map(
              (String k, dynamic s) => MapEntry<String, String>(k, s as String)),
        ));
  }

  /// Translates [s], substituting any `{name}` placeholders from [vars].
  /// An unknown key falls back to the English source string.
  String call(String s, [Map<String, Object?>? vars]) {
    String out = (language == 'en' ? null : _dicts[language]?[s]) ?? s;
    if (vars != null) {
      vars.forEach((String k, Object? v) {
        out = out.replaceAll('{$k}', '$v');
      });
    }
    return out;
  }

  /// True when a language has any dictionary at all.
  bool hasDictionary(String lang) => lang == 'en' || _dicts.containsKey(lang);
}
