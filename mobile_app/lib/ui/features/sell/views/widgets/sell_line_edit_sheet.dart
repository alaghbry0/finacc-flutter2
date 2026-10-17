/// **محرر سطر السلة الموحّد** (R16-a — قرار المالك: إدخال دائم التوفر):
/// BottomSheet يجمع الكمية المدفوعة + **الكمية المجانية (بونص — متاح
/// دائماً هنا بلا أي بوابة إعدادات)** + سعر الوحدة + خصم السطر،
/// والدخول إليه من نقرة على صف السطر.
///
/// **قابلية التمرير (علة قصر الشاشة المؤكدة حياً)**: المحتوى داخل
/// `ListView` بـ `shrinkWrap` مع `isScrollControlled: true` وحشو لوحة
/// المفاتيح (`viewInsets`) — فالحقول السفلية تظل قابلة للوصول على
/// الشاشات القصيرة مهما طال النموذج.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../domain/models/sale.dart';
import '../../../../../l10n/app_localizations.dart';
import 'sell_format.dart';

/// نتيجة محرر السطر الموحّد (R16-a): (الكمية، الكمية المجانية، السعر،
/// نوع الخصم، قيمة الخصم) — null عند الإلغاء.
typedef SellLineEditResult = (double, double, double, SaleDiscountType, double);

/// **محرر سطر السلة الموحّد** (R16-a): يفتح النافذة ويعيد النتيجة —
/// null عند الإلغاء.
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
    final qty = parseSheetNumber(_qtyController.text);
    if (qty == null || qty.isNaN || qty <= 0) {
      setState(() => _qtyError = l10n.sellLineEditQtyError);
      return;
    }
    final freeQty = parseSheetNumber(_bonusController.text);
    if (freeQty == null ||
        freeQty.isNaN ||
        freeQty < 0 ||
        ((freeQty * 1000).roundToDouble() - freeQty * 1000).abs() > 0.001) {
      setState(() => _bonusError = l10n.sellLineEditBonusError);
      return;
    }
    final price = parseSheetNumber(_priceController.text);
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
