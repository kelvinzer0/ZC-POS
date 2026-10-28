class Constants {
  // Prevents instantiation and extension
  Constants._();

  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '555155784059-92oof83j72eakst3g936u0aacs41k6n7.apps.googleusercontent.com',
  );

  static const String selectedDeviceIdKey = 'selected_device_id';
  static const String selectedConnectionTypeKey = 'selected_connection_type';
  static const String selectedPaperSizeKey = 'selected_paper_size';
  static const String selectedBrightnessKey = 'selected_brightness';
  static const String selectedAccentColorKey = 'selected_accent_color';
  static const String receiptLogoPathKey = 'receipt_logo_path';
  static const String receiptHeaderTitleKey = 'receipt_header_title';
  static const String receiptHeaderSubtitleKey = 'receipt_header_subtitle';

  static const int minSyncIntervalToleranceForCriticalInMinutes = 5;
  static const int minSyncIntervalToleranceForLessCriticalInMinutes = 100;

  // Google OAuth scopes required for user authentication
  static const List<String> authScopes = [
    'https://www.googleapis.com/auth/userinfo.profile',
    'https://www.googleapis.com/auth/userinfo.email',
  ];

  // Non-critical error libraries that should be logged but not navigate to error screen
  static const nonCriticalErrorLibraries = {
    'image resource service',
  };
}
