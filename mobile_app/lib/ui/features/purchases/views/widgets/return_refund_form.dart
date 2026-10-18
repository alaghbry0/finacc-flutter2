/// نموذج رد قيمة المرتجع بنافذة المرتجع (الاتجاهات + المبلغ النقدي +
/// المعاينة الحية) — مستخرج من return_refund_sheet (R20-D3b: نقل حرفي
/// بلا أي تغيير سلوكي؛ منطق الحالة يبقى بمتحكم النافذة ويصله عبر
/// النداءات).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/fin_error_card.dart';
import '../../../../core/widgets/fin_sheet_drag_handle.dart';

/// أنماط رد القيمة في النافذة.
enum ReturnRefundMode { fullCash, fullCredit, mixed }

class ReturnRefundForm extends StatelessWidget {
  const ReturnRefundForm({
    super.key,
    required this.mode,
    required this.cashController,
    required this.refundTotal,
    required this.decimals,
    required this.currencyCode,
    required this.partyLabel,
    required this.cashOnly,
    required this.netCash,
    required this.credit,
    required this.error,
    required this.posting,
    required this.onModeChanged,
    required this.onCashChanged,
    required this.onConfirm,
  });

  final ReturnRefundMode mode;
  final TextEditingController cashController;
  final double refundTotal;
  final int decimals;
  final String? currencyCode;
  final String partyLabel;
  final bool cashOnly;
  final double netCash;
  final double credit;
  final String? error;
  final bool posting;
  final ValueChanged<ReturnRefundMode> onModeChanged;
  final VoidCallback onCashChanged;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FinSheetDragHandle(),
        const SizedBox(height: 12),
        Column(
          children: [
            Text(
              l10n.retRefundTotalLabel,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              textBaseline: TextBaseline.alphabetic,
              children: [
                AmountText(
                  amount: refundTotal,
                  size: AmountSize.display,
                  decimals: decimals == 0 ? 0 : 2,
                ),
                if (currencyCode != null && currencyCode!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    currencyCode!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              partyLabel,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        const SizedBox(height: 18),
        SegmentedButton<ReturnRefundMode>(
          segments: [
            ButtonSegment(
              value: ReturnRefundMode.fullCash,
              label: Text(l10n.retRefundCash),
              icon: const Icon(Icons.payments_rounded),
            ),
            ButtonSegment(
              value: ReturnRefundMode.fullCredit,
              label: Text(l10n.retRefundCredit),
              icon: const Icon(Icons.account_balance_wallet_rounded),
            ),
            if (!cashOnly)
              ButtonSegment(
                value: ReturnRefundMode.mixed,
                label: Text(l10n.sellPayMethodMixed),
                icon: const Icon(Icons.call_split_rounded),
              ),
          ],
          selected: {mode},
          onSelectionChanged: cashOnly
              ? null
              : (selection) => onModeChanged(selection.first),
        ),
        const SizedBox(height: 8),
        if (cashOnly)
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
                    l10n.retRefundCashOnlyNote,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (mode != ReturnRefundMode.fullCredit) ...[
          const SizedBox(height: 10),
          TextField(
            key: const Key('ret_refund_cash_field'),
            controller: cashController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,4}')),
            ],
            enabled: !posting,
            onChanged: (_) => onCashChanged(),
            decoration: InputDecoration(
              labelText: l10n.retRefundCashFieldLabel,
              suffixText: currencyCode ?? '',
            ),
          ),
        ],
        const SizedBox(height: 14),
        FinCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _PreviewRow(
                label: l10n.retReceiptRefundCash,
                value: mode == ReturnRefundMode.fullCredit ? 0 : netCash,
                decimals: decimals == 0 ? 0 : 2,
              ),
              if (credit > 0)
                _PreviewRow(
                  label: l10n.retReceiptRefundCredit,
                  value: credit,
                  decimals: decimals == 0 ? 0 : 2,
                ),
              if (credit <= 0)
                _PreviewRow(
                  label: l10n.sellPaySettledFully,
                  value: null,
                  decimals: decimals == 0 ? 0 : 2,
                ),
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 14),
          FinErrorCard(message: error!),
        ],
        const SizedBox(height: 18),
        FilledButton(
          key: const Key('ret_refund_confirm'),
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
              : Text(l10n.retPostButton),
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

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
    required this.decimals,
  });

  final String label;
  final double? value;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          if (value != null)
            AmountText(
              amount: value!,
              decimals: decimals,
              showSignMarker: false,
            )
          else
            const Icon(Icons.check_circle_rounded, size: 20),
        ],
      ),
    );
  }
}
