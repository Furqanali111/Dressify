import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/ai_feedback.dart';
import '../../core/models/outfit.dart';
import '../../core/providers/ai_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/primary_button.dart';

class AiFeedbackSheet extends ConsumerStatefulWidget {
  final Outfit? outfit;

  const AiFeedbackSheet({super.key, this.outfit});

  @override
  ConsumerState<AiFeedbackSheet> createState() => _AiFeedbackSheetState();
}

class _AiFeedbackSheetState extends ConsumerState<AiFeedbackSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arcController;

  double _score = 0.0;
  String _verdict = '';
  List<AiSuggestion> _suggestions = [];
  bool _isLoading = true;
  bool _regenerating = false;
  bool _hasError = false;

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'color':
        return Icons.palette_outlined;
      case 'balance':
        return Icons.balance;
      case 'occasion':
        return Icons.event_available_outlined;
      case 'accessories':
        return Icons.watch_outlined;
      default:
        return Icons.lightbulb_outline;
    }
  }

  @override
  void initState() {
    super.initState();
    _arcController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fetchFeedback();
  }

  @override
  void dispose() {
    _arcController.dispose();
    super.dispose();
  }

  Future<void> _fetchFeedback() async {
    try {
      final aiService = ref.read(aiProvider);
      
      // Use outfit_id when available — backend will persist the feedback automatically.
      // Fall back to item IDs only when there is no persisted outfit yet.
      final String? outfitId = widget.outfit?.id;
      final List<String>? itemIds = outfitId == null &&
              (widget.outfit?.items.isNotEmpty ?? false)
          ? widget.outfit!.items.map((i) => i.clothingItemId).toList()
          : null;

      final response = await aiService.generateFeedback(
        outfitId: outfitId,
        clothingItemIds: itemIds,
        occasion: 'General',
      );

      if (!mounted) return;

      setState(() {
        _score = response.score;
        _verdict = response.verdict;
        _suggestions = response.suggestions;
        _isLoading = false;
        _regenerating = false;
        _hasError = false;
      });
      _arcController.forward(from: 0);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _regenerating = false;
        _hasError = true;
        _verdict = e.response?.data?['detail']?.toString() ?? 'AI Service is currently unavailable.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _regenerating = false;
        _hasError = true;
        _verdict = 'AI Service is currently unavailable.';
      });
    }
  }

  Future<void> _regenerate() async {
    setState(() => _regenerating = true);
    _arcController.value = 0;
    await _fetchFeedback();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final double maxHeight = MediaQuery.of(context).size.height * 0.85;

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ScrollController scrollController) => Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheetTop),
          ),
        ),
        child: Column(
          children: <Widget>[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Your Style Report', style: text.titleLarge),
                        Text(
                          'Casual Weekend',
                          style: text.bodySmall?.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                children: <Widget>[
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_hasError) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_off, size: 64, color: c.textSecondary),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            _verdict,
                            style: text.titleMedium?.copyWith(color: c.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Center(
                      child: AnimatedBuilder(
                        animation: _arcController,
                        builder: (_, _) => _RatingArc(
                          score: _score,
                          animationValue: _arcController.value,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: Text(_verdict, style: text.titleMedium, textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    for (final AiSuggestion s in _suggestions) ...<Widget>[
                      _SuggestionCard(
                        suggestion: s,
                        icon: _getIconForCategory(s.category),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                  Center(
                    child: TextButton.icon(
                      onPressed: _regenerating ? null : _regenerate,
                      icon: _regenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: const Text('Regenerate Feedback'),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: SafeArea(
                top: false,
                child: PrimaryButton(
                  label: 'Done',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatefulWidget {
  const _SuggestionCard({required this.suggestion, required this.icon});

  final AiSuggestion suggestion;
  final IconData icon;

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.thumbnail),
                ),
                child: Icon(widget.icon, color: c.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(widget.suggestion.title, style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      widget.suggestion.detail,
                      maxLines: _expanded ? null : 2,
                      overflow:
                          _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                      style:
                          text.bodyMedium?.copyWith(color: c.textSecondary),
                    ),
                    if (_expanded) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _expanded = false),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Got it'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(60, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingArc extends StatelessWidget {
  const _RatingArc({required this.score, required this.animationValue});

  final double score;
  final double animationValue;

  Color get _color {
    if (score >= 7) return const Color(0xFF22C97A);
    if (score >= 4) return const Color(0xFFF5A623);
    return const Color(0xFFFF5C5C);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: CustomPaint(
        painter: _ArcPainter(
          progress: (score / 10) * animationValue,
          color: _color,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                (score * animationValue).toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '/10',
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) / 2 - 6;

    final Paint track = Paint()
      ..color = const Color(0xFFE8E6F0)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10;

    final Paint fill = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10;

    canvas.drawCircle(center, radius, track);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) =>
      old.progress != progress || old.color != color;
}
