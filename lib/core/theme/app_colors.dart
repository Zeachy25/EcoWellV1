import 'package:flutter/material.dart';

/// Centralized color palette for EcoWell matching the mockups
class AppColors {
  AppColors._();

  // Primary Brand Greens
  static const Color forestDark = Color(0xFF143D2B);      // Deep forest green (headers, weather card, nav bar)
  static const Color forestDeep = Color(0xFF0D2E1F);      // Darkest green (bottom bar backdrop)
  static const Color forestMid = Color(0xFF1B4D36);       // Secondary forest green
  static const Color primaryGreen = Color(0xFF227B4E);    // Standard action green
  static const Color mintGreen = Color(0xFF38B289);       // Bright mint accent
  static const Color mintLight = Color(0xFFE8F5EE);       // Very light mint for chips and active items
  static const Color mintSoft = Color(0xFFC7EBD9);        // Soft mint for outlines and rings
  static const Color emerald = Color(0xFF2EC4B6);         // Teal-emerald accent
  static const Color jade = Color(0xFF52B788);            // Soft jade green

  // Orange / Coral / Streak Accents
  static const Color streakOrange = Color(0xFFFF7A29);    // Fire streak orange
  static const Color streakCoral = Color(0xFFFF5722);     // Coral orange gradient end
  static const Color orangeLight = Color(0xFFFFF3E8);     // Light orange chip/card background
  static const Color amberRating = Color(0xFFFFB703);     // Star rating gold/amber
  static const Color goldStar = Color(0xFFFFC107);

  // Backgrounds & Neutrals
  static const Color background = Color(0xFFF7FAF7);      // Very subtle calm green-tinted white
  static const Color surface = Color(0xFFFFFFFF);         // Pure white card background
  static const Color surfaceMuted = Color(0xFFF1F5F1);    // Muted surface background
  static const Color cardBorder = Color(0xFFE5EDE5);      // Soft organic border
  static const Color inputBorder = Color(0xFF90D5B7);     // Mint green input border from mockup
  static const Color inputFill = Color(0xFFFAFDFB);       // Off-white input fill

  // Text Colors
  static const Color textPrimary = Color(0xFF112217);     // Dark forest-black
  static const Color textSecondary = Color(0xFF55695C);   // Muted calm gray-green
  static const Color textTertiary = Color(0xFF889C8E);    // Light gray-green
  static const Color textOnDark = Color(0xFFFFFFFF);      // Crisp white text on dark cards
  static const Color textOnDarkMuted = Color(0xFFD0E2D7); // Muted white on dark cards
  static const Color textGreenTitle = Color(0xFF2E8B57);  // Green header text ("Login here")

  // Status & Quiet Score Colors
  static const Color scoreHigh = Color(0xFF2E7D32);       // Quiet / Calm High
  static const Color scoreModerate = Color(0xFFF59E0B);   // Moderate amber
  static const Color scoreLow = Color(0xFFEF4444);        // Low red

  // Gradients
  static const LinearGradient primaryButtonGradient = LinearGradient(
    colors: [Color(0xFF5AB68C), Color(0xFF1E5E41)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient streakGradient = LinearGradient(
    colors: [Color(0xFFFFB347), Color(0xFFFF5E36)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient bottomNavGradient = LinearGradient(
    colors: [Color(0xFF1B4F39), Color(0xFF12392B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient heroCardGradient = LinearGradient(
    colors: [Color(0xFF8CE0C7), Color(0xFFBFEFE1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient onboardingCardGradient = LinearGradient(
    colors: [Color(0xFF4FA07B), Color(0xFF225B42)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
