/// شاشة البيع/الكاشير — قلب التطبيق. **V4: هيكل نموذج فاتورة Simple
/// Invoice Manager** (لقطة 062621 + المرجع التصميمي §3.7)، و**V6-B:
/// تبويبا نموذج الإدخال/معاينة فوق الجسم** (نمط النموذج الأولي) والمعاينة
/// ورقة A4 حية من المسودة (`SimInvoiceA4Preview`):
///
/// سطر INV العلوي (رقم كبير عريض + تاريخ بأيقونة تقويم) ← أكورديون
/// العميل (أبيض) ← شريط «إجمالي عناصر» الأزرق النشط (يتوسع لقائمة
/// البنود + زر «اضافة عنصر» المربع) ← أكورديون الخصومات ← شريط
/// «مجموع» الداكن ← شريط الإجراءات السفلي الرباعي (حفظ/عرض سعر/خصم/
/// أكثر).
///
/// **آلية التبويب ملزمة**: تبديل شرطي `if` لا IndexedStack — في كل لحظة
/// شجرة وضع واحد فقط (لا ازدواج find.text باختبارات V4 القائمة)، وحالة
/// الأكورديونات (`_clientExpanded` إلخ) تسكن State فتبقى محفوظة عبر
/// الذهاب للمعاينة والعودة. الشريط السفلي واحد مشترك خارج التبديل
/// (ظاهر في الوضعين كالنموذج الأولي).
///
/// الأفعال كلها كما كانت حرفياً (§6.5): منتقي العميل/النقدي، منتقي
/// الصنف، نافذة الدفع (الترحيل)، حفظ كعرض سعر، خصم الفاتورة/السطر،
/// تفريغ السلة، بوابة FX وإشعارات الباركود — إعادة تصميم جلدية لا
/// تكسر أي سلوك مختبر.
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
import '../../../core/widgets/sim_list_widgets.dart';
import '../view_models/print_on_save.dart';
import '../view_models/sell_cart_session.dart';
import '../view_models/sell_cart_view_model.dart';
import 'widgets/customer_picker_sheet.dart';
import 'widgets/fx_rate_gate_sheet.dart';
import 'widgets/invoice_pdf_preview.dart';
import 'widgets/item_picker_sheet.dart';
import 'widgets/payment_sheet.dart';
import 'widgets/sell_cart_banners.dart';
import 'widgets/sell_cart_line_card.dart';
import 'widgets/sell_checkout_helpers.dart';
import 'widgets/sell_targets_strip.dart';
import 'widgets/sell_widgets.dart';
import 'widgets/sim_invoice_a4_preview.dart';
import 'widgets/sim_invoice_widgets.dart';
import '../../../core/widgets/amount_text.dart';

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
  bool _clientExpanded = false;
  bool _itemsExpanded = true;
  bool _discountsExpanded = false;
  bool _fxGateOpen = false;
  bool _noticeShown = false;

  /// V6-B — وضع العرض: 0 نموذج الإدخال، 1 معاينة A4. تبديل شرطي `if`
  /// (لا IndexedStack) فشجرة وضع واحد فقط بالشاشة في كل لحظة، وحالة
  /// الأكورديونات تسكن State فتبقى محفوظة عبر الذهاب والعودة.
  int _modeTab = 0;

  /// النموذج يُخزَّن حقلاً — قراءة context داخل dispose غير آمنة (عنصر
  /// معطّل) وتكسر تفكيك الشجرة عند مغادرة الكاشير (أصل استثناء Hero
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

  /// قائمة «أكثر» السفلية (SIM — الشريط الرباعي): تفريغ السلة وإضافة
  /// صنف — أفعال ثانوية تُخرج من الشريط الرئيسي.
  Future<void> _openMoreMenu() async {
    final l10n = AppLocalizations.of(context)!;
    final state = context.read<SellCartViewModel>().state;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_shopping_cart_rounded),
              title: Text(l10n.sellAddItem),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(_openItemPicker());
              },
            ),
            ListTile(
              enabled: state.lines.isNotEmpty,
              leading: const Icon(Icons.delete_sweep_rounded),
              title: Text(l10n.sellClearCartTooltip),
              onTap: state.lines.isEmpty
                  ? null
                  : () {
                      Navigator.of(sheetContext).pop();
                      unawaited(_confirmClearCart());
                    },
            ),
          ],
        ),
      ),
    );
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
    final priced = vm.pricedCart;
    final hasError = vm.cartError != null;
    final canPay =
        !state.posting &&
        state.lines.isNotEmpty &&
        !hasError &&
        state.warehouseId != null;
    final canQuotation = !state.posting && state.lines.isNotEmpty && !hasError;
    final decimals = _decimalsFor(priced?.totals.grandTotal);
    final itemsTotal = priced?.totals.subtotal;
    final discountsTotal = priced == null
        ? null
        : priced.totals.lineDiscountsTotal + priced.totals.invoiceDiscount;
    final grandTotal = priced?.totals.grandTotal;

    return SafeArea(
      top: false,
      bottom: false,
      child: Column(
        children: [
          // V6-B — تبويبا نموذج/معاينة فوق الجسم مباشرة (تحت الـAppBar)
          // بنمط النموذج الأولي — الافتراضي نموذج الإدخال.
          SimModeTabs(
            tabs: [
              SimModeTabSpec(
                label: l10n.simModeTabForm,
                onTap: () {
                  if (_modeTab != 0) setState(() => _modeTab = 0);
                },
              ),
              SimModeTabSpec(
                label: l10n.simModeTabPreview,
                onTap: () {
                  if (_modeTab != 1) setState(() => _modeTab = 1);
                },
              ),
            ],
            selectedIndex: _modeTab,
          ),
          // تبديل شرطي `if` (لا IndexedStack) — شجرة وضع واحد فقط في كل
          // لحظة؛ حالة الأكورديونات تسكن State فتبقى محفوظة عبر العودة.
          Expanded(
            child: _modeTab == 0
                ? ListView(
                    padding: const EdgeInsets.only(bottom: 12),
                    children: [
                      // سطر INV العلوي — الرقم كبير عريض + التاريخ بتقويم.
                      SimInvoiceTopRow(
                        invoiceNo:
                            state.nextInvoiceNo ?? l10n.sellNewInvoiceLabel,
                      ),
                      if (state.postError != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: SellPostErrorBanner(message: state.postError!),
                        ),
                      // UX-2a — `invoicing.discount_below_margin`: لافتة
                      // تحذير عند بيع أسطر تحت التكلفة (تحذير لا منع).
                      if (belowCostNames.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: SellBelowCostBanner(lineNames: belowCostNames),
                        ),

                      // أكورديون العميل — أبيض بأيقونة شخص واسم حي.
                      SellClientSection(
                        expanded: _clientExpanded,
                        onToggle: () =>
                            setState(() => _clientExpanded = !_clientExpanded),
                        onPickCustomer: _openCustomerPicker,
                        onPickCash: () =>
                            context.read<SellCartViewModel>().setCashCustomer(),
                        onPickCurrency: (currencyId) => context
                            .read<SellCartViewModel>()
                            .setCurrency(currencyId),
                      ),

                      // شريط «إجمالي عناصر» الأزرق — رأس قسم البنود.
                      SimItemsTotalBar(
                        label: l10n.simItemsTotalTitle,
                        amount: itemsTotal == null
                            ? '0'
                            : AmountText.formatFor(
                                context,
                                itemsTotal,
                                decimals,
                              ),
                        itemCount: state.lines.length,
                        expanded: _itemsExpanded,
                        onToggle: () =>
                            setState(() => _itemsExpanded = !_itemsExpanded),
                      ),
                      if (_itemsExpanded) ...[
                        if (state.lines.isEmpty)
                          SellEmptyCart(onAdd: _openItemPicker)
                        else
                          for (var i = 0; i < state.lines.length; i++)
                            Padding(
                              // 10px فاصلة بين البطاقات وبين الشريط الأزرق
                              // والأولى — إيقاع القائمة القديم نفسه.
                              padding: EdgeInsets.fromLTRB(
                                12,
                                i == 0 ? 10 : 0,
                                12,
                                10,
                              ),
                              child: SellCartLineCard(index: i),
                            ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: SimAddItemSquareButton(
                            label: l10n.sellAddItem,
                            onTap: _openItemPicker,
                          ),
                        ),
                      ],

                      // أكورديون الخصومات — خصم الرأس + ملخص خصوم الأسطر.
                      if (state.showDiscounts)
                        _DiscountsSection(
                          expanded: _discountsExpanded,
                          onToggle: () => setState(
                            () => _discountsExpanded = !_discountsExpanded,
                          ),
                          discountsTotal: discountsTotal,
                          lineDiscountsTotal: priced?.totals.lineDiscountsTotal,
                          invoiceDiscount: priced?.totals.invoiceDiscount,
                          decimals: decimals,
                          onEditInvoiceDiscount: _editInvoiceDiscount,
                        ),

                      // شريط «مجموع» الداكن — الصافي بعد الخصومات.
                      SimDarkTotalBar(
                        label: l10n.simTotalBarLabel,
                        amount: grandTotal == null
                            ? '0'
                            : AmountText.formatFor(
                                context,
                                grandTotal,
                                decimals,
                              ),
                      ),
                    ],
                  )
                : _buildA4Preview(context, vm, state),
          ),
          if (hasError) _CartErrorStrip(message: vm.cartError!),
          SimBottomActionBar(
            items: [
              SimBottomActionItem(
                icon: Icons.save_rounded,
                label: l10n.simActionSave,
                onTap: _openPayment,
                enabled: canPay,
                primary: true,
              ),
              SimBottomActionItem(
                icon: Icons.request_quote_rounded,
                label: l10n.sellSaveQuotation,
                onTap: _saveQuotation,
                enabled: canQuotation,
              ),
              if (state.showDiscounts)
                SimBottomActionItem(
                  icon: Icons.percent_rounded,
                  label: l10n.sellInvoiceDiscountButton,
                  onTap: _editInvoiceDiscount,
                  enabled: !state.posting,
                ),
              SimBottomActionItem(
                icon: Icons.more_horiz_rounded,
                label: l10n.simMoreActionsTitle,
                onTap: _openMoreMenu,
                enabled: !state.posting,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// V6-B — تبويب المعاينة: ورقة A4 حية من المسودة الحالية (قارئة
  /// فقط) تملأ منطقة العرض على الأقل (`SliverFillRemaining`) وتتمرر عند
  /// فيض المحتوى — خلفية منطقة A4 من `SimA4Sheet.pageBackgroundOf`.
  Widget _buildA4Preview(
    BuildContext context,
    SellCartViewModel vm,
    SellCartState state,
  ) {
    final app = context.read<AppController>();
    final l10n = AppLocalizations.of(context)!;
    final priced = vm.pricedCart;
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: SimInvoiceA4Preview(
            invoiceNo: state.nextInvoiceNo ?? l10n.sellNewInvoiceLabel,
            customer: state.customer,
            pricedCart: priced,
            companyName: app.company?.name ?? '',
            currencyCode: state.selectedCurrency?.code,
            decimals: _decimalsFor(priced?.totals.grandTotal),
          ),
        ),
      ],
    );
  }
}

/// أكورديون الخصومات (SIM — «خصم والقروض») بمحتوى نطاقنا: زر خصم
/// الفاتورة (يفتح المحرر القائم) + ملخصَي خصم الأسطر وخصم الرأس.
class _DiscountsSection extends StatelessWidget {
  const _DiscountsSection({
    required this.expanded,
    required this.onToggle,
    required this.discountsTotal,
    required this.lineDiscountsTotal,
    required this.invoiceDiscount,
    required this.decimals,
    required this.onEditInvoiceDiscount,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final double? discountsTotal;
  final double? lineDiscountsTotal;
  final double? invoiceDiscount;
  final int decimals;
  final VoidCallback onEditInvoiceDiscount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        SimAccordionHeader(
          icon: Icons.percent_rounded,
          title: l10n.simDiscountsTitle,
          trailingAmount: discountsTotal == null
              ? null
              : AmountText.formatFor(context, discountsTotal!, decimals),
          expanded: expanded,
          onToggle: onToggle,
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: onEditInvoiceDiscount,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(l10n.sellInvoiceDiscountButton),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                ),
                if ((lineDiscountsTotal ?? 0) > 0) ...[
                  const SizedBox(height: 10),
                  _SummaryRow(
                    label: l10n.sellTotalsLineDiscounts,
                    value: AmountText.formatFor(
                      context,
                      lineDiscountsTotal!,
                      decimals,
                    ),
                  ),
                ],
                if ((invoiceDiscount ?? 0) > 0) ...[
                  _SummaryRow(
                    label: l10n.sellTotalsInvoiceDiscount,
                    value: AmountText.formatFor(
                      context,
                      invoiceDiscount!,
                      decimals,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: FinText.tabularNums,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// شريط خطأ السلة الرقيق فوق شريط الإجراءات — رفض آخر ترحيل يبقى
/// مرئياً بلا إزاحة للبنود.
class _CartErrorStrip extends StatelessWidget {
  const _CartErrorStrip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: colors.errorContainer,
      child: Text(
        message,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colors.onErrorContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// تنسيقات المبالغ المشتركة للشاشة — أرقام صحيحة بلا كسور إلا عند
/// الحاجة (نفس منطق الشريط السفلي القديم).
int _decimalsFor(double? value) =>
    value == null || value == value.truncateToDouble() ? 0 : 2;
