import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Tiny read-through cache for the last good API response, so lists open
/// instantly and still show (stale) data when offline. Not a database.
class JsonCache {
  static const String _prefix = 'cache_';

  static Future<void> put(String key, Object? json) async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.setString('$_prefix$key', jsonEncode(json));
    } catch (_) {
      /* cache is best-effort */
    }
  }

  static Future<dynamic> get(String key) async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      final String? s = p.getString('$_prefix$key');
      return s == null ? null : jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  /// Call on sign-out / session expiry so the next user never sees old data.
  static Future<void> clearAll() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      for (final String k
          in p.getKeys().where((String k) => k.startsWith(_prefix)).toList()) {
        await p.remove(k);
      }
    } catch (_) {}
  }
}
