/// مدرّج الكمية — أزرار ± بأهداف لمس ≥ 48 (DS-29) وقيمة بأرقام جدولية.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/fin_tokens.dart';
import '../../../../core/widgets/amount_text.dart';

/// مدرّج الكمية — أزرار ± بأهداف لمس ≥ 48 (DS-29) وقيمة بأرقام جدولية.
///
/// **R17-a — كتابة الكمية مباشرة**: عند تمرير [onValueTap] تصبح قيمة
/// الكمية نفسها زراً قابلاً للنقر (فتح المحرر الرقمي السريع «تعديل
/// الكمية» بكتابة 7 أو 2.5 مباشرة) — بخلفية خفيفة وأيقونة قلم صغيرة
/// توحي بالقابلية؛ وبدون المعامل تبقى القيمة نصاً ساكناً كسلوكها
/// القديم حصراً (لا مستخدم آخر حالياً لكن المعامل اختياري للأمان).
class QtyStepper extends StatelessWidget {
  const QtyStepper({
    super.key,
    required this.qty,
    required this.onChanged,
    this.enabled = true,
    this.onValueTap,
  });

  final double qty;
  final ValueChanged<double> onChanged;
  final bool enabled;

  /// R17-a — نقرة قيمة الكمية تفتح تحريراً رقمياً فورياً (null = قيمة
  /// ساكنة غير قابلة للنقر — السلوك القديم).
  final VoidCallback? onValueTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final decimals = qty == qty.truncateToDouble() ? 0 : 3;
    // R17-a: تقليم الأصفار الزائدة (2.500 → 2.5) — صف الكمية ضيق على
    // 390dp وأيقونة القلم تشاركه المساحة؛ العرض الأقصر يسع الجميع.
    var qtyText = AmountText.format(qty, decimals);
    if (decimals > 0 && qtyText.contains('.')) {
      qtyText = qtyText
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
    }
    final value = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(qtyText, style: FinText.amountRow(scheme.onSurface)),
        if (onValueTap != null) ...[
          const SizedBox(width: FinSpacing.xs),
          Icon(Icons.edit_rounded, size: 14, color: scheme.onSurfaceVariant),
        ],
      ],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundStepButton(
          icon: Icons.remove_rounded,
          color: colors.negative,
          onPressed: enabled && qty > 1 ? () => onChanged(qty - 1) : null,
        ),
        if (onValueTap == null)
          Container(
            constraints: const BoxConstraints(minWidth: 52),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: value,
          )
        else
          _QtyValueButton(
            key: const Key('sell_line_qty_value'),
            onTap: enabled ? onValueTap : null,
            child: value,
          ),
        _RoundStepButton(
          icon: Icons.add_rounded,
          color: colors.positive,
          onPressed: enabled ? () => onChanged(qty + 1) : null,
        ),
      ],
    );
  }
}

/// هدف نقر قيمة الكمية (R17-a): خلفية خفيفة + نصف قطر تحكم FinRadius +
/// رجل ملموسة ≥ 36 — يميّزها بصرياً عن النص الساكن ويدل على القابلية.
class _QtyValueButton extends StatelessWidget {
  const _QtyValueButton({super.key, required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(FinRadius.control),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 52, minHeight: 36),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: child,
        ),
      ),
    );
  }
}

class _RoundStepButton extends StatelessWidget {
  const _RoundStepButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
