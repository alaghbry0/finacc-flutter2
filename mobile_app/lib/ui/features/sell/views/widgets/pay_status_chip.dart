/// رقائق حالة الدفع وشارة سعر الصرف التقديري (FR-02-20) — مشتركة بين
/// الكاشير وقوائم الفواتير.
library;

import 'package:flutter/material.dart';

import '../../../../../domain/models/sale.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/status_chip.dart';

/// رقاقة حالة الدفع (نقدي/آجل/مختلط) بنص واضح دائماً.
class PayStatusChip extends StatelessWidget {
  const PayStatusChip({super.key, required this.method, this.dense = true});

  final SalePaymentMethod method;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (label, tone, icon) = switch (method) {
      SalePaymentMethod.cash => (
        l10n.sellPayMethodCash,
        ChipTone.positive,
        Icons.payments_rounded,
      ),
      SalePaymentMethod.credit => (
        l10n.sellPayMethodCredit,
        ChipTone.warning,
        Icons.schedule_rounded,
      ),
      SalePaymentMethod.mixed => (
        l10n.sellPayMethodMixed,
        ChipTone.brand,
        Icons.call_split_rounded,
      ),
    };
    return StatusChip(label: label, tone: tone, icon: icon, dense: dense);
  }
}

/// شارة «سعر صرف تقديري» (FR-02-20) — تحذيرية بنص لا لون فقط.
class FallbackRateBadge extends StatelessWidget {
  const FallbackRateBadge({super.key, this.dense = true});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return StatusChip(
      label: l10n.sellFallbackRateBadge,
      tone: ChipTone.warning,
      icon: Icons.price_change_rounded,
      dense: dense,
    );
  }
}
