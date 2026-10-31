import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/friendly_error_interceptor.dart';
import '../../core/providers/tryon_photo_provider.dart';
import '../../core/providers/tryon_provider.dart';
import '../../core/router/app_routes.dart';
import '../../core/widgets/app_toast.dart';

/// Takes (or picks) a portrait photo and saves it server-side as the user's
/// try-on photo. Returns true when a photo is saved.
Future<bool> captureTryOnPhoto(BuildContext context, WidgetRef ref,
    {ImageSource source = ImageSource.camera}) async {
  final bool proceed = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: const Text('Your try-on photo'),
          content: const Text(
            'Stand 2–3 steps back so your whole body is in frame, in good light, '
            'facing the camera in fitted clothes. We save it once and reuse it for every try-on.',
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Take photo')),
          ],
        ),
      ) ??
      false;
  if (!proceed || !context.mounted) return false;

  final XFile? file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1536,
    maxHeight: 2048,
    imageQuality: 90,
  );
  if (file == null || !context.mounted) return false;

  try {
    await ref.read(tryOnPhotoProvider.notifier).save(await file.readAsBytes());
    if (context.mounted) AppToast.success(context, 'Photo saved — try-ons are now one tap');
    return true;
  } on DioException catch (e) {
    if (context.mounted) AppToast.error(context, friendlyMessage(e));
    return false;
  }
}

/// One-tap AI try-on of [clothingItemId] using the saved photo. Asks for a
/// photo first if there isn't one yet, shows progress, then opens the result.
Future<void> runAiTryOn(BuildContext context, WidgetRef ref, String clothingItemId) async {
  final TryOnPhoto? photo = ref.read(tryOnPhotoProvider).value;
  if (photo == null || !photo.hasPhoto) {
    if (!await captureTryOnPhoto(context, ref) || !context.mounted) return;
  }

  final NavigatorState nav = Navigator.of(context, rootNavigator: true);
  final GoRouter router = GoRouter.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: <Widget>[
          SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 16),
          Expanded(child: Text('Creating your look… this takes about 20 seconds')),
        ]),
      ),
    ),
  );

  final TryOnNotifier notifier = ref.read(tryOnProvider.notifier);
  await notifier.generate(clothingItemId: clothingItemId);
  final TryOnState result = ref.read(tryOnProvider);
  nav.pop(); // close progress dialog
  notifier.reset();

  if (result.status == TryOnStatus.done && result.resultUrl != null) {
    router.pushNamed(AppRoute.tryOnResult.name, extra: result.resultUrl);
  } else if (context.mounted) {
    AppToast.error(context, result.errorMessage ?? 'AI try-on failed. Please try again.');
  }
}
