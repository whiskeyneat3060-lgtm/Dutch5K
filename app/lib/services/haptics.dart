import 'package:flutter/services.dart';

/// Tap feedback.
///
/// The web build used `navigator.vibrate` with 10/12/24/30 ms pulses, which
/// silently does nothing on iOS. Mapping onto the platform feedback APIs means
/// iOS users get haptics for the first time.
class Haptics {
  const Haptics._();

  /// Every ordinary tap: tab switch, card flip, filter pick, button press.
  static void tap() => HapticFeedback.selectionClick();

  /// A correct answer in an auto-graded mode.
  static void correct() => HapticFeedback.lightImpact();

  /// A wrong answer in an auto-graded mode.
  static void wrong() => HapticFeedback.heavyImpact();

  /// Reaching the daily goal.
  static void celebrate() => HapticFeedback.mediumImpact();
}
