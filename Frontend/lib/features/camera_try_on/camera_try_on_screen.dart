import 'dart:async';
import 'dart:typed_data';
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
import '../../core/services/luminance_sampler.dart';
import '../../core/services/pose_detection_service.dart';

import '../../core/services/wrinkle_cache_service.dart';
import '../../core/utils/pose_classifier.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_permissions.dart';
import '../../core/utils/garment_control_points.dart';
import '../../core/utils/garment_utils.dart';
import '../../core/utils/tps_warper.dart';
import '../../core/widgets/app_toast.dart';

// ---------------------------------------------------------------------------
// Garment data holder
// ---------------------------------------------------------------------------

class _GarmentData {
  _GarmentData({required this.item, required this.uiImage, this.wrinkleMaps});
  final ClothingItem item;
  final ui.Image uiImage;
  final Map<String, ui.Image>? wrinkleMaps; // pose → decoded ui.Image (S6.6 pre-blit)
  void dispose() {
    uiImage.dispose();
    for (final ui.Image m in wrinkleMaps?.values ?? <ui.Image>[]) {
      m.dispose();
    }
  }
}

// Shared by state (_resolveTpsInto) and painter (_computeShoulderSpan).
double _shoulderSpan(Map<String, NormAnchor> a, Size size) {
  final NormAnchor? ls = a['leftShoulder'];
  final NormAnchor? rs = a['rightShoulder'];
  if (ls != null && rs != null) {
    return (ls.x - rs.x).abs() * size.width;
  }
  final NormAnchor? sh = a['shoulder'];
  final NormAnchor? hip = a['hip'];
  if (sh != null && hip != null) {
    return (hip.y - sh.y).abs() * size.height * 0.85;
  }
  return size.width * 0.40;
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

  // ── Manual fit scale (pinch-to-zoom on live overlay) ──────────────────────
  double _manualScale = 1.0;
  double _scaleOnGestureStart = 1.0;

  // ── Ambient Lighting & Color Temperature ─────────────────────────────────
  double _ambientLuma = 0.5;
  double _rGain = 1.0;
  double _gGain = 1.0;
  double _bGain = 1.0;
  int _frameCount = 0;

  // ── TPS warp solutions ────────────────────────────────────────────────────
  Map<String, TpsSolution?> _tpsSolutions = {};
  Size _displaySize = Size.zero;
  bool _pendingSizeUpdate = false;

  // ── Quality tier (set once from display refresh rate) ─────────────────────
  // false on displays < 60 Hz: skips expensive per-frame blur effects.
  bool _highQuality = true;

  // ── Wrinkle pose crossfade (S4.2.4) ──────────────────────────────────────
  String _currentPose    = 'arms_down';
  String _prevPose       = 'arms_down';
  int    _poseChangedAtMs = 0;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Gate expensive per-frame blur effects on displays that run at 60 Hz+.
    final double hz =
        ui.PlatformDispatcher.instance.displays.firstOrNull?.refreshRate ?? 60.0;
    _highQuality = hz >= 59.0;
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

    _frameCount++;
    if (_frameCount % 3 == 0) {
      final Map<String, NormAnchor>? currentAnchors = _anchors;
      if (currentAnchors != null && currentAnchors.containsKey('shoulder')) {
        final NormAnchor shoulder = currentAnchors['shoulder']!;
        final Rect region = Rect.fromCenter(
          center: Offset(shoulder.x, shoulder.y),
          width: 0.10,
          height: 0.10,
        );
        final double luma = LuminanceSampler.sample(image, region);
        final ({double r, double g, double b}) rgb =
            LuminanceSampler.sampleRGB(image, region);

        // Compute per-channel gains relative to neutral (1.0 = no shift).
        // Normalize so r+g+b = 3.0, then lerp 30% toward scene colour.
        final double total = (rgb.r + rgb.g + rgb.b).clamp(0.01, 3.0);
        const double strength = 0.30;
        final double newR = 1.0 + (rgb.r * 3.0 / total - 1.0) * strength;
        final double newG = 1.0 + (rgb.g * 3.0 / total - 1.0) * strength;
        final double newB = 1.0 + (rgb.b * 3.0 / total - 1.0) * strength;

        final bool lumaChanged = (luma - _ambientLuma).abs() > 0.05;
        final bool gainChanged =
            (newR - _rGain).abs() > 0.02 || (newB - _bGain).abs() > 0.02;

        if (mounted && (lumaChanged || gainChanged)) {
          setState(() {
            if (lumaChanged) _ambientLuma = luma;
            if (gainChanged) { _rGain = newR; _gGain = newG; _bGain = newB; }
          });
        }
      }
    }

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
      if (!mounted) return;
      setState(() {
        _anchors = anchors;
        if (anchors != null && _displaySize != Size.zero) {
          _resolveTpsInto(anchors, _displaySize);
        }
        // S4.2.2 — classify pose and start crossfade timer if it changed
        if (anchors != null) {
          final String newPose = PoseClassifier.classify(anchors);
          if (newPose != _currentPose) {
            _prevPose        = _currentPose;
            _currentPose     = newPose;
            _poseChangedAtMs = DateTime.now().millisecondsSinceEpoch;
          }
        }
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
    _tpsSolutions = {};
  }

  // Solves TPS for every loaded garment against current anchors + display size.
  // Must be called inside setState (mutates _tpsSolutions directly).
  void _resolveTpsInto(Map<String, NormAnchor> anchors, Size size) {
    final double span = _shoulderSpan(anchors, size);
    final Map<String, TpsSolution?> updated = {};
    for (final _GarmentData g in _garments.values) {
      final GarmentControlPoints cp = GarmentControlPoints.forType(g.item.type);
      final List<Offset>? targets =
          cp.computeTargets(g.item.type, anchors, size, span);
      updated[g.item.id] =
          targets != null ? TpsWarper.solve(cp.uvPoints, targets) : null;
    }
    _tpsSolutions = updated;
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
        if (!mounted) { img.dispose(); return; }
        // Show garment immediately; wrinkle maps load in the background (S6.6)
        _garments[ci.id] = _GarmentData(item: ci, uiImage: img);
        WrinkleCacheService.loadForItem(ci).then((Map<String, ui.Image>? wMaps) {
          if (!mounted || wMaps == null || !_garments.containsKey(ci.id)) {
            for (final ui.Image m in wMaps?.values ?? <ui.Image>[]) { m.dispose(); }
            return;
          }
          setState(() {
            final _GarmentData? existing = _garments[ci.id];
            if (existing != null) {
              // Dispose any previously loaded wrinkle maps before replacing.
              for (final ui.Image m in existing.wrinkleMaps?.values ?? <ui.Image>[]) {
                m.dispose();
              }
              _garments[ci.id] = _GarmentData(
                item: existing.item,
                uiImage: existing.uiImage,
                wrinkleMaps: wMaps,
              );
            } else {
              for (final ui.Image m in wMaps.values) { m.dispose(); }
            }
          });
        }).catchError((_) {});
      } catch (_) {
        if (mounted) AppToast.error(context, 'Could not load "${ci.name}" — check your connection');
      }
    }

    _lastLoadedIds = ids;
    if (mounted) {
      setState(() {
        _loadingGarments = false;
        final Map<String, NormAnchor>? a = _anchors;
        if (a != null && _displaySize != Size.zero) {
          _resolveTpsInto(a, _displaySize);
        }
      });
    }
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
                          builder: (_, BoxConstraints bc) {
                            final Size size = bc.biggest;
                            if (_displaySize != size && !_pendingSizeUpdate) {
                              _pendingSizeUpdate = true;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  setState(() {
                                    _displaySize = size;
                                    _pendingSizeUpdate = false;
                                    final Map<String, NormAnchor>? a = _anchors;
                                    if (a != null) _resolveTpsInto(a, size);
                                  });
                                }
                              });
                            }
                            // S6.4: RepaintBoundary isolates garment repaints
                            // from the CameraPreview layer beneath.
                            return RepaintBoundary(
                              child: CustomPaint(
                                size: size,
                                painter: _CameraOverlayPainter(
                                  garments: (_garments.values.toList()
                                        ..sort((a, b) => garmentDepth(a.item.type)
                                            .compareTo(garmentDepth(b.item.type))))
                                      .toList(),
                                  anchors: _anchors,
                                  displaySize: size,
                                  fitScales: ref.watch(fitScalesProvider),
                                  manualScale: _manualScale,
                                  ambientLuma: _ambientLuma,
                                  rGain: _rGain,
                                  gGain: _gGain,
                                  bGain: _bGain,
                                  tpsSolutions: _tpsSolutions,
                                  highQuality: _highQuality,
                                  currentPose: _currentPose,
                                  prevPose: _prevPose,
                                  poseChangedAtMs: _poseChangedAtMs,
                                ),
                              ),
                            );
                          },
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
    required this.ambientLuma,
    required this.rGain,
    required this.gGain,
    required this.bGain,
    required this.tpsSolutions,
    required this.highQuality,
    required this.currentPose,
    required this.prevPose,
    required this.poseChangedAtMs,
  });

  final List<_GarmentData> garments;
  final Map<String, NormAnchor>? anchors;
  final Size displaySize;
  final FitScales fitScales;
  final double manualScale;
  final double ambientLuma;
  final double rGain;
  final double gGain;
  final double bGain;
  final Map<String, TpsSolution?> tpsSolutions;
  final bool highQuality;
  final String currentPose;
  final String prevPose;
  final int poseChangedAtMs;


  @override
  void paint(Canvas canvas, Size size) {
    final Map<String, NormAnchor>? a = anchors;
    if (a == null || a.isEmpty) return;

    // Garments arrive pre-sorted by depth from build() — no sort needed here.
    final List<_GarmentData> sorted = garments;

    final double shoulderSpan = _computeShoulderSpan(a, size);

    // Isolate all garment draws into one layer so BlendMode.dstOut only clears
    // pixels within this layer, not the CameraPreview rendered beneath.
    // ColorFilter applies ambient brightness + scene colour temperature shift.
    final double lum = 0.75 + ambientLuma * 0.50;
    final ColorFilter lightingFilter = ColorFilter.matrix(<double>[
      lum * rGain, 0, 0, 0, 0,
      0, lum * gGain, 0, 0, 0,
      0, 0, lum * bGain, 0, 0,
      0, 0, 0, 1, 0,
    ]);
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..colorFilter = lightingFilter);

    // Shadow opacity damps when the user scales the garment very small (far
    // away) so depth cues don't look wrong at tiny scale values.
    final double shadowOpacity = manualScale < 0.75
        ? ((manualScale - 0.5) / 0.25).clamp(0.0, 1.0)
        : 1.0;

    // S3.1 — body/ground shadow drawn before garments (appears behind them).
    for (final _GarmentData g in sorted) {
      _paintBodyShadow(canvas, size, g, shoulderSpan, shadowOpacity);
    }

    for (final _GarmentData g in sorted) {
      _paintOne(canvas, size, g, a, shoulderSpan);
    }

    // S3.2 — neck/collar shadow drawn after garments (overlays collar area).
    for (final _GarmentData g in sorted) {
      _paintNeckShadow(canvas, size, g, a, shoulderSpan, shadowOpacity);
    }

    canvas.restore(); // composites garment layer into camera preview
  }

  double _computeShoulderSpan(Map<String, NormAnchor> a, Size size) =>
      _shoulderSpan(a, size);

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
    final double ax = anchor.x * size.width;
    final double ay = anchor.y * size.height;

    // ── TPS path: smooth multi-point warp ────────────────────────────────────
    final TpsSolution? tps = tpsSolutions[g.item.id];
    if (tps != null) {
      final double effectiveScale =
          manualScale * fitScales.forType(g.item.type);
      canvas.save();
      if ((effectiveScale - 1.0).abs() > 0.001) {
        canvas.translate(ax, ay);
        canvas.scale(effectiveScale);
        canvas.translate(-ax, -ay);
      }
      final (ui.Vertices verts, Paint paint) =
          TpsWarper.buildMesh(solution: tps, img: img);

      // Soft edge shadow: blurred semi-transparent copy drawn beneath the
      // garment so it appears to rest on the body rather than float above it.
      // Skipped on low-refresh-rate displays to protect frame budget (S6.7).
      if (highQuality) {
        final Paint shadowPaint = Paint()
          ..shader = paint.shader
          ..colorFilter = const ColorFilter.matrix(<double>[
            0, 0, 0, 0, 0, //  R → black
            0, 0, 0, 0, 0, //  G → black
            0, 0, 0, 0, 0, //  B → black
            0, 0, 0, 0.18, 0, // A → 18% of garment alpha
          ])
          ..imageFilter = ui.ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0);
        canvas.drawVertices(verts, BlendMode.srcOver, shadowPaint);
      }

      canvas.drawVertices(verts, BlendMode.srcOver, paint);
      _paintWrinkleOverlay(canvas, g, tps);
      canvas.restore();
      return;
    }

    // ── Fallback: quad warp or skew+paintImage ───────────────────────────────
    final double gW = shoulderSpan *
        garmentShoulderMultiplier(g.item.type) *
        fitScales.forType(g.item.type) *
        manualScale;
    final double gH = gW / (img.width / img.height);

    final Offset norm = garmentAnchorNorm(g.item);
    final Rect rect =
        Rect.fromLTWH(ax - norm.dx * gW, ay - norm.dy * gH, gW, gH);

    final double lsy =
        anchors['leftShoulder']?.y ?? anchors['shoulder']?.y ?? 0.5;
    final double rsy =
        anchors['rightShoulder']?.y ?? anchors['shoulder']?.y ?? 0.5;
    final double skewFactor = (rsy - lsy) * 0.6;

    final List<Offset>? quad = _computeBodyQuad(anchors, size, rect, ay);

    if (quad != null) {
      _paintImageOnQuad(canvas, img, quad);
    } else {
      canvas.save();
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
  }

  // S4.2 — Wrinkle overlay (disabled).
  // All canvas-based approaches (srcOver, multiply, saveLayer+dstIn, saveLayer+srcATop)
  // produce solid black in the TPS path on Android.  The wrinkle maps are still
  // generated and cached by the backend; this can be re-enabled once the
  // Flutter/Skia compositing issue is reproduced in isolation and fixed.
  void _paintWrinkleOverlay(Canvas canvas, _GarmentData g, TpsSolution tps) {
    return;
  }

  List<Offset>? _computeBodyQuad(
    Map<String, NormAnchor> anchors,
    Size size,
    Rect rect,
    double ay,
  ) {
    final NormAnchor? lS = anchors['leftShoulder'];
    final NormAnchor? rS = anchors['rightShoulder'];
    final NormAnchor? lH = anchors['leftHip'];
    final NormAnchor? rH = anchors['rightHip'];

    if (lS == null || rS == null || lH == null || rH == null) return null;

    final double lsy = lS.y;
    final double rsy = rS.y;
    final double lhy = lH.y;
    final double rhy = rH.y;

    final double topSkew = (rsy - lsy) * 0.6;
    final double bottomSkew = (rhy - lhy) * 0.6;

    final double shoulderWidthNorm = (lS.x - rS.x).abs();
    final double hipWidthNorm = (lH.x - rH.x).abs();
    final double taper = shoulderWidthNorm > 0 ? (hipWidthNorm / shoulderWidthNorm).clamp(0.6, 1.2) : 1.0;

    final double topY = rect.top;

    // Explicitly calculate where the user's hips are in pixel space
    final double bodyShoulderY = ((lsy + rsy) / 2) * size.height;
    final double bodyHipY = ((lhy + rhy) / 2) * size.height;
    final double torsoHeight = bodyHipY - bodyShoulderY;

    // A standard top should reach just below the hips (15% of torso height below the hip line)
    final double targetBottomY = bodyHipY + (torsoHeight * 0.15);

    // If the garment's native aspect ratio is shorter than the user's torso, stretch it to the hips!
    // (If it's longer, like a dress, we keep the longer length).
    final double bottomY = rect.bottom < targetBottomY ? targetBottomY : rect.bottom;

    final Offset tl = Offset(rect.left + topSkew * (topY - ay), topY);
    final Offset tr = Offset(rect.right + topSkew * (topY - ay), topY);

    final double cx = rect.center.dx;
    final double bottomHalfWidth = (rect.width / 2) * taper;

    final Offset bl = Offset(cx - bottomHalfWidth + bottomSkew * (bottomY - ay), bottomY);
    final Offset br = Offset(cx + bottomHalfWidth + bottomSkew * (bottomY - ay), bottomY);

    return <Offset>[tl, tr, br, bl];
  }

  void _paintImageOnQuad(Canvas canvas, ui.Image img, List<Offset> quad) {
    final Float32List positions = Float32List.fromList(<double>[
      quad[0].dx, quad[0].dy, // TL
      quad[1].dx, quad[1].dy, // TR
      quad[3].dx, quad[3].dy, // BL
      quad[2].dx, quad[2].dy, // BR
    ]);

    final Float32List textureCoordinates = Float32List.fromList(<double>[
      0, 0,
      img.width.toDouble(), 0,
      0, img.height.toDouble(),
      img.width.toDouble(), img.height.toDouble(),
    ]);

    final ui.Vertices vertices = ui.Vertices.raw(
      ui.VertexMode.triangleStrip,
      positions,
      textureCoordinates: textureCoordinates,
    );

    final Float64List matrix = Matrix4.identity().storage;
    final ui.ImageShader shader = ui.ImageShader(
      img,
      TileMode.clamp,
      TileMode.clamp,
      matrix,
    );

    final Paint paint = Paint()..shader = shader;
    canvas.drawVertices(vertices, BlendMode.srcOver, paint);
  }



  // S3.1 — Soft elliptical ground shadow drawn below the garment hem.
  void _paintBodyShadow(
    Canvas canvas,
    Size size,
    _GarmentData g,
    double shoulderSpan,
    double shadowOpacity,
  ) {
    final TpsSolution? tps = tpsSolutions[g.item.id];
    final Offset hemPt = tps != null
        ? tps.eval(0.5, 1.0)
        : Offset(size.width / 2, size.height * 0.75);

    final double w = shoulderSpan * 0.55;
    final double h = w * 0.18;
    final Rect rect = Rect.fromCenter(
      center: Offset(hemPt.dx, hemPt.dy + h * 0.6),
      width: w,
      height: h,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.black.withValues(alpha: 0.22 * shadowOpacity),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
  }

  // S3.2 — Soft gradient shadow at the collar/neck junction.
  void _paintNeckShadow(
    Canvas canvas,
    Size size,
    _GarmentData g,
    Map<String, NormAnchor> anchors,
    double shoulderSpan,
    double shadowOpacity,
  ) {
    if (g.item.type == 'bottom') return;

    final TpsSolution? tps = tpsSolutions[g.item.id];
    final Offset collarPt;
    if (tps != null) {
      collarPt = tps.eval(0.5, 0.04);
    } else {
      final NormAnchor? sh = anchors['shoulder'];
      if (sh == null) return;
      collarPt = Offset(sh.x * size.width, sh.y * size.height - shoulderSpan * 0.22);
    }

    final double w = shoulderSpan * 0.42;
    final double h = w * 0.28;
    final Rect rect = Rect.fromCenter(center: collarPt, width: w, height: h);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.black.withValues(alpha: 0.14 * shadowOpacity),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _CameraOverlayPainter old) =>
      old.anchors != anchors ||
      old.garments != garments ||
      old.fitScales != fitScales ||
      old.manualScale != manualScale ||
      old.ambientLuma != ambientLuma ||
      old.rGain != rGain ||
      old.gGain != gGain ||
      old.bGain != bGain ||
      old.tpsSolutions != tpsSolutions ||
      old.highQuality != highQuality ||
      old.currentPose != currentPose ||
      old.prevPose != prevPose ||
      old.poseChangedAtMs != poseChangedAtMs;
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
