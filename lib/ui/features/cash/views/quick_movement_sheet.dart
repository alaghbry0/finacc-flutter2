/// النافذة الذكية الموحدة للحركات السريعة (FR-04-02): مصروف/مسحوبات
/// المالك/إيداع المالك/تحويل بين صندوقين/إيداع بنكي/سحب بنكي — نموذج
/// واحد يبدّل حقوله حسب النوع (فئة إلزامية للمصروف حصراً + صندوق هدف
/// للأنواع ذات الساقين) + بوابات أسعار اليوم للعملات غير الأساس
/// (FR-08-09) + تحذير بصري عند رصيد متوقع سالب (FR-04-09 — تحذير بلا
/// منع). تُفتح فوق شريط التبويبات (useRootNavigator: false حصراً).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/cash.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../view_models/quick_movement_view_model.dart';
import 'widgets/cash_widgets.dart';

/// يفتح نافذة الحركة السريعة بنوع ابتدائي — تُغلق بنفسها عند «تم».
Future<void> showQuickMovementSheet(
  BuildContext context, {
  required QuickMovementKind initialKind,
}) async {
  final app = context.read<AppController>();
  final vm = QuickMovementViewModel(
    cashRepo: app.cash!,
    fxRepo: app.fxRates!,
    companyRepo: app.companies!,
    initialKind: initialKind,
  );
  unawaited(vm.load());
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // فوق شريط التبويبات (متصفح الفرع) — لا من أسفل الشاشة خلفه.
    useRootNavigator: false,
    builder: (_) => ChangeNotifierProvider<QuickMovementViewModel>.value(
      value: vm,
      child: const _QuickMovementSheet(),
    ),
  );
}

class _QuickMovementSheet extends StatefulWidget {
  const _QuickMovementSheet();

  @override
  State<_QuickMovementSheet> createState() => _QuickMovementSheetState();
}

class _QuickMovementSheetState extends State<_QuickMovementSheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  QuickMovementReceipt? _receipt;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// رصيد المصدر بعد الحركة بإشارة الدفتر (ملحق و): القبض النقدي
  /// الوحيد هنا هو «إيداع المالك» (+)؛ وكل حركة ذات ساقين — بما فيها
  /// **السحب البنكي** — تخرج من صندوقها المصدر (−). (حساب
  /// `projectedSourceBalance` في النموذج يعدّ السحب البنكي وارداً
  /// للمصدر — إشارة معكوسة عن الدفتر — فنحسب العرض هنا بإشارة الدفتر؛
  /// موثق في سجل العمل 12 للمنسق.)
  double? _projectedSourceAfter(QuickMovementViewModel vm) {
    final box = vm.selectedBox;
    final amount = vm.amount;
    if (box == null || amount == null) return null;
    final inflow = vm.kind == QuickMovementKind.capitalIn;
    return inflow ? box.nativeBalance + amount : box.nativeBalance - amount;
  }

  Future<void> _pickDate(QuickMovementViewModel vm) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.txDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      vm.setDate(picked);
    }
  }

  /// بوابات أسعار اليوم المفقودة قبل الترحيل (FR-08-09) — واحدة لكل
  /// عملة ناقصة؛ إلغاء أي بوابة يوقف الترحيل.
  Future<bool> _ensureTodayRates(QuickMovementViewModel vm) async {
    for (final code in List<String>.of(vm.missingRateCurrencyCodes)) {
      final saved = await showCashFxGateSheet(
        context,
        currencyCode: code,
        onSave: (rate) => vm.saveTodayRate(code, rate),
      );
      if (!saved) return false;
    }
    return true;
  }

  Future<void> _save(QuickMovementViewModel vm) async {
    if (vm.missingRateCurrencyCodes.isNotEmpty) {
      final ready = await _ensureTodayRates(vm);
      if (!ready || !mounted) return;
    }
    final result = await vm.save();
    if (!mounted) return;
    if (result.isOk) {
      setState(() => _receipt = result.valueOrNull);
    }
    // الرفض → vm.saveError تُعرضها البطاقة الحمراء في النموذج.
  }

  void _startAnother(QuickMovementViewModel vm) {
    _amountController.clear();
    _descriptionController.clear();
    vm
      ..setAmount(null)
      ..setDescription('');
    setState(() => _receipt = null);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<QuickMovementViewModel>();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: _receipt == null
            ? _buildForm(context, vm)
            : _buildReceipt(context, vm),
      ),
    );
  }

  // ── النموذج ─────────────────────────────────────────────────────────

  Widget _buildForm(BuildContext context, QuickMovementViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    if (vm.loading) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CashSheetDragHandle(),
          SizedBox(height: 28),
          Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
          SizedBox(height: 32),
        ],
      );
    }
    if (vm.error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CashSheetDragHandle(),
          const SizedBox(height: 12),
          ErrorState(
            title: l10n.genericErrorTitle,
            message: l10n.dbOpenErrorMessage,
            technicalDetails: vm.error.toString(),
            retryLabel: l10n.commonRetry,
            onRetry: vm.load,
            compact: true,
          ),
        ],
      );
    }
    if (vm.boxes.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CashSheetDragHandle(),
          const SizedBox(height: 12),
          EmptyState(
            icon: Icons.account_balance_wallet_rounded,
            title: l10n.cashQmNoBoxesTitle,
            message: l10n.cashQmNoBoxesBody,
            actionLabel: l10n.cashHomeManageBoxes,
            onAction: () {
              Navigator.of(context).pop();
              context.go('/cash/boxes');
            },
            compact: true,
          ),
        ],
      );
    }

    final projected = _projectedSourceAfter(vm);
    final willGoNegative = projected != null && projected < -0.005;

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
          controller: _amountController,
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
          onTap: vm.saving ? null : () => unawaited(_pickDate(vm)),
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.cashQmDateLabel,
              prefixIcon: const Icon(Icons.event_rounded),
              border: OutlineInputBorder(),
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
          controller: _descriptionController,
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
        _MovementPreview(
          vm: vm,
          projected: projected,
          willGoNegative: willGoNegative,
        ),
        if (vm.saveError != null) ...[
          const SizedBox(height: 12),
          CashErrorCard(message: vm.saveError!),
        ],
        const SizedBox(height: 18),
        FilledButton(
          onPressed: vm.saving ? null : () => unawaited(_save(vm)),
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

  // ── إيصال النجاح ───────────────────────────────────────────────────

  Widget _buildReceipt(BuildContext context, QuickMovementViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final receipt = _receipt!;
    final targetCode = vm.selectedTargetBox?.box.currencyCode;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CashSheetDragHandle(),
        const SizedBox(height: 14),
        FinCard(
          accent: colors.positive,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: colors.positive,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.cashQmReceiptTitle,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  AmountText(amount: receipt.amount, size: AmountSize.large),
                  const SizedBox(width: 8),
                  Text(
                    receipt.currencyCode,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ReceiptRow(
                icon: Icons.account_balance_wallet_rounded,
                label: l10n.cashQmSourceBoxLabel,
                value: receipt.sourceBoxName,
              ),
              if (receipt.targetBoxName != null)
                _ReceiptRow(
                  icon: Icons.account_balance_rounded,
                  label: l10n.cashQmTargetBoxLabel,
                  value: receipt.targetBoxName!,
                ),
              if (receipt.targetAmount != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.currency_exchange_rounded,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.cashQmReceiptArrived,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                      AmountText(
                        amount: receipt.targetAmount!,
                        decimals: 2,
                        showSignMarker: false,
                      ),
                      if (targetCode != null && targetCode.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          targetCode,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () => _startAnother(vm),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          icon: const Icon(Icons.post_add_rounded),
          label: Text(l10n.cashQmNewMovement),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonDone),
        ),
      ],
    );
  }
}

/// معاينة حية: رصيد المصدر بعد الحركة + تحذير السالب (FR-04-09) +
/// وصول المبلغ المحوّل للهدف عند اختلاف العملتين.
class _MovementPreview extends StatelessWidget {
  const _MovementPreview({
    required this.vm,
    required this.projected,
    required this.willGoNegative,
  });

  final QuickMovementViewModel vm;
  final double? projected;
  final bool willGoNegative;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final targetAmount = vm.projectedTargetAmount;
    final target = vm.selectedTargetBox;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (projected != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(
                  Icons.functions_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.cashQmProjectedSource,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                AmountText(
                  amount: projected!.abs(),
                  decimals: 2,
                  showSignMarker: false,
                  sign: projected! < 0 ? FinSign.outgoing : FinSign.neutral,
                ),
                const SizedBox(width: 4),
                Text(
                  vm.selectedBox?.box.currencyCode ?? '',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: projected! < 0 ? colors.negative : null,
                  ),
                ),
              ],
            ),
          ),
        if (targetAmount != null && target != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(
                  Icons.currency_exchange_rounded,
                  size: 16,
                  color: colors.gold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.cashQmArrivesAtTarget(
                      AmountText.format(targetAmount, 2),
                      target.box.name,
                      target.box.currencyCode,
                    ),
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        // تحذير بصري متحرك — لا منع أبداً (FR-04-09).
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: willGoNegative
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.negativeContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: colors.negative,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.cashQmNegativeWarning,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onNegativeContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
