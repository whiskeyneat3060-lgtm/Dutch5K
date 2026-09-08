import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/deck_entry.dart';
import '../../models/enums.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// The card shell: a tag strip above a body, drawn per theme.
///
/// Minimalistic is a hard-ruled box, Midnight a soft elevated card, Sepia a
/// ruled dictionary entry with no side borders.
class CardShell extends StatelessWidget {
  const CardShell({
    super.key,
    required this.tagLeft,
    required this.tagRight,
    required this.child,
    this.onTap,
    this.minHeight = 300,
  });

  final String tagLeft;
  final String tagRight;
  final Widget child;
  final VoidCallback? onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final AppTokens t = context.tokens;
    final bool ruled = t.cardStyle == CardStyle.ruled;

    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: ruled ? t.faint : t.line, width: t.ruleWidth),
            ),
            gradient: t.id == AppThemeId.midnight
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[t.blue.withValues(alpha: 0.16), Colors.transparent],
                    stops: const <double>[0, 0.7],
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Flexible(child: _tag(t, tagLeft)),
              _tag(t, tagRight),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: child,
        ),
      ],
    );

    final BoxDecoration decoration = ruled
        ? BoxDecoration(
            border: Border(
              top: BorderSide(color: t.line, width: 2),
              bottom: BorderSide(color: t.line, width: 2),
            ),
          )
        : BoxDecoration(
            color: t.cardBg,
            border: t.ruleBorder,
            borderRadius: t.cardRadius,
            boxShadow: t.shadow,
          );

    return Semantics(
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: BoxConstraints(minHeight: ruled ? 0 : minHeight),
          decoration: decoration,
          clipBehavior: ruled ? Clip.none : Clip.antiAlias,
          child: content,
        ),
      ),
    );
  }

  Widget _tag(AppTokens t, String s) => Text(
        s.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
          color: t.ink,
        ),
      );
}

/// A quick page-flip: the card turns edge-on, the face is swapped at 90°, then
/// the new face turns in. Honours reduced motion by swapping instantly.
class FlipCard extends StatefulWidget {
  const FlipCard({
    super.key,
    required this.showBack,
    required this.child,
    required this.onFlipRequested,
  });

  final bool showBack;
  final Widget child;

  /// Called at the edge-on moment, when the caller should switch faces.
  final VoidCallback onFlipRequested;

  @override
  State<FlipCard> createState() => FlipCardState();
}

class FlipCardState extends State<FlipCard> with SingleTickerProviderStateMixin {
  late final AnimationController _out = AnimationController(
    vsync: this,
    duration: kFlipOutDuration,
  );
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: kFlipInDuration,
  );
  bool _busy = false;

  @override
  void dispose() {
    _out.dispose();
    _in.dispose();
    super.dispose();
  }

  /// Runs the flip. A re-entrancy guard blocks double taps mid-animation.
  Future<void> flip() async {
    if (_busy) return;
    final bool reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      widget.onFlipRequested();
      return;
    }
    _busy = true;
    await _out.forward(from: 0);
    widget.onFlipRequested();
    _out.value = 0;
    await _in.forward(from: 0);
    _busy = false;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_out, _in]),
      builder: (BuildContext context, Widget? child) {
        // Out: 0 -> 90deg. In: -90deg -> 0.
        final double angle = _out.isAnimating || _out.value > 0
            ? _out.value * 1.5707963
            : (_in.value - 1) * 1.5707963;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 1 / 1400) // perspective(1400px)
            ..rotateY(angle),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// The big Dutch headword plus its speaker button.
class Headword extends StatelessWidget {
  const Headword({
    super.key,
    required this.word,
    this.speaker,
    this.prefix,
  });

  final String word;
  final Widget? speaker;

  /// The revealed `de`/`het` in the gender drill.
  final Widget? prefix;

  @override
  Widget build(BuildContext context) {
    final AppTokens t = context.tokens;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        if (prefix != null) prefix!,
        Text(
          word,
          style: TextStyle(
            fontFamily: t.fontHead,
            fontWeight: t.headwordWeight,
            fontStyle: t.headwordItalic ? FontStyle.italic : FontStyle.normal,
            fontSize: t.headwordSize,
            letterSpacing: t.headwordLetterSpacing,
            height: 1,
            color: t.ink,
          ),
        ),
        if (speaker != null) speaker!,
      ],
    );
  }
}

/// The blue meaning line under a headword.
class MeaningText extends StatelessWidget {
  const MeaningText(this.text, {super.key, this.big = false});
  final String text;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final AppTokens t = context.tokens;
    return Text(
      text,
      style: TextStyle(
        fontSize: big ? 26 : 20,
        height: big ? 1.25 : null,
        fontWeight: big ? FontWeight.w700 : FontWeight.w600,
        fontStyle: t.id == AppThemeId.sepia ? FontStyle.italic : FontStyle.normal,
        color: t.blue,
      ),
    );
  }
}

/// The small uppercase rank / chapter line.
class RankLine extends StatelessWidget {
  const RankLine(this.text, {super.key, this.book = false});
  final String text;
  final bool book;

  @override
  Widget build(BuildContext context) {
    final AppTokens t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          letterSpacing: book ? 0.5 : 1,
          fontWeight: book ? FontWeight.w600 : FontWeight.w400,
          color: book ? t.red : t.muted2,
        ),
      ),
    );
  }
}

/// A small uppercase prompt label above a card face.
class PromptLabel extends StatelessWidget {
  const PromptLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final AppTokens t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: t.muted2,
        ),
      ),
    );
  }
}

/// A titled section inside a card body (Forms, Examples, Synonyms, Antonyms).
class CardSection extends StatelessWidget {
  const CardSection({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final AppTokens t = context.tokens;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.line, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontFamily: t.fontHead,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 1.5,
                color: t.muted,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// One `label   value` grammar-form row.
class FormRow extends StatelessWidget {
  const FormRow(this.form, {super.key});
  final WordForm form;

  @override
  Widget build(BuildContext context) {
    final AppTokens t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(
              form.label,
              style: TextStyle(
                  fontSize: 13, height: 1.7, fontWeight: FontWeight.w600, color: t.muted),
            ),
          ),
          Expanded(
            child: Text(
              form.value,
              style: TextStyle(fontSize: 13, height: 1.7, color: t.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// An example sentence: Dutch with a speaker, English beneath.
class ExampleRow extends StatelessWidget {
  const ExampleRow({
    super.key,
    required this.dutch,
    required this.english,
    this.speaker,
  });

  final String dutch;
  final String english;
  final Widget? speaker;

  @override
  Widget build(BuildContext context) {
    final AppTokens t = context.tokens;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: t.yellow, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(dutch, style: TextStyle(fontSize: 14, height: 1.5, color: t.ink)),
              if (speaker != null) speaker!,
            ],
          ),
          if (english.isNotEmpty)
            Text(english, style: TextStyle(fontSize: 12.5, height: 1.4, color: t.muted)),
        ],
      ),
    );
  }
}

/// A tappable synonym or antonym row that links to that word's card.
class RelatedRow extends StatelessWidget {
  const RelatedRow({
    super.key,
    required this.word,
    required this.meaning,
    required this.isSynonym,
    required this.onTap,
  });

  final String word;
  final String? meaning;
  final bool isSynonym;

  /// Null when the word is not in the deck, which renders it as plain text.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppTokens t = context.tokens;
    final Widget row = Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: t.cardBg,
        border: Border(
          top: BorderSide(color: t.line, width: 2),
          right: BorderSide(color: t.line, width: 2),
          bottom: BorderSide(color: t.line, width: 2),
          left: BorderSide(color: isSynonym ? t.blue : t.yellow, width: 6),
        ),
        borderRadius: t.cardRadius,
      ),
      child: Row(
        children: <Widget>[
          Text(
            '${isSynonym ? '=' : '≠'} $word',
            style: TextStyle(
                fontFamily: t.fontHead,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: t.ink),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              meaning ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: t.muted),
            ),
          ),
          if (onTap != null)
            Text('›',
                style: TextStyle(
                    fontFamily: t.fontHead,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: t.red)),
        ],
      ),
    );

    if (onTap == null) return Opacity(opacity: 0.85, child: row);
    return InkWell(onTap: onTap, child: row);
  }
}
