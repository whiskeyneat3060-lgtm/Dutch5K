import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../domain/counts.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// The "By source" donut.
///
/// Geometry matches the web build: radius 52, stroke width 22 in a 140x140 box,
/// starting at 12 o'clock, with a 2px gap between slices so identity never
/// rests on colour alone.
class SourceDonut extends StatelessWidget {
  const SourceDonut({
    super.key,
    required this.buckets,
    required this.centreLabel,
    required this.onTapSource,
  });

  final Map<String, SourceBucket> buckets;
  final String centreLabel;
  final void Function(String source) onTapSource;

  static const double _radius = 52;
  static const double _stroke = 22;
  static const double _size = 140;

  int get _totalLearned =>
      buckets.values.fold(0, (int a, SourceBucket b) => a + b.learned);

  @override
  Widget build(BuildContext context) {
    final AppTokens t = context.tokens;
    final int total = _totalLearned;

    return SizedBox(
      width: _size,
      height: _size,
      child: GestureDetector(
        onTapUp: total == 0 ? null : (TapUpDetails d) => _handleTap(d.localPosition),
        child: Semantics(
          label: 'By source',
          child: CustomPaint(
            painter: _DonutPainter(
              buckets: buckets,
              tokens: t,
              total: total,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '$total',
                    style: TextStyle(
                      fontFamily: t.fontHead,
                      fontWeight: FontWeight.w900,
                      fontSize: 30,
                      height: 1,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    centreLabel.toUpperCase(),
                    style: TextStyle(
                      fontFamily: t.fontHead,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0.5,
                      color: t.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Maps a tap to the slice under it.
  void _handleTap(Offset p) {
    const Offset centre = Offset(_size / 2, _size / 2);
    final Offset v = p - centre;
    final double dist = v.distance;
    if (dist < _radius - _stroke / 2 || dist > _radius + _stroke / 2) return;

    // Angle from 12 o'clock, clockwise.
    double angle = math.atan2(v.dx, -v.dy);
    if (angle < 0) angle += 2 * math.pi;
    final double fraction = angle / (2 * math.pi);

    final int total = _totalLearned;
    if (total == 0) return;
    double acc = 0;
    for (final String src in kSrcOrder) {
      final SourceBucket? b = buckets[src];
      if (b == null || b.learned == 0) continue;
      final double share = b.learned / total;
      if (fraction >= acc && fraction < acc + share) {
        onTapSource(src);
        return;
      }
      acc += share;
    }
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.buckets,
    required this.tokens,
    required this.total,
  });

  final Map<String, SourceBucket> buckets;
  final AppTokens tokens;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = Offset(size.width / 2, size.height / 2);
    final Rect rect =
        Rect.fromCircle(center: centre, radius: SourceDonut._radius);
    final double circumference = 2 * math.pi * SourceDonut._radius;

    if (total == 0) {
      // Empty state: a single faint full ring.
      canvas.drawCircle(
        centre,
        SourceDonut._radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = SourceDonut._stroke
          ..color = tokens.faint,
      );
      return;
    }

    // A 2px gap between slices, expressed as an angle.
    final double gap = 2 / circumference * 2 * math.pi;
    double start = -math.pi / 2; // 12 o'clock

    for (final String src in kSrcOrder) {
      final SourceBucket? b = buckets[src];
      if (b == null || b.learned == 0) continue;
      final double sweep = b.learned / total * 2 * math.pi;
      canvas.drawArc(
        rect,
        start,
        math.max(sweep - gap, 0.0001),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = SourceDonut._stroke
          ..strokeCap = StrokeCap.butt
          ..color = tokens.sourceColor(src),
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.total != total || old.tokens.id != tokens.id;
}

/// A horizontal bar whose fill is split into per-source coloured segments, so
/// the segments sum exactly to the row's learned total.
class StackedBar extends StatelessWidget {
  const StackedBar({
    super.key,
    required this.segments,
    required this.total,
  });

  /// Source id -> learned count.
  final Map<String, int> segments;
  final int total;

  int _remainderFlex(int denom) {
    int learned = 0;
    for (final int v in segments.values) {
      learned += v;
    }
    final int flex = ((denom - learned) / denom * 10000).round();
    return flex < 0 ? 0 : flex;
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens t = context.tokens;
    final int denom = total < 1 ? 1 : total;
    return Container(
      height: 12,
      decoration: BoxDecoration(
        color: t.paper,
        border: Border.all(color: t.line, width: 2),
      ),
      child: Row(
        children: <Widget>[
          for (final String src in kSrcOrder)
            if ((segments[src] ?? 0) > 0)
              Expanded(
                flex: (segments[src]! / denom * 10000).round(),
                child: ColoredBox(color: t.sourceColor(src)),
              ),
          // The unlearned remainder.
          Expanded(
            flex: _remainderFlex(denom),
            child: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
