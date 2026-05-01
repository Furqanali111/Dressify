import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/outfit.dart';
import '../../core/models/wardrobe_analytics.dart';
import '../../core/models/wear_log.dart';
import '../../core/providers/ai_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/wardrobe_analytics_provider.dart';
import '../../core/providers/wear_logs_provider.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/dio_retry.dart';
import '../../core/widgets/app_toast.dart';

class WardrobeAnalyticsScreen extends ConsumerWidget {
  const WardrobeAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final asyncData = ref.watch(wardrobeAnalyticsProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: const Text('Wardrobe Analytics'),
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, _) {
          final bool isRateLimit = err is RateLimitException;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    isRateLimit ? Icons.hourglass_bottom_rounded : Icons.error_outline,
                    size: 48,
                    color: isRateLimit ? c.primary : c.error,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    isRateLimit
                        ? 'You\u2019ve reached the request limit.\nPlease wait a moment and try again.'
                        : 'Could not load analytics',
                    style: text.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: () => ref.read(wardrobeAnalyticsProvider.notifier).refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        },
        data: (analytics) {
          if (analytics == null) {
            return Center(child: Text('No data yet', style: text.bodyMedium));
          }
          return RefreshIndicator(
            onRefresh: () => Future.wait<void>([
              ref.read(wardrobeAnalyticsProvider.notifier).refresh(),
              ref.read(wearLogsProvider.notifier).fetch(),
            ]),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xxxxl,
              ),
              children: <Widget>[
                _StatsHeader(analytics: analytics),
                const SizedBox(height: AppSpacing.xl),
                const _SectionTitle(title: 'Recent Activity'),
                const SizedBox(height: AppSpacing.md),
                _RecentWearHistory(),
                const SizedBox(height: AppSpacing.xl),
                if (analytics.colorDistribution.isNotEmpty) ...<Widget>[
                  const _SectionTitle(title: 'Colour Palette'),
                  const SizedBox(height: AppSpacing.md),
                  _ColorPieChart(data: analytics.colorDistribution),
                  const SizedBox(height: AppSpacing.xl),
                ],
                if (analytics.mostWorn.isNotEmpty) ...<Widget>[
                  const _SectionTitle(title: 'Most Worn'),
                  const SizedBox(height: AppSpacing.md),
                  _MostWornRow(items: analytics.mostWorn),
                  const SizedBox(height: AppSpacing.xl),
                ],
                if (analytics.underutilised.isNotEmpty) ...<Widget>[
                  const _SectionTitle(title: 'Sitting in Your Closet'),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'These haven\'t been worn in the last 30 days.',
                    style: text.bodySmall?.copyWith(color: c.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _UnderutilisedList(items: analytics.underutilised),
                  const SizedBox(height: AppSpacing.xl),
                ],
                if (analytics.styleBreakdown.isNotEmpty) ...<Widget>[
                  const _SectionTitle(title: 'Style Breakdown'),
                  const SizedBox(height: AppSpacing.md),
                  _StyleBarChart(data: analytics.styleBreakdown),
                  const SizedBox(height: AppSpacing.xl),
                ],
                const _SectionTitle(title: 'Outfit Frequency'),
                const SizedBox(height: AppSpacing.md),
                if (analytics.outfitFrequency.isEmpty)
                  _FrequencyEmptyState()
                else
                  _FrequencyBars(weeks: analytics.outfitFrequency),
                const SizedBox(height: AppSpacing.xl),
                const _SectionTitle(title: 'Personalised Look Suggestion'),
                const SizedBox(height: AppSpacing.xs),
                _AiStyleTipsSection(),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent Wear History
// ---------------------------------------------------------------------------

class _RecentWearHistory extends ConsumerWidget {
  const _RecentWearHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final asyncLogs = ref.watch(wearLogsProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.border),
      ),
      child: asyncLogs.loading && asyncLogs.items.isEmpty
          ? const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.md), child: CircularProgressIndicator()))
          : asyncLogs.items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text('No wear logs yet. Wear an outfit to start tracking!',
                      style: text.bodySmall?.copyWith(color: c.textSecondary), textAlign: TextAlign.center),
                )
              : Column(
                  children: asyncLogs.items.take(3).map((log) {
                    final isOutfit = log.outfitId != null;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          Icon(isOutfit ? Icons.style : Icons.checkroom, size: 16, color: c.primary),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              isOutfit ? 'Outfit Worn' : '${log.clothingItemIds?.length ?? 0} Item(s) Worn',
                              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            _timeAgo(log.loggedAt),
                            style: text.bodySmall?.copyWith(color: c.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

// ---------------------------------------------------------------------------
// Stats header
// ---------------------------------------------------------------------------

class _StatsHeader extends StatelessWidget {
  const _StatsHeader({required this.analytics});
  final WardrobeAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Row(
      children: <Widget>[
        Expanded(child: _StatCard(icon: Icons.checkroom, label: 'Items', value: '${analytics.totalItems}', c: c)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _StatCard(icon: Icons.style, label: 'Outfits', value: '${analytics.totalOutfits}', c: c)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value, required this.c});
  final IconData icon;
  final String label;
  final String value;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: <BoxShadow>[BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: c.primary, size: 28),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.textPrimary)),
              Text(label, style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section title
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: c.textPrimary),
    );
  }
}

// ---------------------------------------------------------------------------
// Colour pie chart
// ---------------------------------------------------------------------------


class _ColorPieChart extends StatelessWidget {
  const _ColorPieChart({required this.data});
  final Map<String, int> data;

  static const List<Color> _palette = <Color>[
    Color(0xFF6366F1), Color(0xFF22D3EE), Color(0xFFF59E0B),
    Color(0xFF10B981), Color(0xFFEF4444), Color(0xFFA78BFA),
    Color(0xFFFB923C), Color(0xFF34D399), Color(0xFF60A5FA), Color(0xFFF472B6),
  ];

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    final total   = entries.fold<int>(0, (s, e) => s + e.value);

    return Row(
      children: <Widget>[
        SizedBox(
          width: 140,
          height: 140,
          child: CustomPaint(painter: _PiePainter(entries: entries, total: total, palette: _palette)),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.asMap().entries.map((entry) {
              final int i = entry.key;
              final MapEntry<String, int> e = entry.value;
              final pct = total > 0 ? (e.value / total * 100).round() : 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: <Widget>[
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: _palette[i % _palette.length], shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Expanded(child: Text('${_capitalize(e.key)} ($pct%)', style: const TextStyle(fontSize: 12))),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  static String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _PiePainter extends CustomPainter {
  const _PiePainter({required this.entries, required this.total, required this.palette});
  final List<MapEntry<String, int>> entries;
  final int total;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;
    final Rect rect = Offset.zero & size;
    double startAngle = -math.pi / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < entries.length; i++) {
      final sweep = (entries[i].value / total) * 2 * math.pi;
      paint.color = palette[i % palette.length];
      canvas.drawArc(rect, startAngle, sweep, true, paint);
      startAngle += sweep;
    }

    // White centre hole
    paint.color = Colors.white;
    canvas.drawCircle(rect.center, size.width * 0.28, paint);
  }

  @override
  bool shouldRepaint(covariant _PiePainter old) => old.entries != entries;
}

// ---------------------------------------------------------------------------
// Most-worn row
// ---------------------------------------------------------------------------

class _MostWornRow extends StatelessWidget {
  const _MostWornRow({required this.items});
  final List<WornItem> items;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (_, i) {
          final item = items[i];
          return SizedBox(
            width: 100,
            child: Column(
              children: <Widget>[
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: item.processedUrl.isNotEmpty
                        ? CachedNetworkImage(imageUrl: item.processedUrl, fit: BoxFit.cover)
                        : Container(color: c.surface, child: Icon(Icons.checkroom, color: c.textSecondary)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: c.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Text('${item.wearCount}×', style: TextStyle(fontSize: 10, color: c.primary, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Underutilised list
// ---------------------------------------------------------------------------

class _UnderutilisedList extends ConsumerWidget {
  const _UnderutilisedList({required this.items});
  final List<WornItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = context.colors;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: items.map((item) => GestureDetector(
        onTap: () => Navigator.of(context).maybePop().then((_) {
          if (context.mounted) {
            // Navigate to wardrobe to find the item
          }
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.border),
          ),
          child: Text(item.name, style: TextStyle(fontSize: 13, color: c.textPrimary)),
        ),
      )).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Style bar chart
// ---------------------------------------------------------------------------

class _StyleBarChart extends StatelessWidget {
  const _StyleBarChart({required this.data});
  final Map<String, int> data;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxVal  = entries.isEmpty ? 1 : entries.first.value;

    return Column(
      children: entries.map((e) {
        final frac = maxVal > 0 ? e.value / maxVal : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 90,
                child: Text(
                  _capitalize(e.key),
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 10,
                    backgroundColor: c.border,
                    valueColor: AlwaysStoppedAnimation<Color>(c.primary),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('${e.value}', style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }).toList(),
    );
  }

  static String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ---------------------------------------------------------------------------
// Weekly frequency bars
// ---------------------------------------------------------------------------

class _FrequencyEmptyState extends StatelessWidget {
  const _FrequencyEmptyState();

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: <Widget>[
          Icon(Icons.bar_chart_rounded, size: 40, color: c.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No frequency data yet',
            style: text.titleSmall?.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Try on outfits to start tracking your weekly frequency.',
            style: text.bodySmall?.copyWith(color: c.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FrequencyBars extends StatelessWidget {
  const _FrequencyBars({required this.weeks});
  final List<WeeklyFrequency> weeks;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final maxVal = weeks.isEmpty ? 1 : weeks.map((w) => w.count).reduce(math.max);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: weeks.map((w) {
        final frac = maxVal > 0 ? w.count / maxVal : 0.0;
        final label = w.week.replaceFirst(RegExp(r'\d{4}-'), ''); // "W17"
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: <Widget>[
                Text('${w.count}', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  child: SizedBox(
                    height: 60,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: frac.clamp(0.05, 1.0),
                        child: ColoredBox(color: c.primary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(fontSize: 10, color: c.textSecondary)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// AI Style Tips section
// ---------------------------------------------------------------------------

class _AiStyleTipsSection extends ConsumerStatefulWidget {
  const _AiStyleTipsSection();

  @override
  ConsumerState<_AiStyleTipsSection> createState() => _AiStyleTipsSectionState();
}

class _AiStyleTipsSectionState extends ConsumerState<_AiStyleTipsSection> {
  static const List<String> _occasions = <String>[
    'Casual', 'Work', 'Party', 'Date Night', 'Workout', 'Loungewear',
  ];

  String? _selected;
  bool _loading = false;
  Outfit? _result;

  Future<void> _generate() async {
    if (_selected == null || _loading) return;
    setState(() { _loading = true; _result = null; });

    try {
      final profile = ref.read(profileProvider).value;
      final outfit = await ref.read(aiProvider).generateOutfit(
        occasion: _selected!,
        avatarKind: profile?.avatarKind,
      );
      if (mounted) setState(() => _result = outfit);
    } catch (_) {
      if (mounted) AppToast.show(context, 'Could not generate look. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Pick an occasion and get a personalised outfit suggestion.',
          style: text.bodySmall?.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: _occasions.map((occ) {
            final bool active = _selected == occ;
            return GestureDetector(
              onTap: () => setState(() { _selected = occ; _result = null; }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 7),
                decoration: BoxDecoration(
                  color: active ? c.primary : c.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? c.primary : c.border),
                ),
                child: Text(
                  occ,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    color: active ? Colors.white : c.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _selected == null || _loading ? null : _generate,
            icon: _loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome, size: 16),
            label: Text(_loading ? 'Generating…' : 'Generate Look'),
            style: FilledButton.styleFrom(
              backgroundColor: c.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        if (_selected == null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.info_outline, size: 13, color: c.textSecondary),
              const SizedBox(width: 4),
              Text(
                'Select an occasion above to enable',
                style: TextStyle(fontSize: 12, color: c.textSecondary),
              ),
            ],
          ),
        ],
        if (_result != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: c.primary.withValues(alpha: 0.3)),
              boxShadow: <BoxShadow>[
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(_result!.name, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        '${_result!.items.length} item${_result!.items.length == 1 ? '' : 's'} · $_selected',
                        style: text.bodySmall?.copyWith(color: c.textSecondary),
                      ),
                      if (_result!.personalized == true) ...<Widget>[
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            Icon(Icons.auto_awesome, size: 12, color: c.primary),
                            const SizedBox(width: 4),
                            Text('Personalised for you', style: TextStyle(fontSize: 11, color: c.primary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                FilledButton(
                  onPressed: () => context.pushNamed(AppRoute.tryOn.name, extra: _result),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
                  ),
                  child: const Text('Try It', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xxxxl),
      ],
    );
  }
}
