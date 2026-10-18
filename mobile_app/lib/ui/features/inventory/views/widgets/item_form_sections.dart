/// أقسام نموذج الصنف: الباركود/الفئة/الوحدة/مفتاحا الخدمي والدفعات —
/// مستخرجة من item_form_screen (R19-D3b: نقل حرفي بلا أي تغيير سلوكي؛
/// الحالة تُقرأ من المتحكم الذي يملكها الأب المشيد لهذه الأقسام).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fin_card.dart';
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

/// مفتاح الصنف الخدمي (FR-01-16) — بلا مخزون ولا كميات.
class ItemServiceSwitch extends StatelessWidget {
  const ItemServiceSwitch({super.key, required this.vm});

  final ItemFormViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    return FinCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Material(
        // ListTile فوق بطاقة مزيّنة — يلزمه Material خاص كي لا تُبتلع
        // خلفيته وموج الحبر داخل DecoratedBox البطاقة.
        color: Colors.transparent,
        child: SwitchListTile(
          key: const Key('item_form_service_switch'),
          value: state.isService,
          onChanged: vm.setIsService,
          title: Text(
            l10n.itemFormServiceLabel,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            l10n.itemFormServiceDesc,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          secondary: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiary
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.miscellaneous_services_rounded,
              color: Theme.of(context).colorScheme.tertiary,
            ),
          ),
        ),
      ),
    );
  }
}

/// مفتاح تتبع الدفعات — للصنف غير الخدمي حصراً.
class ItemTrackBatchesSwitch extends StatelessWidget {
  const ItemTrackBatchesSwitch({super.key, required this.vm});

  final ItemFormViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    final colors = FinColors.of(context);
    return FinCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Material(
        // نفس علاج المفتاح الأول — Material شفاف فوق بطاقة مزيّنة.
        color: Colors.transparent,
        child: SwitchListTile(
          key: const Key('item_form_batches_switch'),
          value: state.trackBatches,
          onChanged: vm.setTrackBatches,
          title: Text(
            l10n.itemFormTrackBatchesLabel,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            l10n.itemFormTrackBatchesDesc,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          secondary: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.layers_rounded, color: colors.warning),
          ),
        ),
      ),
    );
  }
}
