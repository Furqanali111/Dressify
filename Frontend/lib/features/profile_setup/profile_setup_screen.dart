import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/profile_provider.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/unit_toggle.dart';

enum HeightUnit { cm, ftIn }

enum WeightUnit { kg, lbs }

enum BodyType { slim, athletic, average, curvy, plus }

extension on BodyType {
  String get label {
    switch (this) {
      case BodyType.slim:
        return 'Slim';
      case BodyType.athletic:
        return 'Athletic';
      case BodyType.average:
        return 'Average';
      case BodyType.curvy:
        return 'Curvy';
      case BodyType.plus:
        return 'Plus';
    }
  }
}

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _heightInchesController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  // Phase 4.1 — optional body measurements
  final TextEditingController _chestController    = TextEditingController();
  final TextEditingController _waistController    = TextEditingController();
  final TextEditingController _hipController      = TextEditingController();
  final TextEditingController _shoulderController = TextEditingController();
  bool _measurementsExpanded = false;

  HeightUnit _heightUnit = HeightUnit.cm;
  WeightUnit _weightUnit = WeightUnit.kg;
  BodyType? _bodyType;
  String? _gender;

  String? _heightError;
  String? _weightError;

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _heightInchesController.dispose();
    _weightController.dispose();
    _chestController.dispose();
    _waistController.dispose();
    _hipController.dispose();
    _shoulderController.dispose();
    super.dispose();
  }

  bool get _canContinue {
    if (_nameController.text.trim().isEmpty) return false;
    final bool hasHeight = _heightController.text.trim().isNotEmpty;
    final bool hasWeight = _weightController.text.trim().isNotEmpty;
    if (!hasHeight && !hasWeight) return false;
    if (_heightError != null || _weightError != null) return false;
    return true;
  }

  void _validateHeight() {
    final String raw = _heightController.text.trim();
    if (raw.isEmpty) {
      setState(() => _heightError = null);
      return;
    }
    final double? value = double.tryParse(raw);
    if (value == null) {
      setState(() => _heightError = 'Enter a number');
      return;
    }

    if (_heightUnit == HeightUnit.cm) {
      if (value < 100 || value > 250) {
        setState(() => _heightError = 'Height must be 100–250 cm');
        return;
      }
    } else {
      if (value < 3 || value > 8) {
        setState(() => _heightError = 'Feet must be 3–8');
        return;
      }
      final String inchesRaw = _heightInchesController.text.trim();
      final double inches = inchesRaw.isEmpty ? 0 : (double.tryParse(inchesRaw) ?? -1);
      if (inches < 0 || inches >= 12) {
        setState(() => _heightError = 'Inches must be 0–11');
        return;
      }
    }

    setState(() => _heightError = null);
  }

  void _validateWeight() {
    final String raw = _weightController.text.trim();
    if (raw.isEmpty) {
      setState(() => _weightError = null);
      return;
    }
    final double? value = double.tryParse(raw);
    if (value == null) {
      setState(() => _weightError = 'Enter a number');
      return;
    }

    if (_weightUnit == WeightUnit.kg) {
      if (value < 30 || value > 300) {
        setState(() => _weightError = 'Weight must be 30–300 kg');
        return;
      }
    } else {
      if (value < 66 || value > 660) {
        setState(() => _weightError = 'Weight must be 66–660 lbs');
        return;
      }
    }

    setState(() => _weightError = null);
  }

  Future<void> _handleContinue() async {
    // Convert to canonical units (cm, kg) before sending.
    double? heightCm;
    if (_heightController.text.isNotEmpty) {
      if (_heightUnit == HeightUnit.cm) {
        heightCm = double.tryParse(_heightController.text);
      } else {
        final ft = double.tryParse(_heightController.text) ?? 0;
        final inch = _heightInchesController.text.isEmpty ? 0 : (double.tryParse(_heightInchesController.text) ?? 0);
        heightCm = (ft * 30.48) + (inch * 2.54);
      }
    }
    
    double? weightKg;
    if (_weightController.text.isNotEmpty) {
      if (_weightUnit == WeightUnit.kg) {
        weightKg = double.tryParse(_weightController.text);
      } else {
        weightKg = (double.tryParse(_weightController.text) ?? 0) * 0.453592;
      }
    }

    double? parseCm(TextEditingController c) {
      final v = double.tryParse(c.text.trim());
      return (v != null && v > 0) ? v : null;
    }

    final Map<String, dynamic> data = <String, dynamic>{
      'height_cm': ?heightCm,
      'weight_kg': ?weightKg,
      if (_bodyType != null) 'body_type': _bodyType!.name,
      if (_gender != null) 'gender': _gender,
      // Phase 4.1 measurements (only if expanded and filled)
      if (_measurementsExpanded) ...{
        if (parseCm(_chestController)    != null) 'chest_cm':    parseCm(_chestController),
        if (parseCm(_waistController)    != null) 'waist_cm':    parseCm(_waistController),
        if (parseCm(_hipController)      != null) 'hip_cm':      parseCm(_hipController),
        if (parseCm(_shoulderController) != null) 'shoulder_cm': parseCm(_shoulderController),
      },
    };

    try {
      await ref.read(profileProvider.notifier).updateProfile(data);
    } catch (e) {
      // Allow moving forward even if API fails for now
    }

    if (!mounted) return;
    context.goNamed(AppRoute.avatarSelection.name, extra: _gender);
  }

  void _handleSkip() {
    context.goNamed(AppRoute.avatarSelection.name);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _Header(onSkip: _handleSkip),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text('Tell us about yourself', style: text.displayMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'This helps us fit clothing more accurately',
                      style: text.bodyMedium?.copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppTextField(
                      label: 'Name',
                      controller: _nameController,
                      hint: 'Your name',
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _HeightField(
                      unit: _heightUnit,
                      cmController: _heightController,
                      inchesController: _heightInchesController,
                      error: _heightError,
                      onChanged: (_) => _validateHeight(),
                      onUnitChanged: (HeightUnit u) {
                        setState(() {
                          _heightUnit = u;
                          _heightController.clear();
                          _heightInchesController.clear();
                          _heightError = null;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _WeightField(
                      unit: _weightUnit,
                      controller: _weightController,
                      error: _weightError,
                      onChanged: (_) => _validateWeight(),
                      onUnitChanged: (WeightUnit u) {
                        setState(() {
                          _weightUnit = u;
                          _weightController.clear();
                          _weightError = null;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Body type',
                      style: text.labelMedium?.copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: BodyType.values.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: AppSpacing.sm),
                        itemBuilder: (_, int i) {
                          final BodyType type = BodyType.values[i];
                          return AppChip(
                            label: type.label,
                            selected: _bodyType == type,
                            onTap: () => setState(() => _bodyType = type),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Gender',
                      style: text.labelMedium?.copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: <Widget>[
                          AppChip(
                            label: 'Female',
                            selected: _gender == 'Female',
                            onTap: () => setState(() => _gender = 'Female'),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          AppChip(
                            label: 'Male',
                            selected: _gender == 'Male',
                            onTap: () => setState(() => _gender = 'Male'),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          AppChip(
                            label: 'Other',
                            selected: _gender == 'Other',
                            onTap: () => setState(() => _gender = 'Other'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Phase 4.1 — optional measurements
                    GestureDetector(
                      onTap: () => setState(
                        () => _measurementsExpanded = !_measurementsExpanded,
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            _measurementsExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 20,
                            color: c.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Add body measurements (optional)',
                            style: text.labelMedium?.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_measurementsExpanded) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Used to scale garments to your proportions. All values in cm.',
                        style: text.bodySmall?.copyWith(color: c.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: AppTextField(
                              label: 'Chest',
                              controller: _chestController,
                              hint: 'e.g. 90',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppTextField(
                              label: 'Waist',
                              controller: _waistController,
                              hint: 'e.g. 74',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: AppTextField(
                              label: 'Hip',
                              controller: _hipController,
                              hint: 'e.g. 96',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppTextField(
                              label: 'Shoulder',
                              controller: _shoulderController,
                              hint: 'e.g. 42',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: Column(
                children: <Widget>[
                  PrimaryButton(
                    label: 'Continue',
                    onPressed: _canContinue ? _handleContinue : null,
                  ),
                  TextButton(
                    onPressed: _handleSkip,
                    child: Text(
                      'Skip for now',
                      style: text.labelLarge?.copyWith(color: c.textSecondary),
                    ),
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

class _Header extends StatelessWidget {
  const _Header({required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        0,
      ),
      child: Row(
        children: <Widget>[
          Text(
            'Step 1 of 2',
            style: text.labelMedium?.copyWith(
              color: c.primary,
              letterSpacing: 0.6,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(48, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Skip',
              style: text.labelLarge?.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeightField extends StatelessWidget {
  const _HeightField({
    required this.unit,
    required this.cmController,
    required this.inchesController,
    required this.error,
    required this.onChanged,
    required this.onUnitChanged,
  });

  final HeightUnit unit;
  final TextEditingController cmController;
  final TextEditingController inchesController;
  final String? error;
  final ValueChanged<String> onChanged;
  final ValueChanged<HeightUnit> onUnitChanged;

  @override
  Widget build(BuildContext context) {
    final List<TextInputFormatter> numericFormatters = <TextInputFormatter>[
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
    ];

    final Widget toggle = UnitToggle<HeightUnit>(
      value: unit,
      onChanged: onUnitChanged,
      options: const <UnitOption<HeightUnit>>[
        UnitOption<HeightUnit>(value: HeightUnit.cm, label: 'cm'),
        UnitOption<HeightUnit>(value: HeightUnit.ftIn, label: 'ft·in'),
      ],
    );

    if (unit == HeightUnit.cm) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: AppTextField(
              label: 'Height',
              controller: cmController,
              hint: 'e.g. 175',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: numericFormatters,
              error: error,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.only(top: 22),
            child: toggle,
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: AppTextField(
            label: 'Height (ft)',
            controller: cmController,
            hint: '5',
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            error: error,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: AppTextField(
            label: 'in',
            controller: inchesController,
            hint: '8',
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.only(top: 22),
          child: toggle,
        ),
      ],
    );
  }
}

class _WeightField extends StatelessWidget {
  const _WeightField({
    required this.unit,
    required this.controller,
    required this.error,
    required this.onChanged,
    required this.onUnitChanged,
  });

  final WeightUnit unit;
  final TextEditingController controller;
  final String? error;
  final ValueChanged<String> onChanged;
  final ValueChanged<WeightUnit> onUnitChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: AppTextField(
            label: 'Weight',
            controller: controller,
            hint: unit == WeightUnit.kg ? 'e.g. 70' : 'e.g. 154',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            error: error,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.only(top: 22),
          child: UnitToggle<WeightUnit>(
            value: unit,
            onChanged: onUnitChanged,
            options: const <UnitOption<WeightUnit>>[
              UnitOption<WeightUnit>(value: WeightUnit.kg, label: 'kg'),
              UnitOption<WeightUnit>(value: WeightUnit.lbs, label: 'lbs'),
            ],
          ),
        ),
      ],
    );
  }
}
