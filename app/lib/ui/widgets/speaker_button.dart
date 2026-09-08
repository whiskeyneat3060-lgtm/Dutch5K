import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/haptics.dart';
import '../../services/tts_service.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Speaks Dutch text. Turns red while speaking, matching the web build.
class SpeakerButton extends ConsumerWidget {
  const SpeakerButton({
    super.key,
    required this.text,
    required this.id,
    this.size = 28,
    this.onUnavailable,
  });

  final String text;

  /// Distinguishes this button from every other one on screen so only the
  /// pressed button shows the speaking state.
  final String id;
  final double size;

  /// Called when the device has no speech synthesis at all.
  final VoidCallback? onUnavailable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTokens t = context.tokens;
    final TtsService tts = ref.watch(ttsProvider);

    return ValueListenableBuilder<String?>(
      valueListenable: tts.speakingId,
      builder: (BuildContext context, String? speaking, _) {
        final bool active = speaking == id;
        return Semantics(
          button: true,
          label: 'Hear pronunciation in Dutch',
          child: InkResponse(
            radius: size * 0.7,
            onTap: () async {
              Haptics.tap();
              final bool ok = await tts.speak(text, id: id);
              if (!ok) onUnavailable?.call();
            },
            child: SizedBox(
              width: size,
              height: size,
              child: Padding(
                padding: EdgeInsets.all(size * 0.11),
                child: Opacity(
                  opacity: active ? 1 : 0.68,
                  child: CustomPaint(
                    painter: _SpeakerPainter(active ? t.red : t.ink),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The speaker glyph, drawn to match the web build's inline SVG exactly:
/// a filled cone plus two arcs.
class _SpeakerPainter extends CustomPainter {
  const _SpeakerPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 24;
    final Paint fill = Paint()..color = color;

    // M4 9v6h4l5 5V4L8 9H4z
    final Path cone = Path()
      ..moveTo(4 * s, 9 * s)
      ..lineTo(4 * s, 15 * s)
      ..lineTo(8 * s, 15 * s)
      ..lineTo(13 * s, 20 * s)
      ..lineTo(13 * s, 4 * s)
      ..lineTo(8 * s, 9 * s)
      ..close();
    canvas.drawPath(cone, fill);

    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round;

    // M15.5 8.5c1.6 1.2 1.6 5.8 0 7
    final Path inner = Path()
      ..moveTo(15.5 * s, 8.5 * s)
      ..cubicTo(17.1 * s, 9.7 * s, 17.1 * s, 14.3 * s, 15.5 * s, 15.5 * s);
    canvas.drawPath(inner, stroke);

    // M18 6c3 2.2 3 9.8 0 12
    final Path outer = Path()
      ..moveTo(18 * s, 6 * s)
      ..cubicTo(21 * s, 8.2 * s, 21 * s, 15.8 * s, 18 * s, 18 * s);
    canvas.drawPath(outer, stroke);
  }

  @override
  bool shouldRepaint(covariant _SpeakerPainter old) => old.color != color;
}

/// The large circular play button used by Listen mode.
class BigPlayButton extends ConsumerWidget {
  const BigPlayButton({
    super.key,
    required this.text,
    required this.id,
    this.onUnavailable,
  });

  final String text;
  final String id;
  final VoidCallback? onUnavailable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTokens t = context.tokens;
    final TtsService tts = ref.watch(ttsProvider);

    return ValueListenableBuilder<String?>(
      valueListenable: tts.speakingId,
      builder: (BuildContext context, String? speaking, _) {
        final bool active = speaking == id;
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Semantics(
              button: true,
              label: 'Play audio',
              child: InkResponse(
                radius: 48,
                onTap: () async {
                  Haptics.tap();
                  final bool ok = await tts.speak(text, id: id);
                  if (!ok) onUnavailable?.call();
                },
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.paper,
                    border: Border.all(
                      color: active ? t.red : t.line,
                      width: t.ruleWidth,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: CustomPaint(
                      painter: _SpeakerPainter(active ? t.red : t.ink),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
