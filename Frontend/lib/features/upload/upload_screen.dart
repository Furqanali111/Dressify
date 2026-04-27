import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import '../../core/enums/app_enums.dart';
import '../../core/models/clothing_item.dart';
import '../../core/providers/wardrobe_provider.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_permissions.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/dashed_border.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';

enum _UploadStage { idle, picked, processing, done, error }

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  final ImagePicker _picker = ImagePicker();

  _UploadStage _stage = _UploadStage.idle;
  XFile? _picked;
  ClothingType _detectedType = ClothingType.top;
  double _progress = 0;
  String? _error;
  List<ClothingItem> _uploadedItems = const [];

  Future<void> _showSourceSheet() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SourceSheet(),
    );
    if (source == null) return;
    await _pickImage(source);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final bool granted = await AppPermissions.ensureCamera(context);
        if (!granted || !mounted) return;
      }
      final XFile? file =
          await _picker.pickImage(source: source, imageQuality: 90);
      if (file == null) return;
      setState(() {
        _picked = file;
        _stage = _UploadStage.picked;
        _error = null;
        _uploadedItems = const [];
        _detectedType = ClothingType.top;
      });
    } catch (_) {
      setState(() {
        _stage = _UploadStage.error;
        _error = 'Could not load that image. Try another.';
      });
    }
  }

  Future<void> _startProcessing() async {
    if (_picked == null) return;
    HapticFeedback.lightImpact();
    setState(() {
      _stage = _UploadStage.processing;
      _progress = 0;
      _error = null;
    });

    try {
      final Dio dio = ref.read(apiClientProvider);
      final String fileName = _picked!.name;
      final String itemName = fileName.contains('.')
          ? fileName.substring(0, fileName.lastIndexOf('.'))
          : fileName;

      final FormData form = FormData.fromMap(<String, dynamic>{
        'image': await MultipartFile.fromFile(_picked!.path, filename: fileName),
        'name': itemName,
      });

      final Response<dynamic> response = await dio.post<dynamic>(
        '/upload',
        data: form,
        onSendProgress: (int sent, int total) {
          if (!mounted || total <= 0) return;
          setState(() => _progress = (sent / total * 0.8).clamp(0.0, 0.8));
        },
        options: Options(contentType: 'multipart/form-data'),
      );

      // Backend now returns a list of extracted garments
      final List<ClothingItem> items = (response.data as List<dynamic>)
          .map((dynamic e) => ClothingItem.fromJson(e as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _uploadedItems = items;
        _detectedType = items.isNotEmpty ? _typeFromString(items.first.type) : ClothingType.other;
        _progress = 1.0;
        _stage = _UploadStage.done;
      });

      // Refresh wardrobe so all new items appear immediately, then poll
      // items that are still being processed by the AI metadata pipeline.
      await ref.read(wardrobeProvider.notifier).fetch();
      final List<String> pendingIds = items
          .where((ClothingItem it) => it.processingStatus == 'processing')
          .map((ClothingItem it) => it.id)
          .toList();
      if (pendingIds.isNotEmpty) {
        ref.read(wardrobeProvider.notifier).pollUntilComplete(pendingIds);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final String msg =
          ((e.response?.data as Map?)?['detail'] as String?) ??
          'Upload failed. Check your connection and try again.';
      setState(() {
        _stage = _UploadStage.error;
        _error = msg;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _stage = _UploadStage.error;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  void _reset() => setState(() {
        _stage = _UploadStage.idle;
        _picked = null;
        _progress = 0;
        _error = null;
        _uploadedItems = const [];
      });

  static ClothingType _typeFromString(String type) {
    switch (type) {
      case 'top':        return ClothingType.top;
      case 'bottom':     return ClothingType.bottom;
      case 'dress':      return ClothingType.dress;
      case 'jacket':     return ClothingType.jacket;
      case 'shoes':      return ClothingType.shoes;
      case 'accessory':  return ClothingType.accessory;
      default:           return ClothingType.other;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('Upload Clothing', style: text.headlineMedium),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_error != null)
                _ErrorBanner(message: _error!, onRetry: _reset)
              else
                Expanded(
                  child: _Hero(
                    stage: _stage,
                    picked: _picked,
                    progress: _progress,
                    uploadedItems: _uploadedItems,
                    onPick: _showSourceSheet,
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              _Bottom(
                stage: _stage,
                detectedType: _detectedType,
                uploadedItems: _uploadedItems,
                onTypeChanged: (ClothingType t) =>
                    setState(() => _detectedType = t),
                onProcess: _startProcessing,
                onChangeImage: _reset,
                onTryOn: () =>
                    context.pushReplacementNamed(AppRoute.tryOn.name),
                onGoToWardrobe: () {
                  AppToast.success(
                    context,
                    '${_uploadedItems.length} item${_uploadedItems.length == 1 ? '' : 's'} saved to wardrobe',
                  );
                  context.goNamed(AppRoute.wardrobe.name);
                },
                onSave: () {
                  AppToast.success(context, 'Saved to wardrobe');
                  context.pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero area
// ---------------------------------------------------------------------------

class _Hero extends StatelessWidget {
  const _Hero({
    required this.stage,
    required this.picked,
    required this.progress,
    required this.uploadedItems,
    required this.onPick,
  });

  final _UploadStage stage;
  final XFile? picked;
  final double progress;
  final List<ClothingItem> uploadedItems;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    if (stage == _UploadStage.idle) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onPick,
          child: CustomPaint(
            painter: DashedRRectPainter(color: c.primary.withValues(alpha: 0.6)),
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(Icons.cloud_upload_outlined, size: 56, color: c.primary),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Tap to upload or drag here',
                      style: text.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Supports JPG, PNG up to 10MB\nWearing multiple items? We\'ll extract each one.',
                      style: text.bodySmall?.copyWith(color: c.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Multi-item done state — show summary card instead of single image
    if (stage == _UploadStage.done && uploadedItems.length > 1) {
      return _MultiItemSummary(items: uploadedItems, c: c, text: text);
    }

    // Single-item done / processing — show the image
    final String? processedUrl =
        uploadedItems.isNotEmpty ? uploadedItems.first.processedUrl : null;
    final bool showProcessed =
        stage == _UploadStage.done &&
        processedUrl != null &&
        processedUrl.isNotEmpty;

    final Widget imageWidget = showProcessed
        ? Image.network(
            processedUrl,
            fit: BoxFit.contain,
            width: double.infinity,
            loadingBuilder: (_, Widget child, ImageChunkEvent? prog) =>
                prog == null ? child : const Center(child: CircularProgressIndicator()),
            errorBuilder: (_, _, _) => _localImage,
          )
        : _localImage;

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: ColoredBox(
              color: c.surface,
              child: imageWidget,
            ),
          ),
        ),
        if (stage == _UploadStage.processing)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.55),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(
                        width: 200,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress < 0.8 ? progress : null,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        progress < 0.8
                            ? 'Uploading… ${(progress / 0.8 * 100).toInt()}%'
                            : 'Detecting & extracting garments…',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (stage == _UploadStage.done && uploadedItems.length == 1)
          Positioned(
            top: AppSpacing.md,
            left: AppSpacing.md,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
              decoration: BoxDecoration(
                color: context.colors.success,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.check, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Garment extracted',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget get _localImage => picked == null
      ? const SizedBox.shrink()
      : Image.file(
          File(picked!.path),
          fit: BoxFit.cover,
          width: double.infinity,
        );
}

class _MultiItemSummary extends StatelessWidget {
  const _MultiItemSummary({
    required this.items,
    required this.c,
    required this.text,
  });

  final List<ClothingItem> items;
  final AppColors c;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: c.success.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_outline, color: c.success, size: 36),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '${items.length} garments extracted!',
            style: text.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Each item has been saved to your wardrobe.',
            style: text.bodyMedium?.copyWith(color: c.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.center,
            children: items.map((ClothingItem item) {
              final ClothingType type = _UploadScreenState._typeFromString(item.type);
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(type.icon, size: 14, color: c.primary),
                    const SizedBox(width: 4),
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.primary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom action bar
// ---------------------------------------------------------------------------

class _Bottom extends StatelessWidget {
  const _Bottom({
    required this.stage,
    required this.detectedType,
    required this.uploadedItems,
    required this.onTypeChanged,
    required this.onProcess,
    required this.onChangeImage,
    required this.onTryOn,
    required this.onGoToWardrobe,
    required this.onSave,
  });

  final _UploadStage stage;
  final ClothingType detectedType;
  final List<ClothingItem> uploadedItems;
  final ValueChanged<ClothingType> onTypeChanged;
  final VoidCallback onProcess;
  final VoidCallback onChangeImage;
  final VoidCallback onTryOn;
  final VoidCallback onGoToWardrobe;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    if (stage == _UploadStage.idle || stage == _UploadStage.error) {
      return const SizedBox.shrink();
    }

    if (stage == _UploadStage.done) {
      // Multi-item: just go to wardrobe
      if (uploadedItems.length > 1) {
        return PrimaryButton(
          label: 'View in Wardrobe',
          icon: Icons.checkroom,
          onPressed: onGoToWardrobe,
        );
      }

      // Single item: offer try-on or save
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _TypeChip(type: detectedType, color: c.success),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: SecondaryButton(
                  label: 'Save to Wardrobe',
                  icon: Icons.bookmark_outline,
                  onPressed: onSave,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: PrimaryButton(
                  label: 'Try On',
                  icon: Icons.checkroom,
                  onPressed: onTryOn,
                ),
              ),
            ],
          ),
        ],
      );
    }

    // picked or processing
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            _TypeChip(type: detectedType, color: c.success),
            const SizedBox(width: AppSpacing.md),
            DropdownButton<ClothingType>(
              value: detectedType,
              underline: const SizedBox.shrink(),
              style: text.bodyMedium,
              onChanged: stage == _UploadStage.processing
                  ? null
                  : (ClothingType? t) {
                      if (t != null) onTypeChanged(t);
                    },
              items: ClothingType.values
                  .map((ClothingType t) => DropdownMenuItem<ClothingType>(
                        value: t,
                        child: Text(t.label),
                      ))
                  .toList(),
            ),
            const Spacer(),
            if (stage != _UploadStage.processing)
              TextButton(
                onPressed: onChangeImage,
                child: const Text('Change image'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          label: stage == _UploadStage.processing
              ? 'Processing…'
              : 'Remove Background',
          onPressed: stage == _UploadStage.processing ? null : onProcess,
          loading: stage == _UploadStage.processing,
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type, required this.color});

  final ClothingType type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(type.icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            type.label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Source picker sheet
// ---------------------------------------------------------------------------

class _SourceSheet extends StatelessWidget {
  const _SourceSheet();

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheetTop),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Choose source', style: text.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: _SourceTile(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    onTap: () => Navigator.of(context).pop(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _SourceTile(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final BorderRadius radius = BorderRadius.circular(AppRadius.card);

    return Material(
      color: c.background,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Column(
            children: <Widget>[
              Icon(icon, size: 36, color: c.primary),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error state
// ---------------------------------------------------------------------------

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;

    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, color: c.error, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
                label: 'Try Again', onPressed: onRetry, fullWidth: false),
          ],
        ),
      ),
    );
  }
}
