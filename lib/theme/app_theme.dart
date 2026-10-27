import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const background = Color(0xFF0A0E17);
  static const card = Color(0xFF111827);
  static const cardBorder = Color(0x14FFFFFF);
  static const primary = Color(0xFF6366F1);
  static const primaryLight = Color(0xFFA5B4FC);
  static const cyan = Color(0xFF06B6D4);
  static const success = Color(0xFF34D399);
  static const danger = Color(0xFFEF4444);
  static const dangerLight = Color(0xFFFB7185);
  static const text = Colors.white;
  static const textSecondary = Color(0xFF94A3B8);
  static const textDim = Color(0xFF64748B);
  static const inputFill = Color(0x0DFFFFFF);
  static const inputBorder = Color(0x1AFFFFFF);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        surface: AppColors.card,
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFill,
        hintStyle: const TextStyle(color: AppColors.textDim),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: _border(AppColors.inputBorder),
        enabledBorder: _border(AppColors.inputBorder),
        focusedBorder: _border(AppColors.primary),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color),
      );
}
