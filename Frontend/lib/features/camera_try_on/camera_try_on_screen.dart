import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/clothing_item.dart';
import '../../core/models/outfit.dart';
import '../../core/providers/camera_garments_provider.dart';
import '../../core/providers/fit_rating_provider.dart';
import '../../core/providers/fit_scale_provider.dart';
import '../../core/providers/wardrobe_provider.dart';
import '../../core/router/app_routes.dart';
import '../../core/services/pose_detection_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_permissions.dart';
import '../../core/utils/garment_utils.dart';
import '../../core/widgets/app_toast.dart';

// ---------------------------------------------------------------------------
// Garment data holder
// ---------------------------------------------------------------------------

class _GarmentData {
  _GarmentData({required this.item, required this.uiImage});
  final ClothingItem item;
  final ui.Image uiImage;
  void dispose() => uiImage.dispose();
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// [tabMode] = true  — lives in the bottom-nav shell; reads garments from
///                     [cameraGarmentsProvider] (set by "See on Me" in wardrobe).
/// [tabMode] = false — pushed as a modal; loads garments from [outfit].
class CameraTryOnScreen extends ConsumerStatefulWidget {
  const CameraTryOnScreen({
    super.key,
    this.outfit,
    this.tabMode = false,
  });

  final Outfit? outfit;
  final bool tabMode;

  @override
  ConsumerState<CameraTryOnScreen> createState() => _CameraTryOnScreenState();
}

class _CameraTryOnScreenState extends ConsumerState<CameraTryOnScreen>
    with WidgetsBindingObserver {
  // ── Camera ────────────────────────────────────────────────────────────────
  CameraController? _controller;
  List<CameraDescription> _cameras = <CameraDescription>[];
  int _cameraIndex = 0;
  bool _cameraReady = false;
  bool _cameraError = false;

  // ── Pose ──────────────────────────────────────────────────────────────────
  final PoseDetectionService _poseService = PoseDetectionService();
  Map<String, NormAnchor>? _anchors;
  DateTime _lastFrameTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _frameThrottle = AppConstants.frameThrottle;

  // ── Garments ──────────────────────────────────────────────────────────────
  // Maps ClothingItem.id → loaded garment data.
  final Map<String, _GarmentData> _garments = <String, _GarmentData>{};
  bool _loadingGarments = false;
  // The item IDs we last loaded garments for (detect changes).
  List<String> _lastLoadedIds = <String>[];

  // ── Capture ───────────────────────────────────────────────────────────────
  final GlobalKey _previewKey = GlobalKey();
  bool _capturing = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    if (!widget.tabMode) {
      _loadGarmentsFromOutfit(widget.outfit);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadItems(ref.read(cameraGarmentsProvider));
      });
    }
  }

  @override
  void didUpdateWidget(CameraTryOnScreen old) {
    super.didUpdateWidget(old);
    if (!widget.tabMode && old.outfit?.id != widget.outfit?.id) {
      _clearGarments();
      _loadGarmentsFromOutfit(widget.outfit);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      ctrl.dispose();
      if (mounted) setState(() => _cameraReady = false);
    } else if (state == AppLifecycleState.resumed) {
      _initControllerFor(_cameras[_cameraIndex]);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _poseService.dispose();
    _clearGarments();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Camera init
  // ---------------------------------------------------------------------------

  Future<void> _initCamera() async {
    if (!mounted) return;
    final bool granted = await AppPermissions.ensureCamera(context);
    if (!granted) {
      if (mounted) setState(() => _cameraError = true);
      return;
    }
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _cameraError = true);
        return;
      }
      final int front = _cameras.indexWhere(
        (CameraDescription c) => c.lensDirection == CameraLensDirection.front,
      );
      _cameraIndex = front >= 0 ? front : 0;
      await _initControllerFor(_cameras[_cameraIndex]);
    } catch (_) {
      if (mounted) setState(() => _cameraError = true);
    }
  }

  Future<void> _initControllerFor(CameraDescription cam) async {
    final CameraController ctrl = CameraController(
      cam,
      AppConstants.cameraResolution,
      enableAudio: false,
      imageFormatGroup: _formatGroup,
    );
    try {
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      _controller = ctrl;
      await ctrl.startImageStream(_onFrame);
      if (mounted) setState(() => _cameraReady = true);
    } catch (_) {
      await ctrl.dispose();
      if (mounted) setState(() => _cameraError = true);
    }
  }

  ImageFormatGroup get _formatGroup {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return ImageFormatGroup.nv21;
    }
    return ImageFormatGroup.bgra8888;
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
    if (mounted) setState(() => _cameraReady = false);
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _initControllerFor(_cameras[_cameraIndex]);
  }

  // ---------------------------------------------------------------------------
  // Frame processing
  // ---------------------------------------------------------------------------

  void _onFrame(CameraImage image) {
    final DateTime now = DateTime.now();
    if (now.difference(_lastFrameTime) < _frameThrottle) return;
    _lastFrameTime = now;
    final CameraController? ctrl = _controller;
    if (ctrl == null) return;
    final CameraDescription cam = _cameras[_cameraIndex];
    _poseService
        .processFrame(
          image: image,
          sensorOrientation: cam.sensorOrientation,
          deviceOrientation: ctrl.value.deviceOrientation,
          lensDirection: cam.lensDirection,
        )
        .then((Map<String, NormAnchor>? anchors) {
      if (mounted) setState(() => _anchors = anchors);
    }).catchError((_) {
      // Ignore transient errors; optionally log them.
    });
  }

  // ---------------------------------------------------------------------------
  // Garment loading
  // ---------------------------------------------------------------------------

  void _clearGarments() {
    for (final _GarmentData g in _garments.values) {
      g.dispose();
    }
    _garments.clear();
    _lastLoadedIds = <String>[];
  }

  Future<void> _loadGarmentsFromOutfit(Outfit? outfit) async {
    if (outfit == null || outfit.items.isEmpty) return;
    final List<ClothingItem> cached =
        ref.read(wardrobeProvider).value ?? const <ClothingItem>[];
    await _loadItems(
      outfit.items
          .map((OutfitItem oi) =>
              cached.cast<ClothingItem?>().firstWhere(
                    (ClothingItem? it) => it?.id == oi.clothingItemId,
                    orElse: () => null,
                  ))
          .whereType<ClothingItem>()
          .toList(),
    );
  }

  Future<void> _loadItems(List<ClothingItem> items) async {
    final List<String> ids = items.map((ClothingItem it) => it.id).toList();
    if (ids.join(',') == _lastLoadedIds.join(',')) return;

    if (mounted) setState(() => _loadingGarments = true);

    // Dispose garments that are no longer in the list.
    final Set<String> newIds = ids.toSet();
    final List<String> toRemove =
        _garments.keys.where((String k) => !newIds.contains(k)).toList();
    for (final String k in toRemove) {
      _garments[k]?.dispose();
      _garments.remove(k);
    }

    for (final ClothingItem ci in items) {
      if (_garments.containsKey(ci.id)) continue;
      if (ci.processedUrl.isEmpty) continue;
      try {
        final ui.Image img = await _decodeNetworkImage(ci.processedUrl);
        if (!mounted) {
          img.dispose();
          return;
        }
        _garments[ci.id] = _GarmentData(item: ci, uiImage: img);
      } catch (_) {}
    }

    _lastLoadedIds = ids;
    if (mounted) setState(() => _loadingGarments = false);
  }

  static Future<ui.Image> _decodeNetworkImage(String url) async {
    final Completer<ui.Image> completer = Completer<ui.Image>();
    final ImageStream stream =
        NetworkImage(url).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        completer.complete(info.image.clone());
        stream.removeListener(listener);
      },
      onError: (Object e, StackTrace? _) {
        completer.completeError(e);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future.timeout(
      AppConstants.imageLoadTimeout,
      onTimeout: () => throw TimeoutException('Image load timed out: $url'),
    );
  }

  // ---------------------------------------------------------------------------
  // Garment picker
  // ---------------------------------------------------------------------------

  void _openGarmentPicker(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _GarmentPickerSheet(),
    );
  }

  // ---------------------------------------------------------------------------
  // Capture
  // ---------------------------------------------------------------------------

  Future<void> _capture() async {
    if (_capturing) return;
    HapticFeedback.mediumImpact();
    setState(() => _capturing = true);
    try {
      await _controller?.stopImageStream();
      final RenderRepaintBoundary? boundary = _previewKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) AppToast.error(context, 'Capture failed — try again');
        return;
      }
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        if (mounted) AppToast.error(context, 'Capture failed — try again');
        return;
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _CapturePreviewDialog(pngBytes: byteData.buffer.asUint8List()),
      );
    } catch (_) {
      if (mounted) AppToast.error(context, 'Capture failed — try again');
    } finally {
      try {
        await _controller?.startImageStream(_onFrame);
      } catch (_) {
        if (mounted) AppToast.error(context, 'Tap to restart camera');
      }
      if (mounted) setState(() => _capturing = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // In tab mode, garments come from the shared provider.
    if (widget.tabMode) {
      ref.listen<List<ClothingItem>>(cameraGarmentsProvider, (_, next) {
        _loadItems(next);
      });
    }

    final bool hasGarments = _garments.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // ── Camera preview + overlay ─────────────────────────────────
            if (_cameraReady && _controller != null)
              RepaintBoundary(
                key: _previewKey,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    CameraPreview(_controller!),
                    if (hasGarments)
                      LayoutBuilder(
                        builder: (_, BoxConstraints bc) => CustomPaint(
                          size: bc.biggest,
                          painter: _CameraOverlayPainter(
                            garments: _garments.values.toList(),
                            anchors: _anchors,
                            displaySize: bc.biggest,
                            fitScales: ref.watch(fitScalesProvider),
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else if (_cameraError)
              const _CameraError()
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // ── "Stand in front" guide ───────────────────────────────────
            if (_cameraReady && hasGarments && _anchors == null)
              Center(
                child: _PillBadge(
                  icon: Icons.person_outline,
                  text: 'Stand in front of the camera',
                ),
              ),

            // ── Tab-mode empty state ─────────────────────────────────────
            if (widget.tabMode && !hasGarments && _cameraReady)
              Center(
                child: _EmptyTabGuide(
                  onAdd: () => _openGarmentPicker(context),
                  onBrowse: () => context.pushNamed(AppRoute.wardrobe.name),
                ),
              ),

            // ── Top bar ──────────────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _TopBar(
                showBack: !widget.tabMode,
                onBack: () => context.pop(),
                onFlip: _cameras.length > 1 ? _flipCamera : null,
                onWardrobe: widget.tabMode
                    ? () => context.pushNamed(AppRoute.wardrobe.name)
                    : null,
              ),
            ),

            // ── Selected garment chips (tab mode only) ───────────────────
            if (widget.tabMode && hasGarments)
              Positioned(
                bottom: 104,
                left: AppSpacing.md,
                right: AppSpacing.md,
                child: _SelectedGarmentBar(
                  garments: _garments.values.toList(),
                  onRemove: (ClothingItem item) {
                    final List<ClothingItem> current =
                        List<ClothingItem>.from(ref.read(cameraGarmentsProvider));
                    current.removeWhere((ClothingItem it) => it.id == item.id);
                    ref.read(cameraGarmentsProvider.notifier).state = current;
                  },
                  onClearAll: () {
                    ref.read(cameraGarmentsProvider.notifier).state =
                        const <ClothingItem>[];
                  },
                ),
              ),

            // ── Garment chips (modal mode only) ─────────────────────────
            if (!widget.tabMode && hasGarments)
              Positioned(
                bottom: 104,
                left: AppSpacing.md,
                right: AppSpacing.md,
                child: _GarmentNameChips(garments: _garments.values.toList()),
              ),

            // ── Capture button ───────────────────────────────────────────
            if (hasGarments)
              Positioned(
                bottom: AppSpacing.lg,
                left: 0,
                right: 0,
                child: Center(
                  child: _CaptureButton(
                    loading: _capturing || _loadingGarments,
                    onCapture: _cameraReady ? _capture : null,
                  ),
                ),
              ),

            // ── Add garment button (tab mode always) ─────────────────────
            if (widget.tabMode)
              Positioned(
                bottom: AppSpacing.lg,
                left: AppSpacing.lg,
                child: _AddGarmentPill(
                  onTap: () => _openGarmentPicker(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overlay painter
// ---------------------------------------------------------------------------

class _CameraOverlayPainter extends CustomPainter {
  const _CameraOverlayPainter({
    required this.garments,
    required this.anchors,
    required this.displaySize,
    required this.fitScales,
  });

  final List<_GarmentData> garments;
  final Map<String, NormAnchor>? anchors;
  final Size displaySize;
  final FitScales fitScales;

  @override
  void paint(Canvas canvas, Size size) {
    final Map<String, NormAnchor>? a = anchors;
    if (a == null || a.isEmpty) return;

    final List<_GarmentData> sorted = List<_GarmentData>.from(garments)
      ..sort((a, b) => garmentDepth(a.item.type).compareTo(garmentDepth(b.item.type)));

    final double shoulderSpan = _computeShoulderSpan(a, size);
    for (final _GarmentData g in sorted) {
      _paintOne(canvas, size, g, a, shoulderSpan);
    }
  }

  double _computeShoulderSpan(Map<String, NormAnchor> a, Size size) {
    final NormAnchor? sh = a['shoulder'];
    final NormAnchor? hip = a['hip'];
    if (sh != null && hip != null) {
      return (hip.y - sh.y).abs() * size.height * 0.85;
    }
    return size.width * 0.40;
  }

  void _paintOne(
    Canvas canvas,
    Size size,
    _GarmentData g,
    Map<String, NormAnchor> anchors,
    double shoulderSpan,
  ) {
    final NormAnchor? anchor = anchors[garmentAnchorKey(g.item.type)];
    if (anchor == null) return;

    final ui.Image img = g.uiImage;
    final double gW = shoulderSpan * garmentShoulderMultiplier(g.item.type) * fitScales.forType(g.item.type);
    final double gH = gW / (img.width / img.height);

    final double ax = anchor.x * size.width;
    final double ay = anchor.y * size.height;
    final Offset norm = garmentAnchorNorm(g.item);

    paintImage(
      canvas: canvas,
      rect: Rect.fromLTWH(ax - norm.dx * gW, ay - norm.dy * gH, gW, gH),
      image: img,
      fit: BoxFit.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _CameraOverlayPainter old) =>
      old.anchors != anchors || old.garments != garments || old.fitScales != fitScales;
}

// ---------------------------------------------------------------------------
// Capture preview dialog
// ---------------------------------------------------------------------------

class _CapturePreviewDialog extends StatelessWidget {
  const _CapturePreviewDialog({required this.pngBytes});
  final Uint8List pngBytes;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Image.memory(pngBytes, fit: BoxFit.contain),
            Container(
              color: Colors.black87,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Retake'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await Share.shareXFiles(
                          <XFile>[
                            XFile.fromData(
                              pngBytes,
                              mimeType: 'image/png',
                              name: 'dressify_outfit.png',
                            ),
                          ],
                          subject: 'My Dressify Outfit',
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab-mode empty guide
// ---------------------------------------------------------------------------

class _EmptyTabGuide extends StatelessWidget {
  const _EmptyTabGuide({required this.onAdd, required this.onBrowse});
  final VoidCallback onAdd;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.camera_alt_outlined,
            color: Colors.white60,
            size: 52,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            children: <Widget>[
              const Text(
                'Your live try-on is ready',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Pick a garment from your wardrobe\nto try it on live.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Garment'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: onBrowse,
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                child: const Text('Browse Wardrobe'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.showBack,
    required this.onBack,
    this.onFlip,
    this.onWardrobe,
  });

  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback? onFlip;
  final VoidCallback? onWardrobe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: <Widget>[
          if (showBack) _Pill(icon: Icons.arrow_back, onTap: onBack),
          const Spacer(),
          if (onWardrobe != null)
            _Pill(icon: Icons.checkroom_outlined, onTap: onWardrobe!),
          if (onFlip != null) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            _Pill(icon: Icons.flip_camera_ios_outlined, onTap: onFlip!),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Selected garment bar (tab mode — shows chips with ×)
// ---------------------------------------------------------------------------

class _SelectedGarmentBar extends StatelessWidget {
  const _SelectedGarmentBar({
    required this.garments,
    required this.onRemove,
    required this.onClearAll,
  });

  final List<_GarmentData> garments;
  final void Function(ClothingItem) onRemove;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(AppRadius.thumbnail),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: garments
                    .map(
                      (g) => Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: _GarmentChip(
                          garment: g,
                          onRemove: () => onRemove(g.item),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          GestureDetector(
            onTap: onClearAll,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close, color: Colors.white60, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _GarmentChip extends StatelessWidget {
  const _GarmentChip({required this.garment, required this.onRemove});
  final _GarmentData garment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            garment.item.name,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, color: Colors.white70, size: 14),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Garment name chips (modal mode — read-only)
// ---------------------------------------------------------------------------

class _GarmentNameChips extends ConsumerWidget {
  const _GarmentNameChips({required this.garments});
  final List<_GarmentData> garments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: garments.map((g) {
        final fitAsync = ref.watch(fitRatingProvider(g.item.id));
        final fit = fitAsync.valueOrNull;

        final Color? badgeColor = fit == null ? null : switch (fit.rating) {
          FitRating.perfect    => Colors.green.shade600,
          FitRating.mayBeSnug  => Colors.orange.shade600,
          FitRating.runsLarge  => Colors.blue.shade600,
          FitRating.unknown    => null,
        };

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (badgeColor != null) ...<Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
              ],
              Text(g.item.name, style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Capture button
// ---------------------------------------------------------------------------

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({required this.onCapture, required this.loading});
  final VoidCallback? onCapture;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCapture,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: Colors.white70, width: 3),
        ),
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.black54,
                ),
              )
            : const Icon(Icons.camera_alt, color: Colors.black87, size: 32),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Camera error
// ---------------------------------------------------------------------------

class _CameraError extends StatelessWidget {
  const _CameraError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.videocam_off, color: Colors.white54, size: 56),
          SizedBox(height: AppSpacing.md),
          Text(
            'Camera unavailable',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pill badge (e.g. "stand in front" hint)
// ---------------------------------------------------------------------------

class _PillBadge extends StatelessWidget {
  const _PillBadge({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.thumbnail),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: Colors.white70, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add-garment pill button
// ---------------------------------------------------------------------------

class _AddGarmentPill extends StatelessWidget {
  const _AddGarmentPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.60),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.add, color: Colors.white, size: 18),
            SizedBox(width: 4),
            Text(
              'Add',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Garment picker sheet
// ---------------------------------------------------------------------------

class _GarmentPickerSheet extends ConsumerWidget {
  const _GarmentPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    final List<ClothingItem> all = (ref.watch(wardrobeProvider).value ?? <ClothingItem>[])
        .where((ClothingItem it) =>
            it.processingStatus != 'processing' && it.processingStatus != 'failed')
        .toList();
    final List<ClothingItem> selected = ref.watch(cameraGarmentsProvider);
    final Set<String> selectedIds = selected.map((ClothingItem it) => it.id).toSet();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheetTop),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.md,
              ),
              child: Column(
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: c.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: <Widget>[
                      Text('Add Garment', style: text.titleMedium),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (all.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
                child: Center(
                  child: Text(
                    'No clothing items yet.\nUpload some from the wardrobe.',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(color: c.textSecondary),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.lg,
                  ),
                  itemCount: all.length,
                  itemBuilder: (_, int i) {
                    final ClothingItem item = all[i];
                    final bool isSelected = selectedIds.contains(item.id);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: item.processedUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: item.processedUrl,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => _swatch(c),
                                errorWidget: (_, _, _) => _swatch(c),
                              )
                            : _swatch(c),
                      ),
                      title: Text(
                        item.name,
                        style: text.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        item.type,
                        style:
                            text.bodySmall?.copyWith(color: c.textSecondary),
                      ),
                      trailing: Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked,
                        color: isSelected ? c.primary : c.border,
                      ),
                      onTap: () {
                        final List<ClothingItem> current =
                            List<ClothingItem>.from(
                                ref.read(cameraGarmentsProvider));
                        if (isSelected) {
                          current.removeWhere(
                              (ClothingItem it) => it.id == item.id);
                        } else {
                          current.add(item);
                        }
                        ref.read(cameraGarmentsProvider.notifier).state =
                            current;
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _swatch(AppColors c) {
    return Container(
      width: 48,
      height: 48,
      color: c.background,
      child: Icon(Icons.checkroom, color: c.primary, size: 20),
    );
  }
}
