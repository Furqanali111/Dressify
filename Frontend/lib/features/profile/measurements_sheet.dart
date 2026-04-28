import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/profile.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/primary_button.dart';

class MeasurementsSheet extends ConsumerStatefulWidget {
  const MeasurementsSheet({super.key, required this.profile});

  final Profile? profile;

  @override
  ConsumerState<MeasurementsSheet> createState() => _MeasurementsSheetState();
}

class _MeasurementsSheetState extends ConsumerState<MeasurementsSheet> {
  late final TextEditingController _chestCtrl;
  late final TextEditingController _waistCtrl;
  late final TextEditingController _hipCtrl;
  late final TextEditingController _shoulderCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _chestCtrl    = TextEditingController(text: _fmt(p?.chestCm));
    _waistCtrl    = TextEditingController(text: _fmt(p?.waistCm));
    _hipCtrl      = TextEditingController(text: _fmt(p?.hipCm));
    _shoulderCtrl = TextEditingController(text: _fmt(p?.shoulderCm));
  }

  @override
  void dispose() {
    _chestCtrl.dispose();
    _waistCtrl.dispose();
    _hipCtrl.dispose();
    _shoulderCtrl.dispose();
    super.dispose();
  }

  String _fmt(double? v) => v == null ? '' : v.toStringAsFixed(0);

  double? _parse(TextEditingController ctrl) {
    final s = ctrl.text.trim();
    return s.isEmpty ? null : double.tryParse(s);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(profileProvider.notifier).updateProfile(<String, dynamic>{
        if (_parse(_chestCtrl)    != null) 'chest_cm':    _parse(_chestCtrl),
        if (_parse(_waistCtrl)    != null) 'waist_cm':    _parse(_waistCtrl),
        if (_parse(_hipCtrl)      != null) 'hip_cm':      _parse(_hipCtrl),
        if (_parse(_shoulderCtrl) != null) 'shoulder_cm': _parse(_shoulderCtrl),
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      AppToast.success(context, 'Measurements saved');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.error(context, 'Failed to save measurements');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Handle
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
          const SizedBox(height: AppSpacing.lg),
          Text('Body Measurements', style: text.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Used to scale garments to your proportions. All values in cm.',
            style: text.bodySmall?.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: <Widget>[
              Expanded(child: _Field(label: 'Chest', hint: '90', ctrl: _chestCtrl, min: 50, max: 200)),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _Field(label: 'Waist', hint: '74', ctrl: _waistCtrl, min: 50, max: 180)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(child: _Field(label: 'Hip', hint: '96', ctrl: _hipCtrl, min: 50, max: 200)),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _Field(label: 'Shoulder', hint: '42', ctrl: _shoulderCtrl, min: 30, max: 80)),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: 'Save',
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: text.labelLarge?.copyWith(color: c.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatefulWidget {
  const _Field({
    required this.label,
    required this.hint,
    required this.ctrl,
    required this.min,
    required this.max,
  });

  final String label;
  final String hint;
  final TextEditingController ctrl;
  final double min;
  final double max;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  String? _error;

  void _validate(String v) {
    final d = double.tryParse(v.trim());
    setState(() {
      if (v.trim().isEmpty) {
        _error = null;
      } else if (d == null) {
        _error = 'Enter a number';
      } else if (d < widget.min || d > widget.max) {
        _error = '${widget.min.toInt()}–${widget.max.toInt()} cm';
      } else {
        _error = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: c.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: widget.ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          onChanged: _validate,
          decoration: InputDecoration(
            hintText: widget.hint,
            suffixText: 'cm',
            errorText: _error,
            filled: true,
            fillColor: c.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(color: c.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(color: c.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(color: c.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
          ),
        ),
      ],
    );
  }
}
