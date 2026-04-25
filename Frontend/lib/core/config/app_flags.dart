/// Build-time feature flags driven by `--dart-define`.
///
/// Run with auth disabled for local UI work:
/// `flutter run --dart-define=BYPASS_AUTH=true`
class AppFlags {
  const AppFlags._();

  /// Skip Google sign-in and route past the auth screen with a stub user.
  /// Splash routes directly to profile setup; sign-in screen auto-advances.
  static const bool bypassAuth = bool.fromEnvironment(
    'BYPASS_AUTH',
    defaultValue: false,
  );

  /// Backend base URL. Override per environment with
  /// `--dart-define=API_BASE_URL=https://api.dressify.app`.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
}
