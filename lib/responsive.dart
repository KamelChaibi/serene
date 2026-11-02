import 'package:flutter/material.dart';

/// Small, dependency-free helpers that make the UI adapt to the device it is
/// running on.
///
/// Serene is designed against a 390 logical-pixel-wide phone. A 320 px phone
/// used to clip the PIN keypad and the five mood faces, while a tablet showed
/// long, hard-to-read lines of text. Everything here derives from the screen
/// size, is clamped so it never becomes absurd, and still respects the font
/// scale the user chose in the operating system.
class Responsive {
  Responsive._();

  /// The width the layouts were designed for.
  static const double designWidth = 390;

  /// How much bigger/smaller the UI should be than the reference design.
  ///
  /// `shortestSide` is used instead of `width` so rotating a phone does not
  /// suddenly blow every icon up.
  static double scaleOf(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;
    if (shortest <= 0) return 1;
    return (shortest / designWidth).clamp(0.85, 1.3);
  }

  /// Scales a logical size (padding, icon, radius…).
  static double of(BuildContext context, double value) =>
      value * scaleOf(context);

  /// A [TextScaler] that combines the OS accessibility setting with the
  /// device-size factor. Clamped so text stays readable without exploding
  /// layouts.
  static TextScaler textScalerOf(BuildContext context) {
    final media = MediaQuery.of(context);
    // `scale(14)` on a linear scaler returns 14 * factor; dividing recovers
    // the user's effective factor without assuming a particular scaler type.
    final userFactor = media.textScaler.scale(14) / 14;
    final deviceFactor = scaleOf(context);
    return TextScaler.linear((userFactor * deviceFactor).clamp(0.8, 2.0));
  }

  /// Applies the adaptive text scale to an entire subtree.
  static Widget textScaled(BuildContext context, Widget child) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(textScaler: textScalerOf(context)),
      child: child,
    );
  }

  /// Wraps [child] with the adaptive text scaler. Used by [MaterialApp.builder]
  /// so every route benefits without touching each screen.
  static Widget wrap(BuildContext context, Widget? child) {
    return textScaled(context, child ?? const SizedBox.shrink());
  }

  /// Keeps long forms readable on tablets instead of stretching them edge to
  /// edge. Returns the child unchanged on phone-sized screens.
  static Widget centered({
    required Widget child,
    double maxWidth = 760,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
