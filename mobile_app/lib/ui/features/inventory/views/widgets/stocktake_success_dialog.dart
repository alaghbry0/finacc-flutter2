// ─────────────────────────────────────────────────────────────────────
// حوار النجاح
// ─────────────────────────────────────────────────────────────────────

/// حوار نجاح اعتماد الجرد (FR-01-08) — يُفتح بعد ترحيل الجرد.
library;

import 'package:flutter/material.dart';

import '../../view_models/stocktake_view_model.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';
import 'stocktake_format.dart';

/// حوار نجاح الاعتماد: التاريخ + أسطر الفروقات + الصافي الملوّن.
Future<void> showStocktakeSuccess(
  BuildContext context,
  StocktakePosted posted,
) {
  final l10n = AppLocalizations.of(context)!;
  final colors = FinColors.of(context);
  final net = posted.netDiffValue;
  final netSign = net > 0.005
      ? FinSign.incoming
      : net < -0.005
      ? FinSign.outgoing
      : FinSign.neutral;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: colors.positive, size: 26),
          const SizedBox(width: 10),
          Expanded(child: Text(l10n.stocktakeSuccessTitle)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.stocktakeSuccessBody,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          _SuccessRow(
            label: l10n.stocktakeCountedAtLabel,
            value: stocktakeFormatDate(posted.countedAt),
          ),
          _SuccessRow(
            label: l10n.stocktakeSuccessDiffs,
            value: posted.diffsCount.toString(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.stocktakeNetDiff,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(dialogContext)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AmountText(amount: net.abs(), sign: netSign),
              ],
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.commonDone),
        ),
      ],
    ),
  );
}

/// سطر قيمة داخل حوار النجاح.
class _SuccessRow extends StatelessWidget {
  const _SuccessRow({required this.label, required this.value});

  final String label;
  final String value;

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
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
