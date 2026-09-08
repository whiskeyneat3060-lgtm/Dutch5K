import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../data/firebase/auth_repository.dart';
import '../../data/firebase/iap_repository.dart';
import '../../data/i18n/ui_strings.dart';
import '../../domain/dates.dart';
import '../../domain/goal.dart';
import '../../models/deck_entry.dart';
import '../../models/enums.dart';
import '../../models/study_plan.dart';
import '../../models/user_profile.dart';
import '../../services/haptics.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';
import '../../state/settings_controller.dart';
import '../../state/study_controller.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'auth_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, required this.onToast});
  final void Function(String message) onToast;

  @override
  ConsumerState<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends ConsumerState<ProfileScreen> {
  final GlobalKey _proKey = GlobalKey();
  final TextEditingController _goalInput = TextEditingController();
  bool _flashPro = false;

  @override
  void dispose() {
    _goalInput.dispose();
    super.dispose();
  }

  /// Scrolls the Pro card into view and flashes it — the target of every
  /// lock overlay.
  Future<void> flashProCard() async {
    final BuildContext? ctx = _proKey.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 300), alignment: 0.3);
    }
    if (!mounted) return;
    setState(() => _flashPro = true);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) setState(() => _flashPro = false);
  }

  @override
  Widget build(BuildContext context) {
    final UiStrings t = ref.watch(uiStringsProvider);
    final AppTokens tk = context.tokens;
    final User? user = ref.watch(authStateProvider).value;
    final UserProfile? profile = ref.watch(userProfileProvider).value;

    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Text(
            t('Profile'),
            style: TextStyle(
              fontFamily: tk.fontHead,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: tk.ink,
            ),
          ),
        ),
        if (user == null) _signedOutCard(tk, t) else _signedInCard(tk, t, profile),
        _proCard(tk, t, profile),
        _goalBox(tk, t),
        _studyPlanBox(tk, t),
      ],
    );
  }

  // -------------------------------------------------------------- account ---

  Widget _signedOutCard(AppTokens tk, UiStrings t) {
    return GenBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: tk.grey),
              child: Text('👤', style: TextStyle(fontSize: 26, color: tk.muted)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            t('Save your progress'),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: tk.fontHead,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: tk.ink),
          ),
          const SizedBox(height: 8),
          Text(
            t('Create an account or log in so your progress and Pro plan live in your account — not just on this device.'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.5, color: tk.muted),
          ),
          const SizedBox(height: 14),
          GenButton(
            label: t('Sign in or create an account'),
            alt: true,
            onPressed: () {
              Haptics.tap();
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => AuthScreen(onToast: widget.onToast),
              ));
            },
          ),
        ],
      ),
    );
  }

  Widget _signedInCard(AppTokens tk, UiStrings t, UserProfile? profile) {
    final StudyController study = ref.read(studyProvider.notifier);
    final String provider = switch (profile?.provider) {
      'google.com' => 'Google',
      'apple.com' => 'Apple',
      _ => t('Email'),
    };

    return Column(
      children: <Widget>[
        GenBox(
          child: Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (profile?.isPro ?? false) ? tk.yellow : tk.blue,
                  border: (profile?.isPro ?? false)
                      ? Border.all(color: tk.ink, width: 2)
                      : null,
                ),
                child: Text(
                  profile?.initials ?? '?',
                  style: TextStyle(
                    fontFamily: tk.fontHead,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: (profile?.isPro ?? false) ? tk.yellowText : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      profile?.shortName ?? '',
                      style: TextStyle(
                          fontFamily: tk.fontHead,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          height: 1.2,
                          color: tk.ink),
                    ),
                    Text(
                      profile?.email ?? '',
                      style: TextStyle(fontSize: 13, color: tk.muted),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${t('Signed in with {p}', <String, Object?>{'p': provider})}'
                      '${profile?.createdAt != null ? ' · ${t('Member since {d}', <String, Object?>{
                              'd': DateFormat.yMMM(_locale).format(profile!.createdAt!)
                            })}' : ''}',
                      style: TextStyle(
                          fontSize: 11, letterSpacing: 0.5, color: tk.muted2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        GenBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _profileRow(tk, t('Plan'),
                  (profile?.isPro ?? false) ? '👑 ${t('Pro')}' : t('Free'),
                  highlight: profile?.isPro ?? false),
              _profileRow(tk, t('Words learned'), '${study.counts.learned}',
                  last: true),
              const SizedBox(height: 6),
              NoteText(t('Your progress is saved to your account and syncs to your other devices.')),
              const SizedBox(height: 12),
              OutlineButton(
                label: t('Sign out'),
                onPressed: () => _confirmSignOut(t),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _confirmDeleteAccount(t),
                child: Text(
                  t('Delete my account'),
                  style: TextStyle(fontSize: 13, color: tk.red),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String? get _locale {
    final String l = ref.read(settingsProvider).language;
    return l == 'en' ? null : l;
  }

  Widget _profileRow(AppTokens tk, String label, String value,
      {bool highlight = false, bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: tk.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: TextStyle(fontSize: 14, color: tk.ink)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: highlight ? tk.blue : tk.ink,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(UiStrings t) async {
    final bool? keep = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(t('Sign out')),
        content: Text(t('Your progress is saved to your account. Keep a copy on this device too?')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(t('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t('Remove from device')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t('Keep on device')),
          ),
        ],
      ),
    );
    if (keep == null) return;

    final StudyController study = ref.read(studyProvider.notifier);
    await study.pushSync();
    if (!keep) await study.clearLocal();
    await ref.read(authRepositoryProvider).signOut();
    widget.onToast(t('Signed out.'));
  }

  Future<void> _confirmDeleteAccount(UiStrings t) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(t('Delete my account')),
        content: Text(t('This permanently deletes your account and all synced progress. This cannot be undone.')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t('Delete'),
                style: TextStyle(color: context.tokens.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(studyProvider.notifier).clearLocal();
      await ref.read(authRepositoryProvider).deleteAccount();
      widget.onToast(t('Your account has been deleted.'));
    } on AuthFailure catch (e) {
      widget.onToast(e.message);
    }
  }

  // ------------------------------------------------------------------ Pro ---

  Widget _proCard(AppTokens tk, UiStrings t, UserProfile? profile) {
    final bool isPro = profile?.isPro ?? false;
    final IapRepository iap = ref.watch(iapProvider);
    final bool signedIn = ref.watch(authStateProvider).value != null;

    return ValueListenableBuilder<ProPurchaseStatus>(
      valueListenable: iap.status,
      builder: (BuildContext context, ProPurchaseStatus status, _) {
        return AnimatedContainer(
          key: _proKey,
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            borderRadius: tk.cardRadius,
            boxShadow: _flashPro
                ? <BoxShadow>[BoxShadow(color: tk.red, blurRadius: 0, spreadRadius: 3)]
                : const <BoxShadow>[],
          ),
          child: GenBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Text('👑', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      t('Pro to go').toUpperCase(),
                      style: TextStyle(
                          fontFamily: tk.fontHead,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          letterSpacing: 1,
                          color: tk.ink),
                    ),
                    const Spacer(),
                    if (isPro)
                      Text('✓ ${t('Active')}',
                          style: TextStyle(
                              fontSize: 12, letterSpacing: 1, color: tk.blue)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isPro
                      ? t('You have full access to every word, list and stat.')
                      : t('Go Pro for full access to every word across all levels, the complete word list and all progress stats.'),
                  style: TextStyle(fontSize: 13, height: 1.5, color: tk.muted),
                ),
                if (!isPro) ...<Widget>[
                  const SizedBox(height: 12),
                  if (status.isBusy)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: tk.blue),
                        ),
                      ),
                    )
                  else
                    GenButton(
                      label: signedIn
                          ? (iap.priceLabel != null
                              ? '${t('Get Pro')} · ${iap.priceLabel}'
                              : t('Get Pro'))
                          : t('Sign in to get Pro'),
                      onPressed: () async {
                        Haptics.tap();
                        if (!signedIn) {
                          await Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => AuthScreen(onToast: widget.onToast),
                          ));
                          return;
                        }
                        await iap.buy();
                      },
                    ),
                  const SizedBox(height: 8),
                  OutlineButton(
                    label: t('Restore purchases'),
                    dense: true,
                    onPressed: () {
                      Haptics.tap();
                      iap.restore();
                    },
                  ),
                  if (status.message != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      status.message!,
                      style: TextStyle(
                        fontSize: 12,
                        color: status.state == PurchaseState.failed ? tk.red : tk.muted,
                      ),
                    ),
                  ],
                  if (!signedIn) ...<Widget>[
                    const SizedBox(height: 8),
                    NoteText(
                      t('Pro is tied to your account, so it follows you to every device.'),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // --------------------------------------------------------- learning goal ---

  Widget _goalBox(AppTokens tk, UiStrings t) {
    final Deck deck = ref.watch(deckProvider);
    final SettingsState s = ref.watch(settingsProvider);
    final StudyController study = ref.read(studyProvider.notifier);
    ref.watch(studyProvider);

    final int total = Goal.total(
      deck: deck,
      state: study.study,
      mode: s.goalMode,
      wordGoal: s.wordGoal,
      goalSources: s.goalSources,
    );
    final int learned = Goal.learned(
      deck: deck,
      state: study.study,
      mode: s.goalMode,
      goalSources: s.goalSources,
      counts: study.counts,
    );
    final NumberFormat nf = NumberFormat.decimalPattern(_locale);
    final List<int> presets =
        kGoalPresets.where((int n) => n < deck.length).toList();

    String compact(int n) => n >= 1000
        ? (n % 1000 == 0 ? '${n ~/ 1000}K' : '${(n / 1000).toStringAsFixed(1)}K')
        : '$n';

    return GenBox(
      title: '🎯 ${t('Learning goal')}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            t('Set a target — a number of words, or specific sources to finish. Your progress percentage and daily plan are measured against it.'),
            style: TextStyle(fontSize: 13, height: 1.5, color: tk.muted),
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(children: <InlineSpan>[
              TextSpan(
                text: nf.format(learned),
                style: TextStyle(
                    fontFamily: tk.fontHead,
                    fontWeight: FontWeight.w900,
                    fontSize: 36,
                    height: 1,
                    color: tk.ink),
              ),
              TextSpan(
                text: ' / ${nf.format(total)}',
                style: TextStyle(fontSize: 18, color: tk.muted2),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
            _chip(tk, t('By word count'), s.goalMode == GoalMode.count,
                () => ref.read(settingsProvider.notifier).setGoalMode(GoalMode.count),
                wide: true),
            _chip(tk, t('By source'), s.goalMode == GoalMode.source,
                () => ref.read(settingsProvider.notifier).setGoalMode(GoalMode.source),
                wide: true),
          ]),
          const SizedBox(height: 14),
          if (s.goalMode == GoalMode.source)
            ..._sourceGoalBody(tk, t, deck, s, nf)
          else
            ..._countGoalBody(tk, t, deck, s, presets, compact, nf),
        ],
      ),
    );
  }

  List<Widget> _countGoalBody(
    AppTokens tk,
    UiStrings t,
    Deck deck,
    SettingsState s,
    List<int> presets,
    String Function(int) compact,
    NumberFormat nf,
  ) {
    return <Widget>[
      _label(tk, t('Words to learn')),
      const SizedBox(height: 6),
      Row(
        children: <Widget>[
          for (final int n in presets) ...<Widget>[
            Expanded(
              child: _chip(tk, compact(n), s.wordGoal == n,
                  () => ref.read(settingsProvider.notifier).setWordGoal(n)),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: _chip(tk, t('All').toUpperCase(), s.wordGoal == null,
                () => ref.read(settingsProvider.notifier).setWordGoal(null)),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _label(tk, t('Or enter an exact number')),
      const SizedBox(height: 6),
      TextField(
        controller: _goalInput,
        keyboardType: TextInputType.number,
        style: TextStyle(fontSize: 14, color: tk.ink),
        decoration: InputDecoration(
          hintText: '${deck.length}',
          hintStyle: TextStyle(color: tk.muted2),
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
        ),
        onSubmitted: (_) => _saveGoalFromInput(t, deck),
      ),
      const SizedBox(height: 10),
      GenButton(label: t('Set goal'), onPressed: () => _saveGoalFromInput(t, deck)),
      if (s.wordGoal != null) ...<Widget>[
        const SizedBox(height: 8),
        OutlineButton(
          label: t('Learn all {n} words',
              <String, Object?>{'n': nf.format(deck.length)}),
          dense: true,
          onPressed: () {
            Haptics.tap();
            ref.read(settingsProvider.notifier).setWordGoal(null);
            widget.onToast(t('Goal reset to all {n} words',
                <String, Object?>{'n': nf.format(deck.length)}));
          },
        ),
      ],
    ];
  }

  void _saveGoalFromInput(UiStrings t, Deck deck) {
    Haptics.tap();
    final int? n = int.tryParse(_goalInput.text.trim());
    if (n == null || n < 1) {
      widget.onToast(t('Enter how many words you want to learn.'));
      return;
    }
    final int capped = n > deck.length ? deck.length : n;
    ref.read(settingsProvider.notifier).setWordGoal(capped);
    _goalInput.clear();
    FocusScope.of(context).unfocus();
    widget.onToast(t('Goal set: {n} words.', <String, Object?>{'n': capped}));
  }

  List<Widget> _sourceGoalBody(
    AppTokens tk,
    UiStrings t,
    Deck deck,
    SettingsState s,
    NumberFormat nf,
  ) {
    final List<String> sources = deck.presentSources;
    final int picked = Goal.sourceList(deck, s.goalSources).length;
    return <Widget>[
      _label(tk, t('Learn every word from the sources you choose')),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final String src in sources)
            _chip(tk, kSrcShort[src] ?? src, s.goalSources.contains(src),
                () => ref.read(settingsProvider.notifier).toggleGoalSource(src),
                wide: true),
        ],
      ),
      const SizedBox(height: 10),
      NoteText(picked > 0
          ? t('Goal: learn all {n} words in the selected {c} source(s).',
              <String, Object?>{
                'n': nf.format(Goal.total(
                  deck: deck,
                  state: ref.read(studyProvider.notifier).study,
                  mode: GoalMode.source,
                  wordGoal: null,
                  goalSources: s.goalSources,
                )),
                'c': picked,
              })
          : t('Pick one or more sources above to set your goal.')),
    ];
  }

  Widget _label(AppTokens tk, String s) => Text(
        s.toUpperCase(),
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: tk.muted),
      );

  Widget _chip(AppTokens tk, String label, bool active, VoidCallback onTap,
      {bool wide = false}) {
    return Material(
      color: active ? tk.blue : tk.paper,
      borderRadius: tk.cardRadius,
      child: InkWell(
        borderRadius: tk.cardRadius,
        onTap: () {
          Haptics.tap();
          onTap();
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: wide ? 16 : 10, vertical: 12),
          decoration: BoxDecoration(
            border: tk.ruleBorder,
            borderRadius: tk.cardRadius,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: tk.fontHead,
              fontWeight: wide ? FontWeight.w800 : FontWeight.w900,
              fontSize: wide ? 14 : 15,
              height: 1.15,
              color: active ? Colors.white : tk.ink,
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------- study plan ---

  Widget _studyPlanBox(AppTokens tk, UiStrings t) {
    final SettingsState s = ref.watch(settingsProvider);
    final StudyController study = ref.read(studyProvider.notifier);
    final Deck deck = ref.watch(deckProvider);
    ref.watch(studyProvider);

    final StudyPlan? plan = s.plan;
    final NumberFormat nf = NumberFormat.decimalPattern(_locale);

    final List<Widget> inner;
    if (plan == null) {
      inner = <Widget>[
        Text(
          t('Pick how many words to learn per day (or a target date), and the app tracks your streak and shows exactly how many to do each day.'),
          style: TextStyle(fontSize: 13, height: 1.5, color: tk.muted),
        ),
        const SizedBox(height: 12),
        _label(tk, t('Words per day')),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            for (final (int i, int n) in kPlanPresets.indexed) ...<Widget>[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: _chip(tk, '$n', false, () {
                  ref.read(settingsProvider.notifier).setPlan(
                        StudyPlan(perDay: n, startDate: todayStr()),
                      );
                }),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        OutlineButton(
          label: t('Or reach a target date'),
          dense: true,
          onPressed: () => _pickTargetDate(t),
        ),
      ];
    } else {
      final int goalTotal = Goal.total(
        deck: deck,
        state: study.study,
        mode: s.goalMode,
        wordGoal: s.wordGoal,
        goalSources: s.goalSources,
      );
      final int goalLearned = Goal.learned(
        deck: deck,
        state: study.study,
        mode: s.goalMode,
        goalSources: s.goalSources,
        counts: study.counts,
      );
      final int remaining = (goalTotal - goalLearned).clamp(0, goalTotal);

      String eta = '';
      int perDayTarget = plan.perDay;
      if (plan.endDate != null) {
        final int daysLeft = daysBetween(todayStr(), plan.endDate!);
        final int safeDays = daysLeft < 1 ? 1 : daysLeft;
        perDayTarget = (remaining / safeDays).ceil();
        eta = t('To hit {goal} by {date}, learn about {n}/day ({d} days left).',
            <String, Object?>{
              'goal': nf.format(goalTotal),
              'date': DateFormat.MMMd(_locale).format(parseDay(plan.endDate!)),
              'n': perDayTarget,
              'd': safeDays,
            });
      } else if (plan.perDay > 0) {
        final int days = (remaining / plan.perDay).ceil();
        eta = t("At {n}/day you'll reach {goal} in about {d} days (~{date}).",
            <String, Object?>{
              'n': plan.perDay,
              'goal': nf.format(goalTotal),
              'd': days,
              'date': DateFormat.yMMMd(_locale)
                  .format(DateTime.now().add(Duration(days: days))),
            });
      }
      if (perDayTarget < 1) perDayTarget = 10;

      final int done = study.todayCount;
      final double pct = (done / perDayTarget).clamp(0, 1).toDouble();

      inner = <Widget>[
        RichText(
          text: TextSpan(children: <InlineSpan>[
            TextSpan(
              text: '$done',
              style: TextStyle(
                  fontFamily: tk.fontHead,
                  fontWeight: FontWeight.w900,
                  fontSize: 36,
                  height: 1,
                  color: tk.ink),
            ),
            TextSpan(
              text: ' / $perDayTarget',
              style: TextStyle(fontSize: 18, color: tk.muted2),
            ),
          ]),
        ),
        const SizedBox(height: 4),
        Text(t('words today').toUpperCase(),
            style: TextStyle(fontSize: 10, letterSpacing: 1, color: tk.muted)),
        const SizedBox(height: 10),
        Container(
          height: 14,
          decoration: BoxDecoration(border: Border.all(color: tk.line, width: 2)),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: pct,
            child: ColoredBox(color: tk.blue),
          ),
        ),
        if (eta.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text(eta, style: TextStyle(fontSize: 13, height: 1.5, color: tk.muted)),
        ],
        const SizedBox(height: 10),
        if (done >= perDayTarget)
          Text('✓ ${t('Daily goal complete — nice work!')}',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: tk.blue))
        else
          GenButton(
            label: '${t('Study now')} →',
            alt: true,
            onPressed: () {
              Haptics.tap();
              DefaultTabController.maybeOf(context)?.animateTo(0);
              widget.onToast(t('Study now'));
            },
          ),
        const SizedBox(height: 10),
        OutlineButton(
          label: t('Remove'),
          dense: true,
          onPressed: () {
            Haptics.tap();
            ref.read(settingsProvider.notifier).setPlan(null);
          },
        ),
      ];
    }

    return GenBox(
      title: '📅 ${t('Study plan')}',
      borderWidthOverride: tk.ruleWidth == 3 ? 3 : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ...inner,
          _reminderBlock(tk, t, s),
        ],
      ),
    );
  }

  Future<void> _pickTargetDate(UiStrings t) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked == null) return;
    await ref.read(settingsProvider.notifier).setPlan(
          StudyPlan(perDay: 0, endDate: dateStr(picked), startDate: todayStr()),
        );
  }

  Widget _reminderBlock(AppTokens tk, UiStrings t, SettingsState s) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: tk.line))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          OutlineButton(
            label: s.remindOn
                ? '✓ ${t('Daily reminders on')}'
                : '🔔 ${t('Turn on daily reminders')}',
            onPressed: () async {
              Haptics.tap();
              final SettingsController sc = ref.read(settingsProvider.notifier);
              if (s.remindOn) {
                await sc.disableReminders();
                widget.onToast(t('Daily reminders off'));
              } else {
                final String? error = await sc.enableReminders();
                widget.onToast(error ?? t('Daily reminders on'));
              }
            },
          ),
          if (s.remindOn) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Text(t('Reminder time').toUpperCase(),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: tk.muted)),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => _pickReminderTime(t, s),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tk.ink,
                    side: BorderSide(color: tk.line, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: tk.cardRadius),
                  ),
                  child: Text(s.remindTime),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<String>(
              future: ref.read(notificationsProvider).localTimezone(),
              builder: (BuildContext context, AsyncSnapshot<String> snap) {
                final String tz = snap.data ?? '';
                return NoteText(tz.isEmpty
                    ? t('Reminders fire once a day, even when the app is closed.')
                    : '${t('Times are in your device timezone ({tz}).', <String, Object?>{'tz': tz})} '
                        '${t('Reminders fire once a day, even when the app is closed.')}');
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickReminderTime(UiStrings t, SettingsState s) async {
    final List<String> parts = s.remindTime.split(':');
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 19,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      ),
    );
    if (picked == null) return;
    final String hhmm =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    await ref.read(settingsProvider.notifier).setRemindTime(hhmm);
    widget.onToast(t('Reminder time set'));
  }
}

/// Apple sign-in is only offered where the platform supports it.
bool get appleAvailable => Platform.isIOS || Platform.isMacOS;
