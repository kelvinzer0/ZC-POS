import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';

class AppSnackBar {
  static Future<dynamic> show(String message) async {
    final pair = _getMessengerAndTheme;
    if (pair == null) return;
    pair.$1.hideCurrentSnackBar();
    pair.$1.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: pair.$2.colorScheme.tertiary,
      ),
    );
  }

  static Future<dynamic> showError(String errorMessage) async {
    final pair = _getMessengerAndTheme;
    if (pair == null) return;
    pair.$1.hideCurrentSnackBar();
    pair.$1.showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: pair.$2.colorScheme.error,
      ),
    );
  }

  static (ScaffoldMessengerState, ThemeData)? get _getMessengerAndTheme {
    final context = AppRoutes.rootNavigatorKey.currentContext;
    if (context == null) return null;

    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);

    return (messenger, theme);
  }
}
