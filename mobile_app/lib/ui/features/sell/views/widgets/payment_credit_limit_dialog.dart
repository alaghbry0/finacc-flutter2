/// حوار حد الائتمان لنافذة الدفع (FR-03-05 / 17-c) — مستخرج من
/// payment_sheet (R19-D3b: نقل حرفي بلا أي تغيير سلوكي).
library;

import 'package:flutter/material.dart';

import '../../../../../domain/services/credit_limit.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';

/// حوار حد الائتمان (FR-03-05 / 17-c): الحد + الرصيد الحالي + الرصيد
/// المتوقع بعد الفاتورة. warn → «متابعة على أي حال / إلغاء»؛
/// block → «رجوع» حصراً (لا متابعة، والنقر خارجه لا يمرر).
class PaymentCreditLimitDialog extends StatelessWidget {
  const PaymentCreditLimitDialog({
    super.key,
    required this.decision,
    required this.gate,
    required this.decimals,
    required this.currencyCode,
    required this.customerName,
  });

  final CreditLimitDecision decision;
  final CreditLimitGate gate;
  final int decimals;
  final String? currencyCode;
  final String? customerName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final d = decimals == 0 ? 0 : 2;

    return AlertDialog(
      icon: Icon(
        Icons.gpp_maybe_rounded,
        color: decision.blocked ? colors.negative : colors.warning,
        size: 32,
      ),
      title: Text(l10n.creditLimitTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            decision.blocked
                ? l10n.creditLimitBlocked
                : l10n.creditLimitExceeded,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (customerName != null) ...[
            const SizedBox(height: 4),
            Text(
              // اسم العميل + رمز عملة الفاتورة (سياق المبالغ المعروضة).
              currencyCode != null && currencyCode!.isNotEmpty
                  ? '$customerName • ${currencyCode!}'
                  : customerName!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          PaymentLimitRow(
            label: l10n.creditLimitLimitLabel,
            value: gate.creditLimit ?? 0,
            decimals: d,
            color: colors.gold,
            emphasized: true,
          ),
          PaymentLimitRow(
            label: l10n.creditLimitCurrentLabel,
            value: gate.currentBalance,
            decimals: d,
            color: scheme.onSurfaceVariant,
          ),
          PaymentLimitRow(
            label: l10n.creditLimitResultingLabel,
            value: decision.resultingBalance,
            decimals: d,
            color: decision.blocked ? colors.negative : colors.warning,
            emphasized: true,
          ),
        ],
      ),
      actions: [
        if (!decision.blocked) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.creditLimitCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.creditLimitContinue),
          ),
        ] else
          FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.creditLimitBack),
          ),
      ],
    );
  }
}

/// سطر مبلغ داخل حوار الائتمان — تسمية + مبلغ بأرقام جدولية.
class PaymentLimitRow extends StatelessWidget {
  const PaymentLimitRow({
    super.key,
    required this.label,
    required this.value,
    required this.decimals,
    required this.color,
    this.emphasized = false,
  });

  final String label;
  final double value;
  final int decimals;
  final Color color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: emphasized ? FontWeight.w800 : FontWeight.w400,
              ),
            ),
          ),
          // مبلغ ملوّن بأرقام جدولية (LTR داخل السياق العربي) — الخط
          // المرافق NotoSansArabic بأرقام متساوية العرض فلا يرتجّ صف
          // الحوار عند تحديث القيم (UX-2b / DS-18n).
          Text(
            AmountText.formatFor(context, value, decimals),
            style: FinText.withTabularDigits(
              Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: color,
                // w600 غير متوفر في Almarai (300/400/700/800 حصراً) —
                // التصحيح إلى w700 المتاح (UX-2b).
                fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
                fontFeatures: FinText.tabularNums,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
