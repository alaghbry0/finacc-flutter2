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

import '../../../../domain/models/sale.dart';
import '../../../../domain/services/credit_limit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/status_chip.dart';
import '../view_models/sell_cart_session.dart';
import '../view_models/sell_cart_view_model.dart';
import 'widgets/customer_picker_sheet.dart';
import 'widgets/fx_rate_gate_sheet.dart';
import 'widgets/item_picker_sheet.dart';
import 'widgets/payment_sheet.dart';
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

  @override
  void initState() {
    super.initState();
    final vm = context.read<SellCartViewModel>();
    vm.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    context.read<SellCartViewModel>().removeListener(_onCartChanged);
    super.dispose();
  }

  /// ردود الفعل للحالات العابرة: بوابة FX (FR-08-09) وإشعارات الباركود.
  void _onCartChanged() {
    final vm = context.read<SellCartViewModel>();
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
      creditGate: () => _resolveCreditGate(app, vm),
    );
    if (posted) {
      vm.dismissReceipt();
    }
  }

  /// يجلب معطيات بوابة حد الائتمان — null عند غياب العميل/المستودعات
  /// (عميل نقدي مجهول: لا آجل أصلاً فلا فحص — FR-03-05).
  Future<CreditLimitGate?> _resolveCreditGate(
    AppController app,
    SellCartViewModel vm,
  ) async {
    final customerId = vm.state.customer?.id;
    final currencyId = vm.state.currencyId;
    if (customerId == null || currencyId == null) return null;
    final customers = app.customers;
    final settings = app.settings;
    if (customers == null || settings == null) return null;
    // checkCredit يقرأ الحد من جدول العميل والرصيد بصيغة FR-03-02
    // بعملة الفاتورة (لا الحقل المخزَّن في السلة — دائماً حي).
    final check = await customers.checkCredit(customerId, currencyId, 0);
    final action = await settings.getString(
      'parties.credit_limit_action',
      'warn',
    );
    return CreditLimitGate(
      creditLimit: check.creditLimit,
      action: action,
      currentBalance: check.balance,
    );
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

  // ── البناء ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SellCartViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/sell')),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.sellScreenTitle),
            Text(
              state.nextInvoiceNo ?? l10n.sellNewInvoiceLabel,
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
              tooltip: l10n.sellClearCartTooltip,
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _confirmClearCart,
            ),
        ],
      ),
      body: state.loading
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: const [ListSkeleton(rows: 6)],
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
                        _TargetsStrip(
                          expanded: _headerExpanded,
                          onToggle: () => setState(
                            () => _headerExpanded = !_headerExpanded,
                          ),
                          onPickCustomer: _openCustomerPicker,
                          onPickCash: () => context
                              .read<SellCartViewModel>()
                              .setCashCustomer(),
                          onPickCurrency: (currencyId) => context
                              .read<SellCartViewModel>()
                              .setCurrency(currencyId),
                        ),
                        const SizedBox(height: 12),
                        if (state.postError != null) ...[
                          _PostErrorBanner(message: state.postError!),
                          const SizedBox(height: 12),
                        ],
                        if (state.lines.isEmpty)
                          _EmptyCart(onAdd: _openItemPicker)
                        else
                          for (var i = 0; i < state.lines.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _CartLineCard(index: i),
                            ),
                      ],
                    ),
                  ),
                  _BottomBar(
                    onAddItem: _openItemPicker,
                    onPay: _openPayment,
                    onSaveQuotation: _saveQuotation,
                    onInvoiceDiscount: _editInvoiceDiscount,
                  ),
                ],
              ),
            ),
    );
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
}

/// شريط الأهداف القابل للطي (عميل + عملة + تاريخ) — §6.5.
class _TargetsStrip extends StatelessWidget {
  const _TargetsStrip({
    required this.expanded,
    required this.onToggle,
    required this.onPickCustomer,
    required this.onPickCash,
    required this.onPickCurrency,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onPickCustomer;
  final VoidCallback onPickCash;
  final ValueChanged<int> onPickCurrency;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SellCartViewModel>();
    final state = vm.state;
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    final customerLabel = state.customer?.name ?? l10n.sellCashCustomer;
    final currency = state.selectedCurrency;
    return FinCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Icon(
                  Icons.person_pin_circle_rounded,
                  color: scheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    customerLabel,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                StatusChip(
                  label: currency?.code ?? '—',
                  tone: ChipTone.brand,
                  dense: true,
                ),
                const SizedBox(width: 8),
                Text(
                  sellFormatDate(now),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontFeatures: FinText.tabularNums,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 240),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onPickCustomer,
                          icon: const Icon(Icons.search_rounded, size: 18),
                          label: Text(l10n.sellPickCustomer),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onPickCash,
                          icon: const Icon(Icons.person_off_outlined, size: 18),
                          label: Text(l10n.sellCashCustomer),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CurrencyPickerRow(
                    currencies: [
                      for (final c in state.currencies)
                        CurrencyOption(
                          id: c.id,
                          code: c.code,
                          isBase: c.isBase,
                          rateKnown: c.isBase || c.id == state.currencyId
                              ? state.rateKnown
                              : true,
                        ),
                    ],
                    selectedId: state.currencyId,
                    todayRate: state.todayRate,
                    onSelect: onPickCurrency,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// لافتة رفض الترحيل — رسالة عربية واضحة والسلة محفوظة.
class _PostErrorBanner extends StatelessWidget {
  const _PostErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = FinColors.of(context);
    return FinCard(
      padding: const EdgeInsets.all(14),
      accent: colors.negative,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: colors.negative, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              tooltip: AppLocalizations.of(context)!.commonDone,
              onPressed: () =>
                  context.read<SellCartViewModel>().clearPostError(),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

/// حالة السلة الفارغة — CTA واحد كبير لإضافة أول صنف.
class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: l10n.sellEmptyCartTitle,
        message: l10n.sellEmptyCartBody,
        actionLabel: l10n.sellAddItem,
        onAction: onAdd,
      ),
    );
  }
}

/// بطاقة سطر سلة واحدة — qty stepper + سعر قابل للتعديل + خصم سطر +
/// إجمالي السطر الحي + «المتاح: N» بتحذير التجاوز (FR-02-02) + حذف بسحب.
class _CartLineCard extends StatelessWidget {
  const _CartLineCard({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SellCartViewModel>();
    final state = vm.state;
    if (index >= state.lines.length) return const SizedBox.shrink();
    final line = state.lines[index];
    final pricedLine = vm.pricedCart?.lines[index];
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final netFinal = pricedLine?.netFinal ?? line.qty * line.unitPrice;

    return Dismissible(
      key: ValueKey('cart_line_${line.productId}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => vm.removeLine(index),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: colors.negativeContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_rounded, color: colors.onNegativeContainer),
      ),
      child: FinCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: (line.isService ? scheme.tertiary : scheme.primary)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    line.isService
                        ? Icons.miscellaneous_services_rounded
                        : Icons.inventory_2_rounded,
                    size: 19,
                    color: line.isService ? scheme.tertiary : scheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.name,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      if (line.availableQty != null)
                        Text(
                          line.exceedsAvailable
                              ? l10n.sellLineOverAvailable(
                                  sellQtyText(line.availableQty!),
                                )
                              : l10n.sellLineAvailable(
                                  sellQtyText(line.availableQty!),
                                ),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: line.exceedsAvailable
                                    ? colors.negative
                                    : scheme.onSurfaceVariant,
                                fontWeight: line.exceedsAvailable
                                    ? FontWeight.w800
                                    : FontWeight.w400,
                                fontFeatures: FinText.tabularNums,
                              ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AmountText(amount: netFinal, decimals: _decimals(netFinal)),
                    Text(
                      l10n.sellLineTotal,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                QtyStepper(
                  qty: line.qty,
                  onChanged: (qty) => vm.setQty(index, qty),
                ),
                const Spacer(),
                _PriceButton(
                  price: line.unitPrice,
                  onTap: () async {
                    final value = await showNumberEditSheet(
                      context,
                      title: l10n.sellEditPriceTitle(line.name),
                      initial: line.unitPrice,
                      confirmLabel: l10n.commonConfirm,
                      icon: Icons.sell_outlined,
                    );
                    if (value != null) {
                      vm.setUnitPrice(index, value);
                    }
                  },
                ),
                const SizedBox(width: 8),
                _LineDiscountChip(
                  type: line.discountType,
                  value: line.discountValue,
                  onTap: () async {
                    final result = await showDiscountEditSheet(
                      context,
                      title: l10n.sellLineDiscountTitle(line.name),
                      initialType: line.discountType,
                      initialValue: line.discountValue,
                    );
                    if (result != null) {
                      vm.setLineDiscount(index, result.$1, result.$2);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static int _decimals(double value) =>
      value == value.truncateToDouble() ? 0 : 2;
}

class _PriceButton extends StatelessWidget {
  const _PriceButton({required this.price, required this.onTap});

  final double price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AmountText(
              amount: price,
              decimals: price == price.truncateToDouble() ? 0 : 2,
            ),
            Text(
              l10n.sellUnitPriceLabel,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineDiscountChip extends StatelessWidget {
  const _LineDiscountChip({
    required this.type,
    required this.value,
    required this.onTap,
  });

  final SaleDiscountType type;
  final double value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final label = value <= 0
        ? l10n.sellLineDiscountNone
        : type == SaleDiscountType.percent
        ? l10n.sellLineDiscountPercent(value.toStringAsFixed(0))
        : l10n.sellLineDiscountAmount(value.toStringAsFixed(2));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: value > 0
              ? colors.negativeContainer
              : Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value > 0 ? Icons.discount_rounded : Icons.add_rounded,
              size: 15,
              color: value > 0 ? colors.onNegativeContainer : null,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: value > 0 ? colors.onNegativeContainer : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// الشريط السفلي الثابت — ملخص حي + خصم الفاتورة + الدفع + عرض السعر.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.onAddItem,
    required this.onPay,
    required this.onSaveQuotation,
    required this.onInvoiceDiscount,
  });

  final VoidCallback onAddItem;
  final VoidCallback onPay;
  final VoidCallback onSaveQuotation;
  final VoidCallback onInvoiceDiscount;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SellCartViewModel>();
    final state = vm.state;
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final priced = vm.pricedCart;
    final hasError = vm.cartError != null;
    final canPay =
        !state.posting &&
        state.lines.isNotEmpty &&
        !hasError &&
        state.warehouseId != null;

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
              Row(
                children: [
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: onAddItem,
                      icon: const Icon(
                        Icons.add_shopping_cart_rounded,
                        size: 20,
                      ),
                      label: Text(l10n.sellAddItem),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: onInvoiceDiscount,
                      icon: Icon(
                        state.invoiceDiscountValue > 0
                            ? Icons.discount_rounded
                            : Icons.percent_rounded,
                        size: 20,
                        color: state.invoiceDiscountValue > 0
                            ? colors.negative
                            : null,
                      ),
                      label: Text(
                        state.invoiceDiscountValue > 0
                            ? (state.invoiceDiscountType ==
                                      SaleDiscountType.percent
                                  ? l10n.sellInvoiceDiscountPercent(
                                      state.invoiceDiscountValue
                                          .toStringAsFixed(0),
                                    )
                                  : l10n.sellInvoiceDiscountAmount(
                                      state.invoiceDiscountValue
                                          .toStringAsFixed(2),
                                    ))
                            : l10n.sellInvoiceDiscountButton,
                      ),
                    ),
                  ),
                ],
              ),
              if (priced != null) ...[
                const SizedBox(height: 8),
                CartTotalsPanel(
                  totals: priced.totals,
                  currencyCode: state.selectedCurrency?.code,
                ),
              ],
              if (hasError) ...[
                const SizedBox(height: 8),
                Text(
                  vm.cartError!,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.negative,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: canPay ? onPay : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        textStyle: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      icon: const Icon(Icons.payments_rounded),
                      label: Text(
                        priced == null
                            ? l10n.sellPayButton
                            : l10n.sellPayButtonWithTotal(
                                AmountText.formatFor(
                                  context,
                                  priced.totals.grandTotal,
                                  priced.totals.grandTotal ==
                                          priced.totals.grandTotal
                                              .truncateToDouble()
                                      ? 0
                                      : 2,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          state.lines.isEmpty || hasError || state.posting
                          ? null
                          : onSaveQuotation,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      icon: const Icon(Icons.request_quote_rounded, size: 20),
                      label: Text(l10n.sellSaveQuotation),
                    ),
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
