import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../data/i18n/content_pack_repository.dart';
import '../../data/i18n/ui_strings.dart';
import '../../domain/counts.dart';
import '../../domain/goal.dart';
import '../../domain/streak_logic.dart';
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
import '../widgets/donut_chart.dart';
import '../widgets/pro_lock.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({
    super.key,
    required this.onOpenWord,
    required this.onUpsell,
    required this.onStartReview,
    required this.onDrillLeeches,
    required this.onFilterByPos,
    required this.onFilterBySource,
  });

  final void Function(int deckIndex, {required bool fromLearn}) onOpenWord;
  final VoidCallback onUpsell;
  final VoidCallback onStartReview;
  final VoidCallback onDrillLeeches;
  final void Function(String pos) onFilterByPos;
  final void Function(String source) onFilterBySource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTokens tk = context.tokens;
    final UiStrings t = ref.watch(uiStringsProvider);
    final Deck deck = ref.watch(deckProvider);
    final StudyController study = ref.read(studyProvider.notifier);
    final SettingsState settings = ref.watch(settingsProvider);
    final bool isPro = ref.watch(isProProvider);
    ref.watch(studyProvider);

    final DeckCounts counts = study.counts;
    final int goalTotal = Goal.total(
      deck: deck,
      state: study.study,
      mode: settings.goalMode,
      wordGoal: settings.wordGoal,
      goalSources: settings.goalSources,
    );
    final int goalLearned = Goal.learned(
      deck: deck,
      state: study.study,
      mode: settings.goalMode,
      goalSources: settings.goalSources,
      counts: counts,
    );
    final NumberFormat nf = NumberFormat.decimalPattern(
        settings.language == 'en' ? null : settings.language);

    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        MondrianStrip(
          learned: counts.learned,
          learning: counts.learning,
          total: counts.total,
        ),
        _statTiles(tk, t, counts, goalLearned, goalTotal, nf),
        _streakCard(tk, t, study),
        _reviewBox(tk, t, study),
        _hardestBox(context, tk, t, ref, study, deck),
        _historyBox(tk, t, study),
        _byWordType(context, tk, t, study, deck, isPro),
        _bySource(context, tk, t, study, deck, isPro),
      ],
    );
  }

  // ----------------------------------------------------------- stat tiles ---

  Widget _statTiles(
    AppTokens tk,
    UiStrings t,
    DeckCounts c,
    int goalLearned,
    int goalTotal,
    NumberFormat nf,
  ) {
    final String pct = Goal.percent(goalLearned, goalTotal).toStringAsFixed(1);

    Widget tile(String value, String label, Color? colour,
        {required bool rightBorder, required bool bottomBorder}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        decoration: BoxDecoration(
          border: Border(
            right: rightBorder
                ? BorderSide(color: tk.line, width: 3)
                : BorderSide.none,
            bottom: bottomBorder
                ? BorderSide(color: tk.line, width: 3)
                : BorderSide.none,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              value,
              style: TextStyle(
                fontFamily: tk.fontHead,
                fontWeight: FontWeight.w900,
                fontSize: 34,
                height: 1,
                color: colour ?? tk.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                  fontSize: 10, letterSpacing: 1.5, color: tk.muted),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(border: tk.ruleBorder, borderRadius: tk.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: tile(nf.format(c.learned), t('Learned'), tk.blue,
                      rightBorder: true, bottomBorder: true),
                ),
                Expanded(
                  child: tile(nf.format(c.learning), t('Still learning'),
                      tk.id == AppThemeId.minimalistic
                          ? const Color(0xFFB89200)
                          : tk.yellow,
                      rightBorder: false, bottomBorder: true),
                ),
              ],
            ),
          ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: tile(nf.format(c.fresh), t('Not started'), null,
                      rightBorder: true, bottomBorder: false),
                ),
                Expanded(
                  child: tile(
                    '$pct%',
                    t('Of {goal} goal', <String, Object?>{'goal': nf.format(goalTotal)}),
                    tk.red,
                    rightBorder: false,
                    bottomBorder: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- streak ---

  Widget _streakCard(AppTokens tk, UiStrings t, StudyController study) {
    return GenBox(
      title: '🔥 ${t('Streak')}',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${study.todayCount}',
                style: TextStyle(
                  fontFamily: tk.fontHead,
                  fontWeight: FontWeight.w900,
                  fontSize: 36,
                  height: 1,
                  color: tk.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(t('words today').toUpperCase(),
                  style: TextStyle(fontSize: 10, letterSpacing: 1, color: tk.muted)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '🔥 ${study.currentStreak}',
                style: TextStyle(
                  fontFamily: tk.fontHead,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  height: 1,
                  color: tk.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(t('day streak').toUpperCase(),
                  style: TextStyle(fontSize: 9, letterSpacing: 1, color: tk.muted)),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- review ---

  Widget _reviewBox(AppTokens tk, UiStrings t, StudyController study) {
    final int due = study.dueCount;
    return GenBox(
      title: '↻ ${t('Review')}',
      borderWidthOverride: tk.ruleWidth == 3 ? 3 : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (due > 0) ...<Widget>[
            Row(
              children: <Widget>[
                Text(
                  '$due',
                  style: TextStyle(
                    fontFamily: tk.fontHead,
                    fontWeight: FontWeight.w900,
                    fontSize: 36,
                    height: 1,
                    color: tk.red,
                  ),
                ),
                const SizedBox(width: 10),
                Text(t('due for review').toUpperCase(),
                    style: TextStyle(fontSize: 10, letterSpacing: 1, color: tk.muted)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              t('Words you’ve started that are scheduled to come back today. Reviewing on time is what moves them into long-term memory.'),
              style: TextStyle(fontSize: 13, height: 1.5, color: tk.muted),
            ),
            const SizedBox(height: 12),
            GenButton(
              label: t('Start review'),
              icon: '↻',
              onPressed: () {
                Haptics.tap();
                onStartReview();
              },
            ),
          ] else
            Text(
              t('All caught up — nothing due right now. Words you learn come back on a spaced schedule so you review them right before you’d forget.'),
              style: TextStyle(fontSize: 13, height: 1.5, color: tk.muted),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------- hardest words ---

  Widget _hardestBox(
    BuildContext context,
    AppTokens tk,
    UiStrings t,
    WidgetRef ref,
    StudyController study,
    Deck deck,
  ) {
    final List<int> leeches = study.leeches;
    if (leeches.isEmpty) return const SizedBox.shrink();
    final ContentPackRepository packs = ref.watch(contentPackProvider);

    return GenBox(
      title: '🔥 ${t('Hardest words')}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final int i in leeches.take(8))
            InkWell(
              onTap: () {
                Haptics.tap();
                onOpenWord(i, fromLearn: false);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: tk.faint)),
                ),
                child: Row(
                  children: <Widget>[
                    Text(
                      deck[i].article != null
                          ? '${deck[i].article} ${deck[i].word}'
                          : deck[i].word,
                      style: TextStyle(
                          fontFamily: tk.fontHead,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: tk.ink),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        packs.translate(deck[i].meaning),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: tk.muted),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: t('times missed'),
                      child: Text(
                        '✗${study.srsOf(deck[i].id)?.lapses ?? 0}',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700, color: tk.red),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          NoteText(t('Words you keep missing. Drill them to lock them in.')),
          const SizedBox(height: 10),
          GenButton(
            label: t('Drill hardest words'),
            icon: '🔥',
            onPressed: () {
              Haptics.tap();
              onDrillLeeches();
            },
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- history ---

  Widget _historyBox(AppTokens tk, UiStrings t, StudyController study) {
    final List<({int count, String day})> days =
        StreakLogic.last14Days(study.streak, DateTime.now());

    return GenBox(
      title: t('Last 14 days'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints bc) {
              const int columns = 14;
              const double gap = 4;
              final double cell = (bc.maxWidth - gap * (columns - 1)) / columns;
              return Row(
                children: <Widget>[
                  for (final (int i, ({int count, String day}) d) in days.indexed) ...<Widget>[
                    if (i > 0) const SizedBox(width: gap),
                    Tooltip(
                      message: '${d.day}: ${d.count == 1 ? t('1 word') : t('{n} words', <String, Object?>{'n': d.count})}',
                      child: Container(
                        width: cell,
                        height: cell,
                        decoration: BoxDecoration(
                          color: switch (StreakLogic.level(d.count)) {
                            0 => tk.paper,
                            1 => tk.histLevel1,
                            2 => tk.histLevel2,
                            _ => tk.blue,
                          },
                          border: Border.all(color: tk.line, width: 2),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          NoteText(t('Each square is a day; darker means more words learned. Learn at least one word a day to keep your streak alive.')),
        ],
      ),
    );
  }

  // ---------------------------------------------------------- breakdowns ---

  Widget _byWordType(
    BuildContext context,
    AppTokens tk,
    UiStrings t,
    StudyController study,
    Deck deck,
    bool isPro,
  ) {
    final Map<String, PosBucket> buckets = Breakdowns.byPos(deck, study.study);
    final List<MapEntry<String, PosBucket>> rows = Breakdowns.posRows(buckets);

    return GenBox(
      title: t('By word type'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ProLock(
            locked: !isPro,
            onUnlock: onUpsell,
            t: t,
            child: Column(
              children: <Widget>[
                for (final MapEntry<String, PosBucket> r in rows)
                  InkWell(
                    onTap: () {
                      Haptics.tap();
                      onFilterByPos(r.key);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: <Widget>[
                          SizedBox(
                            width: 96,
                            child: Text(
                              t(kPosLabels[r.key] ?? r.key),
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: tk.ink),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StackedBar(
                                segments: r.value.bySource, total: r.value.total),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${r.value.learned}/${r.value.total}',
                            style: TextStyle(
                                fontFamily: tk.fontHead,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: tk.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          NoteText(t('Tap a type to study or browse just those words.')),
        ],
      ),
    );
  }

  Widget _bySource(
    BuildContext context,
    AppTokens tk,
    UiStrings t,
    StudyController study,
    Deck deck,
    bool isPro,
  ) {
    final Map<String, SourceBucket> buckets = Breakdowns.bySource(deck, study.study);

    return GenBox(
      title: t('By source'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ProLock(
            locked: !isPro,
            onUnlock: onUpsell,
            t: t,
            child: Wrap(
              spacing: 18,
              runSpacing: 18,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                SourceDonut(
                  buckets: buckets,
                  centreLabel: t('Learned'),
                  onTapSource: onFilterBySource,
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 190, maxWidth: 320),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (final String src in kSrcOrder)
                        if (buckets.containsKey(src))
                          _legendRow(tk, src, buckets[src]!),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          NoteText(t('Tap a source to study or browse just those words.')),
        ],
      ),
    );
  }

  Widget _legendRow(AppTokens tk, String src, SourceBucket b) {
    final int pct = b.total == 0 ? 0 : (b.learned / b.total * 100).round();
    return InkWell(
      onTap: () {
        Haptics.tap();
        onFilterBySource(src);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: <Widget>[
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: tk.sourceColor(src),
                border: Border.all(color: tk.line, width: 2),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 64,
              child: Text(
                kSrcShort[src] ?? src,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: tk.ink),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: tk.paper,
                  border: Border.all(color: tk.line, width: 2),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(flex: pct, child: ColoredBox(color: tk.sourceColor(src))),
                    Expanded(flex: 100 - pct, child: const SizedBox.shrink()),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${b.learned}/${b.total}',
              style: TextStyle(
                  fontFamily: tk.fontHead,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: tk.muted),
            ),
          ],
        ),
      ),
    );
  }
}
