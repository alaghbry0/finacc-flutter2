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

import '../../../../domain/models/party.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/dirty_form_guard.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../view_models/voucher_view_model.dart';
import 'widgets/cash_widgets.dart';

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

  Future<void> _openPartyPicker(VoucherViewModel vm) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // فوق شريط التبويبات (متصفح الفرع) — لا من أسفل الشاشة خلفه.
      useRootNavigator: false,
      builder: (_) => _VoucherPartyPickerSheet(vm: vm),
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
    final l10n = AppLocalizations.of(context)!;
    _captureBaseline(vm);

    // حماية التغييرات غير المحفوظة (P1-4): الرجوع المباشر (النظام/الزر)
    // يعرض حوار «مغادرة/بقاء».
    return DirtyFormGuard(
      isDirty: _isDirty(vm),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
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
        ),
        body: vm.loading
            ? ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: const [ListSkeleton(rows: 6)],
              )
            : vm.error != null
            ? ListView(
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
              )
            : SafeArea(
                top: false,
                bottom: false,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        children: [
                          _PartyCard(
                            vm: vm,
                            onPick: () => unawaited(_openPartyPicker(vm)),
                          ),
                          const SizedBox(height: 12),
                          _AmountCurrencyCard(
                            vm: vm,
                            controller: _amountController,
                          ),
                          const SizedBox(height: 12),
                          _BoxDateCard(
                            vm: vm,
                            onPickDate: () => unawaited(_pickDate(vm)),
                          ),
                          if (vm.partyId != null) ...[
                            const SizedBox(height: 12),
                            _AllocationCard(vm: vm),
                          ],
                          if (vm.isCrossCurrency &&
                              vm.projectedBoxDeposit != null) ...[
                            const SizedBox(height: 12),
                            _CrossCurrencyNote(vm: vm),
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
                        ],
                      ),
                    ),
                    _BottomPostBar(vm: vm, onPost: () => unawaited(_post(vm))),
                  ],
                ),
              ),
      ),
    );
  }
}

/// بطاقة الطرف — زر اختيار كبير أو الطرف المختار برصيده بعملته.
class _PartyCard extends StatelessWidget {
  const _PartyCard({required this.vm, required this.onPick});

  final VoucherViewModel vm;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);

    if (vm.partyId == null) {
      return FinCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  vm.isReceipt
                      ? Icons.person_search_rounded
                      : Icons.local_shipping_rounded,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.cashVoucherPartySection,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.search_rounded, size: 20),
              label: Text(l10n.cashVoucherPickParty),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      );
    }

    final balanceLabel = vm.isReceipt
        ? (vm.partyBalance! > 0
              ? l10n.cashVoucherPartyOwesYou
              : vm.partyBalance! < 0
              ? l10n.cashVoucherPartyCredit
              : l10n.sellCustomerClear)
        : (vm.partyBalance! > 0
              ? l10n.cashVoucherPartyWeOwe
              : vm.partyBalance! < 0
              ? l10n.cashVoucherPartyCredit
              : l10n.sellCustomerClear);
    final balanceColor = vm.partyBalance! > 0
        ? (vm.isReceipt ? colors.positive : colors.warning)
        : vm.partyBalance! < 0
        ? (vm.isReceipt ? colors.neutral : colors.positive)
        : scheme.onSurfaceVariant;

    return FinCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    vm.partyName!.trim().isEmpty
                        ? '؟'
                        : vm.partyName!.trim().characters.first,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vm.partyName!,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          l10n.cashVoucherPartyBalance,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            balanceLabel,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: balanceColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      AmountText(
                        amount: vm.partyBalance!.abs(),
                        decimals: 2,
                        showSignMarker: false,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        vm.partyCurrencyCode ?? '',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.gold,
                          fontWeight: FontWeight.w800,
                          fontFeatures: FinText.tabularNums,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: Text(l10n.cashVoucherChangeParty),
            ),
          ),
        ],
      ),
    );
  }
}

/// المبلغ وعملة السند — خيارات العملة = عملات الصناديق (+ عملة الطرف
/// إن خالفتها)؛ تغييرها يعيد حساب المديونية المفتوحة والتخصيص.
class _AmountCurrencyCard extends StatelessWidget {
  const _AmountCurrencyCard({required this.vm, required this.controller});

  final VoucherViewModel vm;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);

    // خيارات فريدة بمعرّف العملة (صناديق + عملة الطرف عند اختلافها).
    final seen = <int>{};
    final options = <({int id, String code})>[
      for (final b in vm.boxes)
        if (seen.add(b.box.currencyId))
          (id: b.box.currencyId, code: b.box.currencyCode),
      if (vm.partyCurrencyId != null &&
          vm.partyCurrencyCode != null &&
          seen.add(vm.partyCurrencyId!))
        (id: vm.partyCurrencyId!, code: vm.partyCurrencyCode!),
    ];

    return FinCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.cashVoucherAmountSection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          CashAmountField(
            controller: controller,
            label: l10n.cashQmAmountLabel,
            suffixCode: vm.voucherCurrencyCode,
            enabled: !vm.saving,
            onChanged: (raw) => vm.setAmount(CashAmountField.parse(raw)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: vm.voucherCurrencyId,
            onChanged: vm.saving ? null : vm.setVoucherCurrency,
            decoration: InputDecoration(
              labelText: l10n.cashVoucherCurrencyLabel,
              prefixIcon: Icon(
                Icons.currency_exchange_rounded,
                color: colors.gold,
              ),
            ),
            items: [
              for (final option in options)
                DropdownMenuItem<int>(
                  value: option.id,
                  child: Text(
                    option.code,
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(fontFeatures: FinText.tabularNums),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// الصندوق والتاريخ.
class _BoxDateCard extends StatelessWidget {
  const _BoxDateCard({required this.vm, required this.onPickDate});

  final VoucherViewModel vm;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FinCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.cashVoucherBoxSection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          CashBoxPickerField(
            boxes: vm.boxes,
            selectedId: vm.boxId,
            label: l10n.cashMovementFieldBox,
            onChanged: vm.setBox,
            enabled: !vm.saving,
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: vm.saving ? null : onPickDate,
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
        ],
      ),
    );
  }
}

/// خيار التخصيص + معاينة الفواتير المفتوحة وخطة FIFO الحية.
class _AllocationCard extends StatelessWidget {
  const _AllocationCard({required this.vm});

  final VoucherViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final plan = vm.previewPlan;
    final unallocated = vm.unallocatedRemainder;

    return FinCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.cashVoucherAllocationSection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: true,
                label: Text(l10n.cashVoucherAllocFifo),
                icon: const Icon(Icons.low_priority_rounded),
              ),
              ButtonSegment(
                value: false,
                label: Text(l10n.cashVoucherAllocOnAccount),
                icon: const Icon(Icons.account_balance_wallet_rounded),
              ),
            ],
            selected: {vm.allocateFifo},
            onSelectionChanged: vm.saving
                ? null
                : (selection) => vm.setAllocateFifo(selection.first),
          ),
          if (vm.openInvoicesLoading)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            )
          else if (vm.allocateFifo) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.cashVoucherOpenDuesTotal,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                AmountText(
                  amount: vm.openDuesTotal,
                  decimals: 2,
                  showSignMarker: false,
                ),
                const SizedBox(width: 4),
                Text(
                  vm.voucherCurrencyCode ?? '',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.gold,
                  ),
                ),
              ],
            ),
            if (vm.openInvoices.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.cashVoucherNoOpenDues,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else ...[
              const SizedBox(height: 8),
              for (final invoice in vm.openInvoices)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              invoice.invoiceNo,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontFeatures: FinText.tabularNums,
                                  ),
                            ),
                            Text(
                              cashFormatDate(invoice.issuedAt),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(fontFeatures: FinText.tabularNums),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.cashVoucherOpenRemaining,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(width: 6),
                      AmountText(
                        amount: invoice.remaining,
                        decimals: 2,
                        showSignMarker: false,
                      ),
                    ],
                  ),
                ),
              if (plan.isNotEmpty) ...[
                const Divider(height: 18, thickness: 0.6),
                Text(
                  l10n.cashVoucherPlanTitle,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
                for (final entry in plan)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          Icons.subdirectory_arrow_left_rounded,
                          size: 14,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            entry.invoiceNo,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(fontFeatures: FinText.tabularNums),
                          ),
                        ),
                        AmountText(
                          amount: entry.amount,
                          decimals: 2,
                          // DS-18: علامة + غير لونية إلزامية للتخصيصات
                          // (إشارة واردة للفاتورة) — إصلاح جولة 13.
                          sign: FinSign.incoming,
                        ),
                      ],
                    ),
                  ),
                if (unallocated > 0.005)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 14,
                          color: colors.warning,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l10n.cashVoucherUnallocated,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: colors.warning),
                          ),
                        ),
                        AmountText(
                          amount: unallocated,
                          decimals: 2,
                          showSignMarker: false,
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ],
        ],
      ),
    );
  }
}

/// سطر الإيداع المتوقع بعملة الصندوق عند اختلاف عملتي السند والصندوق.
class _CrossCurrencyNote extends StatelessWidget {
  const _CrossCurrencyNote({required this.vm});

  final VoucherViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.currency_exchange_rounded,
            size: 18,
            color: scheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.cashVoucherCrossDeposit(
                AmountText.format(vm.projectedBoxDeposit!, 2),
                vm.selectedBox?.box.currencyCode ?? '',
              ),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// الشريط السفلي الثابت — خطأ الرفض إن وُجد + زر الترحيل الضخم.
class _BottomPostBar extends StatelessWidget {
  const _BottomPostBar({required this.vm, required this.onPost});

  final VoucherViewModel vm;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: colors.cardBorder, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (vm.saveError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: colors.negative,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          vm.saveError!,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: colors.negative,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              FilledButton(
                onPressed: vm.saving ? null : onPost,
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
                    : Text(l10n.cashVoucherPost),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────
/// منتقي الطرف — بحث حي عبر النموذج (عملاء للقبض / موردين للصرف)، سطر
/// لكل طرف×عملة مع رصيده.
/// ─────────────────────────────────────────────────────────────────────

class _VoucherPartyPickerSheet extends StatefulWidget {
  const _VoucherPartyPickerSheet({required this.vm});

  final VoucherViewModel vm;

  @override
  State<_VoucherPartyPickerSheet> createState() =>
      _VoucherPartyPickerSheetState();
}

class _VoucherPartyPickerSheetState extends State<_VoucherPartyPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<PartyBalance> _matches = const <PartyBalance>[];
  bool _loading = true;
  Object? _error;
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    unawaited(_search(''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    _debounce?.cancel();
    _query = query;
    try {
      final matches = await widget.vm.searchParties(query);
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  void _onQueryChanged(String value) {
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_search(value));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final height = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: height * 0.85,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CashSheetDragHandle(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.cashVoucherPickerTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.commonCancel,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchController,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.cashVoucherPickerSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            unawaited(_search(''));
                          },
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildList(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    if (_error != null) {
      return Center(
        child: ErrorState(
          title: l10n.genericErrorTitle,
          message: l10n.dbOpenErrorMessage,
          technicalDetails: _error.toString(),
          retryLabel: l10n.commonRetry,
          onRetry: () => unawaited(_search(_query)),
          compact: true,
        ),
      );
    }
    if (_matches.isEmpty) {
      return Center(
        child: _query.isEmpty
            ? EmptyState(
                icon: widget.vm.isReceipt
                    ? Icons.person_search_rounded
                    : Icons.local_shipping_rounded,
                title: l10n.cashVoucherPickerEmptyTitle,
                message: l10n.cashVoucherPickerEmptyBody,
                compact: true,
              )
            : EmptyState(
                icon: Icons.search_off_rounded,
                title: l10n.cashVoucherPickerNoResultsTitle,
                message: l10n.cashVoucherPickerNoResultsBody,
                compact: true,
              ),
      );
    }
    return ListView.builder(
      itemCount: _matches.length,
      itemBuilder: (context, index) {
        final match = _matches[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _PartyRow(
            match: match,
            isReceipt: widget.vm.isReceipt,
            onTap: () {
              widget.vm.setParty(match);
              Navigator.of(context).pop();
            },
          ),
        );
      },
    );
  }
}

class _PartyRow extends StatelessWidget {
  const _PartyRow({
    required this.match,
    required this.isReceipt,
    required this.onTap,
  });

  final PartyBalance match;
  final bool isReceipt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    // موجب = طرف مدينة لنا (عميل مدين/ مورد ندين له) — إشارة العملة حسب
    // نوع السند (قبض من عميل/صرف لمورد).
    final label = isReceipt
        ? (match.balance > 0
              ? l10n.cashVoucherPartyOwesYou
              : match.balance < 0
              ? l10n.cashVoucherPartyCredit
              : l10n.sellCustomerClear)
        : (match.balance > 0
              ? l10n.cashVoucherPartyWeOwe
              : match.balance < 0
              ? l10n.cashVoucherPartyCredit
              : l10n.sellCustomerClear);
    final color = match.balance > 0
        ? (isReceipt ? colors.positive : colors.warning)
        : match.balance < 0
        ? (isReceipt ? colors.neutral : colors.positive)
        : scheme.onSurfaceVariant;

    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.cardBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    match.name.trim().isEmpty
                        ? '؟'
                        : match.name.trim().characters.first,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.name,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (match.phone != null && match.phone!.isNotEmpty)
                      Text(
                        match.phone!,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(fontFeatures: FinText.tabularNums),
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      AmountText(
                        amount: match.balance.abs(),
                        size: AmountSize.row,
                        decimals: 2,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        match.currencyCode,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.gold,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: color),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
