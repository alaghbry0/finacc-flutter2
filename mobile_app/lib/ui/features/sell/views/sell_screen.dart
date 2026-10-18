/// شاشة البيع/الكاشير — قلب التطبيق، البنية الملزمة وفق SRS §6.5:
/// شاشة واحدة بلا تبويبات: أعلى شريط أهداف قابل للطي (عميل + عملة +
/// التاريخ) — منتصف قائمة بنود السلة الحية (كمية بـ QtyStepper، سعر
/// قابل للتعديل، خصم سطر، إجمالي السطر لحظياً، «المتاح: N» بتحذير عند
/// التجاوز FR-02-02) — أسفل ثابت: المجموع + الخصومات = الصافي الكبير +
/// زر الدفع الضخم + «حفظ كعرض سعر». باركود بإدخال يدوي وEnter يضيف أول
/// تطابق مباشرة (FR-02-02) — الكاميرا مؤجلة لمرحلة التغليف (قرار
/// worklog الموجة 2).
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
import '../view_models/print_on_save.dart';
import '../view_models/sell_cart_session.dart';
import '../view_models/sell_cart_view_model.dart';
import 'widgets/customer_picker_sheet.dart';
import 'widgets/fx_rate_gate_sheet.dart';
import 'widgets/invoice_pdf_preview.dart';
import 'widgets/item_picker_sheet.dart';
import 'widgets/payment_sheet.dart';
import 'widgets/sell_bottom_bar.dart';
import 'widgets/sell_cart_banners.dart';
import 'widgets/sell_cart_line_card.dart';
import 'widgets/sell_checkout_helpers.dart';
import 'widgets/sell_targets_strip.dart';
import 'widgets/sell_widgets.dart';

/// شاشة إنشاء فاتورة بيع جديدة (مسار مقترح `/sell/new` — شاشة كاملة فوق
/// محور البيع).
class SellScreen extends StatelessWidget {
  const SellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    final vm = sellCartSession.attach(
      itemRepo: app.items!,
      companyRepo: app.companies!,
      fxRepo: app.fxRates!,
      saleRepo: app.sales!,
      quotationRepo: app.quotations!,
      database: app.database!.db,
      // UX-2a: سياسات الكاشير الحية من تفضيلات البيع.
      settingsRepo: app.settings,
    );
    unawaited(vm.load());
    return ChangeNotifierProvider<SellCartViewModel>.value(
      value: vm,
      child: const _SellScreenBody(),
    );
  }
}

class _SellScreenBody extends StatefulWidget {
  const _SellScreenBody();

  @override
  State<_SellScreenBody> createState() => _SellScreenBodyState();
}

class _SellScreenBodyState extends State<_SellScreenBody> {
  bool _headerExpanded = false;
  bool _fxGateOpen = false;
  bool _noticeShown = false;

  /// النموذج يُخزَّن حقلاً — قراءة context داخل dispose غير آمنة (عنصر
  /// معطّل) وتكسر تفكيك الشجرة عند مغادرة الكاشير (أصل استثناءHero
  /// أثناء الرجوع من /sell/new).
  late final SellCartViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = context.read<SellCartViewModel>();
    _vm.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    _vm.removeListener(_onCartChanged);
    super.dispose();
  }

  /// ردود الفعل للحالات العابرة: بوابة FX (FR-08-09) وإشعارات الباركود.
  void _onCartChanged() {
    final vm = _vm;
    final state = vm.state;
    if (state.fxGateRequired && !_fxGateOpen) {
      final currency = state.selectedCurrency;
      if (currency != null && !currency.isBase) {
        _fxGateOpen = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final saved = await showFxRateGateSheet(
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

  Future<void> _openCustomerPicker() async {
    final app = context.read<AppController>();
    final vm = context.read<SellCartViewModel>();
    await showCustomerPickerSheet(
      context,
      customerRepo: app.customers!,
      onPick: (pick) =>
          vm.setCustomer(id: pick.partyId, name: pick.name, phone: pick.phone),
      onCashCustomer: vm.setCashCustomer,
      // P1-3: عميل جديد سريع داخل المنتقي — ينشئ طرفاً بحد أدنى من
      // الحقول (اسم + هاتف، بلا رصيد افتتاحي) ويعيده مختاراً للسلة.
      onCreateCustomer: (name, phone) =>
          createQuickSellCustomer(app, vm, name, phone),
    );
  }

  Future<void> _openItemPicker() async {
    final app = context.read<AppController>();
    final vm = context.read<SellCartViewModel>();
    final state = vm.state;
    await showItemPickerSheet(
      context,
      itemRepo: app.items!,
      currencyId: state.currencyId,
      decimals: state.selectedCurrency?.decimals ?? 2,
      currencyCode: state.selectedCurrency?.code,
      onPick: vm.addItemFromInfo,
    );
  }

  Future<void> _openPayment() async {
    final app = context.read<AppController>();
    final vm = context.read<SellCartViewModel>();
    final state = vm.state;
    final priced = vm.pricedCart;
    if (priced == null) return;
    // P0-2: استهلاك invoicing.print_on_save (نمط بوابة الائتمان — قراءة
    // لحظة فتح نافذة الدفع): ask = أزرار، always = معاينة تلقائية، off = إخفاء.
    final printMode = await resolvePrintOnSave(app.settings);
    if (!mounted) return;
    // UX-2a — `sale.default_payment`: الوضع الذي تُفتح عليه نافذة الدفع
    // (نقدي/آجل/مختلط)؛ آجل/مختلط بلا عميل يسقطان إلى نقدي (P2-3).
    final defaultPay = app.settings == null
        ? 'cash'
        : await app.settings!.defaultPayment();
    if (!mounted) return;
    final hasCustomer = state.customer?.id != null;
    final initialPayMode = switch (defaultPay) {
      'credit' => hasCustomer ? 'credit' : 'cash',
      'mixed' => hasCustomer ? 'mixed' : 'cash',
      _ => 'cash',
    };
    final sales = app.sales;
    final posted = await showPaymentSheet(
      context,
      grandTotal: priced.totals.grandTotal,
      decimals: state.selectedCurrency?.decimals ?? 2,
      currencyCode: state.selectedCurrency?.code,
      customerName: state.customer?.name,
      onConfirm: (paidCash, method) =>
          vm.postSale(paidCash: paidCash, method: method),
      // FR-03-05 (17-c): بوابة حد الائتمان — تُجلب لحظة التأكيد من
      // المستودع (الحد + الرصيد الحي بعملة الفاتورة) والإعداد.
      creditGate: () => resolveSellCreditGate(app, vm),
      // P0-2: فتح معاينة PDF للفاتورة المرحّلة (نمط زر PDF القائم).
      printOnSave: printMode,
      // UX-2a: وضع الدفع الافتراضي من تفضيلات البيع.
      initialPayMode: initialPayMode,
      openInvoicePreview: sales == null
          ? null
          : (receipt) => openInvoicePdfPreview(
              context,
              saleRepo: sales,
              invoiceId: receipt.invoiceId,
            ),
    );
    if (posted) {
      vm.dismissReceipt();
    }
  }

  Future<void> _saveQuotation() async {
    final vm = context.read<SellCartViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final result = await vm.saveAsQuotation();
    if (!mounted) return;
    final quotation = result.valueOrNull;
    if (quotation != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.sellQuotationSaved(quotation.quotationNo)),
            action: SnackBarAction(
              label: l10n.sellQuotationSavedOpen,
              onPressed: () => context.go('/sell/quotations'),
            ),
          ),
        );
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(result.errorOrNull!)));
    }
  }

  Future<void> _confirmClearCart() async {
    final vm = context.read<SellCartViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.sellClearCartTitle),
        content: Text(l10n.sellClearCartBody),
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
    final vm = context.read<SellCartViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final result = await showDiscountEditSheet(
      context,
      title: l10n.sellInvoiceDiscountTitle,
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
    final vm = context.watch<SellCartViewModel>();
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/sell')),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocalizations.of(context)!.sellScreenTitle),
            Text(
              state.nextInvoiceNo ??
                  AppLocalizations.of(context)!.sellNewInvoiceLabel,
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
              tooltip: AppLocalizations.of(context)!.sellClearCartTooltip,
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _confirmClearCart,
            ),
        ],
      ),
      body: _buildBody(context, vm, state),
    );
  }

  /// جسم الشاشة بحرّاس خروج مبكرين — نفس دلالة السلاسل المتداخلة
  /// الأصلية حرفياً: تحميل ← خطأ ← المحتوى.
  Widget _buildBody(
    BuildContext context,
    SellCartViewModel vm,
    SellCartState state,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (state.loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: const [ListSkeleton()],
      );
    }
    if (state.error != null) {
      return ListView(
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
      );
    }
    // UX-2a — أسماء أسطر البيع تحت التكلفة (فارغة عند إيقاف التحذير).
    final belowCostNames = vm.belowCostLineNames;
    return SafeArea(
      top: false,
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                SellTargetsStrip(
                  expanded: _headerExpanded,
                  onToggle: () =>
                      setState(() => _headerExpanded = !_headerExpanded),
                  onPickCustomer: _openCustomerPicker,
                  onPickCash: () =>
                      context.read<SellCartViewModel>().setCashCustomer(),
                  onPickCurrency: (currencyId) =>
                      context.read<SellCartViewModel>().setCurrency(currencyId),
                ),
                const SizedBox(height: 12),
                if (state.postError != null) ...[
                  SellPostErrorBanner(message: state.postError!),
                  const SizedBox(height: 12),
                ],
                // UX-2a — `invoicing.discount_below_margin`: لافتة
                // تحذير عند بيع أسطر تحت التكلفة (تحذير لا منع).
                if (belowCostNames.isNotEmpty) ...[
                  SellBelowCostBanner(lineNames: belowCostNames),
                  const SizedBox(height: 12),
                ],
                if (state.lines.isEmpty)
                  SellEmptyCart(onAdd: _openItemPicker)
                else
                  for (var i = 0; i < state.lines.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SellCartLineCard(index: i),
                    ),
              ],
            ),
          ),
          SellBottomBar(
            onAddItem: _openItemPicker,
            onPay: _openPayment,
            onSaveQuotation: _saveQuotation,
            onInvoiceDiscount: _editInvoiceDiscount,
          ),
        ],
      ),
    );
  }
}
