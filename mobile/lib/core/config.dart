import 'package:flutter/foundation.dart' show kIsWeb;

/// Runtime configuration.
///
/// Resolution order for the API base URL:
///  1. `--dart-define=API_BASE_URL=...` (what CI passes when building the APK)
///  2. On web, the origin the app was served from - the backend serves the
///     web bundle itself, so the API is always same-origin. No CORS, no config.
///  3. Otherwise the Android emulator's route to the host machine.
class AppConfig {
  const AppConfig._();

  static const String _override = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) return '${Uri.base.origin}/api';
    return 'http://10.0.2.2:4000/api';
  }

  /// Base origin, used for the chat socket and for rewriting file URLs.
  static String get host => apiBaseUrl.replaceAll(RegExp(r'/api/?$'), '');

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
