import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/enums.dart';
import 'tokens.dart';

/// Builds the three complete themes. Colour values are verbatim from
/// BUILD-SPEC 3.2; the structural fields carry the layout differences that make
/// each theme a different design rather than a repaint.
class AppTheme {
  const AppTheme._();

  // --------------------------------------------------------- Minimalistic ---
  /// Mondrian: black rules, primary blocks, sharp corners, tabs on top.
  static const AppTokens minimalistic = AppTokens(
    id: AppThemeId.minimalistic,
    ink: Color(0xFF111111),
    paper: Color(0xFFFFFFFF),
    grey: Color(0xFFF2F2EF),
    red: Color(0xFFDD0100),
    blue: Color(0xFF225095),
    yellow: Color(0xFFFAC901),
    green: Color(0xFF0B7A3B),
    purple: Color(0xFF6A2C91),
    line: Color(0xFF111111),
    ruleWidth: 3,
    muted: Color(0xFF666666),
    muted2: Color(0xFF999999),
    faint: Color(0xFFCCCCCC),
    radius: 0,
    cardBg: Color(0xFFFFFFFF),
    shadow: <BoxShadow>[],
    accent: Color(0xFFDD0100),
    fontHead: 'Archivo',
    fontBody: 'Inter',
    navPlacement: NavPlacement.topTabs,
    cardStyle: CardStyle.boxed,
    pageMaxWidth: 640,
    pagePadding: EdgeInsets.fromLTRB(16, 16, 16, 48),
    headwordSize: 44,
    headwordItalic: false,
    headwordWeight: FontWeight.w900,
    headwordLetterSpacing: -1,
    centeredHeader: false,
    uppercaseNav: true,
    scrim: Color(0x73000000), // rgba(0,0,0,.45)
    overlayWash: Color(0x99FFFFFF), // rgba(255,255,255,.6)
    statusBarColor: Color(0xFFFFFFFF),
    histLevel1: Color(0xFFBBCCDD),
    histLevel2: Color(0xFF66BB99),
    yellowText: Color(0xFF111111),
  );

  // -------------------------------------------------------------- Midnight ---
  /// Dark mobile app: rounded glowing cards, ambient gradient, floating pill nav.
  static const AppTokens midnight = AppTokens(
    id: AppThemeId.midnight,
    ink: Color(0xFFE8EBF7),
    paper: Color(0xFF0D0E15),
    grey: Color(0xFF1A1C2B),
    red: Color(0xFFFF6B81),
    blue: Color(0xFF6C8CFF),
    yellow: Color(0xFFFFD166),
    green: Color(0xFF57D38A),
    purple: Color(0xFFB18CFF),
    line: Color(0xFF2A2D42),
    ruleWidth: 1,
    muted: Color(0xFFA2A8C4),
    muted2: Color(0xFF767C9C),
    faint: Color(0xFF2A2D42),
    radius: 18,
    cardBg: Color(0xFF161829),
    shadow: <BoxShadow>[
      BoxShadow(color: Color(0x73000000), blurRadius: 30, offset: Offset(0, 10)),
    ],
    accent: Color(0xFF6C8CFF),
    fontHead: 'Inter',
    fontBody: 'Inter',
    navPlacement: NavPlacement.bottomPill,
    cardStyle: CardStyle.soft,
    pageMaxWidth: 640,
    pagePadding: EdgeInsets.fromLTRB(16, 16, 16, 98),
    headwordSize: 44,
    headwordItalic: false,
    headwordWeight: FontWeight.w800,
    headwordLetterSpacing: -1,
    centeredHeader: false,
    uppercaseNav: true,
    scrim: Color(0x99000000), // rgba(0,0,0,.6)
    overlayWash: Color(0x990D0E15), // rgba(13,14,21,.6)
    statusBarColor: Color(0xFF0D0E15),
    histLevel1: Color(0xFF26406E),
    histLevel2: Color(0xFF3A63B0),
    yellowText: Color(0xFF0D0E15),
  );

  // ----------------------------------------------------------------- Sepia ---
  /// Printed book: serif type, narrow cream page, ruled entries, text nav.
  static const AppTokens sepia = AppTokens(
    id: AppThemeId.sepia,
    ink: Color(0xFF3A2E22),
    paper: Color(0xFFF3EAD6),
    grey: Color(0xFFE8DCC2),
    red: Color(0xFF9C3B23),
    blue: Color(0xFF3F6F6F),
    yellow: Color(0xFFB6851B),
    green: Color(0xFF4F7A3A),
    purple: Color(0xFF6D4A86),
    line: Color(0xFFCDBB92),
    ruleWidth: 1,
    muted: Color(0xFF7C6C52),
    muted2: Color(0xFF9A8A6F),
    faint: Color(0xFFDDCEAC),
    radius: 0,
    // The web build sets --card-bg:transparent here; on native a transparent
    // card would let the paper grain show through floating menus, so cards use
    // paper and the ruled style removes the box instead.
    cardBg: Color(0xFFF3EAD6),
    shadow: <BoxShadow>[],
    accent: Color(0xFF9C3B23),
    fontHead: 'Georgia',
    fontBody: 'Georgia',
    navPlacement: NavPlacement.runningHead,
    cardStyle: CardStyle.ruled,
    pageMaxWidth: 520,
    pagePadding: EdgeInsets.fromLTRB(22, 24, 22, 60),
    headwordSize: 46,
    headwordItalic: true,
    headwordWeight: FontWeight.w400,
    headwordLetterSpacing: 0,
    centeredHeader: true,
    uppercaseNav: false,
    scrim: Color(0x73000000),
    overlayWash: Color(0xA3F3EAD6), // rgba(243,234,214,.64)
    statusBarColor: Color(0xFFF3EAD6),
    histLevel1: Color(0xFFBBCCDD),
    histLevel2: Color(0xFF66BB99),
    yellowText: Color(0xFF3A2E22),
  );

  static AppTokens tokensFor(AppThemeId id) => switch (id) {
        AppThemeId.minimalistic => minimalistic,
        AppThemeId.midnight => midnight,
        AppThemeId.sepia => sepia,
      };

  /// Three swatch colours for the theme picker chip.
  static List<Color> swatches(AppThemeId id) => switch (id) {
        AppThemeId.minimalistic => const <Color>[
            Color(0xFFFFFFFF),
            Color(0xFFDD0100),
            Color(0xFF225095),
          ],
        AppThemeId.midnight => const <Color>[
            Color(0xFF0D0E15),
            Color(0xFF6C8CFF),
            Color(0xFFFF6B81),
          ],
        AppThemeId.sepia => const <Color>[
            Color(0xFFF3EAD6),
            Color(0xFF9C3B23),
            Color(0xFF3F6F6F),
          ],
      };

  /// The ambient background behind the whole app.
  ///
  /// Midnight paints two radial glows; Sepia paints a faint horizontal paper
  /// grain; Minimalistic is flat.
  static BoxDecoration backgroundDecoration(AppTokens t) => switch (t.id) {
        AppThemeId.minimalistic => BoxDecoration(color: t.paper),
        AppThemeId.midnight => BoxDecoration(
            color: t.paper,
            gradient: const RadialGradient(
              center: Alignment(0.64, -1.24),
              radius: 1.1,
              colors: <Color>[Color(0x2E6C8CFF), Color(0x006C8CFF)],
              stops: <double>[0, 0.6],
            ),
          ),
        AppThemeId.sepia => BoxDecoration(color: t.paper),
      };

  static ThemeData materialTheme(AppTokens t) {
    final bool dark = t.id == AppThemeId.midnight;
    final ColorScheme scheme = ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: t.blue,
      onPrimary: Colors.white,
      secondary: t.red,
      onSecondary: Colors.white,
      error: t.red,
      onError: Colors.white,
      surface: t.cardBg,
      onSurface: t.ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.paper,
      fontFamily: t.fontBody,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[t],
      textSelectionTheme: TextSelectionThemeData(cursorColor: t.accent),
      // Buttons must set an explicit foreground: the web build hit exactly this
      // bug, where an unstyled button fell back to black and vanished on the
      // dark theme.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: t.ink),
      ),
      iconTheme: IconThemeData(color: t.ink),
      dividerColor: t.line,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.ink,
        contentTextStyle: TextStyle(
          color: t.paper,
          fontFamily: t.fontBody,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Keeps the system status/navigation bars in step with the theme, the native
  /// equivalent of the web build's `<meta name="theme-color">` swap.
  static SystemUiOverlayStyle overlayStyle(AppTokens t) {
    final bool dark = t.id == AppThemeId.midnight;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: t.statusBarColor,
      systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    );
  }
}

/// `context.tokens` everywhere instead of threading the theme by hand.
extension TokensX on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ?? AppTheme.minimalistic;
}
