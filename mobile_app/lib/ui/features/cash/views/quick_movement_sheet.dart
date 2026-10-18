/// النافذة الذكية الموحدة للحركات السريعة (FR-04-02): مصروف/مسحوبات
/// المالك/إيداع المالك/تحويل بين صندوقين/إيداع بنكي/سحب بنكي — نموذج
/// واحد يبدّل حقوله حسب النوع (فئة إلزامية للمصروف حصراً + صندوق هدف
/// للأنواع ذات الساقين) + بوابات أسعار اليوم للعملات غير الأساس
/// (FR-08-09) + تحذير بصري عند رصيد متوقع سالب (FR-04-09 — تحذير بلا
/// منع). تُفتح فوق شريط التبويبات (useRootNavigator على افتراضه false حصراً).
///
/// الرسوم (النموذج/المعاينة الحية/إيصال النجاح) بملفاتها المركزّعة
/// بجوارها (R20-D3d) — هذا الملف: آلة الحالة والحرّاس والتحقق
/// والترحيل (نمط payment_sheet).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/cash.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../view_models/quick_movement_view_model.dart';
import 'widgets/cash_widgets.dart';
import 'widgets/quick_movement_form.dart';
import 'widgets/quick_movement_receipt_view.dart';

/// يفتح نافذة الحركة السريعة بنوع ابتدائي — تُغلق بنفسها عند «تم».
///
/// يعيد `true` إذا رُحّلت حركة فعلاً — ليُعيد المنادي تحميل أرصدته
/// (النافذة لا تغيّر المسار فلا يفعّل RefreshOnActive — إصلاح جولة 13).
Future<bool> showQuickMovementSheet(
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
  var posted = false;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider<QuickMovementViewModel>.value(
      value: vm,
      child: _QuickMovementSheet(onPosted: () => posted = true),
    ),
  );
  return posted;
}

class _QuickMovementSheet extends StatefulWidget {
  const _QuickMovementSheet({required this.onPosted});

  /// تُستدعى مرة واحدة عند أول ترحيل ناجح (لا عند الإغلاق) — علامة
  /// «رُحّلت حركة» التي يقرؤها المنادي بعد إغلاق النافذة بأي طريق.
  final VoidCallback onPosted;

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
      widget.onPosted();
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

    return QuickMovementForm(
      vm: vm,
      amountController: _amountController,
      descriptionController: _descriptionController,
      projected: projected,
      willGoNegative: willGoNegative,
      onPickDate: () => unawaited(_pickDate(vm)),
      onSave: () => unawaited(_save(vm)),
    );
  }

  // ── إيصال النجاح ───────────────────────────────────────────────────

  Widget _buildReceipt(BuildContext context, QuickMovementViewModel vm) {
    return QuickMovementReceiptView(
      vm: vm,
      receipt: _receipt!,
      onStartAnother: () => _startAnother(vm),
    );
  }
}
