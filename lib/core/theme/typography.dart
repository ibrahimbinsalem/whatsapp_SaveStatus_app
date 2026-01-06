import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Application Typography
/// Centralized text style definitions
class AppTypography {
  // Private constructor to prevent instantiation
  AppTypography._();

  // Base Font Family
  static String get fontFamily => GoogleFonts.ibmPlexSansArabic().fontFamily!;

  // Heading Styles
  static TextStyle h1 = GoogleFonts.ibmPlexSansArabic(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static TextStyle h2 = GoogleFonts.ibmPlexSansArabic(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  static TextStyle h3 = GoogleFonts.ibmPlexSansArabic(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static TextStyle h4 = GoogleFonts.ibmPlexSansArabic(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  static TextStyle h5 = GoogleFonts.ibmPlexSansArabic(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.45,
  );

  static TextStyle h6 = GoogleFonts.ibmPlexSansArabic(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.45,
  );

  // Body Text Styles
  static TextStyle bodyLarge = GoogleFonts.ibmPlexSansArabic(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  static TextStyle bodyMedium = GoogleFonts.ibmPlexSansArabic(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  static TextStyle bodySmall = GoogleFonts.ibmPlexSansArabic(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  // Button Text Style
  static TextStyle button = GoogleFonts.ibmPlexSansArabic(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  // Caption Text Style
  static TextStyle caption = GoogleFonts.ibmPlexSansArabic(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  // Overline Text Style
  static TextStyle overline = GoogleFonts.ibmPlexSansArabic(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.6,
  );

  // Label Text Styles
  static TextStyle labelLarge = GoogleFonts.ibmPlexSansArabic(
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static TextStyle labelMedium = GoogleFonts.ibmPlexSansArabic(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  static TextStyle labelSmall = GoogleFonts.ibmPlexSansArabic(
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );
}
