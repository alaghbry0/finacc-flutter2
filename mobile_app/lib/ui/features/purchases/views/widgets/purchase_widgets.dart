/// مكونات مشتركة لواجهات الشراء — رقائق حالة الدفع (نقدي/آجل/مختلط
/// باتجاه الشراء)، منتقي العملة، مدرّج الكمية، محرر الخصم والمحرر الرقمي،
/// شارة سعر الصرف التقديري (FR-02-20)، خط الإجماليات، وإيصال نجاح الشراء.
///
/// مرآة `sell_widgets.dart` (النمط المرجعي) باتجاه الشراء — بلا أي استيراد
/// بين الوحدتين (feature-first: لكل ميزة أدواتها).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../domain/models/company.dart';
import '../../../../../domain/models/purchase.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
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

/// منتقي عملة فاتورة الشراء — رقائق أفقية (الأساس أولاً) مع سعر اليوم.
class PurchaseCurrencyPickerRow extends StatelessWidget {
  const PurchaseCurrencyPickerRow({
    super.key,
    required this.currencies,
    required this.selectedId,
    required this.todayRate,
    required this.onSelect,
  });

  final List<PurchaseCurrencyOption> currencies;
  final int? selectedId;
  final double? todayRate;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < currencies.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _CurrencyChip(
              option: currencies[i],
              selected: currencies[i].id == selectedId,
              rate: currencies[i].id == selectedId ? todayRate : null,
              baseLabel: l10n.sellCurrencyBaseTag,
              missingLabel: l10n.sellCurrencyNoRate,
              onTap: () => onSelect(currencies[i].id),
            ),
          ],
        ],
      ),
    );
  }
}

/// خيار عملة للمنتقي.
class PurchaseCurrencyOption {
  const PurchaseCurrencyOption({
    required this.id,
    required this.code,
    required this.isBase,
    required this.rateKnown,
  });

  final int id;
  final String code;
  final bool isBase;
  final bool rateKnown;

  factory PurchaseCurrencyOption.fromCurrency(
    Currency currency, {
    required bool rateKnown,
  }) => PurchaseCurrencyOption(
    id: currency.id,
    code: currency.code,
    isBase: currency.isBase,
    rateKnown: rateKnown,
  );
}

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({
    required this.option,
    required this.selected,
    required this.rate,
    required this.baseLabel,
    required this.missingLabel,
    required this.onTap,
  });

  final PurchaseCurrencyOption option;
  final bool selected;
  final double? rate;
  final String baseLabel;
  final String missingLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final borderColor = !option.isBase && !option.rateKnown
        ? colors.warning.withValues(alpha: 0.8)
        : selected
        ? scheme.primary.withValues(alpha: 0.55)
        : scheme.outlineVariant.withValues(alpha: 0.5);
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: selected ? 1.4 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(
                option.code,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                ),
              ),
              if (option.isBase) ...[
                const SizedBox(width: 6),
                Text(
                  baseLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ] else if (rate != null && rate! > 0) ...[
                const SizedBox(width: 6),
                Text(
                  AmountText.format(rate!, 4),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontFeatures: FinText.tabularNums,
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ] else if (selected && !option.rateKnown) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: colors.warning,
                ),
                const SizedBox(width: 3),
                Text(
                  missingLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.warning,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// مدرّج الكمية — أزرار ± بأهداف لمس ≥ 48 (DS-29) وقيمة بأرقام جدولية.
class PurchaseQtyStepper extends StatelessWidget {
  const PurchaseQtyStepper({
    super.key,
    required this.qty,
    required this.onChanged,
    this.enabled = true,
    this.min = 1,
  });

  final double qty;
  final ValueChanged<double> onChanged;
  final bool enabled;

  /// الحد الأدنى (1 في السلة، 0 في المرتجع).
  final double min;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final decimals = qty == qty.truncateToDouble() ? 0 : 3;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundStepButton(
          icon: Icons.remove_rounded,
          color: colors.negative,
          onPressed: enabled && qty > min ? () => onChanged(qty - 1) : null,
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 52),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            AmountText.format(qty, decimals),
            style: FinText.amountRow(scheme.onSurface),
          ),
        ),
        _RoundStepButton(
          icon: Icons.add_rounded,
          color: colors.positive,
          onPressed: enabled ? () => onChanged(qty + 1) : null,
        ),
      ],
    );
  }
}

class _RoundStepButton extends StatelessWidget {
  const _RoundStepButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

/// محرر رقم عشري بنافذة سفلية — للتكلفة/الكمية/الخصم/المبلغ النقدي.
Future<double?> showPurchaseNumberEditSheet(
  BuildContext context, {
  required String title,
  required double initial,
  required String confirmLabel,
  String? hint,
  bool allowZero = true,
  int decimals = 2,
  IconData? icon,
}) {
  final controller = TextEditingController(
    text: initial == initial.truncateToDouble()
        ? initial.truncate().toString()
        : initial.toStringAsFixed(decimals),
  );
  String? error;
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    // فوق شريط التبويبات (متصفح الفرع) — لا من أسفل الشاشة خلفه.
    useRootNavigator: false,
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext)!;
      final scheme = Theme.of(sheetContext).colorScheme;
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: scheme.primary, size: 22),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(sheetContext).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: false,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*[\.,]?\d{0,4}'),
                      ),
                    ],
                    onChanged: (_) {
                      if (error != null) {
                        setSheetState(() => error = null);
                      }
                    },
                    onSubmitted: (_) =>
                        Navigator.of(sheetContext).pop(_parse(controller.text)),
                    decoration: InputDecoration(
                      hintText: hint,
                      errorText: error == null ? null : l10n.sellInvalidNumber,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () {
                      final value = _parse(controller.text);
                      if (value == null || value.isNaN || value.isInfinite) {
                        setSheetState(() => error = 'invalid');
                        return;
                      }
                      if (value < 0 || (!allowZero && value == 0)) {
                        setSheetState(() => error = 'invalid');
                        return;
                      }
                      Navigator.of(sheetContext).pop(value);
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(confirmLabel),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: Text(l10n.commonCancel),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  ).whenComplete(controller.dispose);
}

double? _parse(String text) {
  final normalized = text.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

/// محرر خصم شراء (سطر أو رأس) — تبديل نسبة/مبلغ + قيمة.
Future<(PurchaseDiscountType, double)?> showPurchaseDiscountEditSheet(
  BuildContext context, {
  required String title,
  required PurchaseDiscountType initialType,
  required double initialValue,
}) async {
  var type = initialType;
  final controller = TextEditingController(
    text: initialValue == 0
        ? ''
        : initialValue == initialValue.truncateToDouble()
        ? initialValue.truncate().toString()
        : initialValue.toString(),
  );
  String? error;
  final result = await showModalBottomSheet<(PurchaseDiscountType, double)>(
    context: context,
    isScrollControlled: true,
    // فوق شريط التبويبات (نفس قرار بقية نوافذ الوحدة).
    useRootNavigator: false,
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext)!;
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<PurchaseDiscountType>(
                    segments: [
                      ButtonSegment(
                        value: PurchaseDiscountType.amount,
                        label: Text(l10n.sellDiscountAmount),
                        icon: const Icon(Icons.sell_outlined),
                      ),
                      ButtonSegment(
                        value: PurchaseDiscountType.percent,
                        label: Text(l10n.sellDiscountPercent),
                        icon: const Icon(Icons.percent_rounded),
                      ),
                    ],
                    selected: {type},
                    onSelectionChanged: (selection) {
                      setSheetState(() => type = selection.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) {
                      if (error != null) {
                        setSheetState(() => error = null);
                      }
                    },
                    decoration: InputDecoration(
                      suffixText: type == PurchaseDiscountType.percent
                          ? '%'
                          : null,
                      errorText: error,
                      hintText: type == PurchaseDiscountType.percent
                          ? l10n.sellDiscountPercentHint
                          : l10n.sellDiscountAmountHint,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () {
                      final raw = controller.text.trim().replaceAll(',', '.');
                      final value = raw.isEmpty ? 0.0 : double.tryParse(raw);
                      if (value == null ||
                          value.isNaN ||
                          value < 0 ||
                          (type == PurchaseDiscountType.percent &&
                              value > 100)) {
                        setSheetState(
                          () => error = type == PurchaseDiscountType.percent
                              ? l10n.sellDiscountPercentError
                              : l10n.sellDiscountAmountError,
                        );
                        return;
                      }
                      Navigator.of(sheetContext).pop((type, value));
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(l10n.sellDiscountApply),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: Text(l10n.commonCancel),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
  controller.dispose();
  return result;
}

/// إيصال نجاح ترحيل فاتورة الشراء — PUR/الإجمالي/المدفوع/المتبقي آجلاً
/// + شارة السعر التقديري عند fallback (FR-02-20).
class PostedPurchaseReceiptCard extends StatelessWidget {
  const PostedPurchaseReceiptCard({
    super.key,
    required this.receipt,
    this.currencyCode,
  });

  final PurchasePostedReceipt receipt;
  final String? currencyCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    return FinCard(
      accent: colors.positive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.positiveContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: colors.onPositiveContainer,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.purReceiptSuccessTitle,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      receipt.docNo,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFeatures: FinText.tabularNums,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              PurchasePayStatusChip(method: receipt.payStatus, dense: false),
            ],
          ),
          if (receipt.rateIsFallback) ...[
            const SizedBox(height: 12),
            const PurchaseFallbackRateBadge(dense: false),
          ],
          const SizedBox(height: 14),
          _ReceiptRow(
            label: l10n.sellReceiptTotal,
            value: receipt.totals.grandTotal,
          ),
          _ReceiptRow(
            label: l10n.sellReceiptPaidCash,
            value: receipt.totals.grandTotal - receipt.remainingCredit,
            sign: FinSign.outgoing,
          ),
          if (receipt.remainingCredit > 0)
            _ReceiptRow(
              label: l10n.purReceiptSupplierCredit,
              value: receipt.remainingCredit,
              sign: FinSign.outgoing,
              highlight: colors.warning,
            ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.sign = FinSign.neutral,
    this.highlight,
  });

  final String label;
  final double value;
  final FinSign sign;
  final Color? highlight;

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
          AmountText(
            amount: value,
            sign: sign,
            decimals: value == value.truncateToDouble() ? 0 : 2,
          ),
        ],
      ),
    );
  }
}

/// خط الإجماليات الحي لفاتورة الشراء — المجموع/خصومات البنود/خصم الرأس/
/// الصافي المستحق للمورد.
class PurchaseTotalsPanel extends StatelessWidget {
  const PurchaseTotalsPanel({
    super.key,
    required this.totals,
    required this.currencyCode,
  });

  final PurchaseTotals totals;
  final String? currencyCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final decimals = totals.grandTotal == totals.grandTotal.truncateToDouble()
        ? 0
        : 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TotalsRow(
          label: l10n.sellTotalsSubtotal,
          value: totals.subtotal,
          decimals: decimals,
        ),
        if (totals.lineDiscountsTotal > 0)
          _TotalsRow(
            label: l10n.sellTotalsLineDiscounts,
            value: totals.lineDiscountsTotal,
            decimals: decimals,
            color: colors.negative,
            sign: FinSign.outgoing,
          ),
        if (totals.invoiceDiscount > 0)
          _TotalsRow(
            label: l10n.sellTotalsInvoiceDiscount,
            value: totals.invoiceDiscount,
            decimals: decimals,
            color: colors.negative,
            sign: FinSign.outgoing,
          ),
        Divider(
          height: 18,
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.sellTotalsGrandTotal,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            AmountText(
              amount: totals.grandTotal,
              size: AmountSize.large,
              decimals: decimals,
            ),
          ],
        ),
      ],
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({
    required this.label,
    required this.value,
    required this.decimals,
    this.color,
    this.sign = FinSign.neutral,
  });

  final String label;
  final double value;
  final int decimals;
  final Color? color;
  final FinSign sign;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          AmountText(amount: value, sign: sign, decimals: decimals),
        ],
      ),
    );
  }
}

/// نص كمية معروض بأرقام جدولية (المتاح: N).
String purQtyText(double qty) =>
    AmountText.format(qty, qty == qty.truncateToDouble() ? 0 : 3);

/// ينسّق تاريخاً للعرض `يوم/شهر/سنة` بأرقام جدولية بسيطة.
String purFormatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year}';

/// ينسّق تاريخ صلاحية `سنة-شهر-يوم` (صيغة الدفعات بالقاعدة).
String purFormatIsoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// ينسّق وقتاً 12 ساعة مع ص/م.
String purFormatTime(DateTime date) {
  final hour = date.hour == 0
      ? 12
      : date.hour > 12
      ? date.hour - 12
      : date.hour;
  final period = date.hour < 12 ? 'ص' : 'م';
  return '${hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')} $period';
}
