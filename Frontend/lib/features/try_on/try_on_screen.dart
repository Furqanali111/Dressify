import 'dart:async';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/enums/app_enums.dart';
import '../../core/router/app_routes.dart';
import '../../core/models/clothing_item.dart';
import '../../core/models/outfit.dart';
import '../../core/providers/outfits_provider.dart';
import '../../core/providers/fit_rating_provider.dart';
import '../../core/providers/fit_scale_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/style_profile_provider.dart';
import '../../core/providers/wardrobe_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/garment_utils.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../feedback/ai_feedback_sheet.dart';

// ---------------------------------------------------------------------------
// Garment data holder
// ---------------------------------------------------------------------------

class _GarmentData {
  _GarmentData({required this.item, required this.uiImage});

  final ClothingItem item;
  final ui.Image uiImage;
  Offset offset = Offset.zero;

  void dispose() => uiImage.dispose();
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class TryOnScreen extends ConsumerStatefulWidget {
  final Outfit? outfit;
  const TryOnScreen({super.key, this.outfit});

  @override
  ConsumerState<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends ConsumerState<TryOnScreen> {
  AvatarKind _avatar = AvatarKind.maleAthletic;
  bool _avatarInitialized = false;

  double _scale = 1.0;
  Offset _offset = Offset.zero;
  bool _avatarVisible = true;
  bool _saved = false;
  bool _saving = false;
  bool _showFitBadges = false;

  // Garment loading
  final Map<String, _GarmentData> _garments = {};
  bool _loadingGarments = false;
  bool _hasLowConfidence = false;
  Set<String> _failedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadGarments();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(styleProfileProvider.notifier).logInteraction(
        action: 'tried',
        outfitId: widget.outfit?.id,
      );
      _logWearEvent();
    });
  }

  Future<void> _logWearEvent() async {
    final outfitId = widget.outfit?.id;
    if (outfitId == null) return;
    try {
      final dio = ref.read(apiClientProvider);
      await dio.post<void>('/wear-logs', data: {'outfit_id': outfitId});
    } catch (_) {
      // best-effort; failures are silent
    }
  }

  @override
  void didUpdateWidget(TryOnScreen old) {
    super.didUpdateWidget(old);
    if (old.outfit?.id != widget.outfit?.id) {
      for (final g in _garments.values) {
        g.dispose();
      }
      _garments.clear();
      _loadGarments();
    }
  }

  @override
  void dispose() {
    for (final g in _garments.values) {
      g.dispose();
    }
    super.dispose();
  }

  // ---- Garment loading -------------------------------------------------------

  Future<void> _loadGarments() async {
    final outfit = widget.outfit;
    if (outfit == null || outfit.items.isEmpty) return;

    setState(() => _loadingGarments = true);

    final Dio dio = ref.read(apiClientProvider);
    final List<ClothingItem> cached =
        ref.read(wardrobeProvider).value ?? const [];

    bool anyLowConfidence = false;
    final Set<String> currentFailed = <String>{};

    for (final OutfitItem outfitItem in outfit.items) {
      if (_garments.containsKey(outfitItem.clothingItemId)) continue;

      // 1. Try wardrobe cache
      ClothingItem? ci = cached
          .cast<ClothingItem?>()
          .firstWhere((it) => it?.id == outfitItem.clothingItemId,
              orElse: () => null);

      // 2. Fall back to API
      if (ci == null) {
        try {
          final Response<dynamic> resp =
              await dio.get<dynamic>('/clothing/${outfitItem.clothingItemId}');
          ci = ClothingItem.fromJson(resp.data as Map<String, dynamic>);
        } on DioException {
          continue;
        }
      }

      if (ci.processedUrl.isEmpty) continue;

      if ((ci.detectionConfidence ?? 1.0) < 0.7) anyLowConfidence = true;

      try {
        final ui.Image img = await _decodeNetworkImage(ci.processedUrl);
        if (!mounted) {
          img.dispose();
          return;
        }
        final _GarmentData gd = _GarmentData(item: ci, uiImage: img);
        final Map<String, dynamic>? pos = outfitItem.position;
        if (pos != null) {
          gd.offset = Offset(
            (pos['dx'] as num? ?? 0.0).toDouble(),
            (pos['dy'] as num? ?? 0.0).toDouble(),
          );
        }
        setState(() => _garments[outfitItem.clothingItemId] = gd);
      } catch (_) {
        currentFailed.add(outfitItem.clothingItemId);
      }
    }

    if (mounted) {
      setState(() {
        _loadingGarments = false;
        _hasLowConfidence = anyLowConfidence;
        _failedIds = currentFailed;
      });
    }
  }

  static Future<ui.Image> _decodeNetworkImage(String url) async {
    final Completer<ui.Image> completer = Completer<ui.Image>();
    final ImageStream stream =
        NetworkImage(url).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        if (!completer.isCompleted) completer.complete(info.image.clone());
        stream.removeListener(listener);
      },
      onError: (Object error, StackTrace? _) {
        if (!completer.isCompleted) completer.completeError(error);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        stream.removeListener(listener);
        throw TimeoutException('Image load timed out: $url');
      },
    );
  }

  // ---- Actions ---------------------------------------------------------------

  void _resetView() => setState(() {
        _scale = 1.0;
        _offset = Offset.zero;
      });

  Map<String, dynamic> _buildSavePayload() {
    final DateTime now = DateTime.now();
    final String name =
        'Outfit ${now.month}/${now.day} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final List<Map<String, dynamic>> items = _garments.values
        .map((g) => <String, dynamic>{
              'clothing_item_id': g.item.id,
              'position': <String, dynamic>{'dx': g.offset.dx, 'dy': g.offset.dy},
            })
        .toList();
    return <String, dynamic>{
      'name': name,
      'avatar_kind': _avatar.name,
      'items': items,
    };
  }

  Future<void> _save() async {
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);

    try {
      if (widget.outfit?.id == null) {
        final Dio dio = ref.read(apiClientProvider);
        await dio.post<dynamic>('/outfits', data: _buildSavePayload());
      }
      // Refresh the outfits list in both cases
      await ref.read(outfitsProvider.notifier).fetch();

      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
      });
      HapticFeedback.lightImpact();
      AppToast.success(context, 'Outfit saved');
      ref.read(styleProfileProvider.notifier).logInteraction(
        action: 'saved',
        outfitId: widget.outfit?.id,
        clothingItemIds: _garments.keys.toList(),
      );
      Future<void>.delayed(AppConstants.saveFeedbackDuration, () {
        if (mounted) setState(() => _saved = false);
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.error(
        context,
        (e.response?.data as Map<String, dynamic>?)?['detail']?.toString() ??
            'Failed to save outfit',
      );
    }
  }

  void _openFeedback() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiFeedbackSheet(outfit: widget.outfit),
    );
  }

  // ---- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;

    final profileState = ref.watch(profileProvider);
    if (!_avatarInitialized && profileState.hasValue) {
      _avatar = AvatarKind.values.firstWhere(
        (e) => e.name == (profileState.value?.avatarKind ?? ''),
        orElse: () => AvatarKind.maleAthletic,
      );
      _avatarInitialized = true;
    }

    return Scaffold(
      backgroundColor: AppConstants.tryOnCanvasColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            for (final g in _garments.values) { g.dispose(); }
            _garments.clear();
            _resetView();
            await _loadGarments();
          },
          child: Column(
            children: <Widget>[
            _TopBar(
              onBack: () => context.pop(),
              onCamera: _garments.isNotEmpty
                  ? () => context.pushNamed(
                        AppRoute.cameraTryOn.name,
                        extra: widget.outfit,
                      )
                  : null,
              onCheckFit: _garments.isNotEmpty
                  ? () => setState(() => _showFitBadges = !_showFitBadges)
                  : null,
              fitActive: _showFitBadges,
            ),
            Expanded(
              flex: 65,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: GestureDetector(
                      onScaleUpdate: (ScaleUpdateDetails d) => setState(() {
                        _scale = (d.scale * _scale).clamp(0.5, 2.5);
                        _offset += d.focalPointDelta;
                      }),
                      child: ColoredBox(
                        color: AppConstants.tryOnCanvasColor,
                        child: widget.outfit == null && _garments.isEmpty && !_loadingGarments
                            ? _TryOnEmptyState(onBrowse: () => context.pushNamed(AppRoute.wardrobe.name))
                            : Center(
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 180),
                                  opacity: _avatarVisible ? 1 : 0.15,
                                  child: Transform.translate(
                                    offset: _offset,
                                    child: Transform.scale(
                                      scale: _scale,
                                      child: _AvatarPreview(
                                        kind: _avatar,
                                        garments: _garments.values.toList(),
                                        loading: _loadingGarments,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  // Banners (Low confidence / Load failures)
                  if (_hasLowConfidence || _failedIds.isNotEmpty)
                    Positioned(
                      top: AppSpacing.sm,
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          if (_hasLowConfidence)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(AppRadius.thumbnail),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(Icons.warning_amber_rounded, size: 16, color: Colors.black87),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Auto-fit confidence is low. Drag items to adjust.',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_hasLowConfidence && _failedIds.isNotEmpty)
                            const SizedBox(height: AppSpacing.sm),
                          if (_failedIds.isNotEmpty)
                            GestureDetector(
                              onTap: _loadGarments,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(alpha: 0.88),
                                  borderRadius: BorderRadius.circular(AppRadius.thumbnail),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const Icon(Icons.error_outline, size: 16, color: Colors.white),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${_failedIds.length} item(s) couldn\'t load — tap to retry.',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  // Fit personalised chip
                  if (ref.watch(fitScalesProvider).isPersonalized)
                    Positioned(
                      bottom: AppSpacing.sm,
                      left: AppSpacing.md,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: c.primary.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(AppRadius.thumbnail),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.check_circle_outline, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Fit personalised',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Fit rating badges
                  if (_showFitBadges)
                    Positioned(
                      top: AppSpacing.sm,
                      left: AppSpacing.md,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _garments.values.map((g) {
                          final fitAsync = ref.watch(fitRatingProvider(g.item.id));
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: fitAsync.when(
                              data: (fit) => _FitBadge(name: g.item.name, fit: fit),
                              loading: () => const SizedBox.shrink(),
                              error: (_, _) => const SizedBox.shrink(),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  // Canvas controls
                  Positioned(
                    right: AppSpacing.md,
                    bottom: AppSpacing.md,
                    child: Column(
                      children: <Widget>[
                        _CanvasControl(
                          icon: Icons.zoom_in,
                          onTap: () => setState(
                            () => _scale = (_scale + 0.15).clamp(0.5, 2.5),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _CanvasControl(
                          icon: Icons.zoom_out,
                          onTap: () => setState(
                            () => _scale = (_scale - 0.15).clamp(0.5, 2.5),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _CanvasControl(
                          icon: Icons.center_focus_strong_outlined,
                          onTap: _resetView,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _CanvasControl(
                          icon: _avatarVisible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          onTap: () =>
                              setState(() => _avatarVisible = !_avatarVisible),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: c.background,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.sheetTop),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: _DetailsPanel(
                    outfit: widget.outfit,
                    garments: _garments.values.toList(),
                    avatar: _avatar,
                    onAvatarChanged: (AvatarKind k) =>
                        setState(() => _avatar = k),
                    onFeedback: _openFeedback,
                    onSave: _save,
                    saving: _saving,
                    saved: _saved,
                  ),
                ),
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
// Top bar
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, this.onCamera, this.onCheckFit, this.fitActive = false});
  final VoidCallback onBack;
  final VoidCallback? onCamera;
  final VoidCallback? onCheckFit;
  final bool fitActive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onBack,
          ),
          const Spacer(),
          if (onCheckFit != null)
            IconButton(
              icon: Icon(
                Icons.straighten,
                color: fitActive ? Colors.greenAccent : Colors.white,
              ),
              tooltip: 'Check Fit',
              onPressed: onCheckFit,
            ),
          if (onCamera != null)
            IconButton(
              icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
              tooltip: 'Live Try-On',
              onPressed: onCamera,
            ),
          IconButton(
            icon: const Icon(Icons.fullscreen, color: Colors.white),
            tooltip: 'Fullscreen',
            onPressed: () {
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Canvas controls
// ---------------------------------------------------------------------------

class _CanvasControl extends StatelessWidget {
  const _CanvasControl({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 20, color: Colors.black87),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar preview + clothing overlay
// ---------------------------------------------------------------------------

class _AvatarPreview extends ConsumerWidget {
  const _AvatarPreview({
    required this.kind,
    required this.garments,
    this.loading = false,
  });

  final AvatarKind kind;
  final List<_GarmentData> garments;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FitScales fitScales = ref.watch(fitScalesProvider);
    return SizedBox(
      width: 220,
      height: 360,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Avatar base
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  kind.accent.withValues(alpha: 0.4),
                  kind.accent.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Center(
              child: Icon(Icons.person, size: 200, color: kind.accent),
            ),
          ),
          // Clothing overlay via CustomPaint
          if (garments.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: CustomPaint(
                painter: _ClothingPainter(garments: garments, fitScales: fitScales),
              ),
            ),
          // Loading indicator while garments are being fetched/decoded
          if (loading)
            const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white70,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state — shown when no outfit is loaded
// ---------------------------------------------------------------------------

class _TryOnEmptyState extends StatelessWidget {
  const _TryOnEmptyState({required this.onBrowse});
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.checkroom_outlined, size: 64, color: c.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: AppSpacing.md),
            Text('No outfit loaded', style: text.titleMedium?.copyWith(color: c.textSecondary)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Open an outfit from your wardrobe\nto preview it here.',
              style: text.bodySmall?.copyWith(color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: onBrowse,
              icon: const Icon(Icons.checkroom, size: 18),
              label: const Text('Browse Wardrobe'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Clothing overlay painter
// ---------------------------------------------------------------------------

class _ClothingPainter extends CustomPainter {
  const _ClothingPainter({required this.garments, required this.fitScales});

  final List<_GarmentData> garments;
  final FitScales fitScales;

  // --- Avatar anatomy (normalized 0..1 within the 220×360 canvas) -----------
  static const Map<String, Offset> _avatarAnchors = <String, Offset>{
    'shoulder': Offset(0.50, 0.27),
    'chest': Offset(0.50, 0.40),
    'waist': Offset(0.50, 0.56),
    'hip': Offset(0.50, 0.65),
    'feet': Offset(0.50, 0.91),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final List<_GarmentData> sorted = List<_GarmentData>.from(garments)
      ..sort((a, b) => garmentDepth(a.item.type).compareTo(garmentDepth(b.item.type)));

    for (final _GarmentData garment in sorted) {
      _paintOne(canvas, size, garment);
    }
  }

  void _paintOne(Canvas canvas, Size size, _GarmentData garment) {
    final ui.Image img = garment.uiImage;

    // 1. Display size: fixed width scaled by user body measurements, aspect-ratio height
    final double dispW = size.width * garmentWidthFactor(garment.item.type) * fitScales.forType(garment.item.type);
    final double dispH = dispW / (img.width / img.height);

    // 2. Avatar anchor in canvas pixels
    final Offset avatarNorm = _avatarAnchors[garmentAnchorKey(garment.item.type)]!;
    final double avatarX = avatarNorm.dx * size.width;
    final double avatarY = avatarNorm.dy * size.height;

    // 3. Garment anchor in garment pixels
    final Offset gNorm = garmentAnchorNorm(garment.item);
    final double gAnchorX = gNorm.dx * dispW;
    final double gAnchorY = gNorm.dy * dispH;

    // 4. Position garment so its anchor aligns with the avatar anchor,
    //    then apply any user-applied offset
    final double left = avatarX - gAnchorX + garment.offset.dx;
    final double top = avatarY - gAnchorY + garment.offset.dy;

    paintImage(
      canvas: canvas,
      rect: Rect.fromLTWH(left, top, dispW, dispH),
      image: img,
      fit: BoxFit.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _ClothingPainter old) =>
      old.garments != garments || old.fitScales != fitScales;
}

// ---------------------------------------------------------------------------
// Fit badge (shown when "Check Fit" is active)
// ---------------------------------------------------------------------------

class _FitBadge extends StatelessWidget {
  const _FitBadge({required this.name, required this.fit});
  final String name;
  final FitResult fit;

  @override
  Widget build(BuildContext context) {
    final (Color bg, IconData icon, String label) = switch (fit.rating) {
      FitRating.perfect    => (Colors.green.shade700,  Icons.check_circle_outline, 'Perfect fit'),
      FitRating.mayBeSnug  => (Colors.orange.shade700, Icons.warning_amber_rounded, 'May be snug'),
      FitRating.runsLarge  => (Colors.blue.shade700,   Icons.info_outline,          'Runs large'),
      FitRating.unknown    => (Colors.grey.shade700,   Icons.help_outline,          'Unknown fit'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '$name · $label',
            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Details panel
// ---------------------------------------------------------------------------

class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({
    this.outfit,
    required this.garments,
    required this.avatar,
    required this.onAvatarChanged,
    required this.onFeedback,
    required this.onSave,
    required this.saving,
    required this.saved,
  });

  final Outfit? outfit;
  final List<_GarmentData> garments;
  final AvatarKind avatar;
  final ValueChanged<AvatarKind> onAvatarChanged;
  final VoidCallback onFeedback;
  final VoidCallback onSave;
  final bool saving;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    final String itemName = garments.isNotEmpty
        ? garments.first.item.name
        : (outfit?.name ?? 'Try On');
    final String itemSubtitle = outfit != null
        ? '${outfit!.items.length} item${outfit!.items.length == 1 ? '' : 's'}'
        : garments.isNotEmpty
            ? garments.first.item.type
            : '';

    // Thumbnail: use processed image of first garment, or a colour swatch
    Widget thumbnail;
    if (garments.isNotEmpty && garments.first.item.processedUrl.isNotEmpty) {
      thumbnail = ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.thumbnail),
        child: Image.network(
          garments.first.item.processedUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _swatchFallback(c),
        ),
      );
    } else {
      thumbnail = _swatchFallback(c);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            thumbnail,
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(itemName, style: text.titleMedium),
                  if (itemSubtitle.isNotEmpty)
                    Text(
                      itemSubtitle,
                      style: text.bodySmall?.copyWith(color: c.textSecondary),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: AvatarKind.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (_, int i) {
              final AvatarKind k = AvatarKind.values[i];
              final bool selected = k == avatar;
              return GestureDetector(
                onTap: () => onAvatarChanged(k),
                child: Container(
                  width: 56,
                  decoration: BoxDecoration(
                    color: k.accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppRadius.thumbnail),
                    border: Border.all(
                      color: selected ? c.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Icon(Icons.person, color: k.accent, size: 28),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: <Widget>[
            Expanded(
              child: SecondaryButton(
                label: 'AI Feedback',
                icon: Icons.auto_awesome,
                onPressed: onFeedback,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: PrimaryButton(
                label: saved ? 'Saved ✓' : 'Save Outfit',
                icon: saved ? Icons.check : Icons.bookmark_outline,
                loading: saving,
                onPressed: saving || saved ? null : onSave,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _swatchFallback(AppColors c) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: c.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.thumbnail),
        ),
        child: Icon(Icons.checkroom, size: 20, color: c.primary),
      );
}
