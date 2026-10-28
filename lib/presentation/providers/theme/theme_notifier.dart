import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../core/constants/constants.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_theme.dart';
import '../../providers/theme/theme_state.dart';

final themeNotifierProvider = NotifierProvider<ThemeNotifier, ThemeState>(
  ThemeNotifier.new,
);

class ThemeNotifier extends Notifier<ThemeState> {
  @override
  ThemeState build() {
    final sharedPreferences = ref.watch(sharedPreferencesProvider);
    final value = sharedPreferences.getString(Constants.selectedBrightnessKey);
    final isLight = value == 'light';
    final brightness = isLight ? Brightness.light : Brightness.dark;

    final colorValue = sharedPreferences.getInt(Constants.selectedAccentColorKey);
    final accentColor = colorValue != null ? Color(colorValue) : AppColors.orange;

    return ThemeState(
      isLight: isLight,
      accentColor: accentColor,
      themeData: AppTheme().init(
        brightness: brightness,
        primaryColor: accentColor,
      ),
    );
  }

  void changeBrightness(bool isLight) async {
    final sharedPreferences = ref.read(sharedPreferencesProvider);
    await sharedPreferences.setString(
      Constants.selectedBrightnessKey,
      isLight ? 'light' : 'dark',
    );
    final brightness = isLight ? Brightness.light : Brightness.dark;
    state = state.copyWith(
      isLight: isLight,
      themeData: AppTheme().init(
        brightness: brightness,
        primaryColor: state.accentColor,
      ),
    );
  }

  void changeAccentColor(Color color) async {
    final sharedPreferences = ref.read(sharedPreferencesProvider);
    await sharedPreferences.setInt(
      Constants.selectedAccentColorKey,
      color.toARGB32(),
    );
    final brightness = state.isLight ? Brightness.light : Brightness.dark;
    state = state.copyWith(
      accentColor: color,
      themeData: AppTheme().init(
        brightness: brightness,
        primaryColor: color,
      ),
    );
  }
}
