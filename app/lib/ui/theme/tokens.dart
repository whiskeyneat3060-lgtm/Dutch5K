import 'package:flutter/material.dart';

import '../../models/enums.dart';

/// Where the tab bar sits. This is a structural difference, not a colour one —
/// each theme is a different layout (BUILD-SPEC 2.7).
enum NavPlacement {
  /// Filled tabs directly under the header.
  topTabs,

  /// A floating rounded pill above the bottom edge.
  bottomPill,

  /// Centred running-head text tabs with an underline for the active one.
  runningHead,
}

/// How a study card is drawn.
enum CardStyle {
  /// Boxed with a heavy rule and a minimum height.
  boxed,

  /// Rounded, filled, elevated.
  soft,

  /// A ruled dictionary entry: horizontal rules only, transparent ground.
  ruled,
}

/// Every design token from BUILD-SPEC section 3.2, carried through the widget
/// tree as a [ThemeExtension] so widgets read `context.tokens.blue` rather than
/// hard-coding colours.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.id,
    required this.ink,
    required this.paper,
    required this.grey,
    required this.red,
    required this.blue,
    required this.yellow,
    required this.green,
    required this.purple,
    required this.line,
    required this.ruleWidth,
    required this.muted,
    required this.muted2,
    required this.faint,
    required this.radius,
    required this.cardBg,
    required this.shadow,
    required this.accent,
    required this.fontHead,
    required this.fontBody,
    required this.navPlacement,
    required this.cardStyle,
    required this.pageMaxWidth,
    required this.pagePadding,
    required this.headwordSize,
    required this.headwordItalic,
    required this.headwordWeight,
    required this.headwordLetterSpacing,
    required this.scrim,
    required this.overlayWash,
    required this.statusBarColor,
    required this.histLevel1,
    required this.histLevel2,
    required this.yellowText,
    required this.centeredHeader,
    required this.uppercaseNav,
  });

  final AppThemeId id;

  // Palette
  final Color ink;
  final Color paper;
  final Color grey;
  final Color red;
  final Color blue;
  final Color yellow;
  final Color green;
  final Color purple;

  /// Border colour, themeable independently of text ink.
  final Color line;

  /// Standard border width: 3px in Minimalistic, 1px in the other two.
  final double ruleWidth;

  final Color muted;
  final Color muted2;
  final Color faint;

  final double radius;
  final Color cardBg;
  final List<BoxShadow> shadow;
  final Color accent;

  final String fontHead;
  final String fontBody;

  // Structure
  final NavPlacement navPlacement;
  final CardStyle cardStyle;
  final double pageMaxWidth;
  final EdgeInsets pagePadding;
  final double headwordSize;
  final bool headwordItalic;
  final FontWeight headwordWeight;
  final double headwordLetterSpacing;
  final bool centeredHeader;
  final bool uppercaseNav;

  // Overlays
  final Color scrim;
  final Color overlayWash;
  final Color statusBarColor;

  final Color histLevel1;
  final Color histLevel2;

  /// Readable text colour on a yellow ground.
  final Color yellowText;

  /// Colour for a given source id, shared by the donut, stacked bars, legend
  /// dots and row badges so identity is consistent everywhere.
  Color sourceColor(String src) => switch (src) {
        'essential' => purple,
        'general' => muted,
        'gang' => blue,
        'actie' => red,
        'niveau' => yellow,
        'perfectie' => green,
        _ => muted,
      };

  /// Text colour that stays legible on [sourceColor].
  Color onSourceColor(String src) => src == 'niveau' ? yellowText : Colors.white;

  BorderSide get rule => BorderSide(color: line, width: ruleWidth);
  Border get ruleBorder => Border.fromBorderSide(rule);
  BorderRadius get cardRadius => BorderRadius.circular(radius);

  @override
  AppTokens copyWith({AppThemeId? id}) => this;

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    // Themes are discrete layouts, not points on a gradient; snapping avoids
    // an incoherent halfway state where nav placement and colours disagree.
    if (other is! AppTokens) return this;
    return t < 0.5 ? this : other;
  }
}
