// ─────────────────────────────────────────────────────────────────────
// نجاح الإقفال
// ─────────────────────────────────────────────────────────────────────

/// حوار نجاح إقفال الوردية — ملخص + معاينة تقرير PDF + تم.
library;

import 'package:flutter/material.dart';

import '../../../../../data/repositories/shift_repository.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../view_models/shift_view_model.dart';
import 'shift_format.dart';
import 'shift_pdf.dart';

Future<void> showShiftCloseSuccess(
  BuildContext context,
  ShiftViewModel vm,
  ShiftCloseResult result,
) {
  final l10n = AppLocalizations.of(context)!;
  final colors = FinColors.of(context);
  final box = vm.state.boxFor(result.shift.cashboxId);
  final decimals = shiftDecimals(box?.box.currencyCode);
  final diff = result.shift.difference ?? 0;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: colors.positive, size: 26),
          const SizedBox(width: 10),
          Expanded(child: Text(l10n.shiftCloseSuccessTitle)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DialogRow(
            label: l10n.shiftExpectedLabel,
            amount: result.shift.expected ?? 0,
            decimals: decimals,
          ),
          _DialogRow(
            label: l10n.shiftCountedLabel,
            amount: result.shift.counted ?? 0,
            decimals: decimals,
          ),
          _DialogRow(
            label: l10n.shiftDifferenceLabel,
            amount: diff,
            decimals: decimals,
            colored: true,
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
          label: Text(l10n.shiftPdfPreviewAction),
          onPressed: () {
            Navigator.of(dialogContext).pop();
            openShiftPdf(context, vm: vm, shift: result.shift);
          },
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.commonDone),
        ),
      ],
    ),
  );
}

/// سطر مبلغ داخل حوار النجاح.
class _DialogRow extends StatelessWidget {
  const _DialogRow({
    required this.label,
    required this.amount,
    required this.decimals,
    this.colored = false,
  });

  final String label;
  final double amount;
  final int decimals;
  final bool colored;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 8),
          AmountText(
            amount: amount,
            decimals: decimals,
            sign: colored
                ? (amount > 0.005
                      ? FinSign.incoming
                      : amount < -0.005
                      ? FinSign.outgoing
                      : FinSign.neutral)
                : FinSign.neutral,
            showSignMarker: false,
          ),
        ],
      ),
    );
  }
}
