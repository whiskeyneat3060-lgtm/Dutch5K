import 'package:dutch_to_go/domain/search.dart';
import 'package:dutch_to_go/models/deck_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'deck_fixture.dart';

void main() {
  int scoreOf(String word, String? meaning, String q) => SearchScore.score(
        word: word,
        meaning: meaning,
        translatedMeaning: null,
        query: q,
      );

  group('searchScore — BUILD-SPEC 7.11', () {
    test('tier 0: exact field match', () {
      expect(scoreOf('tell', null, 'tell'), 0);
    });

    test('tier 1: starts with the query as a whole word', () {
      expect(scoreOf('tell me', null, 'tell'), 1);
    });

    test('tier 2: whole word inside the field', () {
      expect(scoreOf('you tell me', null, 'tell'), 2);
    });

    test('tier 3: prefix of a longer word', () {
      expect(scoreOf('teller', null, 'tell'), 3);
    });

    test('tier 4: mid-word substring', () {
      expect(scoreOf('vertellen', null, 'tell'), 4);
    });

    test('no match scores 9', () {
      expect(scoreOf('huis', 'house', 'zzz'), 9);
    });

    test('the best score across fields wins', () {
      expect(scoreOf('vertellen', 'to tell', 'tell'), 2);
    });

    test('AC-55 exact hits rank above containing words on the real deck', () {
      final Deck deck = loadRealDeck();
      const String q = 'tell';
      final List<int> matches = <int>[];
      for (final (int i, DeckEntry e) in deck.entries.indexed) {
        final bool hit = e.word.toLowerCase().contains(q) ||
            (e.meaning ?? '').toLowerCase().contains(q);
        if (hit) matches.add(i);
      }
      expect(matches.length, greaterThan(3));

      // Stable sort by score, as renderWordList does.
      final Map<int, int> score = <int, int>{
        for (final int i in matches)
          i: SearchScore.score(
            word: deck[i].word,
            meaning: deck[i].meaning,
            translatedMeaning: null,
            query: q,
          ),
      };
      final List<int> sorted = List<int>.of(matches)
        ..sort((int a, int b) => score[a]!.compareTo(score[b]!));

      expect(sorted.length, matches.length, reason: 'every match still appears');
      for (int i = 1; i < sorted.length; i++) {
        expect(score[sorted[i - 1]]!, lessThanOrEqualTo(score[sorted[i]]!));
      }
    });

    test('an empty query scores everything equally', () {
      expect(scoreOf('anything', null, ''), 0);
    });

    test('regex metacharacters in the query are escaped, not interpreted', () {
      expect(() => scoreOf('a.b', null, '.'), returnsNormally);
      expect(scoreOf('a+b', null, '+'), isNot(9));
    });
  });
}
