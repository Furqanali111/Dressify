import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/mock/mock_data.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/dashed_border.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';

enum _UploadStage { idle, picked, processing, done, error }

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final ImagePicker _picker = ImagePicker();

  _UploadStage _stage = _UploadStage.idle;
  XFile? _picked;
  ClothingType _detectedType = ClothingType.top;
  double _progress = 0;
  String? _error;
  Timer? _progressTimer;

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  Future<void> _showSourceSheet() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => const _SourceSheet(),
    );
    if (source == null) return;
    await _pickImage(source);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(source: source, imageQuality: 90);
      if (file == null) return;
      setState(() {
        _picked = file;
        _stage = _UploadStage.picked;
        _error = null;
        // Mocked auto-detection — pretend the API returned 'Top'.
        _detectedType = ClothingType.top;
      });
    } catch (_) {
      setState(() {
        _stage = _UploadStage.error;
        _error = 'Could not load that image. Try another.';
      });
    }
  }

  void _startProcessing() {
    HapticFeedback.lightImpact();
    setState(() {
      _stage = _UploadStage.processing;
      _progress = 0;
    });

    // TODO(api): POST image to backend `/upload`, stream progress.
    _progressTimer = Timer.periodic(const Duration(milliseconds: 60), (Timer t) {
      if (!mounted) return;
      setState(() => _progress = (_progress + 0.025).clamp(0.0, 1.0));
      if (_progress >= 1.0) {
        t.cancel();
        HapticFeedback.lightImpact();
        setState(() => _stage = _UploadStage.done);
      }
    });
  }

  void _reset() {
    _progressTimer?.cancel();
    setState(() {
      _stage = _UploadStage.idle;
      _picked = null;
      _progress = 0;
      _error = null;
    });
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
                Expanded(child: _Hero(
                  stage: _stage,
                  picked: _picked,
                  progress: _progress,
                  onPick: _showSourceSheet,
                )),
              const SizedBox(height: AppSpacing.lg),
              _Bottom(
                stage: _stage,
                detectedType: _detectedType,
                onTypeChanged: (ClothingType t) =>
                    setState(() => _detectedType = t),
                onProcess: _startProcessing,
                onChangeImage: _reset,
                onTryOn: () => context.pushReplacementNamed(AppRoute.tryOn.name),
                onSave: () {
                  // TODO(api): POST clothing item to wardrobe.
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

class _Hero extends StatelessWidget {
  const _Hero({
    required this.stage,
    required this.picked,
    required this.progress,
    required this.onPick,
  });

  final _UploadStage stage;
  final XFile? picked;
  final double progress;
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
            child: Container(
              width: double.infinity,
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
                    'Supports JPG, PNG up to 10MB',
                    style: text.bodySmall?.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final Widget image = picked == null
        ? const SizedBox.shrink()
        : ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Image.file(
              File(picked!.path),
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          );

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: image,
          ),
        ),
        if (stage == _UploadStage.processing)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.45),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(
                        width: 200,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(Colors.white),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Removing background… ${(progress * 100).toInt()}%',
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
        if (stage == _UploadStage.done)
          Positioned(
            top: AppSpacing.md,
            left: AppSpacing.md,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: c.success,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.check, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Background removed',
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
}

class _Bottom extends StatelessWidget {
  const _Bottom({
    required this.stage,
    required this.detectedType,
    required this.onTypeChanged,
    required this.onProcess,
    required this.onChangeImage,
    required this.onTryOn,
    required this.onSave,
  });

  final _UploadStage stage;
  final ClothingType detectedType;
  final ValueChanged<ClothingType> onTypeChanged;
  final VoidCallback onProcess;
  final VoidCallback onChangeImage;
  final VoidCallback onTryOn;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    if (stage == _UploadStage.idle || stage == _UploadStage.error) {
      return const SizedBox.shrink();
    }

    if (stage == _UploadStage.done) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: c.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(detectedType.icon, size: 14, color: c.success),
                    const SizedBox(width: 4),
                    Text(
                      'Detected: ${detectedType.label}',
                      style: TextStyle(
                        color: c.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: c.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.check, size: 14, color: c.success),
                  const SizedBox(width: 4),
                  Text(
                    '${detectedType.label} detected',
                    style: TextStyle(
                      color: c.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            DropdownButton<ClothingType>(
              value: detectedType,
              underline: const SizedBox.shrink(),
              style: text.bodyMedium,
              onChanged: (ClothingType? t) {
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
            PrimaryButton(label: 'Try Again', onPressed: onRetry, fullWidth: false),
          ],
        ),
      ),
    );
  }
}
