import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Runtime config sourced from `.env` (loaded at startup) with a
/// `--dart-define` override and a hardcoded fallback.
///
/// Lookup order for every key:
///   1. `--dart-define=KEY=value` (compile-time)
///   2. `.env` (runtime, loaded by `dotenv.load()` in `main.dart`)
///   3. Hardcoded default below
///
/// Edit `.env` to change values without rebuilding. To override per-build
/// (CI etc.) pass `--dart-define`.
class AppFlags {
  const AppFlags._();

  /// Skip Google sign-in for local UI work. Splash routes directly to
  /// profile setup; sign-in screen auto-advances. Both surface a visible
  /// "AUTH BYPASSED" indicator so this can't ship.
  static bool get bypassAuth => _bool('BYPASS_AUTH', defaultValue: false);

  /// Backend base URL. Override per environment.
  static String get apiBaseUrl =>
      _string('API_BASE_URL', defaultValue: 'http://localhost:8000');

  /// Sentry DSN. Empty string means crash reporting is disabled.
  static String get sentryDsn => _string('SENTRY_DSN', defaultValue: '');

  // ---- helpers ------------------------------------------------------------

  static String _string(String key, {required String defaultValue}) {
    const Map<String, String> defines = <String, String>{};
    if (defines.containsKey(key)) return defines[key]!;
    final String? fromDefine = _fromDefine(key);
    if (fromDefine != null && fromDefine.isNotEmpty) return fromDefine;
    if (dotenv.isInitialized) {
      final String? v = dotenv.env[key];
      if (v != null && v.isNotEmpty) return v;
    }
    return defaultValue;
  }

  static bool _bool(String key, {required bool defaultValue}) {
    final String raw = _string(key, defaultValue: defaultValue.toString())
        .trim()
        .toLowerCase();
    if (raw == 'true' || raw == '1' || raw == 'yes') return true;
    if (raw == 'false' || raw == '0' || raw == 'no') return false;
    return defaultValue;
  }

  /// Reads a value passed via `--dart-define`. Each key needs an explicit
  /// `String.fromEnvironment` call because the lookup table is constant —
  /// add new keys here as they're introduced.
  static String? _fromDefine(String key) {
    switch (key) {
      case 'BYPASS_AUTH':
        const String v = String.fromEnvironment('BYPASS_AUTH');
        return v.isEmpty ? null : v;
      case 'API_BASE_URL':
        const String v = String.fromEnvironment('API_BASE_URL');
        return v.isEmpty ? null : v;
      case 'SENTRY_DSN':
        const String v = String.fromEnvironment('SENTRY_DSN');
        return v.isEmpty ? null : v;
    }
    return null;
  }
}
