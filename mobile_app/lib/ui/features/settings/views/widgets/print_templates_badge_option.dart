/// بطاقة خيار شارة (بلا/أصل/صورة) لشاشة قوالب الطباعة — مستخرجة
/// حرفياً من `print_templates_screen.dart` (R20-D3d؛ كانت `_BadgeOption`).
library;

import 'package:flutter/material.dart';

/// بطاقة خيار شارة (بلا/أصل/صورة).
class PrintTemplatesBadgeOption extends StatelessWidget {
  const PrintTemplatesBadgeOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected ? scheme.onPrimaryContainer : null,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
