/// الشريط السفلي الثابت — المعدود/الزيادة/العجز + الصافي الملوّن + زر
/// الاعتماد (معطّل أثناء الترحيل أو بلا عدّ).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../view_models/stocktake_view_model.dart';

class StocktakeSummaryBar extends StatelessWidget {
  const StocktakeSummaryBar({super.key, required this.onPost});

  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StocktakeViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final state = vm.state;
    final summary = state.summary;
    final decimals = state.baseCurrencyDecimals;
    final net = summary.netDiffValue;
    final netSign = net > 0.005
        ? FinSign.incoming
        : net < -0.005
        ? FinSign.outgoing
        : FinSign.neutral;

    return Material(
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.cardBorder, width: 1)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.stocktakeCountedProgress(
                        summary.countedCount,
                        summary.linesCount,
                      ),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFeatures: FinText.tabularNums,
                      ),
                    ),
                  ),
                  _ValueChip(
                    label: l10n.stocktakeSurplus,
                    value: summary.surplusValue,
                    decimals: decimals,
                    sign: FinSign.incoming,
                  ),
                  const SizedBox(width: 8),
                  _ValueChip(
                    label: l10n.stocktakeShortage,
                    value: summary.shortageValue,
                    decimals: decimals,
                    sign: FinSign.outgoing,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.stocktakeNetDiff,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        // scaleDown: هذا العمود قد يضيق بجوار زر الاعتماد
                        // (خطوط العربية أعرض) — كتلة واحدة تتقلص بلا فيض.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              AmountText(
                                amount: net.abs(),
                                size: AmountSize.large,
                                decimals: decimals,
                                sign: netSign,
                              ),
                              if (state.baseCurrencyCode.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(
                                  state.baseCurrencyCode,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: colors.gold,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    key: const Key('stocktake_post_button'),
                    onPressed: vm.canPost ? onPost : null,
                    // داخل صف أفقي (عرض غير مقيد) → حد أدنى بعرض المحتوى
                    // لا Size.fromHeight (عرضه لانهائي يكسر التخطيط هنا).
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      textStyle: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    child: vm.state.posting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : Text(l10n.stocktakePost),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// شريحة قيمة صغيرة في الشريط السفلي (زيادة/عجز).
class _ValueChip extends StatelessWidget {
  const _ValueChip({
    required this.label,
    required this.value,
    required this.decimals,
    required this.sign,
  });

  final String label;
  final double value;
  final int decimals;
  final FinSign sign;

  @override
  Widget build(BuildContext context) {
    final colors = FinColors.of(context);
    final (bg, fg) = switch (sign) {
      FinSign.incoming => (
        colors.positiveContainer,
        colors.onPositiveContainer,
      ),
      FinSign.outgoing => (
        colors.negativeContainer,
        colors.onNegativeContainer,
      ),
      FinSign.neutral => (
        Theme.of(context).colorScheme.surfaceContainerHigh,
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: fg, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 4),
          AmountText(amount: value.abs(), decimals: decimals, sign: sign),
        ],
      ),
    );
  }
}
