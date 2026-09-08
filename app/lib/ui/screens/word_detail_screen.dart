import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/i18n/ui_strings.dart';
import '../../models/deck_entry.dart';
import '../../models/enums.dart';
import '../../services/haptics.dart';
import '../../state/providers.dart';
import '../../state/study_controller.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/pro_lock.dart';
import '../widgets/speaker_button.dart';
import '../widgets/study_card.dart';
import '../widgets/word_body.dart';

/// Full detail for one word, with grading that stays on the card.
///
/// Following a synonym pushes another instance onto the navigator, so the
/// system back gesture walks the chain exactly like the web build's back-stack.
class WordDetailScreen extends ConsumerWidget {
  const WordDetailScreen({
    super.key,
    required this.deckIndex,
    required this.onUpsell,
    required this.onToast,
  });

  final int deckIndex;
  final VoidCallback onUpsell;
  final void Function(String message) onToast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTokens tk = context.tokens;
    final UiStrings t = ref.watch(uiStringsProvider);
    final Deck deck = ref.watch(deckProvider);
    final StudyController study = ref.read(studyProvider.notifier);
    ref.watch(studyProvider);

    final DeckEntry e = deck[deckIndex];
    final WordStatus status = study.statusOf(e.id);
    final bool locked = study.isLocked(e);

    final String rankText = e.rank > 0
        ? t('#{n} most frequent', <String, Object?>{'n': e.rank})
        : (e.isBookWord ? t('textbook word') : t('curated extra'));

    return Scaffold(
      backgroundColor: tk.paper,
      body: ThemedBackground(
        child: SafeArea(
          child: PageBody(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                OutlineButton(
                  label: '← ${t('Back')}',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 14),
                if (locked)
                  ProLock(
                    locked: true,
                    onUnlock: onUpsell,
                    t: t,
                    child: CardShell(
                      tagLeft: t(e.pos ?? 'word'),
                      tagRight: t(status.wire),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Headword(word: e.word),
                          const SizedBox(height: 12),
                          Text(
                            t('Tap to reveal meaning, forms, examples & related words'),
                            style: TextStyle(fontSize: 12, color: tk.muted),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...<Widget>[
                  CardShell(
                    tagLeft: e.article != null
                        ? '${t(e.pos ?? 'word')} · ${e.article}'
                        : t(e.pos ?? 'word'),
                    tagRight: t(status.wire),
                    minHeight: 0,
                    child: WordBody(
                      entry: e,
                      onOpenRelated: (int i) => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => WordDetailScreen(
                            deckIndex: i,
                            onUpsell: onUpsell,
                            onToast: onToast,
                          ),
                        ),
                      ),
                      leading: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Headword(
                            word: e.word,
                            speaker: SpeakerButton(
                              text: e.word,
                              id: 'detail-${e.id}',
                              size: 34,
                              onUnavailable: () => onToast(
                                  t("Pronunciation isn't supported on this device")),
                            ),
                          ),
                          RankLine(rankText),
                          if (e.isBookWord) RankLine('📚 ${e.bookTag}', book: true),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _gradeBar(context, tk, t, study, e),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _gradeBar(
    BuildContext context,
    AppTokens tk,
    UiStrings t,
    StudyController study,
    DeckEntry e,
  ) {
    Widget button(String label, String icon, Grade grade,
        {Color? background, Color? foreground}) {
      return Expanded(
        child: Material(
          color: background ?? tk.paper,
          child: InkWell(
            onTap: () {
              Haptics.tap();
              study.gradeWord(e.id, grade);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              child: Text(
                '$icon $label',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: tk.fontHead,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.5,
                  color: foreground ?? tk.ink,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(border: tk.ruleBorder, borderRadius: tk.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: <Widget>[
            button(t('Again'), '✗', Grade.again, foreground: tk.red),
            VerticalDivider(width: tk.ruleWidth, thickness: tk.ruleWidth, color: tk.line),
            button(t('Learning'), '≈', Grade.learning,
                background: tk.yellow, foreground: tk.yellowText),
            VerticalDivider(width: tk.ruleWidth, thickness: tk.ruleWidth, color: tk.line),
            button(t('Know it'), '✓', Grade.knowIt,
                background: tk.blue, foreground: Colors.white),
          ],
        ),
      ),
    );
  }
}
