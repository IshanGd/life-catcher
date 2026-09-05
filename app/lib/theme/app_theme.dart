import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

/// 05_DESIGN.md §1 "Visual language": rounded surfaces (14-20px radius),
/// 1px borders in --border, no heavy shadows except the phone frame (not
/// applicable inside the app itself).
class AppRadii {
  AppRadii._();
  static const card = 18.0;
  static const cardSmall = 14.0;
  static const pill = 999.0;
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgPage,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.amber,
        secondary: AppColors.blue,
        error: AppColors.red,
        onSurface: AppColors.text1,
        onPrimary: Color(0xFF241A03),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: AppColors.text1,
        displayColor: AppColors.text1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgPage,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.text1,
      ),
      dividerColor: AppColors.border,
    );

    return base.copyWith(
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.bgApp,
        indicatorColor: AppColors.amberDim,
        surfaceTintColor: Colors.transparent,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? AppColors.amber : AppColors.text2);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.amber : AppColors.text2,
          );
        }),
      ),
    );
  }
}

/// A rounded, bordered surface matching the mockup's card language
/// (05_DESIGN.md §1). Used as the base for every stat/list card.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.surface,
    this.radius = AppRadii.card,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: child,
    );
  }
}
