/// نموذج الدفع بنافذة الدفع (الطرق + المدفوع نقداً + المعاينة الحية) —
/// مستخرج من payment_sheet (R19-D3b: نقل حرفي بلا أي تغيير سلوكي؛
/// منطق الحالة يبقى بمتحكم النافذة ويصله عبر النداءات).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/fin_error_card.dart';
import '../../../../core/widgets/fin_sheet_drag_handle.dart';
import 'payment_preview_widgets.dart';

/// أنماط الدفع في النافذة.
enum PaymentMode { fullCash, fullCredit, mixed }

class PaymentPayForm extends StatelessWidget {
  const PaymentPayForm({
    super.key,
    required this.mode,
    required this.hasCustomer,
    required this.cashController,
    required this.grandTotal,
    required this.decimals,
    required this.currencyCode,
    required this.customerName,
    required this.netPaid,
    required this.changeDue,
    required this.remainingCredit,
    required this.error,
    required this.posting,
    required this.onModeChanged,
    required this.onCashChanged,
    required this.onConfirm,
  });

  final PaymentMode mode;
  final bool hasCustomer;
  final TextEditingController cashController;
  final double grandTotal;
  final int decimals;
  final String? currencyCode;
  final String? customerName;
  final double netPaid;
  final double changeDue;
  final double remainingCredit;
  final String? error;
  final bool posting;
  final ValueChanged<PaymentMode> onModeChanged;
  final VoidCallback onCashChanged;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FinSheetDragHandle(),
        const SizedBox(height: 12),
        PaymentTotalHeader(
          grandTotal: grandTotal,
          decimals: decimals,
          currencyCode: currencyCode,
          customerName: customerName,
        ),
        const SizedBox(height: 18),
        SegmentedButton<PaymentMode>(
          segments: [
            ButtonSegment(
              value: PaymentMode.fullCash,
              label: Text(l10n.sellPayMethodCash),
              icon: const Icon(Icons.payments_rounded),
            ),
            // P2-3: آجل/مختلط معطّلان بلا عميل (النقدي المجهول يسدد
            // كاملاً حصراً) — التحذير القائم يبقى معروضاً تحتهما.
            ButtonSegment(
              value: PaymentMode.fullCredit,
              label: Text(l10n.sellPayMethodCredit),
              icon: const Icon(Icons.schedule_rounded),
              enabled: hasCustomer,
            ),
            ButtonSegment(
              value: PaymentMode.mixed,
              label: Text(l10n.sellPayMethodMixed),
              icon: const Icon(Icons.call_split_rounded),
              enabled: hasCustomer,
            ),
          ],
          selected: {mode},
          onSelectionChanged: (selection) => onModeChanged(selection.first),
        ),
        const SizedBox(height: 8),
        if (!hasCustomer)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: colors.warning,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.sellPayAnonymousCashOnly,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (mode != PaymentMode.fullCredit) ...[
          const SizedBox(height: 10),
          TextField(
            controller: cashController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,4}')),
            ],
            enabled: !posting,
            onChanged: (_) => onCashChanged(),
            // أرقام جدولية أثناء الكتابة (الخط المرافق — UX-2b): الحقل
            // يتقلص/يتمدد مع كل خانة بأرقام متساوية العرض فلا يقفز النص.
            style: FinText.withTabularDigits(
              Theme.of(context).textTheme.bodyLarge!,
            ),
            decoration: InputDecoration(
              labelText: l10n.sellPayCashFieldLabel,
              suffixText: currencyCode ?? '',
              helperText: mode == PaymentMode.fullCash
                  ? l10n.sellPayCashFieldHelper
                  : null,
            ),
          ),
        ],
        const SizedBox(height: 14),
        PaymentSettlementPreview(
          grandTotal: grandTotal,
          decimals: decimals,
          netPaid: netPaid,
          changeDue: changeDue,
          remainingCredit: remainingCredit,
        ),
        if (error != null) ...[
          const SizedBox(height: 14),
          FinErrorCard(message: error!),
        ],
        const SizedBox(height: 18),
        FilledButton(
          onPressed: posting ? null : onConfirm,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            textStyle: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          child: posting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : Text(l10n.sellPayConfirm),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: posting ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
      ],
    );
  }
}
