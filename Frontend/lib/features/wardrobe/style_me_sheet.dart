import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/primary_button.dart';

class StyleMeSheet extends StatefulWidget {
  const StyleMeSheet({super.key});

  @override
  State<StyleMeSheet> createState() => _StyleMeSheetState();
}

class _StyleMeSheetState extends State<StyleMeSheet> {
  final List<String> _occasions = const <String>[
    'Casual', 'Work', 'Party', 'Date Night', 'Workout', 'Loungewear'
  ];
  String? _selectedOccasion;
  bool _useWeather = false;
  bool _isGenerating = false;

  Future<void> _handleGenerate() async {
    setState(() => _isGenerating = true);
    HapticFeedback.mediumImpact();

    String weatherContext = '';

    if (_useWeather) {
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) throw Exception('Location services disabled.');

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            throw Exception('Location permissions denied.');
          }
        }
        
        if (permission == LocationPermission.deniedForever) {
          throw Exception('Location permissions permanently denied.');
        }

        // Mock getting position and weather
        final Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 5));
        
        // In a real app we'd call an API with position.latitude/longitude
        weatherContext = ' (72°F, Sunny)';
      } catch (e) {
        if (mounted) {
          AppToast.error(context, 'Could not get weather: ${e.toString().split('Exception:').last}');
        }
        setState(() => _useWeather = false);
      }
    }

    // Mock API delay for outfit generation
    await Future<void>.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    
    // Pass context to TryOn via extra if needed, or simply route
    context.pop(); // Close sheet
    context.pushNamed(AppRoute.tryOn.name);
    AppToast.success(context, 'Generated ${_selectedOccasion ?? 'Outfit'}$weatherContext!');
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheetTop)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheetTop)),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
          ),
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: <Widget>[
                    Image.asset('assets/icons/05_icon_magic_wand.png', width: 28, height: 28, color: c.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Style Me', style: text.headlineSmall),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text('What is the occasion?', style: text.bodyMedium?.copyWith(color: c.textSecondary)),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _occasions.map((String occ) {
                    return AppChip(
                      label: occ,
                      selected: _selectedOccasion == occ,
                      onTap: () => setState(() => _selectedOccasion = occ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: c.background.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: c.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.wb_sunny_outlined, color: c.primary, size: 20),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Include Local Weather', style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                            Text('Requires location access', style: text.bodySmall?.copyWith(color: c.textSecondary)),
                          ],
                        ),
                      ),
                      Switch(
                        value: _useWeather,
                        onChanged: (bool val) => setState(() => _useWeather = val),
                        activeColor: c.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                PrimaryButton(
                  label: _isGenerating ? 'Generating...' : 'Generate Outfit',
                  isLoading: _isGenerating,
                  onPressed: _selectedOccasion == null || _isGenerating ? null : _handleGenerate,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
