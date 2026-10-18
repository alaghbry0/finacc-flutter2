/// حقول نموذج الصنف (اسم/تكلفة/حد أدنى/افتتاحية/أسعار/ملاحظات) + زر
/// الحفظ ولافتة خطأ التحقق — مستخرجة من item_form_screen (R19-D3b: نقل
/// حرفي بلا أي تغيير سلوكي؛ المتحكمات يملكها الأب المشيد للحقول).
library;

import 'package:flutter/material.dart';

import '../../../../../domain/models/company.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../view_models/item_form_view_model.dart';

class ItemNameField extends StatelessWidget {
  const ItemNameField({super.key, required this.controller, required this.vm});

  final TextEditingController controller;
  final ItemFormViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TextFormField(
      key: const Key('item_form_name_field'),
      controller: controller,
      onChanged: vm.setName,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: l10n.itemFormNameLabel,
        hintText: l10n.itemFormNameHint,
        prefixIcon: const Icon(Icons.inventory_2_rounded),
      ),
      validator: (value) =>
          (value ?? '').trim().isEmpty ? l10n.itemFormNameRequired : null,
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
    return TextFormField(
      key: const Key('item_form_cost_field'),
      controller: controller,
      onChanged: vm.setCostText,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: l10n.itemFormCostLabel,
        prefixIcon: const Icon(Icons.payments_rounded),
      ),
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
    return TextFormField(
      key: const Key('item_form_min_stock_field'),
      controller: controller,
      onChanged: vm.setMinStockText,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: l10n.itemFormMinStockLabel,
        hintText: l10n.itemFormMinStockHint,
        prefixIcon: const Icon(Icons.low_priority_rounded),
      ),
      validator: (value) {
        final text = (value ?? '').trim();
        if (text.isEmpty) return null;
        final parsed = double.tryParse(text);
        if (parsed == null || parsed < 0) return l10n.itemFormMinStockInvalid;
        return null;
      },
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
    return TextFormField(
      key: const Key('item_form_opening_qty_field'),
      controller: controller,
      onChanged: vm.setOpeningQtyText,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: l10n.itemFormOpeningQtyLabel,
        hintText: l10n.itemFormOpeningQtyHint,
        prefixIcon: const Icon(Icons.inventory_rounded),
      ),
      validator: (value) {
        final text = (value ?? '').trim();
        if (text.isEmpty) return null;
        final parsed = double.tryParse(text);
        if (parsed == null || parsed < 0) {
          return l10n.itemFormOpeningQtyInvalid;
        }
        return null;
      },
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
    return TextFormField(
      key: Key('item_form_price_field_${currency.code}'),
      controller: controller,
      onChanged: (value) => vm.setPriceText(currency.id, value),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: l10n.itemFormPriceLabel(currency.name),
        prefixIcon: const Icon(Icons.sell_outlined),
        suffixText: currency.code,
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
    return TextFormField(
      key: const Key('item_form_notes_field'),
      controller: controller,
      onChanged: vm.setNotes,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: l10n.itemFormNotesLabel,
        hintText: l10n.itemFormNotesHint,
        prefixIcon: const Icon(Icons.notes_rounded),
      ),
    );
  }
}

class ItemSaveButton extends StatelessWidget {
  const ItemSaveButton({
    super.key,
    required this.saving,
    required this.onPressed,
  });

  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FilledButton(
      key: const Key('item_form_save_btn'),
      onPressed: saving ? null : onPressed,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      child: saving
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(l10n.itemFormSaving),
              ],
            )
          : Text(l10n.itemFormSave),
    );
  }
}

/// لافتة خطأ التحقق فوق زر الحفظ.
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
