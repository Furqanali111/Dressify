import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Centralized permission utility for the Dressify app.
/// Call [requestStartupPermissions] once after first authentication
/// to request camera and location permissions upfront.
class AppPermissions {
  const AppPermissions._();

  /// Request camera and location permissions at app startup.
  /// Shows rationale dialogs if previously denied.
  static Future<void> requestStartupPermissions(BuildContext context) async {
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.location,
    ].request();

    // If any permission is permanently denied, nudge the user
    final bool hasPermanentlyDenied =
        statuses.values.any((PermissionStatus s) => s.isPermanentlyDenied);

    if (hasPermanentlyDenied && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Dressify needs camera & location access. Please enable in Settings.',
          ),
          action: SnackBarAction(
            label: 'Open Settings',
            onPressed: openAppSettings,
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// Request camera permission when needed (e.g., before opening camera).
  static Future<bool> ensureCamera(BuildContext context) async {
    PermissionStatus status = await Permission.camera.status;
    if (status.isGranted) return true;

    status = await Permission.camera.request();
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Camera access needed. Please enable in Settings.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: openAppSettings,
          ),
        ),
      );
    }
    return false;
  }

  /// Request location permission when needed (e.g., weather context).
  static Future<bool> ensureLocation(BuildContext context) async {
    PermissionStatus status = await Permission.location.status;
    if (status.isGranted) return true;

    status = await Permission.location.request();
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Location access needed for weather. Enable in Settings.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: openAppSettings,
          ),
        ),
      );
    }
    return false;
  }
}
