import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/i18n/ui_strings.dart';
import '../models/enums.dart';
import '../models/user_profile.dart';
import '../services/haptics.dart';
import '../state/app_state.dart';
import '../state/providers.dart';
import '../state/settings_controller.dart';
import '../state/study_controller.dart';
import 'screens/learn_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/settings_drawer.dart';
import 'screens/word_detail_screen.dart';
import 'screens/words_screen.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'widgets/common.dart';

/// The app frame: header, tabs and the four views.
///
/// Nav placement is a theme decision, not a fixed choice — Minimalistic puts
/// filled tabs at the top, Midnight floats a pill above the bottom edge, and
/// Sepia uses centred running-head text.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _tab = 0; // 0 learn, 1 words, 2 progress, 3 profile
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<ProfileScreenState> _profileKey = GlobalKey<ProfileScreenState>();

  @override
  void initState() {
    super.initState();
    // Celebrate the daily goal exactly once, when it is reached.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(studyProvider.notifier).goalReached.addListener(_onGoalReached);
    });
  }

  @override
  void dispose() {
    ref.read(studyProvider.notifier).goalReached.removeListener(_onGoalReached);
    super.dispose();
  }

  void _onGoalReached() {
    final SettingsState s = ref.read(settingsProvider);
    final int perDay = s.plan?.perDay ?? 0;
    if (perDay <= 0) return;
    Haptics.celebrate();
    _toast('🎉 ${ref.read(uiStringsProvider)('Daily goal reached: {n} words!', <String, Object?>{'n': perDay})}');
  }

  void _toast(String message) {
    if (!mounted) return;
    final AppTokens tk = context.tokens;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        duration: const Duration(milliseconds: 2600),
        backgroundColor: tk.ink,
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: tk.navPlacement == NavPlacement.bottomPill ? 90 : 16,
        ),
      ));
  }

  void _openWord(int deckIndex, {required bool fromLearn}) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => WordDetailScreen(
        deckIndex: deckIndex,
        onUpsell: _openUpsell,
        onToast: _toast,
      ),
    ));
  }

  /// Every lock overlay routes here: switch to Profile and flash the Pro card.
  Future<void> _openUpsell() async {
    setState(() => _tab = 3);
    await WidgetsBinding.instance.endOfFrame;
    await _profileKey.currentState?.flashProCard();
  }

  void _setTab(int i) {
    Haptics.tap();
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tk = context.tokens;
    final UiStrings t = ref.watch(uiStringsProvider);

    final Widget body = switch (_tab) {
      0 => LearnScreen(
          onOpenWord: _openWord,
          onUpsell: _openUpsell,
          onToast: _toast,
        ),
      1 => WordsScreen(
          onOpenWord: _openWord,
          onUpsell: _openUpsell,
          onToast: _toast,
        ),
      2 => ProgressScreen(
          onOpenWord: _openWord,
          onUpsell: _openUpsell,
          onStartReview: () async {
            await ref.read(studyProvider.notifier).startReview();
            setState(() => _tab = 0);
          },
          onDrillLeeches: () async {
            await ref.read(studyProvider.notifier).startLeechDrill();
            setState(() => _tab = 0);
          },
          onFilterByPos: (String pos) {
            ref.read(wordsFiltersProvider.notifier).state =
                WordsFilters(pos: <String>[pos]);
            setState(() => _tab = 1);
          },
          onFilterBySource: (String src) {
            ref.read(wordsFiltersProvider.notifier).state =
                WordsFilters(source: <String>[src]);
            setState(() => _tab = 1);
          },
        ),
      _ => ProfileScreen(key: _profileKey, onToast: _toast),
    };

    final bool bottomNav = tk.navPlacement == NavPlacement.bottomPill;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: tk.paper,
      drawer: SettingsDrawer(onToast: _toast),
      drawerScrimColor: tk.scrim,
      body: ThemedBackground(
        child: SafeArea(
          bottom: !bottomNav,
          child: Stack(
            children: <Widget>[
              Column(
                children: <Widget>[
                  _header(tk, t),
                  if (!bottomNav) _navBar(tk, t),
                  Expanded(
                    child: PageBody(child: body),
                  ),
                ],
              ),
              if (bottomNav)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 14,
                  child: Center(child: _navBar(tk, t)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- header ---

  Widget _header(AppTokens tk, UiStrings t) {
    final UserProfile? profile = ref.watch(userProfileProvider).value;
    final int learned = ref.watch(studyProvider.notifier).counts.learned;
    ref.watch(studyProvider);

    final Widget menuButton = IconButton(
      tooltip: t('Menu'),
      icon: Icon(Icons.menu, color: tk.ink),
      onPressed: () {
        Haptics.tap();
        _scaffoldKey.currentState?.openDrawer();
      },
    );

    final Widget wordmark = RichText(
      text: TextSpan(children: <InlineSpan>[
        TextSpan(
          text: 'DUTCH ',
          style: TextStyle(
            fontFamily: tk.fontHead,
            fontWeight: tk.id == AppThemeId.sepia ? FontWeight.w400 : FontWeight.w900,
            fontSize: tk.id == AppThemeId.sepia ? 26 : 20,
            letterSpacing: tk.id == AppThemeId.sepia ? 0.5 : -0.5,
            color: tk.ink,
          ),
        ),
        TextSpan(
          text: 'to go',
          style: TextStyle(
            fontFamily: tk.fontHead,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            fontSize: tk.id == AppThemeId.sepia ? 26 : 20,
            color: tk.id == AppThemeId.sepia ? tk.accent : tk.red,
          ),
        ),
      ]),
    );

    final Widget avatar = _avatarButton(tk, t, profile);

    if (tk.centeredHeader) {
      // Sepia: a centred title page with the menu pinned to the corner.
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: tk.line, width: tk.ruleWidth)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Column(
              children: <Widget>[
                wordmark,
                const SizedBox(height: 3),
                _counter(tk, t, learned, centred: true),
              ],
            ),
            Positioned(left: 0, child: menuButton),
            Positioned(right: 0, child: avatar),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
          8, tk.id == AppThemeId.midnight ? 12 : 8, 12, 8),
      decoration: BoxDecoration(
        border: tk.id == AppThemeId.midnight
            ? null
            : Border(bottom: BorderSide(color: tk.line, width: tk.ruleWidth)),
      ),
      child: Row(
        children: <Widget>[
          menuButton,
          const SizedBox(width: 4),
          Expanded(child: wordmark),
          _counter(tk, t, learned),
          const SizedBox(width: 12),
          avatar,
        ],
      ),
    );
  }

  Widget _counter(AppTokens tk, UiStrings t, int learned, {bool centred = false}) {
    return Column(
      crossAxisAlignment:
          centred ? CrossAxisAlignment.center : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          t('Words learned').toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            letterSpacing: centred ? 2 : 1,
            color: tk.muted,
          ),
        ),
        Text(
          '$learned',
          style: TextStyle(
            fontFamily: tk.fontHead,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            height: 1.2,
            color: tk.ink,
          ),
        ),
      ],
    );
  }

  Widget _avatarButton(AppTokens tk, UiStrings t, UserProfile? profile) {
    final bool onProfile = _tab == 3;
    final bool signedIn = profile != null;
    final bool isPro = profile?.isPro ?? false;

    return Semantics(
      button: true,
      label: t('Profile'),
      child: InkResponse(
        onTap: () => _setTab(3),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isPro ? tk.yellow : (signedIn ? tk.blue : tk.cardBg),
            border: Border.all(
              color: onProfile ? tk.accent : (signedIn && !isPro ? tk.blue : tk.line),
              width: onProfile ? 3 : 2,
            ),
          ),
          child: signedIn
              ? Text(
                  profile.initials,
                  style: TextStyle(
                    fontFamily: tk.fontHead,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isPro ? tk.yellowText : Colors.white,
                  ),
                )
              : Text('👤', style: TextStyle(fontSize: 15, color: tk.ink)),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ nav ---

  Widget _navBar(AppTokens tk, UiStrings t) {
    final List<String> labels = <String>[
      t('Learn'),
      t('Words'),
      t('Progress'),
    ];

    switch (tk.navPlacement) {
      case NavPlacement.bottomPill:
        return Container(
          width: 440,
          constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.92),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: tk.cardBg.withValues(alpha: 0.9),
            border: Border.all(color: tk.line),
            borderRadius: BorderRadius.circular(22),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0x8C000000), blurRadius: 36, offset: Offset(0, 14)),
            ],
          ),
          child: Row(
            children: <Widget>[
              for (int i = 0; i < labels.length; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => _setTab(i),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: _tab == i
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: <Color>[Color(0xFF6C8CFF), Color(0xFF8A6BFF)],
                              )
                            : null,
                        boxShadow: _tab == i
                            ? const <BoxShadow>[
                                BoxShadow(
                                    color: Color(0x6B6C8CFF),
                                    blurRadius: 18,
                                    offset: Offset(0, 6)),
                              ]
                            : null,
                      ),
                      child: Text(
                        labels[i].toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: tk.fontHead,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.4,
                          color: _tab == i ? Colors.white : tk.muted,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );

      case NavPlacement.runningHead:
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tk.line)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              for (int i = 0; i < labels.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: GestureDetector(
                    onTap: () => _setTab(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _tab == i ? tk.accent : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontFamily: tk.fontHead,
                          fontWeight: FontWeight.w400,
                          fontStyle:
                              _tab == i ? FontStyle.italic : FontStyle.normal,
                          fontSize: 15,
                          letterSpacing: 0.4,
                          color: _tab == i ? tk.ink : tk.muted,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );

      case NavPlacement.topTabs:
        return Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tk.line, width: tk.ruleWidth)),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: <Widget>[
                for (int i = 0; i < labels.length; i++) ...<Widget>[
                  if (i > 0)
                    VerticalDivider(
                        width: tk.ruleWidth, thickness: tk.ruleWidth, color: tk.line),
                  Expanded(
                    child: Material(
                      color: _tab == i ? tk.ink : tk.paper,
                      child: InkWell(
                        onTap: () => _setTab(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 4),
                          child: Text(
                            labels[i].toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: tk.fontHead,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: 1,
                              color: _tab == i ? tk.paper : tk.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
    }
  }
}
