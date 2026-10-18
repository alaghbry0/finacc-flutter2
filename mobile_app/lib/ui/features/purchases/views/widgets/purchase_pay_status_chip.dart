/// رقائق حالة دفع الشراء (R19-D3a — مستخرجة حرفياً من
/// `purchase_widgets.dart` بلا أي تغيير دلالة).
library;

import 'package:flutter/material.dart';

import '../../../../../domain/models/purchase.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/status_chip.dart';

/// رقاقة حالة دفع فاتورة الشراء (نقدي/آجل/مختلط) بنص واضح دائماً.
class PurchasePayStatusChip extends StatelessWidget {
  const PurchasePayStatusChip({
    super.key,
    required this.method,
    this.dense = true,
  });

  final PurchasePaymentMethod method;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (label, tone, icon) = switch (method) {
      PurchasePaymentMethod.cash => (
        l10n.sellPayMethodCash,
        ChipTone.positive,
        Icons.payments_rounded,
      ),
      PurchasePaymentMethod.credit => (
        l10n.sellPayMethodCredit,
        ChipTone.warning,
        Icons.schedule_rounded,
      ),
      PurchasePaymentMethod.mixed => (
        l10n.sellPayMethodMixed,
        ChipTone.brand,
        Icons.call_split_rounded,
      ),
    };
    return StatusChip(label: label, tone: tone, icon: icon, dense: dense);
  }
}

/// شارة «سعر صرف تقديري» (FR-02-20) — تحذيرية بنص لا لون فقط.
class PurchaseFallbackRateBadge extends StatelessWidget {
  const PurchaseFallbackRateBadge({super.key, this.dense = true});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    return StatusChip(
      label: AppLocalizations.of(context)!.sellFallbackRateBadge,
      tone: ChipTone.warning,
      icon: Icons.price_change_rounded,
      dense: dense,
    );
  }
}
