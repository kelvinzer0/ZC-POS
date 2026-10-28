import 'package:flutter/material.dart';

import '../../../core/themes/app_colors.dart';

class ThemeState {
  final bool isLight;
  final Color accentColor;
  final ThemeData themeData;

  const ThemeState({
    required this.isLight,
    this.accentColor = AppColors.orange,
    required this.themeData,
  });

  ThemeState copyWith({
    bool? isLight,
    Color? accentColor,
    ThemeData? themeData,
  }) {
    return ThemeState(
      isLight: isLight ?? this.isLight,
      accentColor: accentColor ?? this.accentColor,
      themeData: themeData ?? this.themeData,
    );
  }
}
