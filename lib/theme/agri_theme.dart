import 'package:flutter/material.dart';

import '../models/analysis_models.dart';

class AgriTheme {
  static ThemeData materialTheme() {
    const seed = Color(0xFF1B5E20);
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
      ),
    );
  }

  static ThemeData darkTheme() {
    const seed = Color(0xFF66BB6A);
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static Color healthColor(CropHealthLevel level) {
    return switch (level) {
      CropHealthLevel.healthy => const Color(0xFF2E7D32),
      CropHealthLevel.moderate => const Color(0xFFF9A825),
      CropHealthLevel.critical => const Color(0xFFC62828),
    };
  }

  static Color pestColor(PestRiskLevel level) {
    return switch (level) {
      PestRiskLevel.low => const Color(0xFF2E7D32),
      PestRiskLevel.medium => const Color(0xFFEF6C00),
      PestRiskLevel.high => const Color(0xFFC62828),
    };
  }
}
