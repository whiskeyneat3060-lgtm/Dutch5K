import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../data/i18n/content_pack_repository.dart';
import '../../data/i18n/ui_strings.dart';
import '../../domain/answer_check.dart';
import '../../models/deck_entry.dart';
import '../../models/enums.dart';
import '../../services/haptics.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';
import '../../state/settings_controller.dart';
import '../../state/study_controller.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/filter_dropdown.dart';
import '../widgets/pro_lock.dart';
import '../widgets/speaker_button.dart';
import '../widgets/study_card.dart';
import '../widgets/word_body.dart';

class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({
    super.key,
    required this.onOpenWord,
    required this.onUpsell,
    required this.onToast,
  });

  final void Function(int deckIndex, {required bool fromLearn}) onOpenWord;
  final VoidCallback onUpsell;
  final void Function(String message) onToast;

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  final GlobalKey<FlipCardState> _flipKey = GlobalKey<FlipCardState>();
  final TextEditingController _answer = TextEditingController();
  final FocusNode _answerFocus = FocusNode();

  @override
  void dispose() {
    _answer.dispose();
    _answerFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UiStrings t = ref.watch(uiStringsProvider);
    final StudySession session = ref.watch(studyProvider);
    final SettingsState settings = ref.watch(settingsProvider);
    final Deck deck = ref.watch(deckProvider);
    final StudyController study = ref.read(studyProvider.notifier);

    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        _filterBar(t, deck, settings, session),
        if (session.filters.leechOnly) _drillBanner(t, study),
        if (session.isEmpty)
          _emptyState(t, settings, session)
        else
          _cardArea(t, deck, session, study, settings),
      ],
    );
  }

  // ------------------------------------------------------------- filters ---

  Widget _filterBar(
    UiStrings t,
    Deck deck,
    SettingsState settings,
    StudySession session,
  ) {
    final StudyController study = ref.read(studyProvider.notifier);
    final List<String> sources = deck.presentSources;

    return FilterBar(children: <Widget>[
      FilterDropdown(
        name: t('Study mode'),
        multi: false,
        selected: <String>[settings.studyMode.id],
        options: <DropOption>[
          for (final StudyMode m in StudyMode.values)
            DropOption(m.id, m == StudyMode.dehet ? m.label : t(m.label), icon: m.icon),
        ],
        onChanged: (List<String> v) async {
          if (v.isEmpty) return;
          await ref.read(settingsProvider.notifier).setStudyMode(StudyMode.fromId(v.first));
          _answer.clear();
          study.rebuildQueue();
        },
      ),
      if (sources.length > 1)
        FilterDropdown(
          name: t('Source'),
          selected: session.filters.source,
          resetLabel: t('All sources'),
          options: <DropOption>[
            for (final String s in sources)
              DropOption(s, t(kSrcFilterLabel[s] ?? s)),
          ],
          onChanged: (List<String> v) =>
              study.setFilters(session.filters.copyWith(source: v)),
        ),
      FilterDropdown(
        name: t('Word type'),
        selected: session.filters.pos,
        resetLabel: t('All types'),
        options: <DropOption>[
          for (final String p in kPosFilter) DropOption(p, t(kPosLabels[p] ?? p)),
        ],
        onChanged: (List<String> v) =>
            study.setFilters(session.filters.copyWith(pos: v)),
      ),
      FilterDropdown(
        name: t('Options'),
        selected: <String>[
          if (settings.shuffle) 'shuffle',
          if (settings.newOnly) 'newonly',
        ],
        options: <DropOption>[
          DropOption('shuffle', t('Shuffle'), icon: '🔀'),
          DropOption('newonly', t('New words only'), icon: '🔴'),
        ],
        onChanged: (List<String> v) async {
          final SettingsController sc = ref.read(settingsProvider.notifier);
          final bool wantShuffle = v.contains('shuffle');
          final bool wantNewOnly = v.contains('newonly');
          if (wantShuffle != settings.shuffle) {
            await sc.setShuffle(wantShuffle);
            widget.onToast(wantShuffle
                ? '🔀 ${t('Shuffle on · strategic mix of new words')}'
                : t('Shuffle off · frequency order'));
          }
          if (wantNewOnly != settings.newOnly) {
            await sc.setNewOnly(wantNewOnly);
            widget.onToast(wantNewOnly
                ? '🔴 ${t('New words only · reviews paused')}'
                : t('Reviews resumed'));
            if (wantNewOnly) study.exitLeechDrill();
          }
          study.rebuildQueue();
        },
      ),
    ]);
  }

  Widget _drillBanner(UiStrings t, StudyController study) {
    final AppTokens tk = context.tokens;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(border: Border.all(color: tk.red, width: 2)),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '🔥 ${t('Drilling hardest words').toUpperCase()}',
              style: TextStyle(
                fontFamily: tk.fontHead,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 1,
                color: tk.red,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: t('Exit drill'),
            icon: Icon(Icons.close, color: tk.red, size: 18),
            onPressed: () {
              Haptics.tap();
              study.exitLeechDrill();
            },
          ),
        ],
      ),
    );
  }

  Widget _emptyState(UiStrings t, SettingsState settings, StudySession session) {
    final String message = session.filters.leechOnly
        ? t('No tricky words yet — keep going!')
        : settings.newOnly
            ? t('No new words left — turn off “New words only” to review.')
            : t('No words available for this mode with these filters.');
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: EmptyPanel(message: message, hint: t('Try “All”.')),
    );
  }

  // ---------------------------------------------------------------- card ---

  Widget _cardArea(
    UiStrings t,
    Deck deck,
    StudySession session,
    StudyController study,
    SettingsState settings,
  ) {
    final int idx = session.currentIndex!;
    final DeckEntry e = deck[idx];
    final WordStatus status = study.statusOf(e.id);
    final AppTokens tk = context.tokens;

    final String rankText = e.rank > 0
        ? t('#{n} most frequent', <String, Object?>{'n': e.rank})
        : (e.isBookWord ? e.bookTag : t('curated extra'));

    final Widget card;
    if (study.isLocked(e)) {
      card = _lockedCard(t, e, status, rankText);
    } else if (settings.studyMode.isTyping) {
      card = _typeCard(t, e, status, session, study);
    } else if (settings.studyMode == StudyMode.dehet) {
      card = _deHetCard(t, e, status, session, study);
    } else {
      card = _recognitionCard(t, e, status, rankText, session, study, settings);
    }

    final int due = study.dueCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MondrianStrip(
          learned: study.counts.learned,
          learning: study.counts.learning,
          total: study.counts.total,
        ),
        card,
        const SizedBox(height: 10),
        _deckInfo(tk, t('Card {a} of {b} in this round · {c} words in deck',
            <String, Object?>{
              'a': session.position + 1,
              'b': session.queue.length,
              'c': deck.length,
            })),
        if (settings.plan != null)
          _deckInfo(
            tk,
            '${t('Today: {n} learned · streak {s}', <String, Object?>{
                  'n': settings.plan!.perDay > 0
                      ? '${study.todayCount} / ${settings.plan!.perDay}'
                      : '${study.todayCount}',
                  's': '${study.currentStreak}',
                })} 🔥',
          ),
        if (due > 0)
          _deckInfo(tk, '↻ ${t('{n} due for review', <String, Object?>{'n': due})}'),
      ],
    );
  }

  Widget _deckInfo(AppTokens tk, String s) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          s,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: tk.muted),
        ),
      );

  String _cardTag(UiStrings t, DeckEntry e) {
    final String pos = t(e.pos ?? 'word');
    return e.article != null ? '$pos · ${e.article}' : pos;
  }

  Widget _lockedCard(UiStrings t, DeckEntry e, WordStatus status, String rankText) {
    return ProLock(
      locked: true,
      onUnlock: widget.onUpsell,
      t: t,
      child: CardShell(
        tagLeft: _cardTag(t, e),
        tagRight: t(status.wire),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Headword(word: e.word),
            RankLine(rankText),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------- recognition modes ---

  Widget _recognitionCard(
    UiStrings t,
    DeckEntry e,
    WordStatus status,
    String rankText,
    StudySession session,
    StudyController study,
    SettingsState settings,
  ) {
    final AppTokens tk = context.tokens;
    final ContentPackRepository packs = ref.watch(contentPackProvider);
    final StudyMode mode = settings.studyMode;

    Widget faceFront() {
      switch (mode) {
        case StudyMode.reverse:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              PromptLabel(t('What is this in Dutch?')),
              MeaningText(packs.translate(e.meaning), big: true),
            ],
          );
        case StudyMode.listen:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              PromptLabel(t('Listen, then recall the meaning')),
              BigPlayButton(
                text: e.word,
                id: 'learn-${e.id}',
                onUnavailable: () =>
                    widget.onToast(t("Pronunciation isn't supported on this device")),
              ),
            ],
          );
        default:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Headword(
                word: e.word,
                speaker: SpeakerButton(text: e.word, id: 'learn-${e.id}', size: 34),
              ),
              RankLine(rankText),
              if (e.isBookWord) RankLine('📚 ${e.bookTag}', book: true),
            ],
          );
      }
    }

    Widget faceBack() {
      final Widget meaning = MeaningBlock(
        entry: e,
        onOpenRelated: (int i) => widget.onOpenWord(i, fromLearn: true),
      );
      if (mode == StudyMode.cards) return meaning;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Headword(
            word: e.word,
            speaker: SpeakerButton(text: e.word, id: 'learn-${e.id}', size: 34),
          ),
          RankLine(rankText),
          if (e.isBookWord) RankLine('📚 ${e.bookTag}', book: true),
          const SizedBox(height: 8),
          meaning,
        ],
      );
    }

    final String hint = switch (mode) {
      StudyMode.reverse => t('Tap to reveal the Dutch word'),
      StudyMode.listen => t('Tap the card to reveal'),
      _ => t('Tap to reveal meaning, forms, examples & related words'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FlipCard(
          key: _flipKey,
          showBack: session.flipped,
          onFlipRequested: study.flip,
          child: CardShell(
            tagLeft: _cardTag(t, e),
            tagRight: t(status.wire),
            onTap: () => _flipKey.currentState?.flip(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (session.flipped)
                  faceBack()
                else ...<Widget>[
                  faceFront(),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(hint,
                        style: TextStyle(fontSize: 12, color: tk.muted)),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (session.flipped) ...<Widget>[
          _gradeRow(t, study),
          const SizedBox(height: 10),
          _actionRow(<Widget>[
            _actionButton(t('Skip for now'), () {
              Haptics.tap();
              study.skip();
            }, icon: '↷', muted: true),
          ]),
        ] else
          _actionRow(<Widget>[
            _actionButton(t('Show answer'), () => _flipKey.currentState?.flip()),
            _actionButton(t('Skip'), () {
              Haptics.tap();
              study.skip();
            }, icon: '↷', muted: true),
          ]),
      ],
    );
  }

  Widget _gradeRow(UiStrings t, StudyController study) {
    final AppTokens tk = context.tokens;
    return _actionRow(<Widget>[
      _actionButton(t('Again'), () => _grade(study, Grade.again),
          icon: '✗', foreground: tk.red),
      _actionButton(t('Learning'), () => _grade(study, Grade.learning),
          icon: '≈', background: tk.yellow, foreground: tk.yellowText),
      _actionButton(t('Know it'), () => _grade(study, Grade.knowIt),
          icon: '✓', background: tk.blue, foreground: Colors.white),
    ]);
  }

  Future<void> _grade(StudyController study, Grade g) async {
    Haptics.tap();
    _answer.clear();
    await study.gradeCurrent(g);
  }

  /// A hard-ruled row of equal-width buttons, matching the web `.actions` bar.
  Widget _actionRow(List<Widget> children) {
    final AppTokens tk = context.tokens;
    return Container(
      decoration: BoxDecoration(border: tk.ruleBorder, borderRadius: tk.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: <Widget>[
            for (int i = 0; i < children.length; i++) ...<Widget>[
              if (i > 0)
                VerticalDivider(width: tk.ruleWidth, thickness: tk.ruleWidth, color: tk.line),
              Expanded(child: children[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionButton(
    String label,
    VoidCallback onTap, {
    String? icon,
    Color? background,
    Color? foreground,
    bool muted = false,
  }) {
    final AppTokens tk = context.tokens;
    return Material(
      color: background ?? tk.paper,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Text(
            icon == null ? label : '$icon $label',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: tk.fontHead,
              fontWeight: FontWeight.w700,
              fontSize: muted ? 12 : 13,
              letterSpacing: 0.5,
              color: foreground ?? (muted ? tk.muted : tk.ink),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------- typing modes ---

  Widget _typeCard(
    UiStrings t,
    DeckEntry e,
    WordStatus status,
    StudySession session,
    StudyController study,
  ) {
    final AppTokens tk = context.tokens;
    final ContentPackRepository packs = ref.watch(contentPackProvider);
    final bool isCloze = ref.watch(settingsProvider).studyMode == StudyMode.cloze;
    final ObjectiveResult? result = session.result;
    final ClozePrompt? cloze = isCloze ? AnswerCheck.pickCloze(e) : null;

    Widget prompt() {
      if (isCloze) {
        final ClozePrompt c = cloze ??
            ClozePrompt(pre: '', answer: e.word, post: '', english: '', full: e.word);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PromptLabel(t('Fill in the missing word')),
            Text.rich(
              TextSpan(children: <InlineSpan>[
                TextSpan(text: c.pre),
                TextSpan(
                  text: result == null ? ' _____ ' : ' ${result.answer} ',
                  style: TextStyle(
                    color: tk.red,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline,
                    decorationColor: tk.red,
                    decorationThickness: 3,
                  ),
                ),
                TextSpan(text: c.post),
              ]),
              style: TextStyle(
                  fontSize: 19, height: 1.5, fontWeight: FontWeight.w600, color: tk.ink),
            ),
            if (c.english.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  packs.translate(c.english),
                  style: TextStyle(
                      fontSize: 13, fontStyle: FontStyle.italic, color: tk.muted),
                ),
              ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PromptLabel(t('Type the Dutch word')),
          MeaningText(packs.translate(e.meaning), big: true),
          if (e.pos != null)
            RankLine(e.article != null ? '${t(e.pos!)} · ${e.article}' : t(e.pos!)),
        ],
      );
    }

    final Widget body;
    final Widget actions;

    if (result == null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          prompt(),
          const SizedBox(height: 14),
          TextField(
            controller: _answer,
            focusNode: _answerFocus,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _check(e, cloze, study),
            style: TextStyle(fontSize: 18, color: tk.ink),
            decoration: InputDecoration(
              hintText: t('Type here…'),
              hintStyle: TextStyle(color: tk.muted2),
              filled: true,
              fillColor: tk.paper,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: OutlineInputBorder(
                borderRadius: tk.cardRadius,
                borderSide: BorderSide(color: tk.line, width: tk.ruleWidth),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: tk.cardRadius,
                borderSide: BorderSide(color: tk.line, width: tk.ruleWidth),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: tk.cardRadius,
                borderSide: BorderSide(color: tk.blue, width: tk.ruleWidth),
              ),
            ),
          ),
        ],
      );
      actions = _actionRow(<Widget>[
        _actionButton(t('Check'), () => _check(e, cloze, study),
            background: tk.blue, foreground: Colors.white),
        _actionButton(t('Skip'), () {
          Haptics.tap();
          _answer.clear();
          study.skip();
        }, icon: '↷', muted: true),
      ]);
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          prompt(),
          const SizedBox(height: 14),
          _resultBox(t, e, result),
        ],
      );
      actions = result.correct
          ? _actionRow(<Widget>[
              _actionButton('${t('Continue')} →', () => _grade(study, Grade.knowIt),
                  background: tk.blue, foreground: Colors.white),
            ])
          : _actionRow(<Widget>[
              _actionButton(t('Review again'), () => _grade(study, Grade.again),
                  icon: '↷', foreground: tk.red),
              _actionButton(t('I knew it'), () => _grade(study, Grade.knowIt),
                  background: tk.blue, foreground: Colors.white),
            ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        CardShell(
          tagLeft: t(isCloze ? 'Cloze' : 'Type'),
          tagRight: t(status.wire),
          child: body,
        ),
        const SizedBox(height: 14),
        actions,
      ],
    );
  }

  void _check(DeckEntry e, ClozePrompt? cloze, StudyController study) {
    final String expected = cloze?.answer ?? e.word;
    final String given = _answer.text;
    final bool correct = AnswerCheck.isCorrect(given, expected);
    correct ? Haptics.correct() : Haptics.wrong();
    study.setResult(
        ObjectiveResult(correct: correct, given: given, answer: expected));
  }

  Widget _resultBox(UiStrings t, DeckEntry e, ObjectiveResult r) {
    final AppTokens tk = context.tokens;
    final ContentPackRepository packs = ref.watch(contentPackProvider);
    final Color accent = r.correct ? tk.blue : tk.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(accent.withValues(alpha: 0.12), tk.paper),
        border: Border.all(color: accent, width: 2),
        borderRadius: tk.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            r.correct ? '✓ ${t('Correct!')}' : '✗ ${t('Not quite')}',
            style: TextStyle(
              fontFamily: tk.fontHead,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 1,
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  r.answer,
                  style: TextStyle(
                      fontFamily: tk.fontHead,
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                      color: tk.ink),
                ),
              ),
              SpeakerButton(text: r.answer, id: 'result-${e.id}'),
            ],
          ),
          if (!r.correct && r.given.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${t('You typed:')} ${r.given}',
                style: TextStyle(
                  fontSize: 13,
                  color: tk.muted,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ),
          if (e.meaning != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: MeaningText(packs.translate(e.meaning)),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ de / het ---

  Widget _deHetCard(
    UiStrings t,
    DeckEntry e,
    WordStatus status,
    StudySession session,
    StudyController study,
  ) {
    final AppTokens tk = context.tokens;
    final ContentPackRepository packs = ref.watch(contentPackProvider);
    final ObjectiveResult? r = session.result;

    Widget genderButton(String value) => Expanded(
          child: Material(
            color: tk.paper,
            borderRadius: tk.cardRadius,
            child: InkWell(
              borderRadius: tk.cardRadius,
              onTap: () {
                final bool correct = value == e.article;
                correct ? Haptics.correct() : Haptics.wrong();
                study.setResult(ObjectiveResult(
                  correct: correct,
                  given: value,
                  answer: e.article ?? '',
                ));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  border: tk.ruleBorder,
                  borderRadius: tk.cardRadius,
                ),
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: tk.fontHead,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: tk.ink,
                  ),
                ),
              ),
            ),
          ),
        );

    final Widget body = r == null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              PromptLabel(t('de or het?')),
              Headword(
                word: e.word,
                speaker: SpeakerButton(text: e.word, id: 'dehet-${e.id}', size: 34),
              ),
              const SizedBox(height: 18),
              Row(children: <Widget>[
                genderButton('de'),
                const SizedBox(width: 12),
                genderButton('het'),
              ]),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              PromptLabel(t('de or het?')),
              Headword(
                word: e.word,
                prefix: Text(
                  '${r.answer} ',
                  style: TextStyle(
                    fontFamily: tk.fontHead,
                    fontWeight: tk.headwordWeight,
                    fontSize: tk.headwordSize,
                    height: 1,
                    color: tk.blue,
                  ),
                ),
                speaker: SpeakerButton(
                    text: '${r.answer} ${e.word}', id: 'dehet-${e.id}', size: 34),
              ),
              if (e.meaning != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: MeaningText(packs.translate(e.meaning)),
                ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                      (r.correct ? tk.blue : tk.red).withValues(alpha: 0.12), tk.paper),
                  border: Border.all(color: r.correct ? tk.blue : tk.red, width: 2),
                  borderRadius: tk.cardRadius,
                ),
                child: Text(
                  r.correct
                      ? '✓ ${t('Correct!')}'
                      : '✗ ${t('It is “{a}”', <String, Object?>{'a': r.answer})}',
                  style: TextStyle(
                    fontFamily: tk.fontHead,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1,
                    color: r.correct ? tk.blue : tk.red,
                  ),
                ),
              ),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        CardShell(
          tagLeft: t('article'),
          tagRight: t(status.wire),
          child: body,
        ),
        const SizedBox(height: 14),
        if (r == null)
          _actionRow(<Widget>[
            _actionButton(t('Skip'), () {
              Haptics.tap();
              study.skip();
            }, icon: '↷', muted: true),
          ])
        else
          _actionRow(<Widget>[
            // A correct gender proves only the article, so it grades as
            // "learning" rather than "learned".
            _actionButton(
              '${t('Next')} →',
              () => _grade(study, r.correct ? Grade.learning : Grade.again),
              background: tk.blue,
              foreground: Colors.white,
            ),
          ]),
      ],
    );
  }
}
