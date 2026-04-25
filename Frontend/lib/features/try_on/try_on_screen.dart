import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/mock/mock_data.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../feedback/ai_feedback_sheet.dart';

class TryOnScreen extends StatefulWidget {
  const TryOnScreen({super.key});

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends State<TryOnScreen> {
  AvatarKind _avatar = AvatarKind.athletic;
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  bool _avatarVisible = true;
  bool _saved = false;
  bool _saving = false;

  void _resetView() {
    setState(() {
      _scale = 1.0;
      _offset = Offset.zero;
    });
  }

  Future<void> _save() async {
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    // TODO(api): POST outfit to backend.
    await Future<void>.delayed(const Duration(milliseconds: 600));
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
  }

  void _openFeedback() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AiFeedbackSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;

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
                                child: _AvatarPreview(kind: _avatar),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
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

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({required this.kind});

  final AvatarKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 360,
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
      child: Stack(
        children: <Widget>[
          Center(child: Icon(Icons.person, size: 200, color: kind.accent)),
          // Mock clothing overlay — a colored rectangle approximating a top.
          Positioned(
            top: 90,
            left: 50,
            right: 50,
            height: 110,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1F2A55),
                borderRadius: BorderRadius.circular(AppRadius.thumbnail),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({
    required this.avatar,
    required this.onAvatarChanged,
    required this.onFeedback,
    required this.onSave,
    required this.saving,
    required this.saved,
  });

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1F2A55),
                borderRadius: BorderRadius.circular(AppRadius.thumbnail),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Navy Crew Tee', style: text.titleMedium),
                  Text(
                    'Top',
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
}
