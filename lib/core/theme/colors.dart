import 'package:flutter/material.dart';

/// Application Color Constants
class AppColors {
  AppColors._();

  // Primary Colors
  static const Color primary = Color(0xFF0F8A6A);
  static const Color primaryDark = Color(0xFF0B6B5C);
  static const Color primaryLight = Color(0xFF35B38E);

  // Secondary Colors
  static const Color secondary = Color(0xFF1E5D6A);
  static const Color secondaryDark = Color(0xFF184C56);
  static const Color secondaryLight = Color(0xFF2F7A86);

  // Accent Colors
  static const Color accent = Color(0xFFF4B860);
  static const Color accentDark = Color(0xFFE3A24E);
  static const Color accentLight = Color(0xFFFFD9A6);

  // Background Colors
  static const Color background = Color(0xFFF6F7F4);
  static const Color backgroundDark = Color(0xFF0E1C1B);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF152625);

  // Text Colors
  static const Color textPrimary = Color(0xFF1F2A2A);
  static const Color textSecondary = Color(0xFF5B6B6A);
  static const Color textLight = Color(0xFFC7D1CF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Status Colors
  static const Color success = Color(0xFF2CB67D);
  static const Color warning = Color(0xFFF4A261);
  static const Color error = Color(0xFFE76F51);
  static const Color info = Color(0xFF4EA8DE);

  // Border & Divider Colors
  static const Color border = Color(0xFFE2E6E1);
  static const Color divider = Color(0xFFECEFED);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, Color(0xFFF7D08A)],
  );

  static const LinearGradient mistGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF6F7F4), Color(0xFFE9F1EC)],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [backgroundDark, surfaceDark],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1F8A70), Color(0xFF7ADAC2)],
  );
}
