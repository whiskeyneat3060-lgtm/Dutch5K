import 'package:dutch_to_go/domain/answer_check.dart';
import 'package:dutch_to_go/models/deck_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'deck_fixture.dart';

void main() {
  group('normalizeAns — BUILD-SPEC 7.12', () {
    test('AC-29 case, articles and trailing punctuation are ignored', () {
      const List<String> variants = <String>['huis', 'Huis', 'het huis', 'HUIS.', '  huis  '];
      for (final String v in variants) {
        expect(AnswerCheck.normalize(v), 'huis', reason: v);
      }
      expect(AnswerCheck.normalize('de auto'), 'auto');
      expect(AnswerCheck.normalize('een appel!'), 'appel');
    });

    test('AC-30 diacritics are ignored', () {
      expect(AnswerCheck.normalize('één'), AnswerCheck.normalize('een'));
      expect(AnswerCheck.normalize('café'), 'cafe');
      expect(AnswerCheck.normalize('vóórkomen'), 'voorkomen');
    });

    test('interior whitespace collapses', () {
      expect(AnswerCheck.normalize('een   hekel   hebben'), 'hekel hebben');
    });

    test('an article-only answer does not become empty by accident', () {
      expect(AnswerCheck.normalize('de'), 'de');
    });

    test('AC-31 an empty answer is always wrong', () {
      expect(AnswerCheck.isCorrect('', 'huis'), isFalse);
      expect(AnswerCheck.isCorrect('   ', ''), isFalse);
      expect(AnswerCheck.isCorrect('', ''), isFalse);
    });

    test('correct answers grade correct', () {
      expect(AnswerCheck.isCorrect('Het Huis.', 'huis'), isTrue);
      expect(AnswerCheck.isCorrect('huis', 'het huis'), isTrue);
      expect(AnswerCheck.isCorrect('huisje', 'huis'), isFalse);
    });
  });

  group('clozePick — BUILD-SPEC 7.12', () {
    late Deck deck;
    setUpAll(() => deck = loadRealDeck());

    test('AC-32 blanks the headword on a whole-word boundary', () {
      final DeckEntry viool = deck.byId['essential:viool']!;
      final ClozePrompt? c = AnswerCheck.pickCloze(viool);
      expect(c, isNotNull);
      expect(c!.answer.toLowerCase(), 'viool');
      expect(c.pre + c.answer + c.post, c.full);
      expect(c.pre, isNot(contains('viool')));
    });

    test('does not match the headword inside a longer word', () {
      const DeckEntry e = DeckEntry(
        id: 'x',
        word: 'tel',
        rank: 1,
        srcTags: <String>['general'],
        rich: true,
        hasMeaning: true,
        examples: <Example>[Example('De teller staat stil.', 'The counter is still.')],
      );
      expect(AnswerCheck.pickCloze(e), isNull);
    });

    test('matches case-insensitively at the start of a sentence', () {
      const DeckEntry e = DeckEntry(
        id: 'x',
        word: 'huis',
        rank: 1,
        srcTags: <String>['general'],
        rich: true,
        hasMeaning: true,
        examples: <Example>[Example('Huis is mooi.', 'House is nice.')],
      );
      final ClozePrompt c = AnswerCheck.pickCloze(e)!;
      expect(c.pre, '');
      expect(c.answer, 'Huis');
      expect(c.post, ' is mooi.');
    });

    test('returns null when there are no examples', () {
      const DeckEntry e = DeckEntry(
        id: 'x',
        word: 'huis',
        rank: 1,
        srcTags: <String>['general'],
        rich: false,
        hasMeaning: false,
      );
      expect(AnswerCheck.pickCloze(e), isNull);
    });

    test('every cloze-eligible deck entry produces a reconstructable sentence', () {
      int checked = 0;
      for (final DeckEntry e in deck.entries) {
        final ClozePrompt? c = AnswerCheck.pickCloze(e);
        if (c == null) continue;
        expect(c.pre + c.answer + c.post, c.full);
        expect(AnswerCheck.isCorrect(c.answer, c.answer), isTrue);
        if (++checked > 800) break;
      }
      expect(checked, greaterThan(500));
    });
  });
}
