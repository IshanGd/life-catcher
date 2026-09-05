import 'package:flutter/material.dart';

/// Design tokens from 05_DESIGN.md §1. Dark theme only, deliberately — see
/// 05_DESIGN.md §5: "The amber/dark palette ... not a placeholder."
class AppColors {
  AppColors._();

  static const bgApp = Color(0xFF0E1116);
  static const bgPage = Color(0xFF0A0C10);
  static const surface = Color(0xFF171B21);
  static const surface2 = Color(0xFF1E242C);
  static const surface3 = Color(0xFF252C36);

  static const amber = Color(0xFFFFB020);
  static const amberDim = Color(0x24FFB020); // rgba(255,176,32,0.14)
  static const red = Color(0xFFFF5C5C);
  static const redDim = Color(0x24FF5C5C); // rgba(255,92,92,0.14)
  static const green = Color(0xFF35C48C);
  static const greenDim = Color(0x2435C48C); // rgba(53,196,140,0.14)
  static const blue = Color(0xFF4FA8FF);
  static const blueDim = Color(0x244FA8FF); // rgba(79,168,255,0.14)

  static const text1 = Color(0xFFF2F4F7);
  static const text2 = Color(0xFF98A1B0);
  static const text3 = Color(0xFF5C6472);

  static const border = Color(0xFF262C35);
  static const borderSoft = Color(0xFF1D222A);
}
