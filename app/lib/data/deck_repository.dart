import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/deck_entry.dart';

/// Loads the bundled deck asset.
///
/// The deck is ~1.8 MB of JSON and 6,752 entries. Parsing happens on a
/// background isolate via [compute] so the first frame is never blocked; the
/// result is held in memory for the life of the process (a few MB), which keeps
/// every filter, sort and count a plain synchronous Dart operation exactly
/// mirroring the web implementation.
class DeckRepository {
  static const String assetPath = 'assets/data/deck.json';

  Deck? _cached;

  Future<Deck> load() async {
    final Deck? c = _cached;
    if (c != null) return c;
    final String raw = await rootBundle.loadString(assetPath);
    final Deck deck = await compute(_parseDeck, raw);
    _cached = deck;
    return deck;
  }

  /// Parses a raw JSON string. Public so tests can feed it a fixture.
  static Deck parse(String raw) => _parseDeck(raw);
}

Deck _parseDeck(String raw) =>
    Deck.fromJson(json.decode(raw) as Map<String, dynamic>);
