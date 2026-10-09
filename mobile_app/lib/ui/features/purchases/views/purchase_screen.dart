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

import '../../../../domain/models/purchase.dart';
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
import '../view_models/purchase_cart_session.dart';
import '../view_models/purchase_cart_view_model.dart';
import 'widgets/purchase_fx_gate_sheet.dart';
import 'widgets/purchase_item_picker_sheet.dart';
import 'widgets/purchase_payment_sheet.dart';
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
                          onPickSupplier: _openSupplierPicker,
                          onPickCurrency: (currencyId) => context
                              .read<PurchaseCartViewModel>()
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
                              child: _PurchaseLineCard(index: i),
                            ),
                      ],
                    ),
                  ),
                  _BottomBar(
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

/// شريط الأهداف القابل للطي (مورد + عملة + تاريخ) — مرآة الكاشير.
class _TargetsStrip extends StatelessWidget {
  const _TargetsStrip({
    required this.expanded,
    required this.onToggle,
    required this.onPickSupplier,
    required this.onPickCurrency,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onPickSupplier;
  final ValueChanged<int> onPickCurrency;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PurchaseCartViewModel>();
    final state = vm.state;
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    final supplierLabel = state.supplier?.name ?? l10n.purSupplierRequired;
    final currency = state.selectedCurrency;
    return FinCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const Key('pur_targets_toggle'),
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Icon(
                  Icons.local_shipping_rounded,
                  color: scheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    supplierLabel,
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
                  purFormatDate(now),
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
                  OutlinedButton.icon(
                    key: const Key('pur_pick_supplier_button'),
                    onPressed: onPickSupplier,
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: Text(l10n.purPickSupplier),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  const SizedBox(height: 12),
                  PurchaseCurrencyPickerRow(
                    currencies: [
                      for (final c in state.currencies)
                        PurchaseCurrencyOption.fromCurrency(
                          c,
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

/// لافتة رفض الترحيل — رسالة عربية واضحة والفاتورة محفوظة.
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
                  context.read<PurchaseCartViewModel>().clearPostError(),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

/// حالة الفاتورة الفارغة — CTA واحد كبير لإضافة أول صنف.
class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: EmptyState(
        icon: Icons.add_shopping_cart_outlined,
        title: l10n.purEmptyCartTitle,
        message: l10n.purEmptyCartBody,
        actionLabel: l10n.purAddItem,
        onAction: onAdd,
      ),
    );
  }
}

/// بطاقة سطر شراء واحدة — qty stepper + تكلفة الوحدة + خصم سطر + إجمالي
/// السطر الحي + الرصيد الحالي (معلوماتي) + **دفعة واردة** (رقم + صلاحية)
/// للأصناف المتتبعة + حذف بسحب.
class _PurchaseLineCard extends StatelessWidget {
  const _PurchaseLineCard({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PurchaseCartViewModel>();
    final state = vm.state;
    if (index >= state.lines.length) return const SizedBox.shrink();
    final line = state.lines[index];
    final pricedLine = vm.pricedCart?.lines[index];
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final netFinal = pricedLine?.netFinal ?? line.qty * line.unitCost;

    return Dismissible(
      key: ValueKey('purchase_line_${line.productId}_$index'),
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
                      if (line.currentStock != null)
                        Text(
                          l10n.purLineStock(purQtyText(line.currentStock!)),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
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
                    AmountText(
                      amount: netFinal,
                      decimals: netFinal == netFinal.truncateToDouble() ? 0 : 2,
                    ),
                    Text(
                      l10n.sellLineTotal,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // R16-a — بونص الشراء: حقل «كمية مجانية» صغير بجانب الكمية
            // **دائم التوفر للإدخال** (لا بوابة إعدادات)؛ وحين وجوده تعرض
            // الشارة «+N مجاني». السعر والخصم بسطر مستقل أسفلها — صف
            // الكمية + الشارة + التكلفة + الخصم معاً يفيض على 390dp
            // (نفس خلل الكاشير الموثّق بـ UX-4-finish).
            Row(
              children: [
                PurchaseQtyStepper(
                  qty: line.qty,
                  onChanged: (qty) => vm.setQty(index, qty),
                  // R17-a — نقرة قيمة الكمية: تحرير رقمي فوري بنفس قيود
                  // setQty (> 0) — الكاشير يكتب 7 أو 2.5 مباشرة.
                  onValueTap: () async {
                    final value = await showPurchaseNumberEditSheet(
                      context,
                      title: l10n.purchaseQtyEditTitle(line.name),
                      initial: line.qty,
                      confirmLabel: l10n.commonConfirm,
                      allowZero: false,
                      decimals: 3,
                      icon: Icons.edit_outlined,
                    );
                    if (value != null && value > 0) {
                      vm.setQty(index, value);
                    }
                  },
                ),
                const SizedBox(width: 8),
                _PurchaseBonusChip(
                  freeQty: line.freeQty,
                  onTap: () async {
                    final value = await showPurchaseNumberEditSheet(
                      context,
                      title: l10n.purBonusEditTitle(line.name),
                      initial: line.freeQty,
                      confirmLabel: l10n.commonConfirm,
                      allowZero: true,
                      decimals: 3,
                      icon: Icons.redeem_outlined,
                    );
                    if (value != null) {
                      vm.setFreeQty(index, value);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Spacer(),
                _CostButton(
                  cost: line.unitCost,
                  onTap: () async {
                    final value = await showPurchaseNumberEditSheet(
                      context,
                      title: l10n.purEditCostTitle(line.name),
                      initial: line.unitCost,
                      confirmLabel: l10n.commonConfirm,
                      icon: Icons.sell_outlined,
                    );
                    if (value != null) {
                      vm.setUnitCost(index, value);
                    }
                  },
                ),
                const SizedBox(width: 8),
                _LineDiscountChip(
                  type: line.discountType,
                  value: line.discountValue,
                  onTap: () async {
                    final result = await showPurchaseDiscountEditSheet(
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
            if (!line.isService && line.trackBatches) ...[
              const SizedBox(height: 10),
              _IncomingBatchSection(index: index),
            ],
          ],
        ),
      ),
    );
  }
}

/// حقل الكمية المجانية (بونص) الصغير بجوار الكمية (R16-a) — **دائم
/// التوفر للإدخال**: «بونص» عند الصفر و«+N مجاني» عند وجوده؛ نقرة تفتح
/// محرر الرقم السفلي (الصفر يمسح). البونص لا يدخل المستحق للمورد —
/// المستلم الكلي (qty + freeQty) يدخل المخزون ويخفّض WAC.
class _PurchaseBonusChip extends StatelessWidget {
  const _PurchaseBonusChip({required this.freeQty, required this.onTap});

  final double freeQty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final hasBonus = freeQty > 0.000001;
    final label = hasBonus
        ? l10n.bonusQtyChipValue(purQtyText(freeQty))
        : l10n.bonusQtyChipEmpty;
    return InkWell(
      key: const Key('pur_line_bonus_chip'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: hasBonus
              ? colors.positiveContainer
              : Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.redeem_rounded,
              size: 15,
              color: hasBonus ? colors.onPositiveContainer : null,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: hasBonus ? colors.onPositiveContainer : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// زر تكلفة الوحدة — قابل للنقر للتعديل.
class _CostButton extends StatelessWidget {
  const _CostButton({required this.cost, required this.onTap});

  final double cost;
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
              amount: cost,
              decimals: cost == cost.truncateToDouble() ? 0 : 2,
            ),
            Text(
              l10n.purUnitCostLabel,
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

  final PurchaseDiscountType type;
  final double value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final label = value <= 0
        ? l10n.sellLineDiscountNone
        : type == PurchaseDiscountType.percent
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

/// قسم الدفعة الواردة لسطر متتبع — رقم الدفعة (حقل نصي) + الصلاحية
/// (رقاقة التاريخ + اختصارات +30/+90/+180 يوماً وسنة + التقويم).
class _IncomingBatchSection extends StatefulWidget {
  const _IncomingBatchSection({required this.index});

  final int index;

  @override
  State<_IncomingBatchSection> createState() => _IncomingBatchSectionState();
}

class _IncomingBatchSectionState extends State<_IncomingBatchSection> {
  late final TextEditingController _batchController;

  @override
  void initState() {
    super.initState();
    final line = context
        .read<PurchaseCartViewModel>()
        .state
        .lines[widget.index];
    _batchController = TextEditingController(text: line.batchNo);
  }

  @override
  void didUpdateWidget(covariant _IncomingBatchSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // مزامنة الحقل عند تغيّر قيمة السطر من خارج الحقل (تفريغ الفاتورة).
    final line = context
        .read<PurchaseCartViewModel>()
        .state
        .lines[widget.index];
    if (_batchController.text != line.batchNo) {
      _batchController.text = line.batchNo;
    }
  }

  @override
  void dispose() {
    _batchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PurchaseCartViewModel>();
    final state = vm.state;
    if (widget.index >= state.lines.length) return const SizedBox.shrink();
    final line = state.lines[widget.index];
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final missingBatch = line.batchNo.trim().isEmpty;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: missingBatch
              ? colors.warning.withValues(alpha: 0.7)
              : scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.layers_rounded,
                size: 16,
                color: missingBatch ? colors.warning : scheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.purIncomingBatchTitle,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: missingBatch ? colors.warning : scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: Key('pur_batch_field_${widget.index}'),
            controller: _batchController,
            onChanged: (value) => vm.setBatchNo(widget.index, value),
            decoration: InputDecoration(
              hintText: l10n.purBatchNoHint,
              isDense: true,
              prefixIcon: const Icon(Icons.tag_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  key: Key('pur_expiry_chip_${widget.index}'),
                  onTap: () => _pickExpiry(context, vm),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: line.expiryDate == null
                          ? colors.warningContainer
                          : scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_rounded,
                          size: 16,
                          color: line.expiryDate == null
                              ? colors.onWarningContainer
                              : scheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            line.expiryDate == null
                                ? l10n.purExpiryPick
                                : l10n.purExpiryValue(
                                    purFormatIsoDate(line.expiryDate!),
                                  ),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: line.expiryDate == null
                                      ? colors.onWarningContainer
                                      : scheme.onPrimaryContainer,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (label, days) in [
                (l10n.purExpiryQuickMonth, 30),
                (l10n.purExpiryQuick3Months, 90),
                (l10n.purExpiryQuick6Months, 180),
                (l10n.purExpiryQuickYear, 365),
              ])
                ActionChip(
                  key: Key('pur_expiry_quick_${days}_${widget.index}'),
                  label: Text(label),
                  onPressed: () => vm.setExpiry(
                    widget.index,
                    DateTime.now().add(Duration(days: days)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickExpiry(
    BuildContext context,
    PurchaseCartViewModel vm,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      helpText: l10n.purExpiryDialogTitle,
    );
    if (picked != null) {
      vm.setExpiry(widget.index, picked);
    }
  }
}

/// الشريط السفلي الثابت — ملخص حي + خصم الفاتورة + زر الترحيل الضخم.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.onAddItem,
    required this.onPost,
    required this.onInvoiceDiscount,
  });

  final VoidCallback onAddItem;
  final VoidCallback onPost;
  final VoidCallback onInvoiceDiscount;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PurchaseCartViewModel>();
    final state = vm.state;
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final priced = vm.pricedCart;
    final hasError = vm.cartError != null;
    final supplierMissing = state.supplier == null;
    final canPost =
        !state.posting &&
        state.lines.isNotEmpty &&
        !hasError &&
        !supplierMissing;

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
                      key: const Key('pur_add_item_button'),
                      onPressed: onAddItem,
                      icon: const Icon(
                        Icons.add_shopping_cart_rounded,
                        size: 20,
                      ),
                      label: Text(l10n.purAddItem),
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
                                      PurchaseDiscountType.percent
                                  ? l10n.sellInvoiceDiscountPercent(
                                      state.invoiceDiscountValue
                                          .toStringAsFixed(0),
                                    )
                                  : l10n.sellInvoiceDiscountAmount(
                                      state.invoiceDiscountValue
                                          .toStringAsFixed(2),
                                    ))
                            : l10n.purInvoiceDiscountButton,
                      ),
                    ),
                  ),
                ],
              ),
              if (priced != null) ...[
                const SizedBox(height: 8),
                PurchaseTotalsPanel(
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
              if (supplierMissing) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.purSupplierRequired,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              FilledButton.icon(
                key: const Key('pur_post_button'),
                onPressed: canPost ? onPost : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  textStyle: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                icon: const Icon(Icons.local_shipping_rounded),
                label: Text(
                  priced == null
                      ? l10n.purPayButton
                      : l10n.purPayButtonWithTotal(
                          AmountText.formatFor(
                            context,
                            priced.totals.grandTotal,
                            priced.totals.grandTotal ==
                                    priced.totals.grandTotal.truncateToDouble()
                                ? 0
                                : 2,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
