import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  ErrorWidget.builder = (FlutterErrorDetails details) => Material(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Something went wrong.\n${details.exception}',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );

  // Load .env if present. Missing file is fine — AppFlags falls back to
  // --dart-define values, then to hardcoded defaults.
  try {
    await dotenv.load();
  } catch (_) {
    // Swallow: .env not bundled / not configured. Use defaults.
  }

  runApp(const ProviderScope(child: DressifyApp()));
}
