import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Helps adapt the UI to small screens (e.g. the 3.0" Doogee U10).
///
/// [scale] shrinks font sizes and paddings when the shortest screen side is
/// below the standard ~360dp. [isCompact] enables "less information" layouts.
class ScreenFit {
  final double scale;
  final bool isCompact;
  final double width;
  final double height;

  const ScreenFit._(this.scale, this.isCompact, this.width, this.height);

  factory ScreenFit.of(BuildContext context) {
    return ScreenFit.fromSize(MediaQuery.sizeOf(context));
  }

  factory ScreenFit.fromSize(Size size) {
    final shortest = math.min(size.width, size.height);
    final scale = (shortest / 360.0).clamp(0.66, 1.12).toDouble();
    final isCompact = shortest < 340;
    return ScreenFit._(scale, isCompact, size.width, size.height);
  }

  /// Scales a design size by the detected factor.
  double s(double value) => value * scale;
}

/// Global text scale factor derived from the screen size.
double screenTextScale(Size size) {
  final shortest = math.min(size.width, size.height);
  return (shortest / 360.0).clamp(0.68, 1.12).toDouble();
}
