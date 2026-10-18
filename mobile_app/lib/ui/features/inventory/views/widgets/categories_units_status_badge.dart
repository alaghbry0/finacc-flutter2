/// شارة نصية صغيرة مصبوغة (رئيسية/معامل تحويل) — مستخرجة من
/// categories_units_screen (R20-D3c: نقل حرفي بلا أي تغيير سلوكي؛ كانت
/// StatusBadge عامة بالشاشة وليس لها مستورد خارجي فأخذت بادئة الميزة).
library;

import 'package:flutter/material.dart';

/// شارة نصية صغيرة مصبوغة.
class CategoriesUnitsStatusBadge extends StatelessWidget {
  const CategoriesUnitsStatusBadge({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}
