/// مكونات مشتركة لواجهات البيع — منتقي العملة، مدرّج الكمية (وقيمته
/// قابلة للنقر لتحرير رقمي مباشر — R17-a)، محرر الخصم،
/// شارة سعر الصرف التقديري (FR-02-20)، رقائق حالة الدفع، وإيصال النجاح،
/// ومحرر السطر الموحّد (R16-a: كمية/كمية مجانية/سعر/خصم في BottomSheet
/// واحد قابل للتمرير).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../domain/models/sale.dart';
import '../../../../../domain/services/sale_pricing.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/fin_tokens.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
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

/// منتقي عملة الفاتورة — رقائق أفقية (الأساس أولاً) مع سعر اليوم.
class CurrencyPickerRow extends StatelessWidget {
  const CurrencyPickerRow({
    super.key,
    required this.currencies,
    required this.selectedId,
    required this.todayRate,
    required this.onSelect,
  });

  final List<CurrencyOption> currencies;
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
class CurrencyOption {
  const CurrencyOption({
    required this.id,
    required this.code,
    required this.isBase,
    required this.rateKnown,
  });

  final int id;
  final String code;
  final bool isBase;
  final bool rateKnown;
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

  final CurrencyOption option;
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
///
/// **R17-a — كتابة الكمية مباشرة**: عند تمرير [onValueTap] تصبح قيمة
/// الكمية نفسها زراً قابلاً للنقر (فتح المحرر الرقمي السريع «تعديل
/// الكمية» بكتابة 7 أو 2.5 مباشرة) — بخلفية خفيفة وأيقونة قلم صغيرة
/// توحي بالقابلية؛ وبدون المعامل تبقى القيمة نصاً ساكناً كسلوكها
/// القديم حصراً (لا مستخدم آخر حالياً لكن المعامل اختياري للأمان).
class QtyStepper extends StatelessWidget {
  const QtyStepper({
    super.key,
    required this.qty,
    required this.onChanged,
    this.enabled = true,
    this.onValueTap,
  });

  final double qty;
  final ValueChanged<double> onChanged;
  final bool enabled;

  /// R17-a — نقرة قيمة الكمية تفتح تحريراً رقمياً فورياً (null = قيمة
  /// ساكنة غير قابلة للنقر — السلوك القديم).
  final VoidCallback? onValueTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final decimals = qty == qty.truncateToDouble() ? 0 : 3;
    // R17-a: تقليم الأصفار الزائدة (2.500 → 2.5) — صف الكمية ضيق على
    // 390dp وأيقونة القلم تشاركه المساحة؛ العرض الأقصر يسع الجميع.
    var qtyText = AmountText.format(qty, decimals);
    if (decimals > 0 && qtyText.contains('.')) {
      qtyText = qtyText
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
    }
    final value = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(qtyText, style: FinText.amountRow(scheme.onSurface)),
        if (onValueTap != null) ...[
          const SizedBox(width: FinSpacing.xs),
          Icon(Icons.edit_rounded, size: 14, color: scheme.onSurfaceVariant),
        ],
      ],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundStepButton(
          icon: Icons.remove_rounded,
          color: colors.negative,
          onPressed: enabled && qty > 1 ? () => onChanged(qty - 1) : null,
        ),
        if (onValueTap == null)
          Container(
            constraints: const BoxConstraints(minWidth: 52),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: value,
          )
        else
          _QtyValueButton(
            key: const Key('sell_line_qty_value'),
            onTap: enabled ? onValueTap : null,
            child: value,
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

/// هدف نقر قيمة الكمية (R17-a): خلفية خفيفة + نصف قطر تحكم FinRadius +
/// رجل ملموسة ≥ 36 — يميّزها بصرياً عن النص الساكن ويدل على القابلية.
class _QtyValueButton extends StatelessWidget {
  const _QtyValueButton({super.key, required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(FinRadius.control),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 52, minHeight: 36),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: child,
        ),
      ),
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

/// محرر رقم عشري بنافذة سفلية — للسعر/الكمية/الخصم/المبلغ النقدي.
/// R17-a: هو بوابة «تعديل الكمية» الفورية من نقرة قيمة QtyStepper.
Future<double?> showNumberEditSheet(
  BuildContext context, {
  required String title,
  required double initial,
  required String confirmLabel,
  String? hint,
  bool allowZero = true,
  int decimals = 2,
  IconData? icon,
}) => showModalBottomSheet<double>(
  context: context,
  isScrollControlled: true,
  // فوق شريط التبويبات: تُفتح على متصفح الفرع لا الجذر — تنزلق
  // من فوق الشريط السفلي بدل أن تغطيه من أسفل الشاشة.
  useRootNavigator: false,
  builder: (sheetContext) => _NumberEditSheet(
    title: title,
    initial: initial,
    confirmLabel: confirmLabel,
    hint: hint,
    allowZero: allowZero,
    decimals: decimals,
    icon: icon,
  ),
);

/// جسم محرر الرقم — StatefulWidget يملك متحكمه (يُنشأ بـ initState
/// ويُدمَّر بـ dispose): المتحكم يبقى حياً طوال حياة النافذة **بما فيها
/// حركة الخروج** (دماره عند اكتمال مستقبل showModalBottomSheet مبكراً
/// كان يفجر «used after being disposed» بإعادة بناء الحقل أثناء
/// الحركة — نفس علة محرر السطر الموحّد المكتشفة باختبارات R16-a،
/// كشفتها هنا اختبارات R17-a بفتح النافذة من قيمة الكمية).
class _NumberEditSheet extends StatefulWidget {
  const _NumberEditSheet({
    required this.title,
    required this.initial,
    required this.confirmLabel,
    required this.allowZero,
    required this.decimals,
    this.hint,
    this.icon,
  });

  final String title;
  final double initial;
  final String confirmLabel;
  final String? hint;
  final bool allowZero;
  final int decimals;
  final IconData? icon;

  @override
  State<_NumberEditSheet> createState() => _NumberEditSheetState();
}

class _NumberEditSheetState extends State<_NumberEditSheet> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initial == widget.initial.truncateToDouble()
          ? widget.initial.truncate().toString()
          : widget.initial.toStringAsFixed(widget.decimals),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _parse(_controller.text);
    if (value == null || value.isNaN || value.isInfinite) {
      setState(() => _error = 'invalid');
      return;
    }
    if (value < 0 || (!widget.allowZero && value == 0)) {
      setState(() => _error = 'invalid');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: scheme.primary, size: 22),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: false,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,4}')),
              ],
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) =>
                  Navigator.of(context).pop(_parse(_controller.text)),
              decoration: InputDecoration(
                hintText: widget.hint,
                errorText: _error == null ? null : l10n.sellInvalidNumber,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(widget.confirmLabel),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonCancel),
            ),
          ],
        ),
      ),
    );
  }
}

double? _parse(String text) {
  final normalized = text.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

/// نتيجة محرر السطر الموحّد (R16-a): (الكمية، الكمية المجانية، السعر،
/// نوع الخصم، قيمة الخصم) — null عند الإلغاء.
typedef SellLineEditResult = (double, double, double, SaleDiscountType, double);

/// **محرر سطر السلة الموحّد** (R16-a — قرار المالك: إدخال دائم التوفر):
/// BottomSheet يجمع الكمية المدفوعة + **الكمية المجانية (بونص — متاح
/// دائماً هنا بلا أي بوابة إعدادات)** + سعر الوحدة + خصم السطر،
/// والدخول إليه من نقرة على صف السطر.
///
/// **قابلية التمرير (علة قصر الشاشة المؤكدة حياً)**: المحتوى داخل
/// `ListView` بـ `shrinkWrap` مع `isScrollControlled: true` وحشو لوحة
/// المفاتيح (`viewInsets`) — فالحقول السفلية تظل قابلة للوصول على
/// الشاشات القصيرة مهما طال النموذج.
Future<SellLineEditResult?> showSellLineEditSheet(
  BuildContext context, {
  required String title,
  required double initialQty,
  required double initialFreeQty,
  required double initialPrice,
  required SaleDiscountType initialDiscountType,
  required double initialDiscountValue,
}) => showModalBottomSheet<SellLineEditResult>(
  context: context,
  isScrollControlled: true,
  // فوق شريط التبويبات (متصفح الفرع) — نفس قرار بقية نوافذ البيع.
  useRootNavigator: false,
  builder: (sheetContext) => _SellLineEditSheet(
    title: title,
    initialQty: initialQty,
    initialFreeQty: initialFreeQty,
    initialPrice: initialPrice,
    initialDiscountType: initialDiscountType,
    initialDiscountValue: initialDiscountValue,
  ),
);

/// جسم محرر السطر — StatefulWidget يملك متحكماته (تُنشأ بـ initState
/// وتُدمَّر بـ dispose): المتحكمات تبقى حية طوال حياة النافذة **بما فيها
/// حركة الخروج** (دمارها عند اكتمال مستقبل showModalBottomSheet مبكراً
/// كان يفجر «used after being disposed» بإعادة بناء الحقول أثناء
/// الحركة — خلل كشفته اختبارات R16-a).
class _SellLineEditSheet extends StatefulWidget {
  const _SellLineEditSheet({
    required this.title,
    required this.initialQty,
    required this.initialFreeQty,
    required this.initialPrice,
    required this.initialDiscountType,
    required this.initialDiscountValue,
  });

  final String title;
  final double initialQty;
  final double initialFreeQty;
  final double initialPrice;
  final SaleDiscountType initialDiscountType;
  final double initialDiscountValue;

  @override
  State<_SellLineEditSheet> createState() => _SellLineEditSheetState();
}

class _SellLineEditSheetState extends State<_SellLineEditSheet> {
  late final TextEditingController _qtyController;
  late final TextEditingController _bonusController;
  late final TextEditingController _priceController;
  late final TextEditingController _discountController;
  late SaleDiscountType _discountType;
  String? _qtyError;
  String? _bonusError;
  String? _priceError;
  String? _discountError;

  static String _initialText(double value, {int decimals = 3}) =>
      value == value.truncateToDouble()
      ? value.truncate().toString()
      : value.toStringAsFixed(decimals);

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(
      text: _initialText(widget.initialQty),
    );
    _bonusController = TextEditingController(
      text: _initialText(widget.initialFreeQty),
    );
    _priceController = TextEditingController(
      text: _initialText(widget.initialPrice, decimals: 2),
    );
    _discountController = TextEditingController(
      text: widget.initialDiscountValue == 0
          ? ''
          : _initialText(widget.initialDiscountValue),
    );
    _discountType = widget.initialDiscountType;
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _bonusController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: ListView(
          shrinkWrap: true,
          key: const Key('sell_line_edit_sheet'),
          children: [
            Row(
              children: [
                Icon(Icons.edit_note_rounded, color: scheme.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('sell_line_edit_qty_field'),
              controller: _qtyController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: false,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,4}')),
              ],
              onChanged: (_) {
                if (_qtyError != null) setState(() => _qtyError = null);
              },
              decoration: InputDecoration(
                labelText: l10n.sellLineEditQtyLabel,
                errorText: _qtyError,
              ),
            ),
            const SizedBox(height: 12),
            // الكمية المجانية (بونص) — دائم التوفر هنا (R16-a): لا بوابة
            // إعدادات؛ الشارة بالسطر تظهر لاحقاً عند > 0.
            TextField(
              key: const Key('sell_line_edit_bonus_field'),
              controller: _bonusController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: false,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,4}')),
              ],
              onChanged: (_) {
                if (_bonusError != null) setState(() => _bonusError = null);
              },
              decoration: InputDecoration(
                labelText: l10n.sellLineEditBonusLabel,
                prefixIcon: const Icon(Icons.redeem_outlined, size: 20),
                errorText: _bonusError,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('sell_line_edit_price_field'),
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: false,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,4}')),
              ],
              onChanged: (_) {
                if (_priceError != null) setState(() => _priceError = null);
              },
              decoration: InputDecoration(
                labelText: l10n.sellLineEditPriceLabel,
                errorText: _priceError,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.sellLineEditDiscountLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            SegmentedButton<SaleDiscountType>(
              segments: [
                ButtonSegment(
                  value: SaleDiscountType.amount,
                  label: Text(l10n.sellDiscountAmount),
                  icon: const Icon(Icons.sell_outlined),
                ),
                ButtonSegment(
                  value: SaleDiscountType.percent,
                  label: Text(l10n.sellDiscountPercent),
                  icon: const Icon(Icons.percent_rounded),
                ),
              ],
              selected: {_discountType},
              onSelectionChanged: (selection) {
                setState(() => _discountType = selection.first);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('sell_line_edit_discount_field'),
              controller: _discountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) {
                if (_discountError != null) {
                  setState(() => _discountError = null);
                }
              },
              decoration: InputDecoration(
                suffixText: _discountType == SaleDiscountType.percent
                    ? '%'
                    : null,
                errorText: _discountError,
                hintText: _discountType == SaleDiscountType.percent
                    ? l10n.sellDiscountPercentHint
                    : l10n.sellDiscountAmountHint,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('sell_line_edit_save'),
              onPressed: _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(l10n.sellLineEditSave),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonCancel),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final l10n = AppLocalizations.of(context)!;
    final qty = _parse(_qtyController.text);
    if (qty == null || qty.isNaN || qty <= 0) {
      setState(() => _qtyError = l10n.sellLineEditQtyError);
      return;
    }
    final freeQty = _parse(_bonusController.text);
    if (freeQty == null ||
        freeQty.isNaN ||
        freeQty < 0 ||
        ((freeQty * 1000).roundToDouble() - freeQty * 1000).abs() > 0.001) {
      setState(() => _bonusError = l10n.sellLineEditBonusError);
      return;
    }
    final price = _parse(_priceController.text);
    if (price == null || price.isNaN || price < 0) {
      setState(() => _priceError = l10n.sellLineEditPriceError);
      return;
    }
    final rawDiscount = _discountController.text.trim().replaceAll(',', '.');
    final discount = rawDiscount.isEmpty ? 0.0 : double.tryParse(rawDiscount);
    if (discount == null ||
        discount.isNaN ||
        discount < 0 ||
        (_discountType == SaleDiscountType.percent && discount > 100)) {
      setState(
        () => _discountError = _discountType == SaleDiscountType.percent
            ? l10n.sellDiscountPercentError
            : l10n.sellDiscountAmountError,
      );
      return;
    }
    Navigator.of(context).pop((qty, freeQty, price, _discountType, discount));
  }
}

/// محرر خصم (سطر أو رأس) — تبديل نسبة/مبلغ + قيمة، بنتيجة (نوع، قيمة).
Future<(SaleDiscountType, double)?> showDiscountEditSheet(
  BuildContext context, {
  required String title,
  required SaleDiscountType initialType,
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
  final result = await showModalBottomSheet<(SaleDiscountType, double)>(
    context: context,
    isScrollControlled: true,
    // فوق شريط التبويبات (نفس قرار بقية نوافذ الكاشير).
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
                  SegmentedButton<SaleDiscountType>(
                    segments: [
                      ButtonSegment(
                        value: SaleDiscountType.amount,
                        label: Text(l10n.sellDiscountAmount),
                        icon: const Icon(Icons.sell_outlined),
                      ),
                      ButtonSegment(
                        value: SaleDiscountType.percent,
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
                      suffixText: type == SaleDiscountType.percent ? '%' : null,
                      errorText: error,
                      hintText: type == SaleDiscountType.percent
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
                          (type == SaleDiscountType.percent && value > 100)) {
                        setSheetState(
                          () => error = type == SaleDiscountType.percent
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

/// إيصال النجاح بعد الترحيل — INV/الإجمالي/المدفوع/الباقي/المتبقي آجلاً
/// + شارة السعر التقديري عند fallback (FR-02-20) + زرا «طباعة الفاتورة»
/// و«مشاركة/واتساب» الفوريان (P0-2 — يفتحان معاينة PDF للفاتورة
/// المرحّلة؛ يخفيان عند off أو غياب المستدعي).
class PostedReceiptCard extends StatelessWidget {
  const PostedReceiptCard({
    super.key,
    required this.receipt,
    this.currencyCode,
    this.onPrint,
    this.onShare,
  });

  final SalePostedReceipt receipt;
  final String? currencyCode;

  /// فتح معاينة الطباعة (زر الطباعة) — null = إخفاء الزرين.
  final VoidCallback? onPrint;

  /// فتح معاينة المشاركة/واتساب — null = إخفاء الزرين.
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final showPrintActions = onPrint != null && onShare != null;
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
                      l10n.sellReceiptSuccessTitle,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      receipt.invoiceNo,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFeatures: FinText.tabularNums,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              PayStatusChip(method: receipt.payStatus, dense: false),
            ],
          ),
          if (receipt.rateIsFallback) ...[
            const SizedBox(height: 12),
            FallbackRateBadge(dense: false),
          ],
          const SizedBox(height: 14),
          _ReceiptRow(
            label: l10n.sellReceiptTotal,
            value: receipt.totals.grandTotal,
          ),
          _ReceiptRow(
            label: l10n.sellReceiptPaidCash,
            value: receipt.totals.grandTotal - receipt.remainingCredit,
            sign: FinSign.incoming,
          ),
          if (receipt.changeDue > 0)
            _ReceiptRow(
              label: l10n.sellReceiptChangeDue,
              value: receipt.changeDue,
              sign: FinSign.outgoing,
              highlight: colors.warning,
            ),
          if (receipt.remainingCredit > 0)
            _ReceiptRow(
              label: l10n.sellReceiptRemainingCredit,
              value: receipt.remainingCredit,
              sign: FinSign.outgoing,
              highlight: colors.warning,
            ),
          // P0-2: أزرار الطباعة/المشاركة الفورية داخل بطاقة الإيصال —
          // أقصر مسار للطباعة (كان 5-6 خطوات عبر قائمة الفواتير).
          if (showPrintActions) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('sell_receipt_print_button'),
                    onPressed: onPrint,
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: Text(l10n.sellFixPrintInvoice),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('sell_receipt_share_button'),
                    onPressed: onShare,
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: Text(l10n.sellFixShareInvoice),
                  ),
                ),
              ],
            ),
          ],
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

/// نص كمية معروض بأرقام جدولية (المتاح: N).
String sellQtyText(double qty) =>
    AmountText.format(qty, qty == qty.truncateToDouble() ? 0 : 3);

/// خط الإجماليات الحي — المجموع/خصم الأسطر/خصم الرأس/الصافي (§6.5).
class CartTotalsPanel extends StatelessWidget {
  const CartTotalsPanel({
    super.key,
    required this.totals,
    required this.currencyCode,
  });

  final CartTotals totals;
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

/// ينسّق تاريخاً للعرض `يوم/شهر/سنة` بأرقام جدولية بسيطة.
String sellFormatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year}';

/// ينسّق وقتاً 12 ساعة مع ص/م.
String sellFormatTime(DateTime date) {
  final hour = date.hour == 0
      ? 12
      : date.hour > 12
      ? date.hour - 12
      : date.hour;
  final period = date.hour < 12 ? 'ص' : 'م';
  return '${hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')} $period';
}

/// فاصل قيمة تسوية الدفع (للعرض المتكرر في PaymentSheet).
({double netPaid, double changeDue, double remainingCredit}) settlePreview(
  double grandTotal,
  double paidCash,
) {
  final settlement = SalePricing.settlePayment(grandTotal, paidCash);
  return (
    netPaid: settlement.netPaid,
    changeDue: settlement.changeDue,
    remainingCredit: settlement.remainingCredit,
  );
}
