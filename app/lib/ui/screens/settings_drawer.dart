import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../data/i18n/ui_strings.dart';
import '../../models/deck_entry.dart';
import '../../models/enums.dart';
import '../../services/haptics.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';
import '../../state/settings_controller.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// The settings drawer: About, App language, Theme, Contact.
///
/// Sections are single-open accordions, matching the web build — expanding one
/// collapses the others so the drawer never runs out of room.
class SettingsDrawer extends ConsumerStatefulWidget {
  const SettingsDrawer({super.key, required this.onToast});
  final void Function(String message) onToast;

  @override
  ConsumerState<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends ConsumerState<SettingsDrawer> {
  String? _open;

  @override
  Widget build(BuildContext context) {
    final AppTokens tk = context.tokens;
    final UiStrings t = ref.watch(uiStringsProvider);

    return Drawer(
      backgroundColor: tk.paper,
      width: 340,
      shape: const RoundedRectangleBorder(),
      child: ThemedBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: tk.line, width: tk.ruleWidth)),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        tk.id == AppThemeId.sepia
                            ? t('Menu')
                            : t('Menu').toUpperCase(),
                        style: TextStyle(
                          fontFamily: tk.fontHead,
                          fontWeight:
                              tk.id == AppThemeId.sepia ? FontWeight.w400 : FontWeight.w900,
                          fontStyle: tk.id == AppThemeId.sepia
                              ? FontStyle.italic
                              : FontStyle.normal,
                          fontSize: tk.id == AppThemeId.sepia ? 20 : 18,
                          letterSpacing: 1,
                          color: tk.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: t('Close'),
                      icon: Icon(Icons.close, color: tk.ink),
                      onPressed: () {
                        Haptics.tap();
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  children: <Widget>[
                    _accordion('about', t('About the app'), _aboutBody(tk, t)),
                    _accordion('lang', t('App language'), _languageBody(tk, t)),
                    _accordion('theme', t('Theme'), _themeBody(tk)),
                    _accordion('contact', t('Contact us'), _contactBody(tk, t)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accordion(String id, String title, Widget body) {
    final AppTokens tk = context.tokens;
    final bool open = _open == id;
    return Container(
      margin: const EdgeInsets.only(top: 18),
      decoration: BoxDecoration(
        border: tk.ruleBorder,
        borderRadius: tk.cardRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            onTap: () {
              Haptics.tap();
              // Single-open: tapping a header collapses every other section.
              setState(() => _open = open ? null : id);
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        fontFamily: tk.fontHead,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 0.5,
                        color: tk.ink,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.25 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Text('›',
                        style: TextStyle(fontSize: 22, height: 1, color: tk.muted)),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: body,
            ),
            crossFadeState:
                open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 280),
          ),
        ],
      ),
    );
  }

  Widget _aboutBody(AppTokens tk, UiStrings t) {
    final Deck deck = ref.watch(deckProvider);
    TextStyle style = TextStyle(fontSize: 13, height: 1.5, color: tk.muted);

    Widget line(String icon, String label, String value) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: RichText(
            text: TextSpan(style: style, children: <InlineSpan>[
              TextSpan(text: '$icon '),
              TextSpan(
                  text: label,
                  style: style.copyWith(
                      fontWeight: FontWeight.w700, color: tk.ink)),
              TextSpan(text: ': $value'),
            ]),
          ),
        );

    final int essential = deck.countWithTag('essential');
    final int general = deck.countWithTag('general');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          t('Build your Dutch vocabulary in a structured way. This one-stop app shows all the details of a word — meaning, example sentences, grammar forms and synonyms — so learners can pick it up in a practical way.'),
          style: style,
        ),
        const SizedBox(height: 6),
        Text(
          t('The app has {n} common Dutch words, grouped by level:',
              <String, Object?>{'n': deck.length}),
          style: style,
        ),
        if (essential > 0)
          line('⭐', t('Essential'),
              t('{n} core everyday words.', <String, Object?>{'n': essential})),
        line('📚', 'General',
            t('{n} popular words.', <String, Object?>{'n': general})),
        for (final String src in kBookSources)
          if (deck.chaptersFor(src).isNotEmpty)
            line('📚', kSrcShort[src]!,
                '${t('{n} words', <String, Object?>{'n': deck.countWithTag(src)})}.'),
      ],
    );
  }

  Widget _languageBody(AppTokens tk, UiStrings t) {
    final SettingsState s = ref.watch(settingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (s.packDownloading)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: tk.blue),
                ),
                const SizedBox(width: 10),
                Text(t('Downloading language…'),
                    style: TextStyle(fontSize: 12, color: tk.muted)),
              ],
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final AppLanguage l in kLanguages)
              Tooltip(
                message: l.name,
                child: Material(
                  color: tk.cardBg,
                  borderRadius: tk.cardRadius,
                  child: InkWell(
                    borderRadius: tk.cardRadius,
                    onTap: s.packDownloading
                        ? null
                        : () async {
                            Haptics.tap();
                            final String? error = await ref
                                .read(settingsProvider.notifier)
                                .setLanguage(l.id);
                            if (error != null) widget.onToast(error);
                          },
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 52),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: tk.ruleBorder,
                        borderRadius: tk.cardRadius,
                        boxShadow: s.language == l.id
                            ? <BoxShadow>[
                                BoxShadow(
                                    color: tk.accent,
                                    blurRadius: 0,
                                    spreadRadius: 0,
                                    offset: Offset.zero),
                              ]
                            : null,
                      ),
                      foregroundDecoration: s.language == l.id
                          ? BoxDecoration(
                              border: Border.all(color: tk.accent, width: 3),
                              borderRadius: tk.cardRadius,
                            )
                          : null,
                      child: Text(
                        l.code,
                        style: TextStyle(
                          fontFamily: tk.fontHead,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 1,
                          color: tk.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          t('Some languages may not be fully translated. English is used where a translation is missing.'),
          style: TextStyle(fontSize: 12, height: 1.4, color: tk.muted),
        ),
      ],
    );
  }

  Widget _themeBody(AppTokens tk) {
    final SettingsState s = ref.watch(settingsProvider);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final AppThemeId id in AppThemeId.values)
          Tooltip(
            message: id.displayName,
            child: Semantics(
              label: id.displayName,
              button: true,
              child: InkWell(
                borderRadius: tk.cardRadius,
                onTap: () {
                  Haptics.tap();
                  ref.read(settingsProvider.notifier).setTheme(id);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: tk.ruleBorder,
                    borderRadius: tk.cardRadius,
                  ),
                  foregroundDecoration: s.theme == id
                      ? BoxDecoration(
                          border: Border.all(color: tk.accent, width: 3),
                          borderRadius: tk.cardRadius,
                        )
                      : null,
                  child: Container(
                    width: 44,
                    height: 24,
                    decoration: BoxDecoration(
                      border: Border.all(color: tk.line, width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      children: <Widget>[
                        for (final Color c in AppTheme.swatches(id))
                          Expanded(child: ColoredBox(color: c)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _contactBody(AppTokens tk, UiStrings t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          t('Found a wrong translation, a bug, or have an idea? We would like to hear it.'),
          style: TextStyle(fontSize: 13, height: 1.5, color: tk.muted),
        ),
        const SizedBox(height: 12),
        GenButton(
          label: t('Send feedback'),
          alt: true,
          onPressed: () async {
            Haptics.tap();
            final Uri uri = Uri(
              scheme: 'mailto',
              path: _supportAddress,
              queryParameters: <String, String>{
                'subject': 'Dutch To Go — ${t('General feedback')}',
              },
            );
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            } else {
              widget.onToast(t('No email app is set up on this device.'));
            }
          },
        ),
      ],
    );
  }

  /// Assembled at use time rather than sitting as one scrapable literal.
  String get _supportAddress => <String>['whiskeyneat3060', 'gmail.com'].join('@');
}
