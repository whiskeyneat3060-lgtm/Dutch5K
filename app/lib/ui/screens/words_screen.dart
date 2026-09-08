import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../data/i18n/content_pack_repository.dart';
import '../../data/i18n/ui_strings.dart';
import '../../domain/search.dart';
import '../../models/deck_entry.dart';
import '../../models/enums.dart';
import '../../services/haptics.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';
import '../../state/study_controller.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/filter_dropdown.dart';
import '../widgets/speaker_button.dart';

/// Words-tab filter state, kept above the screen so it survives navigation
/// into a word detail and back.
final StateProvider<WordsFilters> wordsFiltersProvider =
    StateProvider<WordsFilters>((Ref ref) => const WordsFilters());

class WordsScreen extends ConsumerStatefulWidget {
  const WordsScreen({
    super.key,
    required this.onOpenWord,
    required this.onUpsell,
    required this.onToast,
  });

  final void Function(int deckIndex, {required bool fromLearn}) onOpenWord;
  final VoidCallback onUpsell;
  final void Function(String message) onToast;

  @override
  ConsumerState<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends ConsumerState<WordsScreen> {
  late final TextEditingController _search =
      TextEditingController(text: ref.read(wordsFiltersProvider).query);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Filters, then re-orders by search relevance, then applies free-first.
  List<int> _visibleIndices(Deck deck, StudyController study, WordsFilters f,
      ContentPackRepository packs) {
    final String q = f.query.toLowerCase().trim();
    final List<int> list = <int>[];

    for (final (int i, DeckEntry e) in deck.entries.indexed) {
      final WordStatus s = study.statusOf(e.id);
      if (f.status.isNotEmpty && !f.status.contains(s.wire)) continue;
      if (f.pos.isNotEmpty && !f.pos.contains((e.pos ?? '').toLowerCase())) continue;
      if (f.source.isNotEmpty && !f.source.any(e.inSource)) continue;
      if (q.isNotEmpty) {
        final String translated =
            packs.isEnglish ? '' : packs.translate(e.meaning).toLowerCase();
        final bool hit = e.word.toLowerCase().contains(q) ||
            (e.meaning ?? '').toLowerCase().contains(q) ||
            translated.contains(q);
        if (!hit) continue;
      }
      list.add(i);
    }

    if (q.isNotEmpty) {
      // A stable sort keeps corpus-frequency order inside each relevance tier.
      final Map<int, int> score = <int, int>{
        for (final int i in list)
          i: SearchScore.score(
            word: deck[i].word,
            meaning: deck[i].meaning,
            translatedMeaning:
                packs.isEnglish ? null : packs.translate(deck[i].meaning),
            query: q,
          ),
      };
      mergeSortInPlace(list, (int a, int b) => score[a]!.compareTo(score[b]!));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tk = context.tokens;
    final UiStrings t = ref.watch(uiStringsProvider);
    final Deck deck = ref.watch(deckProvider);
    final WordsFilters f = ref.watch(wordsFiltersProvider);
    final ContentPackRepository packs = ref.watch(contentPackProvider);
    final StudyController study = ref.read(studyProvider.notifier);
    // Rebuild the list when a grade changes a status dot.
    ref.watch(studyProvider);

    final List<int> all = _visibleIndices(deck, study, f, packs);
    final List<int> shown = study
        .freeIds
        .isEmpty // Pro: no partitioning needed.
        ? all
        : _freeFirst(all, deck, study);
    final List<int> page = shown.take(f.limit).toList();
    final List<String> sources = deck.presentSources;

    return ListView.builder(
      padding: EdgeInsets.zero,
      // search + filters + rows + footer
      itemCount: page.length + 3,
      itemBuilder: (BuildContext context, int i) {
        if (i == 0) return _searchField(tk, t);
        if (i == 1) {
          return FilterBar(children: <Widget>[
            FilterDropdown(
              name: t('Status'),
              selected: f.status,
              resetLabel: t('All'),
              options: <DropOption>[
                DropOption('new', t('new')),
                DropOption('learning', t('learning')),
                DropOption('learned', t('learned')),
              ],
              onChanged: (List<String> v) => ref
                  .read(wordsFiltersProvider.notifier)
                  .state = f.copyWith(status: v, limit: kListLimitInitial),
            ),
            if (sources.length > 1)
              FilterDropdown(
                name: t('Source'),
                selected: f.source,
                resetLabel: t('All sources'),
                options: <DropOption>[
                  for (final String s in sources)
                    DropOption(s, t(kSrcFilterLabel[s] ?? s)),
                ],
                onChanged: (List<String> v) => ref
                    .read(wordsFiltersProvider.notifier)
                    .state = f.copyWith(source: v, limit: kListLimitInitial),
              ),
            FilterDropdown(
              name: t('Word type'),
              selected: f.pos,
              resetLabel: t('All types'),
              options: <DropOption>[
                for (final String p in kPosFilter) DropOption(p, t(kPosLabels[p] ?? p)),
              ],
              onChanged: (List<String> v) => ref
                  .read(wordsFiltersProvider.notifier)
                  .state = f.copyWith(pos: v, limit: kListLimitInitial),
            ),
          ]);
        }
        if (i == page.length + 2) return _footer(tk, t, shown.length, f);

        final int deckIndex = page[i - 2];
        return _row(tk, t, packs, deck[deckIndex], deckIndex, study,
            isLast: i - 2 == page.length - 1);
      },
    );
  }

  Widget _searchField(AppTokens tk, UiStrings t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _search,
        autocorrect: false,
        textInputAction: TextInputAction.search,
        style: TextStyle(fontSize: 14, color: tk.ink),
        // Only the list rebuilds, so the keyboard is never dismissed.
        onChanged: (String v) => ref.read(wordsFiltersProvider.notifier).state =
            ref.read(wordsFiltersProvider).copyWith(query: v, limit: kListLimitInitial),
        decoration: InputDecoration(
          hintText: t('Search Dutch or English…'),
          hintStyle: TextStyle(color: tk.muted2),
          prefixIcon: Icon(Icons.search, size: 18, color: tk.muted),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close, size: 18, color: tk.muted),
                  onPressed: () {
                    _search.clear();
                    ref.read(wordsFiltersProvider.notifier).state = ref
                        .read(wordsFiltersProvider)
                        .copyWith(query: '', limit: kListLimitInitial);
                  },
                ),
          filled: true,
          fillColor: tk.cardBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
            borderSide: BorderSide(color: tk.accent, width: tk.ruleWidth),
          ),
        ),
      ),
    );
  }

  Widget _row(
    AppTokens tk,
    UiStrings t,
    ContentPackRepository packs,
    DeckEntry e,
    int deckIndex,
    StudyController study, {
    required bool isLast,
  }) {
    final bool locked = study.isLocked(e);
    final WordStatus status = study.statusOf(e.id);
    final String meaning = e.showsMeaning
        ? packs.translate(e.meaning)
        : (e.isBookWord ? t('tap to open') : '#${e.rank} · ${t('tap to open')}');

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              e.article != null ? '${e.article} ${e.word}' : e.word,
              style: TextStyle(
                  fontFamily: tk.fontHead,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: tk.ink),
            ),
            if (e.pos != null) ...<Widget>[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(border: Border.all(color: tk.faint)),
                child: Text(
                  t(e.pos!).toUpperCase(),
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                      color: tk.muted2),
                ),
              ),
            ],
            for (final String s in e.srcTags)
              if (s != 'general') SourceBadge(s),
            if (!locked)
              SpeakerButton(text: e.word, id: 'row-${e.id}', size: 26),
          ],
        ),
        Text(meaning, style: TextStyle(fontSize: 13, color: tk.muted)),
      ],
    );

    return InkWell(
      onTap: () {
        Haptics.tap();
        if (locked) {
          widget.onUpsell();
        } else {
          widget.onOpenWord(deckIndex, fromLearn: false);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: tk.line, width: 2),
            left: BorderSide(color: tk.line, width: 2),
            right: BorderSide(color: tk.line, width: 2),
            bottom: isLast
                ? BorderSide(color: tk.line, width: 2)
                : BorderSide.none,
          ),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: locked
                  ? Opacity(
                      opacity: 0.6,
                      child: ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                        child: content,
                      ),
                    )
                  : content,
            ),
            const SizedBox(width: 10),
            if (locked)
              Text('🔒', style: TextStyle(fontSize: 16, color: tk.ink))
            else
              StatusDot(switch (status) {
                WordStatus.learned => tk.blue,
                WordStatus.learning => tk.yellow,
                WordStatus.fresh => tk.paper,
              }),
          ],
        ),
      ),
    );
  }

  Widget _footer(AppTokens tk, UiStrings t, int total, WordsFilters f) {
    if (total == 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: EmptyPanel(message: t('No words match.')),
      );
    }
    if (total > f.limit) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: OutlineButton(
          label: t('Show more ({n} remaining)',
              <String, Object?>{'n': total - f.limit}),
          onPressed: () {
            Haptics.tap();
            ref.read(wordsFiltersProvider.notifier).state =
                f.copyWith(limit: f.limit + kListLimitIncrement);
          },
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Text(
        total == 1 ? t('1 word') : t('{n} words', <String, Object?>{'n': total}),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: tk.muted),
      ),
    );
  }

  List<int> _freeFirst(List<int> order, Deck deck, StudyController study) {
    if (order.length < 2) return order;
    final List<int> free = <int>[];
    final List<int> locked = <int>[];
    for (final int i in order) {
      (study.isLocked(deck[i]) ? locked : free).add(i);
    }
    if (free.isEmpty || locked.isEmpty) return order;
    return <int>[...free, ...locked];
  }
}

/// Dart's `sort` is not stable, and search ordering relies on frequency order
/// surviving inside each relevance tier, so we use an explicit merge sort.
void mergeSortInPlace<T>(List<T> list, int Function(T, T) compare) {
  if (list.length < 2) return;
  final List<T> sorted = _mergeSort(list, compare);
  for (int i = 0; i < list.length; i++) {
    list[i] = sorted[i];
  }
}

List<T> _mergeSort<T>(List<T> list, int Function(T, T) compare) {
  if (list.length < 2) return list;
  final int mid = list.length >> 1;
  final List<T> left = _mergeSort(list.sublist(0, mid), compare);
  final List<T> right = _mergeSort(list.sublist(mid), compare);
  final List<T> out = <T>[];
  int i = 0, j = 0;
  while (i < left.length && j < right.length) {
    // <= keeps the earlier element first, which is what makes this stable.
    out.add(compare(left[i], right[j]) <= 0 ? left[i++] : right[j++]);
  }
  while (i < left.length) {
    out.add(left[i++]);
  }
  while (j < right.length) {
    out.add(right[j++]);
  }
  return out;
}
