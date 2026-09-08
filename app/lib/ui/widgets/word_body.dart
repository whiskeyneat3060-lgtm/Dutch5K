import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/i18n/content_pack_repository.dart';
import '../../data/i18n/ui_strings.dart';
import '../../models/deck_entry.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'speaker_button.dart';
import 'study_card.dart';

/// The full detail body of a word: meaning, forms, examples, related words.
///
/// Shared by the Learn card's revealed face and the Words detail screen so the
/// two can never drift apart.
class WordBody extends ConsumerWidget {
  const WordBody({
    super.key,
    required this.entry,
    required this.onOpenRelated,
    this.showMeaning = true,
    this.leading,
  });

  final DeckEntry entry;

  /// Opens another word's detail card by deck index.
  final void Function(int index) onOpenRelated;
  final bool showMeaning;
  final Widget? leading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTokens tk = context.tokens;
    final UiStrings t = ref.watch(uiStringsProvider);
    final ContentPackRepository packs = ref.watch(contentPackProvider);
    final Deck deck = ref.watch(deckProvider);

    final List<Widget> children = <Widget>[
      if (leading != null) leading!,
      if (showMeaning && entry.meaning != null)
        MeaningText(packs.translate(entry.meaning)),
    ];

    if (entry.forms.isNotEmpty) {
      children.add(CardSection(
        title: t('Forms'),
        children: <Widget>[
          for (final WordForm f in entry.forms)
            FormRow(WordForm(t(f.label), f.value)),
        ],
      ));
    }

    if (entry.examples.isNotEmpty) {
      children.add(CardSection(
        title: t('Examples'),
        children: <Widget>[
          for (final (int i, Example ex) in entry.examples.indexed)
            ExampleRow(
              dutch: ex.nl,
              english: packs.translate(ex.en),
              speaker: SpeakerButton(
                text: ex.nl,
                id: '${entry.id}-ex$i',
                size: 22,
              ),
            ),
        ],
      ));
    }

    if (entry.synonyms.isNotEmpty) {
      children.add(CardSection(
        title: t('Synonyms'),
        children: <Widget>[
          for (final String s in entry.synonyms) _related(deck, packs, s, true),
        ],
      ));
    }

    if (entry.antonyms.isNotEmpty) {
      children.add(CardSection(
        title: t('Antonyms'),
        children: <Widget>[
          for (final String s in entry.antonyms) _related(deck, packs, s, false),
        ],
      ));
    }

    // A word with a meaning but no examples is still being filled in.
    if (!entry.rich && entry.hasMeaning && entry.examples.isEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Text(
          t('More examples and grammar forms are being added.'),
          style: TextStyle(fontSize: 12, color: tk.muted),
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _related(
    Deck deck,
    ContentPackRepository packs,
    String word,
    bool isSynonym,
  ) {
    final int idx = deck.findWordIndex(word);
    final String? meaning = deck.relatedMeaning(word);
    return RelatedRow(
      word: word,
      meaning: meaning == null ? null : packs.translate(meaning),
      isSynonym: isSynonym,
      onTap: idx >= 0 ? () => onOpenRelated(idx) : null,
    );
  }
}

/// The four-state meaning block used by the Learn card's revealed face.
class MeaningBlock extends ConsumerWidget {
  const MeaningBlock({
    super.key,
    required this.entry,
    required this.onOpenRelated,
  });

  final DeckEntry entry;
  final void Function(int index) onOpenRelated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTokens tk = context.tokens;
    final UiStrings t = ref.watch(uiStringsProvider);

    if (entry.rich || entry.hasMeaning) {
      return WordBody(entry: entry, onOpenRelated: onOpenRelated);
    }
    return Text(
      t('Not translated yet'),
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: tk.blue),
    );
  }
}
