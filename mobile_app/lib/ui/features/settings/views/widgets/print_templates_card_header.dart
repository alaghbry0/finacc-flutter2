/// رأس بطاقة شاشة قوالب الطباعة (أيقونة + عنوان) — مستخرج حرفياً من
/// `print_templates_screen.dart` (R20-D3d؛ كان `_CardHeader`).
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/fin_tokens.dart';

/// رأس بطاقة (أيقونة + عنوان).
class PrintTemplatesCardHeader extends StatelessWidget {
  const PrintTemplatesCardHeader({
    super.key,
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(FinRadius.control),
          ),
          child: Icon(icon, size: 20, color: scheme.primary),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
