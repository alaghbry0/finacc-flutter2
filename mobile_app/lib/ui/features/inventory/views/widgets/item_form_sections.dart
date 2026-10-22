/// أقسام نموذج الصنف بهوية Simple Invoice Manager (V10): قسم الباركود
/// وصفا الفئة/الوحدة **باقيان كما هما حرفياً** (البادئة توليد EAN-13
/// والمعاينة والقوائم المنسدلة بأزرار الإضافة الفورية وقرار 🟡-13
/// بحواراتها)، بينما انتقل مفتاحا «صنف خدمي» و«تتبع الدفعات» إلى
/// `SimFormSwitchRow` بنفس المفاتيح ونصوص l10n القائمة (سطر مفتاح 48dp
/// بنمط «تمكين جرد المنتج» بالنموذج الأولي). الحالة تُقرأ من المتحكم
/// الذي يملكها الأب المشيد لهذه الأقسام — تحويل بصري فقط.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/sim_form_widgets.dart';
import '../../view_models/item_form_view_model.dart';
import 'inventory_widgets.dart';
import 'item_form_dialogs.dart';

/// قسم الباركود: الحقل + زر التوليد (إنشاء فقط) + المعاينة.
class ItemBarcodeSection extends StatelessWidget {
  const ItemBarcodeSection({
    super.key,
    required this.controller,
    required this.vm,
  });

  final TextEditingController controller;
  final ItemFormViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                key: const Key('item_form_barcode_field'),
                controller: controller,
                onChanged: vm.setBarcode,
                keyboardType: TextInputType.text,
                // الباركود LTR دائماً (§6.2 — أرقام/لاتيني).
                decoration: InputDecoration(
                  labelText: l10n.itemFormBarcodeLabel,
                  hintText: l10n.itemFormBarcodeHint,
                  prefixIcon: const Icon(Icons.qr_code_2_rounded),
                ),
              ),
            ),
            // التوليد في الإنشاء فقط — التعديل لا يولّد من جديد.
            if (!state.editMode) ...[
              const SizedBox(width: 10),
              FilledButton.tonalIcon(
                key: const Key('item_form_generate_btn'),
                onPressed: vm.generateBarcode,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  state.barcode.isEmpty
                      ? l10n.itemFormBarcodeGenerate
                      : l10n.itemFormBarcodeRegenerate,
                ),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              ),
            ],
          ],
        ),
        if (state.barcode.isNotEmpty) ...[
          const SizedBox(height: 12),
          FinCard(
            padding: const EdgeInsets.all(14),
            child: BarcodePreview(code: state.barcode, name: state.name),
          ),
        ],
      ],
    );
  }
}

/// صف الفئة: قائمة منسدلة + زر إضافة فورية.
class ItemCategoryRow extends StatelessWidget {
  const ItemCategoryRow({super.key, required this.vm});

  final ItemFormViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int?>(
            key: Key('item_form_category_${state.categoryId}'),
            initialValue: state.categoryId,
            onChanged: vm.setCategory,
            decoration: InputDecoration(
              labelText: l10n.itemFormCategoryLabel,
              prefixIcon: const Icon(Icons.category_rounded),
            ),
            items: [
              DropdownMenuItem<int?>(child: Text(l10n.itemFormCategoryNone)),
              for (final category in state.categories)
                DropdownMenuItem<int?>(
                  value: category.id,
                  child: Text(category.name),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        IconButton.outlined(
          tooltip: l10n.itemFormCategoryAdd,
          icon: const Icon(Icons.add_rounded),
          onPressed: () => unawaited(openAddCategoryDialog(context, l10n, vm)),
          style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
        ),
      ],
    );
  }
}

/// صف الوحدة: قائمة منسدلة + زر إضافة فورية.
class ItemUnitRow extends StatelessWidget {
  const ItemUnitRow({super.key, required this.vm});

  final ItemFormViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int?>(
            key: Key('item_form_unit_${state.unitId}'),
            initialValue: state.unitId,
            onChanged: vm.setUnit,
            decoration: InputDecoration(
              labelText: l10n.itemFormUnitLabel,
              prefixIcon: const Icon(Icons.straighten_rounded),
            ),
            items: [
              DropdownMenuItem<int?>(child: Text(l10n.itemFormUnitNone)),
              for (final unit in state.units)
                DropdownMenuItem<int?>(value: unit.id, child: Text(unit.name)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        IconButton.outlined(
          tooltip: l10n.itemFormUnitAdd,
          icon: const Icon(Icons.add_rounded),
          onPressed: () => unawaited(openAddUnitDialog(context, l10n, vm)),
          style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
        ),
      ],
    );
  }
}

/// مفتاح الصنف الخدمي (FR-01-16) — بلا مخزون ولا كميات؛ سطر مفتاح SIM
/// بنفس نصي l10n القائمين (التسمية والوصف).
class ItemServiceSwitch extends StatelessWidget {
  const ItemServiceSwitch({super.key, required this.vm});

  final ItemFormViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    return SimFormSwitchRow(
      key: const Key('item_form_service_switch'),
      label: l10n.itemFormServiceLabel,
      description: l10n.itemFormServiceDesc,
      value: state.isService,
      onChanged: vm.setIsService,
    );
  }
}

/// مفتاح تتبع الدفعات — للصنف غير الخدمي حصراً؛ سطر مفتاح SIM بنفس
/// نصي l10n القائمين.
class ItemTrackBatchesSwitch extends StatelessWidget {
  const ItemTrackBatchesSwitch({super.key, required this.vm});

  final ItemFormViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    return SimFormSwitchRow(
      key: const Key('item_form_batches_switch'),
      label: l10n.itemFormTrackBatchesLabel,
      description: l10n.itemFormTrackBatchesDesc,
      value: state.trackBatches,
      onChanged: vm.setTrackBatches,
    );
  }
}
