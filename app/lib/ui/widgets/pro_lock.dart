import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/i18n/ui_strings.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// The upsell overlay drawn on top of blurred locked content.
class ProOverlay extends StatelessWidget {
  const ProOverlay({super.key, required this.onTap, required this.t});
  final VoidCallback onTap;
  final UiStrings t;

  @override
  Widget build(BuildContext context) {
    final AppTokens tk = context.tokens;
    return Positioned.fill(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          color: tk.overlayWash,
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text('🔒', style: TextStyle(fontSize: 34, height: 1)),
              const SizedBox(height: 9),
              Text(
                t('Locked'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: tk.fontHead,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 2,
                  color: tk.ink,
                ),
              ),
              const SizedBox(height: 9),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 250),
                child: Text(
                  t('Unlock Pro version for full access'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: tk.muted),
                ),
              ),
              const SizedBox(height: 13),
              Material(
                color: tk.red,
                borderRadius: tk.cardRadius,
                child: InkWell(
                  borderRadius: tk.cardRadius,
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    child: Text(
                      '${t('Unlock Pro to go')} →',
                      style: TextStyle(
                        fontFamily: tk.fontHead,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps content that is gated behind Pro: blurs and disables it, then draws
/// [ProOverlay] on top.
class ProLock extends StatelessWidget {
  const ProLock({
    super.key,
    required this.locked,
    required this.child,
    required this.onUnlock,
    required this.t,
  });

  final bool locked;
  final Widget child;
  final VoidCallback onUnlock;
  final UiStrings t;

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;
    return Stack(
      children: <Widget>[
        // IgnorePointer + opacity mirrors the web build's blur + pointer-events
        // lock; ImageFiltered gives the actual 5px blur.
        IgnorePointer(
          child: Opacity(
            opacity: 0.6,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: child,
            ),
          ),
        ),
        ProOverlay(onTap: onUnlock, t: t),
      ],
    );
  }
}
