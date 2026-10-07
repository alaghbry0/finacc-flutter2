/// StatusChip — DS-26: شريحة حالة **دائماً بنص لا لون فقط** (§6.1).
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// نبرة الحالة.
enum ChipTone { positive, negative, warning, neutral, brand }

/// شريحة حالة بنص واضح.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = ChipTone.neutral,
    this.icon,
    this.dense = false,
  });

  /// نص الحالة (إلزامي — هو العلامة غير اللونية).
  final String label;

  /// النبرة اللونية الدلالية.
  final ChipTone tone;

  /// أيقونة صغيرة مرافقة (اختيارية).
  final IconData? icon;

  /// كثافة مضغوطة للقوائم.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = FinColors.of(context);
    final (bg, fg) = switch (tone) {
      ChipTone.positive => (
        colors.positiveContainer,
        colors.onPositiveContainer,
      ),
      ChipTone.negative => (
        colors.negativeContainer,
        colors.onNegativeContainer,
      ),
      ChipTone.warning => (colors.warningContainer, colors.onWarningContainer),
      ChipTone.neutral => (
        Theme.of(context).colorScheme.surfaceContainerHigh,
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      ChipTone.brand => (
        Theme.of(context).colorScheme.primaryContainer,
        Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: fg, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
