/// شاشة سند القبض/الصرف (FR-04-02/03/10) — مسار `/cash/voucher/:type`:
/// منتقي طرف ببحث (عميل للقبض RVT / مورد للصرف PMT — سطر رصيد لكل
/// طرف×عملة) + مبلغ وعملة السند + صندوق + تاريخ + خيار التخصيص
/// (على الحساب | FIFO بمعاينة الفواتير المفتوحة التي سيوزع عليها) +
/// ملاحظات + بوابة سعر اليوم لعملة سند غير أساس (FR-08-09) + زر ترحيل
/// يُظهر SnackBar برقم السند المرقّم. منطق FIFO والعملات في النموذج —
/// الشاشة عرض وإدخال حصراً.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/dirty_form_guard.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../view_models/voucher_view_model.dart';
import 'widgets/cash_widgets.dart';
import 'widgets/voucher_allocation_card.dart';
import 'widgets/voucher_amount_card.dart';
import 'widgets/voucher_bottom_bar.dart';
import 'widgets/voucher_party_card.dart';
import 'widgets/voucher_party_picker_sheet.dart';

/// حارس التأريخ الرجعي (UX-2a — `dating.max_backdate_days`): أقدم تاريخ
/// يسمح به منتقي تاريخ السند = `now − الحد` (حد 0 أو سالب = اليوم فقط).
/// كان المنتقي يقبل سنتين رجعياً بلا أي سقف من الإعدادات.
///
/// (علنية لتُختبر مباشرة — نفس نمط sellFormatDate بالوحدة.)
DateTime voucherBackdateLowerBound(DateTime now, int maxBackdateDays) {
  if (maxBackdateDays <= 0) return now;
  return now.subtract(Duration(days: maxBackdateDays));
}

/// شاشة السند — `type` من المسار: `receipt` (قبض من عميل) أو `payment`
/// (صرف لمورد؛ أي قيمة أخرى تُعامل صرفاً).
class VoucherScreen extends StatelessWidget {
  const VoucherScreen({super.key, required this.isReceipt});

  final bool isReceipt;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final VoucherViewModel vm;
    vm = VoucherViewModel(
      cashRepo: app.cash!,
      customerRepo: app.customers!,
      supplierRepo: app.suppliers!,
      fxRepo: app.fxRates!,
      companyRepo: app.companies!,
      isReceipt: isReceipt,
    );
    unawaited(vm.load());
    return ChangeNotifierProvider<VoucherViewModel>.value(
      value: vm,
      child: const _VoucherScreenBody(),
    );
  }
}

class _VoucherScreenBody extends StatefulWidget {
  const _VoucherScreenBody();

  @override
  State<_VoucherScreenBody> createState() => _VoucherScreenBodyState();
}

class _VoucherScreenBodyState extends State<_VoucherScreenBody> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  /// لقطة ما بعد التحميل — حماية «التغييرات غير المحفوظة» (P1-4).
  bool _baselineReady = false;
  double? _bAmount;
  String _bNotes = '';
  int? _bPartyId;
  int? _bBoxId;
  int? _bCurrencyId;
  DateTime _bDate = DateTime.now();
  bool _bFifo = true;

  /// يلتقط لقطة الحالة الأولى القابلة للتحرير (مرة واحدة بعد التحميل).
  void _captureBaseline(VoucherViewModel vm) {
    if (_baselineReady || vm.loading || vm.error != null) return;
    _baselineReady = true;
    _bAmount = vm.amount;
    _bNotes = vm.notes;
    _bPartyId = vm.partyId;
    _bBoxId = vm.boxId;
    _bCurrencyId = vm.voucherCurrencyId;
    _bDate = vm.txDate;
    _bFifo = vm.allocateFifo;
  }

  /// هل في السند تغييرات غير محفوظة؟
  bool _isDirty(VoucherViewModel vm) {
    if (!_baselineReady) return false;
    return vm.amount != _bAmount ||
        vm.notes != _bNotes ||
        vm.partyId != _bPartyId ||
        vm.boxId != _bBoxId ||
        vm.voucherCurrencyId != _bCurrencyId ||
        vm.txDate != _bDate ||
        vm.allocateFifo != _bFifo;
  }

  /// رجوع محروس: زر الرجوع الصريح (go) يمر بنفس حوار الحماية (P1-4).
  Future<void> _guardedBack(VoucherViewModel vm) async {
    if (_isDirty(vm) && !await confirmDiscardChanges(context)) {
      return;
    }
    if (mounted) context.go('/cash');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(VoucherViewModel vm) async {
    // UX-2a — حارس التأريخ الرجعي: سقف الرجوع من الإعدادات
    // (`dating.max_backdate_days`، افتراضي 30 يوماً) بدل سنتين مفتوحتين.
    final settings = context.read<AppController>().settings;
    final maxDays = settings == null ? 30 : await settings.maxBackdateDays();
    if (!mounted) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.txDate,
      firstDate: voucherBackdateLowerBound(now, maxDays),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (picked != null) {
      vm.setDate(picked);
    }
  }

  Future<void> _openPartyPicker(VoucherViewModel vm) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => VoucherPartyPickerSheet(vm: vm),
    );
  }

  Future<void> _post(VoucherViewModel vm) async {
    // بوابة سعر اليوم لعملة السند غير الأساس (FR-08-09).
    if (vm.voucherRateMissing) {
      final saved = await showCashFxGateSheet(
        context,
        currencyCode: vm.voucherCurrencyCode ?? '',
        onSave: vm.saveTodayRate,
      );
      if (!saved || !mounted) return;
    }
    final result = await vm.save();
    if (!mounted) return;
    if (result.isOk) {
      final receipt = result.valueOrNull!;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              l10n.cashVoucherPostedSnackBar(
                receipt.voucherNo,
                AmountText.format(receipt.amount, 2),
                receipt.currencyCode,
              ),
            ),
          ),
        );
      // العودة للمحور — RefreshOnActive (^/cash$) يعيد تحميل الأرصدة حياً.
      context.go('/cash');
    }
    // الرفض → vm.saveError تُعرض فوق زر الترحيل.
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VoucherViewModel>();
    _captureBaseline(vm);

    // حماية التغييرات غير المحفوظة (P1-4): الرجوع المباشر (النظام/الزر)
    // يعرض حوار «مغادرة/بقاء».
    return DirtyFormGuard(
      isDirty: _isDirty(vm),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: _buildAppBar(context, vm),
        body: _buildBody(context, vm),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, VoucherViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    return AppBar(
      leading: BackButton(onPressed: () => unawaited(_guardedBack(vm))),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            vm.isReceipt
                ? l10n.cashVoucherReceiptTitle
                : l10n.cashVoucherPaymentTitle,
          ),
          Text(
            vm.isReceipt
                ? l10n.cashVoucherReceiptSubtitle
                : l10n.cashVoucherPaymentSubtitle,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// جسم الشاشة بحرّاس خروج مبكرين — نفس دلالة السلاسل المتداخلة
  /// الأصلية حرفياً: تحميل ← خطأ ← النموذج.
  Widget _buildBody(BuildContext context, VoucherViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    if (vm.loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: const [ListSkeleton()],
      );
    }
    if (vm.error != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
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
    return SafeArea(
      top: false,
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: _formChildren(context, vm),
            ),
          ),
          VoucherBottomPostBar(vm: vm, onPost: () => unawaited(_post(vm))),
        ],
      ),
    );
  }

  /// حقول النموذج فوق الشريط السفلي.
  List<Widget> _formChildren(BuildContext context, VoucherViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    return [
      VoucherPartyCard(vm: vm, onPick: () => unawaited(_openPartyPicker(vm))),
      const SizedBox(height: 12),
      VoucherAmountCurrencyCard(vm: vm, controller: _amountController),
      const SizedBox(height: 12),
      VoucherBoxDateCard(vm: vm, onPickDate: () => unawaited(_pickDate(vm))),
      if (vm.partyId != null) ...[
        const SizedBox(height: 12),
        VoucherAllocationCard(vm: vm),
      ],
      if (vm.isCrossCurrency && vm.projectedBoxDeposit != null) ...[
        const SizedBox(height: 12),
        VoucherCrossCurrencyNote(vm: vm),
      ],
      const SizedBox(height: 12),
      TextField(
        controller: _notesController,
        enabled: !vm.saving,
        maxLines: 2,
        maxLength: 200,
        onChanged: vm.setNotes,
        decoration: InputDecoration(
          labelText: l10n.cashVoucherNotesLabel,
          helperText: l10n.cashVoucherNotesHint,
          prefixIcon: const Icon(Icons.notes_rounded),
        ),
      ),
    ];
  }
}
