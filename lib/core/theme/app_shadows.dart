import 'package:flutter/material.dart';

/// Shared shadows. The names below are guesses: they must match what
/// your code uses, for example AppShadows.card.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> strong = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.16),
      blurRadius: 14,
      offset: const Offset(0, 6),
    ),
  ];
}