import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers/tryon_provider.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_toast.dart';

class TryOnResultScreen extends ConsumerWidget {
  const TryOnResultScreen({super.key, required this.imageUrl});

  final String imageUrl;

  static final Dio _shareDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  Future<Uint8List?> _fetchBytes(BuildContext context) async {
    try {
      final Response<List<int>> resp = await _shareDio.get<List<int>>(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(resp.data ?? <int>[]);
    } catch (_) {
      if (context.mounted) AppToast.error(context, 'Could not download image');
      return null;
    }
  }

  Future<void> _share(BuildContext context) async {
    final Uint8List? bytes = await _fetchBytes(context);
    if (bytes == null) return;
    await Share.shareXFiles(
      <XFile>[XFile.fromData(bytes, mimeType: 'image/jpeg', name: 'dressify_tryon.jpg')],
      subject: 'My AI Try-On — Dressify',
    );
  }

  Future<void> _saveToGallery(BuildContext context) async {
    final Uint8List? bytes = await _fetchBytes(context);
    if (bytes == null) return;
    try {
      await Gal.putImageBytes(bytes, name: 'dressify_tryon.jpg');
      if (context.mounted) AppToast.success(context, 'Saved to gallery');
    } catch (_) {
      if (context.mounted) AppToast.error(context, 'Could not save to gallery');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('AI Try-On Result'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: () => _saveToGallery(context),
            tooltip: 'Save to gallery',
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _share(context),
            tooltip: 'Share',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(tryOnProvider.notifier).reset();
              Navigator.of(context).pop();
            },
            tooltip: 'Try again',
          ),
        ],
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (_, _) => const Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: CircularProgressIndicator(color: Colors.white54),
            ),
            errorWidget: (_, _, _) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.broken_image_outlined, color: Colors.white38, size: 56),
                SizedBox(height: AppSpacing.md),
                Text(
                  'Could not load result',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
