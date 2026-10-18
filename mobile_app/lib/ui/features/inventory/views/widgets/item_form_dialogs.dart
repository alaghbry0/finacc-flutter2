/// حوارات الإضافة الفورية (فئة/وحدة) بنموذج الصنف — مستخرجة من
/// item_form_screen (R19-D3b: نقل حرفي بلا أي تغيير سلوكي).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../view_models/item_form_view_model.dart';

Future<void> openAddCategoryDialog(
  BuildContext context,
  AppLocalizations l10n,
  ItemFormViewModel vm,
) async {
  final controller = TextEditingController();
  var errorText = '';
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(l10n.categoryNameLabel),
        // R16-b — جسم الحوار قابل للتمرير (scrollable): لا ينفيض ولا
        // تحتجب حقوله خلف لوحة المفاتيح على الشاشات القصيرة.
        scrollable: true,
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
              final error = await vm.addCategory(name);
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

Future<void> openAddUnitDialog(
  BuildContext context,
  AppLocalizations l10n,
  ItemFormViewModel vm,
) async {
  final nameController = TextEditingController();
  final factorController = TextEditingController(text: '1');
  var errorText = '';
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(l10n.unitNameLabel),
        // R16-b — نفس علاج حوار الفئة: جسم قابل للتمرير.
        scrollable: true,
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
