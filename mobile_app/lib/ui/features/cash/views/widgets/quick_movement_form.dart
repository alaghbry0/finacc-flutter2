/// نموذج الحركة السريعة (FR-04-02): رقائق النوع الست + المبلغ + صناديق
/// المصدر/الهدف + فئة المصروف + التاريخ + الوصف — مستخرج حرفياً من
/// `quick_movement_sheet.dart` (R20-D3d؛ كان جسم `_buildForm` بعد
/// الحرّاس) بنمط payment_pay_form: المتحكمات ملك حالة النافذة الأم
/// تمرَّر معاملات، والمنطق (بوابات الأسعار/التحقق/الترحيل) بقي عندها.
library;

import 'package:flutter/material.dart';

import '../../../../../domain/models/cash.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/fin_error_card.dart';
import '../../view_models/quick_movement_view_model.dart';
import 'cash_widgets.dart';
import 'quick_movement_preview.dart';

/// نموذج حركة سريعة واحد يبدّل حقوله حسب النوع (فئة إلزامية للمصروف
/// حصراً + صندوق هدف للأنواع ذات الساقين).
class QuickMovementForm extends StatelessWidget {
  const QuickMovementForm({
    super.key,
    required this.vm,
    required this.amountController,
    required this.descriptionController,
    required this.projected,
    required this.willGoNegative,
    required this.onPickDate,
    required this.onSave,
  });

  final QuickMovementViewModel vm;

  /// متحكم المبلغ — ملك حالة النافذة الأم (يُصفَّر عند «حركة جديدة»).
  final TextEditingController amountController;

  /// متحكم الوصف — ملك حالة النافذة الأم (يُصفَّر عند «حركة جديدة»).
  final TextEditingController descriptionController;

  /// رصيد المصدر بعد الحركة (بإشارة الدفتر) — null قبل اكتمال المدخلات.
  final double? projected;

  /// تحذير بصري عند رصيد متوقع سالب (FR-04-09 — تحذير بلا منع).
  final bool willGoNegative;

  /// يفتح منتقي التاريخ (يعيّن النتيجة على النموذج).
  final VoidCallback onPickDate;

  /// يرحّل الحركة (بوابات أسعار اليوم ثم الحفظ).
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CashSheetDragHandle(),
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(Icons.bolt_rounded, color: scheme.primary, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.cashQmSheetTitle,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: l10n.commonCancel,
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (kind, label) in [
              (QuickMovementKind.expense, l10n.cashQmKindExpense),
              (QuickMovementKind.ownerDraw, l10n.cashQmKindOwnerDraw),
              (QuickMovementKind.capitalIn, l10n.cashQmKindCapitalIn),
              (QuickMovementKind.boxTransfer, l10n.cashQmKindTransfer),
              (QuickMovementKind.bankDeposit, l10n.cashQmKindBankDeposit),
              (QuickMovementKind.bankWithdraw, l10n.cashQmKindBankWithdraw),
            ])
              ChoiceChip(
                label: Text(label),
                selected: vm.kind == kind,
                onSelected: (_) => vm.setKind(kind),
              ),
          ],
        ),
        const SizedBox(height: 16),
        CashAmountField(
          controller: amountController,
          label: l10n.cashQmAmountLabel,
          helper: l10n.cashQmAmountHint,
          suffixCode: vm.selectedBox?.box.currencyCode,
          enabled: !vm.saving,
          onChanged: (raw) => vm.setAmount(CashAmountField.parse(raw)),
        ),
        const SizedBox(height: 12),
        CashBoxPickerField(
          boxes: vm.boxes,
          selectedId: vm.boxId,
          label: l10n.cashQmSourceBoxLabel,
          onChanged: vm.setBox,
          enabled: !vm.saving,
        ),
        if (vm.needsTargetBox) ...[
          const SizedBox(height: 12),
          CashBoxPickerField(
            boxes: vm.boxes,
            selectedId: vm.targetBoxId,
            label: l10n.cashQmTargetBoxLabel,
            onChanged: vm.setTargetBox,
            enabled: !vm.saving,
            icon: Icons.account_balance_rounded,
          ),
        ],
        if (vm.needsCategory) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: vm.categoryId,
            onChanged: vm.saving ? null : vm.setCategory,
            decoration: InputDecoration(
              labelText: l10n.cashQmCategoryLabel,
              helperText: l10n.cashQmCategoryHint,
              prefixIcon: const Icon(Icons.category_rounded),
            ),
            items: [
              for (final category in vm.categories)
                DropdownMenuItem<int>(
                  value: category.id,
                  child: Text(category.name),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        InkWell(
          onTap: vm.saving ? null : onPickDate,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.cashQmDateLabel,
              prefixIcon: const Icon(Icons.event_rounded),
              border: const OutlineInputBorder(),
            ),
            child: Text(
              cashFormatDate(vm.txDate),
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(fontFeatures: FinText.tabularNums),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: descriptionController,
          enabled: !vm.saving,
          maxLines: 2,
          maxLength: 140,
          onChanged: vm.setDescription,
          decoration: InputDecoration(
            labelText: l10n.cashQmDescriptionLabel,
            helperText: l10n.cashQmDescriptionHint,
            prefixIcon: const Icon(Icons.notes_rounded),
          ),
        ),
        const SizedBox(height: 6),
        QuickMovementPreview(
          vm: vm,
          projected: projected,
          willGoNegative: willGoNegative,
        ),
        if (vm.saveError != null) ...[
          const SizedBox(height: 12),
          FinErrorCard(message: vm.saveError!),
        ],
        const SizedBox(height: 18),
        FilledButton(
          onPressed: vm.saving ? null : onSave,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            textStyle: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          child: vm.saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : Text(l10n.cashQmSave),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: vm.saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
      ],
    );
  }
}
