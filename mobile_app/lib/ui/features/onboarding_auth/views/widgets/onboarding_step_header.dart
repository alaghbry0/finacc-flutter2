/// ترويسة خطوة موحدة للترحيب والتأسيس (R19-D3c — مستخرجة حرفياً من
/// `onboarding_screen.dart` بلا أي تغيير دلالة).
library;

import 'package:flutter/material.dart';

/// ترويسة خطوة موحدة — رقم الخطوة الدائري + العنوان والوصف.
class OnboardingStepHeader extends StatelessWidget {
  const OnboardingStepHeader({
    super.key,
    required this.index,
    required this.title,
    required this.subtitle,
  });

  final int index;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$index',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: scheme.onPrimary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
