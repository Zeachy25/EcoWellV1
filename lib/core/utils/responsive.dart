import 'package:flutter/material.dart';

/// Lightweight responsive utilities for EcoWell.
///
/// All scaling is relative to a 390px-wide design baseline (iPhone 14 Pro).
/// Call these in build() methods via Responsive.xxx(context, ...).
class Responsive {
  Responsive._();

  /// Design baseline width (iPhone 14 Pro logical pixels).
  static const double _designWidth = 390.0;

  /// Design baseline height (iPhone 14 Pro logical pixels).
  static const double _designHeight = 844.0;

  /// Returns the current screen width.
  static double screenWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  /// Returns the current screen height.
  static double screenHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  /// Returns the top safe area inset (status bar / notch).
  static double topPadding(BuildContext context) =>
      MediaQuery.paddingOf(context).top;

  /// Returns the bottom safe area inset (home indicator).
  static double bottomPadding(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom;

  /// Scale a value proportionally to screen width relative to 390px baseline.
  static double w(BuildContext context, double designPx) {
    return designPx * screenWidth(context) / _designWidth;
  }

  /// Scale a value proportionally to screen height relative to 844px baseline.
  static double h(BuildContext context, double designPx) {
    return designPx * screenHeight(context) / _designHeight;
  }

  /// Scale a font size proportionally to screen width.
  /// Clamps to ±20% of design size to prevent extreme values on very small/large screens.
  static double fontSize(BuildContext context, double designPx) {
    final scaled = designPx * screenWidth(context) / _designWidth;
    final min = designPx * 0.82;
    final max = designPx * 1.18;
    return scaled.clamp(min, max);
  }

  /// Scale a border radius proportionally to screen width.
  static double radius(BuildContext context, double designPx) {
    return designPx * screenWidth(context) / _designWidth;
  }

  /// Scale a generic dimension (width, height, padding, margin) proportionally.
  static double size(BuildContext context, double designPx) {
    return designPx * screenWidth(context) / _designWidth;
  }

  /// Scale horizontal padding that accounts for typical screen edge insets.
  /// Returns a value that adapts to the screen width.
  static double horizontalPadding(BuildContext context) {
    final screenW = screenWidth(context);
    if (screenW < 360) return 12.0;
    if (screenW < 390) return 14.0;
    if (screenW < 420) return 16.0;
    return 20.0;
  }

  /// Common bottom padding for screens with a floating bottom nav bar.
  static double bottomNavClearance(BuildContext context) {
    return 90.0 + bottomPadding(context);
  }
}
