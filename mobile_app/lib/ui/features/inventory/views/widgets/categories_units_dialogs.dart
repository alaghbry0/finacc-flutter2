/// حوارات الإضافة الفورية (فئة/وحدة) بشاشة «الفئات والوحدات» —
/// مستخرجة من categories_units_screen (R20-D3c: نقل حرفي بلا أي تغيير
/// سلوكي؛ بادئة الميزة تميّزها عن حوارَي نموذج الصنف المماثلين بـ
/// item_form_dialogs — مرآة موثقة بقرار R20-D2 لا تُوحَّد).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../view_models/categories_units_view_model.dart';

Future<void> openCategoriesUnitsAddCategoryDialog(
  BuildContext context,
  CategoriesUnitsViewModel vm,
  AppLocalizations l10n,
) async {
  final controller = TextEditingController();
  final roots = vm.state.roots;
  int? parentId;
  var errorText = '';
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(l10n.categoriesAdd),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.categoryNameLabel,
                errorText: errorText.isEmpty ? null : errorText,
              ),
            ),
            if (roots.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                key: ValueKey('cat_parent_$parentId'),
                initialValue: parentId,
                onChanged: (value) => setDialogState(() => parentId = value),
                decoration: InputDecoration(
                  labelText: l10n.categoryParentLabel,
                ),
                items: [
                  DropdownMenuItem<int?>(child: Text(l10n.categoryParentNone)),
                  for (final root in roots)
                    DropdownMenuItem<int?>(
                      value: root.id,
                      child: Text(root.name),
                    ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) {
                setDialogState(() => errorText = l10n.categoryNameLabel);
                return;
              }
              final error = await vm.addCategory(name, parentId: parentId);
              if (!dialogContext.mounted) return;
              if (error != null) {
                setDialogState(() => errorText = error);
                return;
              }
              Navigator.of(dialogContext).pop();
            },
            child: Text(l10n.commonAdd),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
}

Future<void> openCategoriesUnitsAddUnitDialog(
  BuildContext context,
  CategoriesUnitsViewModel vm,
  AppLocalizations l10n,
) async {
  final nameController = TextEditingController();
  final factorController = TextEditingController(text: '1');
  var errorText = '';
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(l10n.unitsAdd),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.unitNameLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: factorController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.unitFactorLabel,
                hintText: l10n.unitFactorHint,
                errorText: errorText.isEmpty ? null : errorText,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final factor = double.tryParse(factorController.text.trim());
              if (name.isEmpty) {
                setDialogState(() => errorText = l10n.unitNameLabel);
                return;
              }
              if (factor == null || factor <= 0) {
                setDialogState(() => errorText = l10n.unitFactorInvalid);
                return;
              }
              final error = await vm.addUnit(name, factor: factor);
              if (!dialogContext.mounted) return;
              if (error != null) {
                setDialogState(() => errorText = error);
                return;
              }
              Navigator.of(dialogContext).pop();
            },
            child: Text(l10n.commonAdd),
          ),
        ],
      ),
    ),
  );
  nameController.dispose();
  factorController.dispose();
}
