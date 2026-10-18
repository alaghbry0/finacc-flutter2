// ─────────────────────────────────────────────────────────────────────
// نافذة المراجعة قبل الاعتماد (نمط payment_sheet السفلية)
// ─────────────────────────────────────────────────────────────────────

/// يفتح نافذة مراجعة الفروقات — الفروقات فقط + القيم بتكلفة اللقطة +
/// تحذير قفل الأرصدة + تأكيد يرحّل ثم حوار نجاح.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../data/repositories/stocktake_repository.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../view_models/stocktake_view_model.dart';
import 'stocktake_format.dart';
import 'stocktake_success_dialog.dart';

/// مقبض النافذة السفلية (نمط موحّد).
class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 4,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

Future<void> showStocktakeReview(BuildContext context, StocktakeViewModel vm) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider<StocktakeViewModel>.value(
      value: vm,
      child: const StocktakeReviewSheet(),
    ),
  );
}

class StocktakeReviewSheet extends StatefulWidget {
  const StocktakeReviewSheet({super.key});

  @override
  State<StocktakeReviewSheet> createState() => _StocktakeReviewSheetState();
}

class _StocktakeReviewSheetState extends State<StocktakeReviewSheet> {
  Future<void> _confirm(StocktakeViewModel vm) async {
    final result = await vm.post();
    if (!mounted) return;
    if (result.isErr) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.errorOrNull!)));
      return;
    }
    Navigator.of(context).pop();
    unawaited(showStocktakeSuccess(context, result.valueOrNull!));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StocktakeViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final state = vm.state;
    final summary = state.summary;
    final decimals = state.baseCurrencyDecimals;
    final countedAt = state.countedAt ?? DateTime.now();

    // أسطر الفروقات فقط (المعدودة ذات فرق ≠ 0).
    final diffLines = <StocktakeLineDraft>[
      for (final line in state.lines)
        if (line.diff != null && line.diff!.abs() > stocktakeQtyEps) line,
    ];
    final uncounted = summary.linesCount - summary.countedCount;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetDragHandle(),
            Text(
              l10n.stocktakeReviewTitle,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '${l10n.stocktakeCountedAtLabel}: ${stocktakeFormatDate(countedAt)}'
              ' · ${l10n.stocktakeCountedByLabel}: ${state.countedBy.trim()}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            if (diffLines.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.positiveContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      color: colors.onPositiveContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.stocktakeReviewNoDiffs,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onPositiveContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final line in diffLines)
                _ReviewLineRow(line: line, decimals: decimals),
            const SizedBox(height: 12),
            Divider(height: 1, thickness: 0.8, color: colors.divider),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ReviewTotalColumn(
                    label: l10n.stocktakeSurplus,
                    value: summary.surplusValue,
                    decimals: decimals,
                    sign: FinSign.incoming,
                  ),
                ),
                Expanded(
                  child: _ReviewTotalColumn(
                    label: l10n.stocktakeShortage,
                    value: summary.shortageValue,
                    decimals: decimals,
                    sign: FinSign.outgoing,
                  ),
                ),
                Expanded(
                  child: _ReviewTotalColumn(
                    label: l10n.stocktakeNetDiff,
                    value: summary.netDiffValue,
                    decimals: decimals,
                    net: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.negativeContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_rounded, color: colors.negative, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.stocktakeReviewWarning,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onNegativeContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (uncounted > 0) ...[
              const SizedBox(height: 8),
              Text(
                l10n.stocktakeReviewSkipNote(uncounted),
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              key: const Key('stocktake_confirm_button'),
              onPressed: state.posting ? null : () => unawaited(_confirm(vm)),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                textStyle: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              child: state.posting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : Text(l10n.stocktakeConfirmPost),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: state.posting
                  ? null
                  : () => Navigator.of(context).pop(),
              child: Text(l10n.commonCancel),
            ),
          ],
        ),
      ),
    );
  }
}

/// سطر فرق واحد في المراجعة: الاسم + الفرق بإشارة + القيمة بتكلفة اللقطة.
class _ReviewLineRow extends StatelessWidget {
  const _ReviewLineRow({required this.line, required this.decimals});

  final StocktakeLineDraft line;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final diff = line.diff!;
    final value = diff * line.unitCost;
    final sign = diff > 0 ? FinSign.incoming : FinSign.outgoing;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${l10n.stocktakeBookQty} ${stocktakeQty(line.bookQty)}'
                  ' ← ${l10n.stocktakeCountedQty} '
                  '${stocktakeQty(line.countedQty!)}'
                  '${line.unitName == null ? '' : ' ${line.unitName}'}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: FinText.tabularNums,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AmountText(amount: diff.abs(), decimals: 3, sign: sign),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: AmountText(
                    amount: value.abs(),
                    decimals: decimals,
                    sign: sign,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// عمود إجمالي في المراجعة (زيادة/عجز/صافي).
class _ReviewTotalColumn extends StatelessWidget {
  const _ReviewTotalColumn({
    required this.label,
    required this.value,
    required this.decimals,
    this.sign = FinSign.neutral,
    this.net = false,
  });

  final String label;
  final double value;
  final int decimals;
  final FinSign sign;
  final bool net;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveSign = net
        ? (value > 0.005
              ? FinSign.incoming
              : value < -0.005
              ? FinSign.outgoing
              : FinSign.neutral)
        : sign;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        AmountText(
          amount: value.abs(),
          decimals: decimals,
          sign: effectiveSign,
        ),
      ],
    );
  }
}
