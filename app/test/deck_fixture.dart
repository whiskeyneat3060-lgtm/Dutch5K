import 'dart:io';

import 'package:dutch_to_go/data/deck_repository.dart';
import 'package:dutch_to_go/models/deck_entry.dart';

/// Loads the real bundled deck straight off disk so tests can assert against
/// the shipped data rather than a hand-made fixture.
Deck loadRealDeck() =>
    DeckRepository.parse(File('assets/data/deck.json').readAsStringSync());
