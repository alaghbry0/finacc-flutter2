/// كشف العدّ — بطاقة واحدة تضم صفوف الأصناف بفواصل رقيقة (قابل للنمو).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../../../../../data/repositories/stocktake_repository.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../view_models/stocktake_view_model.dart';
import 'stocktake_format.dart';

class StocktakeCountedSheet extends StatelessWidget {
  const StocktakeCountedSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StocktakeViewModel>();
    final lines = vm.state.visibleLines;

    return FinCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant
                    .withValues(alpha: 0.4),
              ),
            _CountedRow(index: i, line: lines[i], enabled: !vm.state.posting),
          ],
        ],
      ),
    );
  }
}

/// صف عدّ واحد: الاسم + شارة الفرق (عند العدّ) / دفتري + لقطة التكلفة +
/// حقل الفعلي + رقاقة «＝ الدفتري» — بدخول متدرج خفيف كصفوف محور المخزن.
class _CountedRow extends StatefulWidget {
  const _CountedRow({
    required this.index,
    required this.line,
    required this.enabled,
  });

  final int index;
  final StocktakeLineDraft line;
  final bool enabled;

  @override
  State<_CountedRow> createState() => _CountedRowState();
}

class _CountedRowState extends State<_CountedRow> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    final counted = widget.line.countedQty;
    _controller.text = counted == null ? '' : stocktakeQty(counted);
  }

  @override
  void didUpdateWidget(covariant _CountedRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // مزامنة مع الحالة: إعادة تحميل الكشف تمسح العدّ؛ والتحديث الخارجي
    // يكتب القيمة الجديدة (التعيين البرمجي لا يطلق onChanged).
    final counted = widget.line.countedQty;
    final text = counted == null ? '' : stocktakeQty(counted);
    if (_controller.text != text) {
      _controller.text = text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String raw, StocktakeViewModel vm) {
    final cleaned = raw.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) {
      vm.setCounted(widget.line.productId, null);
      return;
    }
    final value = double.tryParse(cleaned);
    if (value == null || value.isNaN || value.isInfinite || value < 0) {
      vm.setCounted(widget.line.productId, null);
      return;
    }
    vm.setCounted(widget.line.productId, value);
  }

  void _copyBook(StocktakeViewModel vm) {
    final book = stocktakeQty(widget.line.bookQty);
    _controller.text = book;
    vm.setCounted(widget.line.productId, widget.line.bookQty);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StocktakeViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final line = widget.line;
    final diff = line.diff;
    final decimals = vm.state.baseCurrencyDecimals;

    // حركة الدخول: تأخير خفيف بحسب الترتيب (نمط صفوف محور المخزن).
    final start = (widget.index * 0.05).clamp(0.0, 0.5);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 8),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    line.name,
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (line.unitName != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    line.unitName!,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(width: 8),
                if (diff == null)
                  Text(
                    '—',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: FinText.tabularNums,
                    ),
                  )
                else
                  StatusChip(
                    label: diff > stocktakeQtyEps
                        ? '+${stocktakeQty(diff)}'
                        : diff < -stocktakeQtyEps
                        ? '−${stocktakeQty(diff.abs())}'
                        : l10n.stocktakeMatched,
                    tone: diff > stocktakeQtyEps
                        ? ChipTone.positive
                        : diff < -stocktakeQtyEps
                        ? ChipTone.negative
                        : ChipTone.neutral,
                    dense: true,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _QtyColumn(
                  label: l10n.stocktakeBookQty,
                  value: stocktakeQty(line.bookQty),
                ),
                const SizedBox(width: 10),
                _QtyColumn(
                  label: l10n.stocktakeUnitCost,
                  value: AmountText.formatFor(context, line.unitCost, decimals),
                  gold: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: Key('stocktake_counted_field_${line.productId}'),
                    controller: _controller,
                    enabled: widget.enabled,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*[\.,]?\d{0,3}'),
                      ),
                    ],
                    onChanged: (raw) => _onChanged(raw, vm),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontFeatures: FinText.tabularNums,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.stocktakeCountedQty,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: l10n.stocktakeSetBook,
                  child: Material(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: widget.enabled ? () => _copyBook(vm) : null,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                        child: Text(
                          '＝',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: scheme.onSecondaryContainer,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// عمود كمية صغير (تسمية + قيمة جدولية) — دفتري/لقطة التكلفة.
class _QtyColumn extends StatelessWidget {
  const _QtyColumn({
    required this.label,
    required this.value,
    this.gold = false,
  });

  final String label;
  final String value;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return SizedBox(
      width: 74,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              value,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: gold ? colors.gold : null,
                fontWeight: FontWeight.w800,
                fontFeatures: FinText.tabularNums,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
