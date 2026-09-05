import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

/// 05_DESIGN.md §1 "Typography":
/// - Space Grotesk (500/600/700): headings, large numeric stats.
/// - Inter (400/500/600/700): body text, UI copy.
/// - IBM Plex Mono (400/500/600): eyebrow labels, tags, device IDs.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle heading({
    double size = 20,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.text1,
  }) =>
      GoogleFonts.spaceGrotesk(fontSize: size, fontWeight: weight, color: color);

  /// The big ring number / dashboard counters.
  static TextStyle statLarge({
    double size = 44,
    Color color = AppColors.text1,
  }) =>
      GoogleFonts.spaceGrotesk(fontSize: size, fontWeight: FontWeight.w700, color: color, height: 1.0);

  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.text1,
  }) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

  static TextStyle bodySecondary({
    double size = 13,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.text2,
  }) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

  static TextStyle caption({
    double size = 12,
    Color color = AppColors.text3,
  }) =>
      GoogleFonts.inter(fontSize: size, fontWeight: FontWeight.w400, color: color);

  /// Eyebrow labels, tags, device IDs -- "system/telemetry" read.
  static TextStyle eyebrowMono({
    double size = 11,
    Color color = AppColors.text2,
    double letterSpacing = 0.6,
  }) =>
      GoogleFonts.ibmPlexMono(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: letterSpacing,
      );

  static TextStyle tagMono({
    double size = 11,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.text1,
  }) =>
      GoogleFonts.ibmPlexMono(fontSize: size, fontWeight: weight, color: color);
}
