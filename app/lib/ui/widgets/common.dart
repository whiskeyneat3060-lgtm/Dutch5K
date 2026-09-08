import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/enums.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// A boxed section with a heavy rule, the workhorse container of the design.
class GenBox extends StatelessWidget {
  const GenBox({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(top: 18),
    this.borderWidthOverride,
  });

  final Widget child;
  final String? title;
  final EdgeInsets padding;
  final EdgeInsets margin;

  /// The Review and Study-plan boxes use a heavier 3px rule.
  final double? borderWidthOverride;

  @override
  Widget build(BuildContext context) {
    final AppTokens t = context.tokens;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: t.cardBg,
        border: Border.all(color: t.line, width: borderWidthOverride ?? t.ruleWidth),
        borderRadius: t.cardRadius,
        boxShadow: t.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (title != null) ...<Widget>[
            SectionHeading(title!),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

/// The uppercase heavy heading used by every box.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final AppTokens t = context.tokens;
    return Text(
      text,
      style: TextStyle(
        fontFamily: t.fontHead,
        fontWeight: FontWeight.w900,
        fontSize: 16,
        letterSpacing: 0.5,
        color: t.ink,
      ),
    );
  }
}

/// Muted explanatory copy under a control.
class NoteText extends StatelessWidget {
  const NoteText(this.text, {super.key, this.textAlign});
  final String text;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final AppTokens t = context.tokens;
    return Text(
      text,
      textAlign: textAlign,
      style: TextStyle(fontSize: 11.5, height: 1.5, color: t.muted),
    );
  }
}

/// Solid primary action button (red by default, blue in the `alt` variant).
class GenButton extends StatelessWidget {
  const GenButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.alt = false,
    this.icon,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool alt;
  final String? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final AppTokens t = context.tokens;
    final Color bg = !enabled ? t.muted2 : (alt ? t.blue : t.red);
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: bg,
        borderRadius: t.cardRadius,
        child: InkWell(
          borderRadius: t.cardRadius,
          onTap: enabled ? onPressed : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Text(
              icon == null ? label : '$icon $label',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: t.fontHead,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 1,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined full-width secondary button (the web build's `.loadmore`).
class OutlineButton extends StatelessWidget {
  const OutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final AppTokens t = context.tokens;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: t.cardRadius,
          onTap: onPressed,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: dense ? 9 : 12, horizontal: 12),
            decoration: BoxDecoration(
              border: t.ruleBorder,
              borderRadius: t.cardRadius,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: t.fontHead,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                fontSize: dense ? 13 : 15,
                color: t.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty-state panel.
class EmptyPanel extends StatelessWidget {
  const EmptyPanel({super.key, required this.message, this.hint});
  final String message;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final AppTokens t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(border: t.ruleBorder, borderRadius: t.cardRadius),
      child: Column(
        children: <Widget>[
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: t.muted),
          ),
          if (hint != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(hint!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: t.muted)),
          ],
        ],
      ),
    );
  }
}

/// The learned / learning / new proportion strip.
class MondrianStrip extends StatelessWidget {
  const MondrianStrip({
    super.key,
    required this.learned,
    required this.learning,
    required this.total,
  });

  final int learned;
  final int learning;
  final int total;

  @override
  Widget build(BuildContext context) {
    final AppTokens t = context.tokens;
    final int denom = total < 1 ? 1 : total;
    // A non-zero bucket always gets a visible sliver, matching the web build.
    final double pl = learned == 0 ? 0 : (learned / denom * 100).clamp(2, 100).toDouble();
    final double pg =
        learning == 0 ? 0 : (learning / denom * 100).clamp(2, 100).toDouble();
    final double pn = (100 - pl - pg).clamp(0, 100).toDouble();

    Widget seg(double flex, Color color, {bool last = false}) => Expanded(
          flex: (flex * 1000).round().clamp(0, 1 << 30),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              border: last
                  ? null
                  : Border(right: BorderSide(color: t.line, width: t.ruleWidth)),
            ),
          ),
        );

    return Container(
      height: 22,
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(border: t.ruleBorder, borderRadius: t.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: <Widget>[
          if (pl > 0) seg(pl, t.blue),
          if (pg > 0) seg(pg, t.yellow),
          seg(pn <= 0 ? 0.0001 : pn, t.paper, last: true),
        ],
      ),
    );
  }
}

/// The source badge shown on word rows (★ / A2 / B1 / B2 / C1).
class SourceBadge extends StatelessWidget {
  const SourceBadge(this.src, {super.key});
  final String src;

  @override
  Widget build(BuildContext context) {
    final AppTokens t = context.tokens;
    final String? label = kSrcBadge[src];
    if (label == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      constraints: const BoxConstraints(minWidth: 15),
      height: 15,
      alignment: Alignment.center,
      color: t.sourceColor(src),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: t.fontHead,
          fontWeight: FontWeight.w900,
          fontSize: 9,
          height: 1,
          color: t.onSourceColor(src),
        ),
      ),
    );
  }
}

/// Learned / learning / new status dot.
class StatusDot extends StatelessWidget {
  const StatusDot(this.color, {super.key});
  final Color color;

  @override
  Widget build(BuildContext context) {
    final AppTokens t = context.tokens;
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: t.line, width: 2),
      ),
    );
  }
}

/// Constrains content to the theme's reading width and applies page padding.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppTokens t = context.tokens;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: t.pageMaxWidth),
        child: Padding(padding: t.pagePadding, child: child),
      ),
    );
  }
}

/// Whole-app background: flat, ambient gradient, or paper grain per theme.
class ThemedBackground extends StatelessWidget {
  const ThemedBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppTokens t = context.tokens;
    return DecoratedBox(
      decoration: AppTheme.backgroundDecoration(t),
      child: t.id == AppThemeId.sepia
          ? CustomPaint(painter: _PaperGrainPainter(t.ink), child: child)
          : child,
    );
  }
}

/// Sepia's faint horizontal paper grain: 2px of tint every 5px.
class _PaperGrainPainter extends CustomPainter {
  const _PaperGrainPainter(this.ink);
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()..color = const Color(0x0C785A32);
    for (double y = 0; y < size.height; y += 5) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 2), p);
    }
  }

  @override
  bool shouldRepaint(covariant _PaperGrainPainter oldDelegate) => false;
}
