/// إجراء إبطال حركة الصندوق أسفل نافذة التفاصيل — مستخرج حرفياً من
/// `movement_detail_sheet.dart` (R20-D3d؛ كان زر الإبطال/ملاحظة
/// «غير قابلة للإبطال»): زر أحمر أثناء التحميل يتحول لمؤشر، أو ملاحظة
/// خافتة للحركات غير القابلة، ولا شيء للمبطلة.
library;

import 'package:flutter/material.dart';

import '../../../../../domain/models/cash.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

/// زر الإبطال (أو ملاحظة عدم القابلية) — [voiding] يعطّل الزر بمؤشر
/// دائري، و[onVoid] يشغّل حوار التأكيد لدى حالة النافذة الأم.
class MovementDetailVoidAction extends StatelessWidget {
  const MovementDetailVoidAction({
    super.key,
    required this.movement,
    required this.voiding,
    required this.onVoid,
  });

  final CashMovementRow movement;
  final bool voiding;
  final VoidCallback onVoid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    if (movement.isVoidable) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: colors.negative,
          foregroundColor: colors.onNegative,
          minimumSize: const Size.fromHeight(52),
        ),
        onPressed: voiding ? null : onVoid,
        icon: voiding
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            : const Icon(Icons.block_rounded, size: 20),
        label: Text(l10n.cashMovementVoidButton),
      );
    }
    if (!movement.isVoided) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.cashMovementNotVoidableNote,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
