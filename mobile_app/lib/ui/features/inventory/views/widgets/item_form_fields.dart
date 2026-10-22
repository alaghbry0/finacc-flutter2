/// حقول نموذج الصنف بهوية Simple Invoice Manager (V10): الاسم/التكلفة/
/// أسعار العملات/الملاحظات حقول سطور `.input-line`، والحد الأدنى/الكمية
/// الافتتاحية صندوقا `.input-box` — عدة `sim_form_widgets` الجاهزة.
/// المتحكمات يملكها الأب المشيد للحقول، والمنطق (onChanged/validator)
/// منقول حرفياً من حقول FinAcc القديمة — تحويل بصري فقط. لافتة خطأ
/// التحقق (R16-b) باقية كما هي؛ زر الحفظ انتقل إلى `SimFormSaveBar`
/// الثابت أسفل الشاشة في item_form_screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../domain/models/company.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sim_form_widgets.dart';
import '../../view_models/item_form_view_model.dart';

/// 🟡-12 (نقد V10) — تصفية الحقول الرقمية: أرقام غربية + فاصلة عشرية
/// فقط، مع كيبورد `numberWithOptions(decimal: true)` القائم نفسه
/// (نمط ItemCostField القائم).
final List<TextInputFormatter> decimalDigitsOnly = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
];

/// تلميح تفسيري صغير تحت الحقل — يحفظ نصوص l10n الإرشادية القائمة
/// (12sp رمادي) بنمط توأم الجولة party_form_fields.
class _FieldHint extends StatelessWidget {
  const _FieldHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class ItemNameField extends StatelessWidget {
  const ItemNameField({super.key, required this.controller, required this.vm});

  final TextEditingController controller;
  final ItemFormViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // نمط «اسم المنتج *» بالنموذج الأولي (modal-product-edit) — تلميح
    // سطري بنجمة الإلزام + التلميح الإرشادي القائم تحته.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SimFormLineField(
          fieldKey: const Key('item_form_name_field'),
          hint: l10n.itemFormNameLabel,
          required: true,
          controller: controller,
          onChanged: vm.setName,
          validator: (value) =>
              (value ?? '').trim().isEmpty ? l10n.itemFormNameRequired : null,
        ),
        _FieldHint(l10n.itemFormNameHint),
      ],
    );
  }
}

class ItemCostField extends StatelessWidget {
  const ItemCostField({super.key, required this.controller, required this.vm});

  final TextEditingController controller;
  final ItemFormViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SimFormLineField(
      fieldKey: const Key('item_form_cost_field'),
      hint: l10n.itemFormCostLabel,
      controller: controller,
      onChanged: vm.setCostText,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: decimalDigitsOnly,
      validator: (value) {
        final text = (value ?? '').trim();
        final parsed = double.tryParse(text);
        if (text.isEmpty || parsed == null || parsed < 0) {
          return l10n.itemFormCostInvalid;
        }
        return null;
      },
    );
  }
}

class ItemMinStockField extends StatelessWidget {
  const ItemMinStockField({
    super.key,
    required this.controller,
    required this.vm,
  });

  final TextEditingController controller;
  final ItemFormViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SimFormBoxField(
          fieldKey: const Key('item_form_min_stock_field'),
          hint: l10n.itemFormMinStockLabel,
          controller: controller,
          onChanged: vm.setMinStockText,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: decimalDigitsOnly,
          validator: (value) {
            final text = (value ?? '').trim();
            if (text.isEmpty) return null;
            final parsed = double.tryParse(text);
            if (parsed == null || parsed < 0) {
              return l10n.itemFormMinStockInvalid;
            }
            return null;
          },
        ),
        _FieldHint(l10n.itemFormMinStockHint),
      ],
    );
  }
}

class ItemOpeningQtyField extends StatelessWidget {
  const ItemOpeningQtyField({
    super.key,
    required this.controller,
    required this.vm,
  });

  final TextEditingController controller;
  final ItemFormViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SimFormBoxField(
          fieldKey: const Key('item_form_opening_qty_field'),
          hint: l10n.itemFormOpeningQtyLabel,
          controller: controller,
          onChanged: vm.setOpeningQtyText,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: decimalDigitsOnly,
          validator: (value) {
            final text = (value ?? '').trim();
            if (text.isEmpty) return null;
            final parsed = double.tryParse(text);
            if (parsed == null || parsed < 0) {
              return l10n.itemFormOpeningQtyInvalid;
            }
            return null;
          },
        ),
        _FieldHint(l10n.itemFormOpeningQtyHint),
      ],
    );
  }
}

class ItemPriceField extends StatelessWidget {
  const ItemPriceField({
    super.key,
    required this.controller,
    required this.vm,
    required this.currency,
  });

  final TextEditingController controller;
  final ItemFormViewModel vm;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // المتحكم والوظيفة (خريطة أسعار العملات) كما هما — اللاحقة ترمز
    // عملة السعر بدل suffixText القديم (بصري فقط).
    return SimFormLineField(
      fieldKey: Key('item_form_price_field_${currency.code}'),
      hint: l10n.itemFormPriceLabel(currency.name),
      controller: controller,
      onChanged: (value) => vm.setPriceText(currency.id, value),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: decimalDigitsOnly,
      suffix: Padding(
        padding: const EdgeInsetsDirectional.only(start: 6),
        child: Text(
          currency.code,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      validator: (value) {
        final text = (value ?? '').trim();
        if (text.isEmpty) return null;
        final parsed = double.tryParse(text);
        if (parsed == null || parsed < 0) return l10n.itemFormPriceInvalid;
        return null;
      },
    );
  }
}

class ItemNotesField extends StatelessWidget {
  const ItemNotesField({super.key, required this.controller, required this.vm});

  final TextEditingController controller;
  final ItemFormViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SimFormLineField(
          fieldKey: const Key('item_form_notes_field'),
          hint: l10n.itemFormNotesLabel,
          controller: controller,
          onChanged: vm.setNotes,
          maxLines: 3,
        ),
        _FieldHint(l10n.itemFormNotesHint),
      ],
    );
  }
}

/// لافتة خطأ التحقق فوق شريط الحفظ (R16-b — بلا أي تعديل).
class ItemFormValidationErrorBanner extends StatelessWidget {
  const ItemFormValidationErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = FinColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.negativeContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: colors.onNegativeContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onNegativeContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
