import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/clothing_item.dart';
import '../../core/providers/wardrobe_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/primary_button.dart';

class EditClothingSheet extends ConsumerStatefulWidget {
  const EditClothingSheet({super.key, required this.item});
  final ClothingItem item;

  @override
  ConsumerState<EditClothingSheet> createState() => _EditClothingSheetState();
}

class _EditClothingSheetState extends ConsumerState<EditClothingSheet> {
  static const List<String> _sizeOptions = <String>[
    'XS', 'S', 'M', 'L', 'XL', 'XXL', 'One Size',
  ];

  late final TextEditingController _nameCtrl;
  late final TextEditingController _colorCtrl;
  String? _selectedSize;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _colorCtrl = TextEditingController(text: widget.item.color ?? '');
    final String? sl = widget.item.sizeLabel;
    _selectedSize = (sl != null && _sizeOptions.contains(sl)) ? sl : null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(wardrobeProvider.notifier).update(
        widget.item.id,
        <String, dynamic>{
          'name': name,
          if (_colorCtrl.text.trim().isNotEmpty) 'color': _colorCtrl.text.trim(),
          if (_selectedSize != null) 'size_label': _selectedSize,
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      AppToast.success(context, 'Updated "$name"');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.error(context, 'Failed to update item');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheetTop),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl,
        ),
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
              const SizedBox(height: AppSpacing.lg),
              Text('Edit Item', style: text.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Item name',
                ),
                textCapitalization: TextCapitalization.words,
                maxLength: 100,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _colorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Color',
                  hintText: 'e.g. Navy Blue',
                ),
                textCapitalization: TextCapitalization.words,
                maxLength: 50,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _selectedSize,
                decoration: const InputDecoration(labelText: 'Size'),
                hint: const Text('Select size'),
                items: _sizeOptions
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedSize = v),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'Save Changes',
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
