import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/outfit.dart';
import '../../core/providers/outfits_provider.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/primary_button.dart';
import '../feedback/ai_feedback_sheet.dart';

class AiFeedbackScreen extends ConsumerWidget {
  const AiFeedbackScreen({super.key});

  void _openReport(BuildContext context, Outfit outfit) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiFeedbackSheet(outfit: outfit),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final AsyncValue<List<Outfit>> outfits = ref.watch(outfitsProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('AI Style Report', style: text.headlineMedium),
      ),
      body: outfits.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _ErrorState(c: c, text: text),
        data: (List<Outfit> list) {
          if (list.isEmpty) return _EmptyState(c: c, text: text);
          return _OutfitList(
            outfits: list,
            onReport: (Outfit o) => _openReport(context, o),
            c: c,
            text: text,
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _OutfitList extends StatelessWidget {
  const _OutfitList({
    required this.outfits,
    required this.onReport,
    required this.c,
    required this.text,
  });

  final List<Outfit> outfits;
  final void Function(Outfit) onReport;
  final AppColors c;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.lg,
          ),
          child: Text(
            'Select an outfit to get personalised AI feedback on colour, balance, and occasion fit.',
            style: text.bodyMedium?.copyWith(color: c.textSecondary),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xxxl,
            ),
            itemCount: outfits.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (_, int i) => _OutfitReportCard(
              outfit: outfits[i],
              onReport: onReport,
              c: c,
              text: text,
            ),
          ),
        ),
      ],
    );
  }
}

class _OutfitReportCard extends StatelessWidget {
  const _OutfitReportCard({
    required this.outfit,
    required this.onReport,
    required this.c,
    required this.text,
  });

  final Outfit outfit;
  final void Function(Outfit) onReport;
  final AppColors c;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.thumbnail),
            ),
            child: Icon(Icons.checkroom, color: c.primary, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  outfit.name,
                  style: text.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${outfit.items.length} item${outfit.items.length == 1 ? '' : 's'}',
                  style: text.bodySmall?.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          TextButton(
            onPressed: () => onReport(outfit),
            style: TextButton.styleFrom(
              backgroundColor: c.primary.withValues(alpha: 0.10),
              foregroundColor: c.primary,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.auto_awesome, size: 14, color: c.primary),
                const SizedBox(width: 4),
                const Text('Report', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.c, required this.text});

  final AppColors c;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.auto_awesome_outlined, size: 64, color: c.textSecondary),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No outfits yet',
            style: text.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Generate or save an outfit first, then come back for your style report.',
            style: text.bodyMedium?.copyWith(color: c.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            width: 220,
            child: PrimaryButton(
              label: 'Build an Outfit',
              icon: Icons.add,
              onPressed: () => context.goNamed(AppRoute.home.name),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.c, required this.text});

  final AppColors c;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.cloud_off_outlined, size: 52, color: c.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Could not load outfits.',
              style: text.titleMedium?.copyWith(color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
