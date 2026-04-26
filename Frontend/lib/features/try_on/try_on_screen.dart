import 'dart:async';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/mock/mock_data.dart';
import '../../core/models/clothing_item.dart';
import '../../core/models/outfit.dart';
import '../../core/providers/outfits_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/wardrobe_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
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

  // Garment loading
  final Map<String, _GarmentData> _garments = {};
  bool _loadingGarments = false;
  bool _hasLowConfidence = false;

  @override
  void initState() {
    super.initState();
    _loadGarments();
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
        setState(() => _garments[outfitItem.clothingItemId] =
            _GarmentData(item: ci!, uiImage: img));
      } catch (_) {
        // Skip items whose image fails to load
      }
    }

    if (mounted) {
      setState(() {
        _loadingGarments = false;
        _hasLowConfidence = anyLowConfidence;
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
        completer.complete(info.image.clone());
        stream.removeListener(listener);
      },
      onError: (Object error, StackTrace? _) {
        completer.completeError(error);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  // ---- Actions ---------------------------------------------------------------

  void _resetView() => setState(() {
        _scale = 1.0;
        _offset = Offset.zero;
      });

  Future<void> _save() async {
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);

    try {
      if (widget.outfit?.id == null) {
        // Manual outfit — persist it for the first time
        final Dio dio = ref.read(apiClientProvider);
        final List<Map<String, dynamic>> items = _garments.values
            .map((g) => <String, dynamic>{'clothing_item_id': g.item.id})
            .toList();
        await dio.post<dynamic>('/outfits', data: <String, dynamic>{
          'name': 'My Outfit',
          'avatar_kind': _avatar.name,
          'items': items,
        });
      }
      // Refresh the outfits list in both cases
      ref.read(outfitsProvider.notifier).fetch();

      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
      });
      HapticFeedback.lightImpact();
      AppToast.success(context, 'Outfit saved');
      Future<void>.delayed(const Duration(seconds: 2), () {
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
      final profile = profileState.value;
      _avatar = profile?.avatarKind != null
          ? AvatarKind.values.firstWhere(
              (e) => e.name == profile!.avatarKind,
              orElse: () => AvatarKind.maleAthletic,
            )
          : AvatarKind.maleAthletic;
      _avatarInitialized = true;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2A),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _TopBar(onBack: () => context.pop()),
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
                        color: const Color(0xFF1A1A2A),
                        child: Center(
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
                  // Low-confidence warning banner
                  if (_hasLowConfidence)
                    Positioned(
                      top: AppSpacing.sm,
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.88),
                          borderRadius:
                              BorderRadius.circular(AppRadius.thumbnail),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.warning_amber_rounded,
                                size: 16, color: Colors.black87),
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
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});
  final VoidCallback onBack;

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
          IconButton(
            icon: const Icon(Icons.fullscreen, color: Colors.white),
            onPressed: () {},
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

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({
    required this.kind,
    required this.garments,
    this.loading = false,
  });

  final AvatarKind kind;
  final List<_GarmentData> garments;
  final bool loading;

  @override
  Widget build(BuildContext context) {
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
                painter: _ClothingPainter(garments: garments),
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
// Clothing overlay painter
// ---------------------------------------------------------------------------

class _ClothingPainter extends CustomPainter {
  const _ClothingPainter({required this.garments});

  final List<_GarmentData> garments;

  // --- Avatar anatomy (normalized 0..1 within the 220×360 canvas) -----------
  static const Map<String, Offset> _avatarAnchors = <String, Offset>{
    'shoulder': Offset(0.50, 0.27),
    'chest': Offset(0.50, 0.40),
    'waist': Offset(0.50, 0.56),
    'hip': Offset(0.50, 0.65),
    'feet': Offset(0.50, 0.91),
  };

  // Which avatar anchor to snap each garment type to
  static String _anchorKey(String type) {
    switch (type) {
      case 'top':
      case 'jacket':
      case 'dress':
        return 'shoulder';
      case 'bottom':
        return 'waist';
      case 'shoes':
        return 'feet';
      default:
        return 'chest';
    }
  }

  // Garment display width as fraction of canvas width
  static double _widthFactor(String type) {
    switch (type) {
      case 'top':
      case 'jacket':
      case 'dress':
        return 0.72;
      case 'bottom':
        return 0.66;
      case 'shoes':
        return 0.52;
      default:
        return 0.42;
    }
  }

  // Where the snap anchor sits within the garment image (normalized 0..1).
  // Uses anchorPoints from the backend; falls back to type-based defaults.
  static Offset _garmentAnchorNorm(ClothingItem item) {
    final Map<String, dynamic>? ap = item.anchorPoints;
    final String key = _anchorKey(item.type);
    if (ap != null && ap.containsKey(key)) {
      final Map<String, dynamic> pt = ap[key] as Map<String, dynamic>;
      return Offset(
        (pt['x'] as num? ?? 0.5).toDouble(),
        (pt['y'] as num? ?? 0.15).toDouble(),
      );
    }
    // Sensible defaults when backend didn't return anchor points
    switch (item.type) {
      case 'top':
      case 'jacket':
        return const Offset(0.5, 0.16);
      case 'dress':
        return const Offset(0.5, 0.12);
      case 'bottom':
        return const Offset(0.5, 0.07);
      case 'shoes':
        return const Offset(0.5, 0.10);
      default:
        return const Offset(0.5, 0.20);
    }
  }

  // Depth order — bottoms/shoes paint first (behind tops)
  static int _depth(String type) {
    switch (type) {
      case 'shoes':
        return 0;
      case 'bottom':
        return 1;
      case 'dress':
        return 2;
      case 'top':
      case 'jacket':
        return 3;
      default:
        return 4;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final List<_GarmentData> sorted = List<_GarmentData>.from(garments)
      ..sort((a, b) => _depth(a.item.type).compareTo(_depth(b.item.type)));

    for (final _GarmentData garment in sorted) {
      _paintOne(canvas, size, garment);
    }
  }

  void _paintOne(Canvas canvas, Size size, _GarmentData garment) {
    final ui.Image img = garment.uiImage;

    // 1. Display size: fixed width, aspect-ratio height
    final double dispW = size.width * _widthFactor(garment.item.type);
    final double dispH = dispW / (img.width / img.height);

    // 2. Avatar anchor in canvas pixels
    final Offset avatarNorm = _avatarAnchors[_anchorKey(garment.item.type)]!;
    final double avatarX = avatarNorm.dx * size.width;
    final double avatarY = avatarNorm.dy * size.height;

    // 3. Garment anchor in garment pixels
    final Offset gNorm = _garmentAnchorNorm(garment.item);
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
      old.garments != garments;
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
