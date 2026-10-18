/// شاشة فاتورة الشراء الجديدة — قلب وحدة المشتريات (المرحلة 5 / FR-02-08)،
/// بنية مرآة لشاشة الكاشير: شريط أهداف قابل للطي (مورد + عملة + التاريخ)
/// — قائمة بنود الفاتورة الحية (كمية، تكلفة الوحدة، خصم سطر، **رقم دفعة
/// وتاريخ صلاحية لكل بند للأصناف المتتبعة** FR-01-10) — أسفل ثابت:
/// المجموع + الخصومات = الصافي الكبير + زر الترحيل الضخم. الترحيل عبر
/// `PurchaseRepository.postPurchase` الذرّي: رقم PUR + WAC + الدفعات
/// الواردة + المخزون + سند الصرف للجزء النقدي.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../view_models/purchase_cart_session.dart';
import '../view_models/purchase_cart_view_model.dart';
import 'widgets/purchase_fx_gate_sheet.dart';
import 'widgets/purchase_bottom_bar.dart';
import 'widgets/purchase_cart_banners.dart';
import 'widgets/purchase_item_picker_sheet.dart';
import 'widgets/purchase_line_card.dart';
import 'widgets/purchase_payment_sheet.dart';
import 'widgets/purchase_targets_strip.dart';
import 'widgets/purchase_widgets.dart';
import 'widgets/supplier_picker_sheet.dart';

/// شاشة إنشاء فاتورة شراء جديدة (مسار `/purchases/new`) — الفاتورة تنجو
/// من التنقل عبر [purchaseCartSession].
class PurchaseScreen extends StatelessWidget {
  const PurchaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    final vm = purchaseCartSession.attach(
      companyRepo: app.companies!,
      fxRepo: app.fxRates!,
      purchaseRepo: app.purchases!,
      database: app.database!.db,
    );
    unawaited(vm.load());
    return ChangeNotifierProvider<PurchaseCartViewModel>.value(
      value: vm,
      child: const _PurchaseScreenBody(),
    );
  }
}

class _PurchaseScreenBody extends StatefulWidget {
  const _PurchaseScreenBody();

  @override
  State<_PurchaseScreenBody> createState() => _PurchaseScreenBodyState();
}

class _PurchaseScreenBodyState extends State<_PurchaseScreenBody> {
  bool _headerExpanded = false;
  bool _fxGateOpen = false;
  bool _noticeShown = false;

  /// النموذج يُخزَّن حقلاً — قراءة context داخل dispose غير آمنة (عنصر
  /// معطّل) وتكسر تفكيك الشجرة عند مغادرة الفاتورة. نفس علة/علاج شاشة
  /// البيع الموثّقة (أصل استثناء Hero أثناء الرجوع من /sell/new) —
  /// كشفتها هنا اختبارات R17-a عند تفكيك الشجرة.
  late final PurchaseCartViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = context.read<PurchaseCartViewModel>();
    _vm.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    _vm.removeListener(_onCartChanged);
    super.dispose();
  }

  /// ردود الفعل للحالات العابرة: بوابة FX (FR-08-09) والإشعارات.
  void _onCartChanged() {
    final vm = context.read<PurchaseCartViewModel>();
    final state = vm.state;
    if (state.fxGateRequired && !_fxGateOpen) {
      final currency = state.selectedCurrency;
      if (currency != null && !currency.isBase) {
        _fxGateOpen = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final saved = await showPurchaseFxRateGateSheet(
            context,
            cartVm: vm,
            currencyCode: currency.code,
          );
          _fxGateOpen = false;
          vm.clearFxGate();
          if (!saved || !mounted) return;
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l10n.sellFxSavedAndResumed)));
        });
      } else {
        vm.clearFxGate();
      }
    }
    if (state.notice != null && !_noticeShown) {
      _noticeShown = true;
      final message = state.notice!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        vm.clearNotice();
        _noticeShown = false;
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      });
    }
  }

  // ── الإجراءات ─────────────────────────────────────────────────────

  Future<void> _openSupplierPicker() async {
    final app = context.read<AppController>();
    final vm = context.read<PurchaseCartViewModel>();
    await showSupplierPickerSheet(
      context,
      supplierRepo: app.suppliers!,
      onPick: (pick) =>
          vm.setSupplier(id: pick.partyId, name: pick.name, phone: pick.phone),
    );
  }

  Future<void> _openItemPicker() async {
    final app = context.read<AppController>();
    final vm = context.read<PurchaseCartViewModel>();
    await showPurchaseItemPickerSheet(
      context,
      itemRepo: app.items!,
      onPick: vm.addItemFromInfo,
    );
  }

  Future<void> _openPayment() async {
    final vm = context.read<PurchaseCartViewModel>();
    final state = vm.state;
    final priced = vm.pricedCart;
    if (priced == null) return;
    final posted = await showPurchasePaymentSheet(
      context,
      grandTotal: priced.totals.grandTotal,
      decimals: state.selectedCurrency?.decimals ?? 2,
      currencyCode: state.selectedCurrency?.code,
      supplierName: state.supplier?.name,
      onConfirm: (paidCash, method) =>
          vm.postPurchase(paidCash: paidCash, method: method),
    );
    if (posted) {
      vm.dismissReceipt();
    }
  }

  Future<void> _confirmClearCart() async {
    final vm = context.read<PurchaseCartViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.purClearCartTitle),
        content: Text(l10n.purClearCartBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      vm.startNewInvoice();
    }
  }

  Future<void> _editInvoiceDiscount() async {
    final vm = context.read<PurchaseCartViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final result = await showPurchaseDiscountEditSheet(
      context,
      title: l10n.purInvoiceDiscountTitle,
      initialType: vm.state.invoiceDiscountType,
      initialValue: vm.state.invoiceDiscountValue,
    );
    if (result != null) {
      vm.setInvoiceDiscount(result.$1, result.$2);
    }
  }

  // ── البناء ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PurchaseCartViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/purchases')),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.purScreenTitle),
            Text(
              state.nextInvoiceNo ?? l10n.purNewInvoiceLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontFeatures: FinText.tabularNums,
              ),
            ),
          ],
        ),
        actions: [
          if (state.lines.isNotEmpty)
            IconButton(
              tooltip: l10n.purClearCartTooltip,
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _confirmClearCart,
            ),
        ],
      ),
      body: state.loading
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: const [ListSkeleton()],
            )
          : state.error != null
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                ErrorState(
                  title: l10n.genericErrorTitle,
                  message: l10n.dbOpenErrorMessage,
                  technicalDetails: state.error.toString(),
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
                        PurchaseTargetsStrip(
                          expanded: _headerExpanded,
                          onToggle: () => setState(
                            () => _headerExpanded = !_headerExpanded,
                          ),
                          onPickSupplier: _openSupplierPicker,
                          onPickCurrency: (currencyId) => context
                              .read<PurchaseCartViewModel>()
                              .setCurrency(currencyId),
                        ),
                        const SizedBox(height: 12),
                        if (state.postError != null) ...[
                          PurchasePostErrorBanner(message: state.postError!),
                          const SizedBox(height: 12),
                        ],
                        if (state.lines.isEmpty)
                          PurchaseEmptyCart(onAdd: _openItemPicker)
                        else
                          for (var i = 0; i < state.lines.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: PurchaseLineCard(index: i),
                            ),
                      ],
                    ),
                  ),
                  PurchaseBottomBar(
                    onAddItem: _openItemPicker,
                    onPost: _openPayment,
                    onInvoiceDiscount: _editInvoiceDiscount,
                  ),
                ],
              ),
            ),
    );
  }
}
