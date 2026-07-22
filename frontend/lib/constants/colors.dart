import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF0F5238);
  static const Color primaryContainer = Color(0xFF2D6A4F);
  static const Color onPrimary = Colors.white;
  static const Color onPrimaryContainer = Color(0xFFA8E7C5);
  
  static const Color secondary = Color(0xFF2B694D);
  static const Color onSecondary = Colors.white;
  static const Color secondaryContainer = Color(0xFFB0F1CC);
  static const Color onSecondaryContainer = Color(0xFF327053);
  
  static const Color tertiary = Color(0xFF364D3C);
  static const Color onTertiary = Colors.white;
  static const Color tertiaryContainer = Color(0xFF4D6553);
  static const Color onTertiaryContainer = Color(0xFFC6E1CA);
  
  static const Color background = Color(0xFFF8F9FA);
  static const Color onBackground = Color(0xFF191C1D);
  
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF191C1D);
  static const Color onSurfaceVariant = Color(0xFF404943);
  
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF3F4F5);
  static const Color surfaceContainer = Color(0xFFEDEEEF);
  static const Color surfaceContainerHigh = Color(0xFFE7E8E9);
  static const Color surfaceContainerHighest = Color(0xFFE1E3E4);
  
  static const Color outline = Color(0xFF707973);
  static const Color outlineVariant = Color(0xFFBFC9C1);
  
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Colors.white;
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);
}

class AppDesign {
  static const double borderRadiusSm = 8.0;
  static const double borderRadiusDefault = 16.0;
  static const double borderRadiusMd = 24.0;
  static const double borderRadiusLg = 32.0;
  static const double borderRadiusXl = 48.0;

  static const List<BoxShadow> level1Shadow = [
    BoxShadow(
      color: Color.fromRGBO(45, 106, 79, 0.04),
      offset: Offset(0, 2),
      blurRadius: 4,
    ),
  ];

  static const List<BoxShadow> level2Shadow = [
    BoxShadow(
      color: Color.fromRGBO(45, 106, 79, 0.08),
      offset: Offset(0, 12),
      blurRadius: 24,
    ),
  ];
}
