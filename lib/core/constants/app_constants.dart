// app_constants.dart
// Central place for build-time and runtime constants.
//
// To override the backend URL for a physical device or production, build with:
//   flutter run --dart-define=BACKEND_URL=http://192.168.x.x:8000
//   flutter build apk --dart-define=BACKEND_URL=https://your-production-domain.com

class AppConstants {
  AppConstants._();

  /// Python FastAPI backend base URL.
  /// Override at build time with --dart-define=BACKEND_URL=...
  /// Default: host machine's local network IP (works on physical devices on same Wi-Fi).
  /// For Android emulator use http://10.0.2.2:8000 instead.
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://192.168.4.62:8000',
  );

  static const Duration httpTimeout = Duration(seconds: 30);
}
