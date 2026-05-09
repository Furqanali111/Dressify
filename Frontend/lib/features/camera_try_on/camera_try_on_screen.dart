import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
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
import '../../core/providers/tryon_provider.dart';
import '../../core/providers/wardrobe_provider.dart';
import '../../core/router/app_routes.dart';
import '../../core/services/pose_detection_service.dart';
import '../../core/services/segmentation_service.dart';
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

  // ── Segmentation ──────────────────────────────────────────────────────────
  final SegmentationService _segService = SegmentationService();
  ui.Image? _segMaskImage;

  // ── Garments ──────────────────────────────────────────────────────────────
  // Maps ClothingItem.id → loaded garment data.
  final Map<String, _GarmentData> _garments = <String, _GarmentData>{};
  bool _loadingGarments = false;
  // The item IDs we last loaded garments for (detect changes).
  List<String> _lastLoadedIds = <String>[];

  // ── Capture ───────────────────────────────────────────────────────────────
  final GlobalKey _previewKey = GlobalKey();
  bool _capturing = false;

  // ── Manual fit scale (pinch-to-zoom on live overlay) ──────────────────────
  double _manualScale = 1.0;
  double _scaleOnGestureStart = 1.0;

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
    _segService.dispose();
    _segMaskImage?.dispose();
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
    // Reset manual scale on flip — the new camera angle is a fresh framing.
    _manualScale = 1.0;
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

    // Pose and segmentation are dispatched concurrently on the same throttle.
    // Neither is awaited here — results arrive via .then() on the next frame.
    // Both services have an internal _busy guard: if the previous call hasn't
    // finished (device struggling), processFrame returns null and the tick is
    // skipped automatically — no explicit skip flag needed.
    _poseService
        .processFrame(
          image: image,
          sensorOrientation: cam.sensorOrientation,
          deviceOrientation: ctrl.value.deviceOrientation,
          lensDirection: cam.lensDirection,
        )
        .then((Map<String, NormAnchor>? anchors) {
      if (mounted) setState(() => _anchors = anchors);
    }).catchError((_) {});

    _segService
        .processFrame(
          image: image,
          sensorOrientation: cam.sensorOrientation,
          deviceOrientation: ctrl.value.deviceOrientation,
          lensDirection: cam.lensDirection,
        )
        .then((SegmentationMaskResult? result) {
      if (!mounted || result == null) return;
      _buildMaskImage(result).then((ui.Image img) {
        if (!mounted) { img.dispose(); return; }
        setState(() {
          _segMaskImage?.dispose();
          _segMaskImage = img;
        });
      });
    }).catchError((_) {});
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
    final Set<String> newSet = ids.toSet();
    if (newSet.length == _lastLoadedIds.length && newSet.containsAll(_lastLoadedIds)) return;

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

  // Converts a segmentation mask (List<double> confidences) into a ui.Image
  // where each pixel's alpha = confidence. Used by the painter to clip erases
  // to only pixels where a person is detected.
  static Future<ui.Image> _buildMaskImage(SegmentationMaskResult result) {
    final int w = result.width;
    final int h = result.height;
    final Uint8List pixels = Uint8List(w * h * 4);
    final int count = result.confidences.length.clamp(0, w * h);
    for (int i = 0; i < count; i++) {
      final int a = (result.confidences[i] * 255).round().clamp(0, 255);
      pixels[i * 4]     = 255;
      pixels[i * 4 + 1] = 255;
      pixels[i * 4 + 2] = 255;
      pixels[i * 4 + 3] = a;
    }
    final Completer<ui.Image> c = Completer<ui.Image>();
    ui.decodeImageFromPixels(pixels, w, h, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }

  // Shared Dio for garment image downloads — avoids a new TCP handshake per item.
  static final Dio _imageDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  static Future<ui.Image> _decodeNetworkImage(String url) async {
    final Response<List<int>> resp = await _imageDio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    ).timeout(AppConstants.imageLoadTimeout);
    final Uint8List bytes = Uint8List.fromList(resp.data ?? <int>[]);
    if (bytes.isEmpty) throw Exception('Empty image response for $url');
    final Completer<ui.Image> completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
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
        builder: (_) => _CapturePreviewDialog(
          pngBytes: byteData.buffer.asUint8List(),
          garments: _garments.values.toList(),
          onTryOnResult: (String url) =>
              context.pushNamed(AppRoute.tryOnResult.name, extra: url),
        ),
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
              GestureDetector(
                // Pinch-to-scale: two-finger scale gesture adjusts garment size.
                // Single-finger taps pass through to Positioned buttons above.
                onScaleStart: (ScaleStartDetails _) {
                  _scaleOnGestureStart = _manualScale;
                },
                onScaleUpdate: (ScaleUpdateDetails d) {
                  if (d.pointerCount < 2) return;
                  final double next =
                      (_scaleOnGestureStart * d.scale).clamp(0.5, 2.0);
                  if ((next - _manualScale).abs() > 0.005) {
                    setState(() => _manualScale = next);
                  }
                },
                child: RepaintBoundary(
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
                              // Pre-sorted by depth so paint() skips re-sorting every frame.
                              garments: (_garments.values.toList()
                                    ..sort((a, b) => garmentDepth(a.item.type)
                                        .compareTo(garmentDepth(b.item.type))))
                                  .toList(),
                              anchors: _anchors,
                              displaySize: bc.biggest,
                              fitScales: ref.watch(fitScalesProvider),
                              segMaskImage: _segMaskImage,
                              manualScale: _manualScale,
                            ),
                          ),
                        ),
                    ],
                  ),
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
              const Center(
                child: _PillBadge(
                  icon: Icons.person_outline,
                  text: 'Stand in front of the camera',
                ),
              ),

            // ── Pose quality hint ─────────────────────────────────────────
            // Shown when pose is detected but only via midpoint fallback (no
            // individual shoulder landmarks) — usually means the user is too
            // far away and ML Kit can't resolve individual shoulder positions.
            if (_cameraReady && hasGarments && _anchors != null &&
                !(_anchors!.containsKey('leftShoulder') ||
                  _anchors!.containsKey('rightShoulder')))
              const Positioned(
                top: 56,
                left: 0,
                right: 0,
                child: Center(
                  child: _PillBadge(
                    icon: Icons.warning_amber_rounded,
                    text: 'Step closer for better fit',
                  ),
                ),
              ),

            // ── Pinch-scale indicator + reset ─────────────────────────────
            if (_cameraReady && hasGarments && (_manualScale - 1.0).abs() > 0.01)
              Positioned(
                top: 56,
                right: AppSpacing.md,
                child: _ScalePill(
                  scale: _manualScale,
                  onReset: () => setState(() => _manualScale = 1.0),
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
    required this.manualScale,
    this.segMaskImage,
  });

  final List<_GarmentData> garments;
  final Map<String, NormAnchor>? anchors;
  final Size displaySize;
  final FitScales fitScales;
  final double manualScale;
  final ui.Image? segMaskImage;

  @override
  void paint(Canvas canvas, Size size) {
    final Map<String, NormAnchor>? a = anchors;
    if (a == null || a.isEmpty) return;

    // Garments arrive pre-sorted by depth from build() — no sort needed here.
    final List<_GarmentData> sorted = garments;

    final double shoulderSpan = _computeShoulderSpan(a, size);

    // Isolate all garment draws (and future dstOut erases) into one layer so
    // BlendMode.dstOut only clears pixels within this layer, not the
    // CameraPreview rendered beneath this CustomPaint.
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    for (final _GarmentData g in sorted) {
      _paintOne(canvas, size, g, a, shoulderSpan);
    }

    // ── Erase arm and neck regions so the live camera shows through ──────────
    // The inner saveLayer composites with dstOut into the garment layer above,
    // erasing garment pixels proportionally to the alpha drawn in this layer.
    final Path leftArm  = _buildArmPath(a, 'left',  size, shoulderSpan);
    final Path rightArm = _buildArmPath(a, 'right', size, shoulderSpan);
    final Path neck     = _buildNeckPath(a, size, shoulderSpan);

    final Rect canvasRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.saveLayer(canvasRect, Paint()..blendMode = BlendMode.dstOut);

    // Draw erase shapes with soft gradient (no explicit blendMode — the layer
    // itself applies dstOut when it composites back into the garment layer).
    canvas.drawPath(leftArm,  _softGradientPaint(leftArm.getBounds()));
    canvas.drawPath(rightArm, _softGradientPaint(rightArm.getBounds()));
    canvas.drawPath(neck,     _softGradientPaint(neck.getBounds()));

    // Phase 2: if a segmentation mask image is available, intersect the erase
    // region with person pixels only (dstIn keeps alpha where mask is opaque).
    // This prevents erasing garment pixels that extend beyond the body edge.
    final ui.Image? maskImg = segMaskImage;
    if (maskImg != null) {
      canvas.drawImageRect(
        maskImg,
        Rect.fromLTWH(0, 0, maskImg.width.toDouble(), maskImg.height.toDouble()),
        canvasRect,
        Paint()..blendMode = BlendMode.dstIn,
      );
    }

    canvas.restore(); // composites erase layer (dstOut) → punches holes in garments
    canvas.restore(); // composites garment layer into camera preview
  }

  double _computeShoulderSpan(Map<String, NormAnchor> a, Size size) {
    // Prefer actual horizontal distance between left and right shoulder tips —
    // this gives correctly scaled garment width regardless of camera distance.
    final NormAnchor? ls = a['leftShoulder'];
    final NormAnchor? rs = a['rightShoulder'];
    if (ls != null && rs != null) {
      return (ls.x - rs.x).abs() * size.width;
    }
    // Fallback: torso-height proxy when only midpoint is available.
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
    final double gW = shoulderSpan * garmentShoulderMultiplier(g.item.type) * fitScales.forType(g.item.type) * manualScale;
    final double gH = gW / (img.width / img.height);

    final double ax = anchor.x * size.width;
    final double ay = anchor.y * size.height;
    final Offset norm = garmentAnchorNorm(g.item);

    final Rect rect = Rect.fromLTWH(ax - norm.dx * gW, ay - norm.dy * gH, gW, gH);

    // Shoulder-angle skew: tilt the garment to match body lean.
    // Compute skew from individual shoulder Y positions (0 when both level).
    final double lsy = anchors['leftShoulder']?.y  ?? anchors['shoulder']?.y ?? 0.5;
    final double rsy = anchors['rightShoulder']?.y ?? anchors['shoulder']?.y ?? 0.5;
    final double skewFactor = (rsy - lsy) * 0.6;

    canvas.save();
    // Column-major Matrix4 for X-shear: x' = x + skewFactor*(y - ay), y' = y.
    // Columns: [1,0,0,0], [k,1,0,0], [0,0,1,0], [-k*ay,0,0,1]
    canvas.transform(
      Matrix4(
        1, 0, 0, 0,
        skewFactor, 1, 0, 0,
        0, 0, 1, 0,
        -skewFactor * ay, 0, 0, 1,
      ).storage,
    );

    paintImage(canvas: canvas, rect: rect, image: img, fit: BoxFit.fill);

    canvas.restore();
  }

  // Returns a paint with a soft radial gradient (opaque centre → transparent edge).
  // Used inside the dstOut erase layer — no blendMode needed here since the
  // layer itself composites with dstOut when restored.
  static Paint _softGradientPaint(Rect bounds) {
    if (bounds.isEmpty) return Paint()..color = Colors.white;
    return Paint()
      ..shader = const RadialGradient(
        colors: <Color>[Colors.white, Color(0x00FFFFFF)],
        stops: <double>[0.55, 1.0],
      ).createShader(bounds);
  }

  // Builds a capsule path covering one arm: shoulder → elbow → wrist.
  // Falls back gracefully when elbow or wrist landmark is unavailable.
  static Path _buildArmPath(
    Map<String, NormAnchor> a,
    String side,
    Size size,
    double shoulderSpan,
  ) {
    final String sKey = side == 'left' ? 'leftShoulder' : 'rightShoulder';
    final String eKey = side == 'left' ? 'leftElbow'    : 'rightElbow';
    final String wKey = side == 'left' ? 'leftWrist'    : 'rightWrist';

    final NormAnchor? shoulder = a[sKey];
    if (shoulder == null) return Path();

    final double r = shoulderSpan * 0.18;
    final Offset p0 = Offset(shoulder.x * size.width, shoulder.y * size.height);

    final NormAnchor? elbowA = a[eKey];
    final Offset p1 = elbowA != null
        ? Offset(elbowA.x * size.width, elbowA.y * size.height)
        : Offset(p0.dx + (side == 'left' ? -r * 0.5 : r * 0.5), p0.dy + shoulderSpan * 0.6);

    final NormAnchor? wristA = a[wKey];
    final List<Offset> joints = <Offset>[
      p0,
      p1,
      if (wristA != null) Offset(wristA.x * size.width, wristA.y * size.height),
    ];
    return _capsulePath(joints, r);
  }

  // Builds a soft ellipse covering the neck region between nose and shoulders.
  static Path _buildNeckPath(
    Map<String, NormAnchor> a,
    Size size,
    double shoulderSpan,
  ) {
    final NormAnchor? shoulder = a['shoulder'];
    if (shoulder == null) return Path();

    final double cx = shoulder.x * size.width;
    final NormAnchor? nose = a['nose'];
    final double top = nose != null
        ? (nose.y * size.height + shoulder.y * size.height) / 2
        : shoulder.y * size.height - shoulderSpan * 0.35;
    final double bottom = shoulder.y * size.height;
    final double neckW = shoulderSpan * 0.38;
    final double neckH = (bottom - top).abs();

    return Path()
      ..addOval(Rect.fromCenter(
        center: Offset(cx, top + neckH / 2),
        width: neckW,
        height: neckH,
      ));
  }

  // Builds a rounded-capsule path connecting a sequence of joint offsets.
  // Each segment becomes an RRect inflated by [radius], giving a pill shape.
  static Path _capsulePath(List<Offset> joints, double radius) {
    if (joints.isEmpty) return Path();
    if (joints.length == 1) {
      return Path()..addOval(Rect.fromCircle(center: joints[0], radius: radius));
    }
    final Path path = Path();
    for (int i = 0; i < joints.length - 1; i++) {
      path.addRRect(RRect.fromRectAndRadius(
        Rect.fromPoints(joints[i], joints[i + 1]).inflate(radius),
        Radius.circular(radius),
      ));
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _CameraOverlayPainter old) =>
      old.anchors != anchors ||
      old.garments != garments ||
      old.fitScales != fitScales ||
      old.manualScale != manualScale ||
      old.segMaskImage != segMaskImage;
}

// ---------------------------------------------------------------------------
// Capture preview dialog
// ---------------------------------------------------------------------------

class _CapturePreviewDialog extends ConsumerStatefulWidget {
  const _CapturePreviewDialog({
    required this.pngBytes,
    required this.garments,
    required this.onTryOnResult,
  });

  final Uint8List pngBytes;
  final List<_GarmentData> garments;
  final void Function(String resultUrl) onTryOnResult;

  @override
  ConsumerState<_CapturePreviewDialog> createState() =>
      _CapturePreviewDialogState();
}

class _CapturePreviewDialogState extends ConsumerState<_CapturePreviewDialog> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final TryOnState tryOnState = ref.watch(tryOnProvider);

    ref.listen<TryOnState>(tryOnProvider, (_, TryOnState next) {
      if (next.status == TryOnStatus.done && next.resultUrl != null) {
        final String url = next.resultUrl!;
        ref.read(tryOnProvider.notifier).reset();
        if (context.mounted) {
          Navigator.of(context).pop();
          widget.onTryOnResult(url);
        }
      } else if (next.status == TryOnStatus.error && context.mounted) {
        AppToast.error(
          context,
          next.errorMessage ?? 'AI try-on failed. Please try again.',
        );
      }
    });

    final bool hasGarments = widget.garments.isNotEmpty;
    final _GarmentData? selected =
        hasGarments ? widget.garments[_selectedIndex] : null;
    final AppColors c = context.colors;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Image.memory(widget.pngBytes, fit: BoxFit.contain),
            Container(
              color: Colors.black87,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Garment selector (only when > 1 garment loaded)
                  if (widget.garments.length > 1) ...<Widget>[
                    const Text(
                      'Select garment for AI try-on:',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: widget.garments
                            .asMap()
                            .entries
                            .map((MapEntry<int, _GarmentData> e) {
                          final bool isSel = e.key == _selectedIndex;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedIndex = e.key),
                            child: Container(
                              margin:
                                  const EdgeInsets.only(right: AppSpacing.xs),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isSel ? Colors.white : Colors.white24,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                e.value.item.name,
                                style: TextStyle(
                                  color: isSel
                                      ? Colors.black87
                                      : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: isSel
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  // Retake / Share row
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                          ),
                          onPressed: tryOnState.isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Retake'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.share),
                          label: const Text('Share'),
                          onPressed: tryOnState.isLoading
                              ? null
                              : () async {
                                  Navigator.of(context).pop();
                                  await Share.shareXFiles(
                                    <XFile>[
                                      XFile.fromData(
                                        widget.pngBytes,
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
                  // AI Try-On button
                  if (selected != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: Colors.white,
                      ),
                      icon: tryOnState.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome, size: 18),
                      label: Text(
                          tryOnState.isLoading ? 'Generating…' : 'AI Try-On'),
                      onPressed: tryOnState.isLoading
                          ? null
                          : () => ref.read(tryOnProvider.notifier).generate(
                                personImageBytes: widget.pngBytes,
                                clothingItemId: selected.item.id,
                              ),
                    ),
                  ],
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
// Pinch-scale indicator pill
// ---------------------------------------------------------------------------

class _ScalePill extends StatelessWidget {
  const _ScalePill({required this.scale, required this.onReset});
  final double scale;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onReset,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.zoom_out_map, color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Text(
              '${(scale * 100).round()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.close, color: Colors.white54, size: 13),
          ],
        ),
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

    final AsyncValue<List<ClothingItem>> wardrobeAsync = ref.watch(wardrobeProvider);
    final List<ClothingItem> all = (wardrobeAsync.value ?? <ClothingItem>[])
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
            if (wardrobeAsync.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (all.isEmpty)
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
