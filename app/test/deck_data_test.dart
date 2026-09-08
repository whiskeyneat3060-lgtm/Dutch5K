import 'package:dutch_to_go/core/constants.dart';
import 'package:dutch_to_go/domain/free_plan.dart';
import 'package:dutch_to_go/models/deck_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'deck_fixture.dart';

/// Verifies the bundled asset against BUILD-SPEC 11.1 (data integrity).
void main() {
  late Deck deck;
  setUpAll(() => deck = loadRealDeck());

  test('AC-1 the deck contains exactly 6,752 entries', () {
    expect(deck.length, 6752);
  });

  test('AC-2 every id is unique', () {
    expect(deck.byId.length, deck.length);
  });

  test('AC-3 the four id schemes have the documented counts', () {
    int pipe = 0, book = 0, essential = 0, bare = 0;
    for (final DeckEntry e in deck.entries) {
      if (e.id.startsWith('book:')) {
        book++;
      } else if (e.id.startsWith('essential:')) {
        essential++;
      } else if (e.id.contains('|')) {
        pipe++;
      } else {
        bare++;
      }
    }
    expect(pipe, 115);
    expect(book, 1772);
    expect(essential, 484);
    expect(bare, 4381);
  });

  test('AC-4 rich / hasMeaning / neither counts', () {
    expect(deck.entries.where((DeckEntry e) => e.rich).length, 6729);
    expect(deck.entries.where((DeckEntry e) => e.hasMeaning).length, 6583);
    expect(
      deck.entries.where((DeckEntry e) => !e.rich && !e.hasMeaning).length,
      23,
      reason: 'the known extraction artifacts (BUILD-SPEC 12.6)',
    );
  });

  test('AC-5 field-presence counts', () {
    expect(deck.entries.where((DeckEntry e) => e.examples.isNotEmpty).length, 6729);
    expect(deck.entries.where((DeckEntry e) => e.forms.isNotEmpty).length, 897);
    expect(deck.entries.where((DeckEntry e) => e.synonyms.isNotEmpty).length, 849);
    expect(deck.entries.where((DeckEntry e) => e.antonyms.isNotEmpty).length, 488);
    expect(deck.entries.where((DeckEntry e) => e.article != null).length, 1176);
  });

  test('AC-6 source-tag totals', () {
    final Map<String, int> tally = <String, int>{};
    for (final DeckEntry e in deck.entries) {
      for (final String t in e.srcTags) {
        tally[t] = (tally[t] ?? 0) + 1;
      }
    }
    expect(tally['general'], 2365);
    expect(tally['essential'], 1484);
    expect(tally['actie'], 1214);
    expect(tally['gang'], 946);
    expect(tally['niveau'], 499);
    expect(tally['perfectie'], 368);
  });

  test('AC-7 essential and general are disjoint', () {
    final Iterable<DeckEntry> both = deck.entries.where(
        (DeckEntry e) => e.srcTags.contains('essential') && e.srcTags.contains('general'));
    expect(both, isEmpty);
  });

  test('AC-8 chapter ranges per book source', () {
    expect(deck.chaptersFor('gang'), List<int>.generate(18, (int i) => i + 1));
    expect(deck.chaptersFor('actie'), List<int>.generate(11, (int i) => i + 1));
    expect(deck.chaptersFor('niveau'), List<int>.generate(6, (int i) => i + 1));
    expect(deck.chaptersFor('perfectie'), List<int>.generate(8, (int i) => i + 1));
  });

  test('AC-9 bereiken is fully enriched', () {
    final DeckEntry e = deck.byId['bereiken']!;
    expect(e.meaning, 'to reach, to achieve, to attain; to get in touch with someone');
    expect(e.pos, 'verb');
    expect(e.forms.length, 3);
    expect(e.forms.first.label, 'Present');
    expect(e.synonyms, <String>['halen', 'verwezenlijken']);
    expect(e.antonyms, <String>['mislopen', 'falen']);
    expect(e.examples.length, 2);
    expect(e.books.single.src, 'actie');
    expect(e.books.single.ch, 1);
    expect(e.bookTag, 'A2–B1 H1');
  });

  test('AC-11 computeFree unlocks exactly 850 ids', () {
    expect(FreePlan.computeFreeIds(deck.entries).length, 850);
  });

  test('AC-12 corrected homograph glosses survived the port', () {
    expect(deck.byId['kan']!.meaning, 'can; to be able to (form of kunnen)');
    expect(deck.byId['waar']!.meaning, 'where; true, real');
    expect(deck.byId['tel']!.meaning, 'count; tally');
  });

  test('a word in two books carries both tags and both chapters', () {
    final DeckEntry e = deck.byId['book:actie:een hekel hebben aan iets']!;
    expect(e.srcTags, containsAll(<String>['actie', 'niveau']));
    expect(e.bookTag, 'A2–B1 H1 · B1–B2 H2');
  });

  test('primarySource attributes each word to exactly one source', () {
    for (final DeckEntry e in deck.entries) {
      expect(kSrcOrder, contains(e.primarySource));
    }
  });

  test('every present source has a short label and a badge or is general', () {
    for (final String s in deck.presentSources) {
      expect(kSrcShort[s], isNotNull);
      expect(s == 'general' || kSrcBadge[s] != null, isTrue);
    }
  });
}
