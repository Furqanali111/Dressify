import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class AiFeedbackScreen extends StatelessWidget {
  const AiFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: Text('Style Report', style: text.headlineMedium)),
      body: const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: Text(
            'AI feedback rendered as a bottom sheet from Try-On.\n'
            'This route exists for deep-linking and a future full-page variant.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
