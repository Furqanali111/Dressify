import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/style_profile.dart';
import '../../core/providers/style_profile_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/primary_button.dart';

// ---------------------------------------------------------------------------
// Preset option lists
// ---------------------------------------------------------------------------

const List<String> _kColors = [
  'Black', 'White', 'Navy', 'Grey', 'Beige', 'Brown',
  'Red', 'Blue', 'Green', 'Yellow', 'Pink', 'Purple', 'Orange',
];

const List<String> _kStyles = [
  'Casual', 'Formal', 'Business Casual', 'Sporty', 'Streetwear',
  'Vintage', 'Minimalist', 'Bohemian', 'Preppy', 'Elegant',
];

const List<String> _kPatterns = [
  'Solid', 'Striped', 'Plaid', 'Floral', 'Graphic Print',
  'Animal Print', 'Geometric', 'Tie-Dye', 'Camouflage',
];

// ---------------------------------------------------------------------------
// Sheet
// ---------------------------------------------------------------------------

class StyleDnaSheet extends ConsumerStatefulWidget {
  const StyleDnaSheet({super.key, required this.profile});
  final StyleProfile? profile;

  @override
  ConsumerState<StyleDnaSheet> createState() => _StyleDnaSheetState();
}

class _StyleDnaSheetState extends ConsumerState<StyleDnaSheet> {
  late Set<String> _likedColors;
  late Set<String> _likedStyles;
  late Set<String> _likedPatterns;
  late Set<String> _dislikedStyles;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _likedColors    = Set<String>.from(p?.likedColors    ?? []);
    _likedStyles    = Set<String>.from(p?.likedStyles    ?? []);
    _likedPatterns  = Set<String>.from(p?.likedPatterns  ?? []);
    _dislikedStyles = Set<String>.from(p?.dislikedStyles ?? []);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(styleProfileProvider.notifier).patchProfile({
        'liked_colors':    _likedColors.toList(),
        'liked_styles':    _likedStyles.toList(),
        'liked_patterns':  _likedPatterns.toList(),
        'disliked_styles': _dislikedStyles.toList(),
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      AppToast.success(context, 'Style DNA saved');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.error(context, 'Failed to save style preferences');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheetTop)),
        ),
        child: Column(
          children: <Widget>[
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('My Style DNA', style: text.titleLarge),
                  const SizedBox(height: 4),
                  Text('Select your preferences to personalise outfit suggestions.',
                      style: text.bodySmall?.copyWith(color: c.textSecondary)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
                children: <Widget>[
                  _Section(
                    title: 'Favourite Colors',
                    options: _kColors,
                    selected: _likedColors,
                    color: c.primary,
                    onToggle: (v) => setState(() => _likedColors.contains(v) ? _likedColors.remove(v) : _likedColors.add(v)),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _Section(
                    title: 'Favourite Styles',
                    options: _kStyles,
                    selected: _likedStyles,
                    color: c.primary,
                    onToggle: (v) => setState(() => _likedStyles.contains(v) ? _likedStyles.remove(v) : _likedStyles.add(v)),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _Section(
                    title: 'Favourite Patterns',
                    options: _kPatterns,
                    selected: _likedPatterns,
                    color: c.primary,
                    onToggle: (v) => setState(() => _likedPatterns.contains(v) ? _likedPatterns.remove(v) : _likedPatterns.add(v)),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _Section(
                    title: 'Styles to Avoid',
                    options: _kStyles,
                    selected: _dislikedStyles,
                    color: c.error,
                    onToggle: (v) => setState(() => _dislikedStyles.contains(v) ? _dislikedStyles.remove(v) : _dislikedStyles.add(v)),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(label: 'Save', loading: _saving, onPressed: _saving ? null : _save),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel', style: text.labelLarge?.copyWith(color: c.textSecondary)),
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

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.options,
    required this.selected,
    required this.color,
    required this.onToggle,
  });

  final String title;
  final List<String> options;
  final Set<String> selected;
  final Color color;
  final void Function(String) onToggle;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: c.textSecondary, letterSpacing: 0.5,
        )),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: options.map((opt) {
            final bool on = selected.contains(opt);
            return GestureDetector(
              onTap: () => onToggle(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                decoration: BoxDecoration(
                  color: on ? color.withValues(alpha: 0.15) : c.surface,
                  border: Border.all(color: on ? color : c.border, width: on ? 1.5 : 1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  opt,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                    color: on ? color : c.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
