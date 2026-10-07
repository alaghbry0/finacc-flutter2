/// شاشتا المرتجعات المرتبطة (المرحلة 5 — FR-02-07/08):
/// - **مرتجع البيع SRN** (`/purchases/returns/sale`): اختيار فاتورة بيع
///   مكتملة → بنودها القابلة للإرجاع بكميات → اتجاه رد القيمة → ترحيل
///   ذرّي (الكمية تعود للمخزون بتكلفتها الأصلية — لا WAC يُلمس).
/// - **مرتجع الشراء PRN** (`/purchases/returns/purchase`): اختيار فاتورة
///   شراء مكتملة → البنود والكميات → ترحيل ذرّي (WAC يُعاد حسابه على
///   المتبقي بتكلفة الشراء الأصلية Snapshot + فحص تغطية المخزون).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/refresh_on_active.dart';
import '../../../core/widgets/status_chip.dart';
import '../view_models/returns_view_model.dart';
import 'widgets/purchase_widgets.dart';
import 'widgets/return_refund_sheet.dart';

/// شاشة مرتجع البيع (SRN) — من فاتورة بيع أصلية مكتملة.
class SaleReturnScreen extends StatelessWidget {
  const SaleReturnScreen({super.key, this.preselectedInvoiceId});

  /// فاتورة مسبقة الاختيار (وصول من تفاصيل فاتورة البيع).
  final int? preselectedInvoiceId;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final SaleReturnViewModel vm;
    vm = SaleReturnViewModel(
      saleRepo: app.sales!,
      returnRepo: app.returns!,
      preselectedInvoiceId: preselectedInvoiceId,
    );
    unawaited(vm.load(userIdLoader: app.companies!.findAdminUserId));
    return ChangeNotifierProvider<SaleReturnViewModel>.value(
      value: vm,
      // تحديث حي عند العودة من ترحيل مرتجع آخر (المتاح تغيّر — قاعدة §10).
      child: RefreshOnActive(
        routePattern: RegExp(r'^/purchases/returns/sale$'),
        onActivate: () => vm.load(userIdLoader: null),
        child: const _SaleReturnBody(),
      ),
    );
  }
}

class _SaleReturnBody extends StatelessWidget {
  const _SaleReturnBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SaleReturnViewModel>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/purchases')),
        title: Text(l10n.retSaleTitle),
      ),
      body: _buildBody(context, vm),
    );
  }

  Widget _buildBody(BuildContext context, SaleReturnViewModel vm) {
    final state = vm.state;
    if (state.loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: const [ListSkeleton(rows: 6)],
      );
    }
    if (state.error != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          ErrorState(
            title: AppLocalizations.of(context)!.genericErrorTitle,
            message: AppLocalizations.of(context)!.dbOpenErrorMessage,
            technicalDetails: state.error.toString(),
            retryLabel: AppLocalizations.of(context)!.commonRetry,
            onRetry: () => vm.load(userIdLoader: null),
            compact: true,
          ),
        ],
      );
    }
    switch (state.phase) {
      case ReturnPhase.pickingInvoice:
        return _InvoicePickerSection(vm: vm, isSale: true);
      case ReturnPhase.pickingLines:
        return _LinesSection(vm: vm, isSale: true);
      case ReturnPhase.done:
        return _DoneSection(vm: vm, isSale: true);
    }
  }
}

/// شاشة مرتجع الشراء (PRN) — من فاتورة شراء أصلية مكتملة.
class PurchaseReturnScreen extends StatelessWidget {
  const PurchaseReturnScreen({super.key, this.preselectedInvoiceId});

  /// فاتورة مسبقة الاختيار (وصول من تفاصيل فاتورة الشراء).
  final int? preselectedInvoiceId;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final PurchaseReturnViewModel vm;
    vm = PurchaseReturnViewModel(
      purchaseRepo: app.purchases!,
      returnRepo: app.returns!,
      preselectedInvoiceId: preselectedInvoiceId,
    );
    unawaited(vm.load(userIdLoader: app.companies!.findAdminUserId));
    return ChangeNotifierProvider<PurchaseReturnViewModel>.value(
      value: vm,
      child: RefreshOnActive(
        routePattern: RegExp(r'^/purchases/returns/purchase$'),
        onActivate: () => vm.load(userIdLoader: null),
        child: const _PurchaseReturnBody(),
      ),
    );
  }
}

class _PurchaseReturnBody extends StatelessWidget {
  const _PurchaseReturnBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PurchaseReturnViewModel>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/purchases')),
        title: Text(l10n.retPurchaseTitle),
      ),
      body: _buildBody(context, vm),
    );
  }

  Widget _buildBody(BuildContext context, PurchaseReturnViewModel vm) {
    final state = vm.state;
    if (state.loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: const [ListSkeleton(rows: 6)],
      );
    }
    if (state.error != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          ErrorState(
            title: AppLocalizations.of(context)!.genericErrorTitle,
            message: AppLocalizations.of(context)!.dbOpenErrorMessage,
            technicalDetails: state.error.toString(),
            retryLabel: AppLocalizations.of(context)!.commonRetry,
            onRetry: () => vm.load(userIdLoader: null),
            compact: true,
          ),
        ],
      );
    }
    switch (state.phase) {
      case ReturnPhase.pickingInvoice:
        return _InvoicePickerSection(vm: vm, isSale: false);
      case ReturnPhase.pickingLines:
        return _LinesSection(vm: vm, isSale: false);
      case ReturnPhase.done:
        return _DoneSection(vm: vm, isSale: false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// أقسام مشتركة (تعمل فوق أي من النموذجين عبر الواجهة الموحَّدة ReturnFlowVm).
// ─────────────────────────────────────────────────────────────────────

/// طور اختيار الفاتورة الأصلية — بحث + بطاقات فواتير مكتملة.
class _InvoicePickerSection extends StatefulWidget {
  const _InvoicePickerSection({required this.vm, required this.isSale});

  /// النموذج خلف الواجهة الموحَّدة (بيع أو شراء).
  final ReturnFlowVm vm;

  /// مرتجع بيع؟ (للنصوص: الفاتورة الأصلية بيع/شراء).
  final bool isSale;

  @override
  State<_InvoicePickerSection> createState() => _InvoicePickerSectionState();
}

class _InvoicePickerSectionState extends State<_InvoicePickerSection> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    final query = state.filterQuery.trim();
    final visible = query.isEmpty
        ? state.invoices
        : [
            for (final invoice in state.invoices)
              if (invoice.invoiceNo.contains(query) ||
                  (invoice.partyName ?? '').contains(query))
                invoice,
          ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: TextField(
            key: const Key('ret_invoice_search_field'),
            controller: _searchController,
            onChanged: vm.setFilter,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: widget.isSale
                  ? l10n.retPickInvoiceSearchHint
                  : l10n.retPickPurchaseSearchHint,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        vm.setFilter('');
                      },
                    ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: visible.isEmpty
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  children: [
                    EmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: state.invoices.isEmpty
                          ? l10n.retPickInvoiceEmptyTitle
                          : l10n.sellInvoicesNoResultsTitle,
                      message: state.invoices.isEmpty
                          ? l10n.retPickInvoiceEmptyBody
                          : l10n.sellInvoicesNoResultsBody,
                      compact: true,
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  children: [
                    for (final invoice in visible)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _OriginalInvoiceCard(
                          invoice: invoice,
                          isSale: widget.isSale,
                          onTap: () => vm.selectInvoice(invoice.id),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// بطاقة فاتورة أصلية واحدة في طور الاختيار.
class _OriginalInvoiceCard extends StatelessWidget {
  const _OriginalInvoiceCard({
    required this.invoice,
    required this.isSale,
    required this.onTap,
  });

  final ReturnableInvoice invoice;
  final bool isSale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final local = invoice.issuedAt.toLocal();

    return FinCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  invoice.invoiceNo,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: FinText.tabularNums,
                  ),
                ),
              ),
              if (!invoice.hasParty && isSale)
                StatusChip(
                  label: l10n.sellCashCustomer,
                  tone: ChipTone.neutral,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  invoice.partyName ??
                      (isSale
                          ? l10n.sellCashCustomer
                          : l10n.purSupplierRequired),
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${purFormatDate(local)} · ${purFormatTime(local)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: FinText.tabularNums,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Spacer(),
              AmountText(
                amount: invoice.total,
                decimals: invoice.total == invoice.total.truncateToDouble()
                    ? 0
                    : 2,
              ),
              if (invoice.currencyCode != null) ...[
                const SizedBox(width: 4),
                Text(
                  invoice.currencyCode!,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: colors.gold),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// طور البنود — رأس الفاتورة الأصلية + البنود القابلة للإرجاع بكميات
/// (سقف المتاح) + شريط سفلي بقيمة المرتجع وزر الترحيل.
class _LinesSection extends StatelessWidget {
  const _LinesSection({required this.vm, required this.isSale});

  final ReturnFlowVm vm;
  final bool isSale;

  @override
  Widget build(BuildContext context) {
    final state = vm.state;
    final l10n = AppLocalizations.of(context)!;
    final selected = state.selected;
    if (selected == null) return const SizedBox.shrink();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            children: [
              _SelectedInvoiceHeader(
                invoice: selected,
                isSale: isSale,
                onChange: vm.backToInvoices,
              ),
              const SizedBox(height: 12),
              if (state.postError != null) ...[
                FinCard(
                  padding: const EdgeInsets.all(14),
                  accent: FinColors.of(context).negative,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: FinColors.of(context).negative,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          state.postError!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (state.linesLoading)
                const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
              else if (state.linesError != null)
                ErrorState(
                  title: l10n.genericErrorTitle,
                  message: l10n.dbOpenErrorMessage,
                  technicalDetails: state.linesError.toString(),
                  retryLabel: l10n.commonRetry,
                  onRetry: () => vm.selectInvoice(selected.id),
                  compact: true,
                )
              else if (state.lines.isEmpty)
                EmptyState(
                  icon: Icons.block_rounded,
                  title: l10n.retNoLinesTitle,
                  message: l10n.retNoLinesBody,
                  compact: true,
                )
              else ...[
                Text(
                  l10n.retLinesTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < state.lines.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ReturnLineCard(
                      line: state.lines[i],
                      onChanged: (qty) => vm.setQty(i, qty),
                    ),
                  ),
              ],
            ],
          ),
        ),
        _RefundBottomBar(vm: vm, isSale: isSale),
      ],
    );
  }
}

/// رأس الفاتورة الأصلية المختارة + زر تغييرها.
class _SelectedInvoiceHeader extends StatelessWidget {
  const _SelectedInvoiceHeader({
    required this.invoice,
    required this.isSale,
    required this.onChange,
  });

  final ReturnableInvoice invoice;
  final bool isSale;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final local = invoice.issuedAt.toLocal();
    return FinCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isSale
                    ? Icons.receipt_long_rounded
                    : Icons.local_shipping_rounded,
                color: scheme.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  invoice.invoiceNo,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: FinText.tabularNums,
                  ),
                ),
              ),
              TextButton.icon(
                key: const Key('ret_change_invoice_button'),
                onPressed: onChange,
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: Text(l10n.retChangeInvoice),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${invoice.partyName ?? (isSale ? l10n.sellCashCustomer : l10n.purSupplierRequired)} · ${purFormatDate(local)} · ${purFormatTime(local)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: FinText.tabularNums,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// بطاقة بند قابل للإرجاع — الاسم + الكمية الأصلية/المرجعة/المتاحة +
/// مدرّج كمية الإرجاع (0..المتاح) + قيمة رد السطر عند الاختيار.
class _ReturnLineCard extends StatelessWidget {
  const _ReturnLineCard({required this.line, required this.onChanged});

  final ReturnUiLine line;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final data = line.line;
    final selected = line.hasSelection;

    return FinCard(
      padding: const EdgeInsets.all(12),
      accent: selected ? colors.gold : null,
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
                  color: (selected ? scheme.primary : scheme.tertiary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  selected ? Icons.undo_rounded : Icons.inventory_2_outlined,
                  size: 19,
                  color: selected ? scheme.primary : scheme.tertiary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.lineDesc ?? l10n.sellDetailUnknownItem,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${l10n.retOriginalQty(purQtyText(data.originalQty))}'
                      '${data.returnedQty > 0 ? ' · ${l10n.retReturnedQty(purQtyText(data.returnedQty))}' : ''}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFeatures: FinText.tabularNums,
                      ),
                    ),
                    Text(
                      l10n.retAvailableQty(purQtyText(data.availableQty)),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: data.availableQty > 0
                            ? scheme.onSurfaceVariant
                            : colors.negative,
                        fontWeight: FontWeight.w700,
                        fontFeatures: FinText.tabularNums,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (selected)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AmountText(
                      amount: line.lineRefund,
                      decimals:
                          line.lineRefund == line.lineRefund.truncateToDouble()
                          ? 0
                          : 2,
                    ),
                    Text(
                      l10n.retLineRefundLabel,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
            ],
          ),
          if (data.availableQty > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                PurchaseQtyStepper(
                  qty: line.selectedQty,
                  min: 0,
                  onChanged: onChanged,
                ),
                const Spacer(),
                Text(
                  l10n.retQtyLabel,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// الشريط السفلي لطور البنود — قيمة المرتجع الحية + زر الترحيل.
class _RefundBottomBar extends StatelessWidget {
  const _RefundBottomBar({required this.vm, required this.isSale});

  final ReturnFlowVm vm;
  final bool isSale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final state = vm.state;
    final refundTotal = state.refundTotal;
    final canPost = state.hasSelection && !state.posting;

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
                  Expanded(
                    child: Text(
                      l10n.retRefundTotalLabel,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  AmountText(
                    amount: refundTotal,
                    size: AmountSize.large,
                    decimals: refundTotal == refundTotal.truncateToDouble()
                        ? 0
                        : 2,
                  ),
                  if (state.selected?.currencyCode != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      state.selected!.currencyCode!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                key: const Key('ret_post_button'),
                onPressed: canPost ? () => _openRefundSheet(context) : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  textStyle: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                icon: const Icon(Icons.undo_rounded),
                label: Text(l10n.retPostButton),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openRefundSheet(BuildContext context) async {
    // النموذج الحقيقي (بيع/شراء) لاستدعاء الترحيل الصحيح.
    final SaleReturnViewModel? saleVm = isSale
        ? context.read<SaleReturnViewModel>()
        : null;
    final PurchaseReturnViewModel? purchaseVm = isSale
        ? null
        : context.read<PurchaseReturnViewModel>();
    final state = vm.state;
    final selected = state.selected;
    if (selected == null || (saleVm == null && purchaseVm == null)) return;
    final l10n = AppLocalizations.of(context)!;
    final partyLabel =
        selected.partyName ??
        (isSale ? l10n.sellCashCustomer : l10n.purSupplierRequired);
    final refundTotal = state.refundTotal;

    final posted = await showReturnRefundSheet(
      context,
      refundTotal: refundTotal,
      decimals: 2,
      currencyCode: selected.currencyCode,
      partyLabel: partyLabel,
      cashOnly: !selected.hasParty,
      onConfirm: (cash, method) => saleVm != null
          ? saleVm.post(refundCash: cash, method: method)
          : purchaseVm!.post(refundCash: cash, method: method),
    );
    if (posted) {
      await vm.startNewReturn();
    }
  }
}

/// طور الإنجاز الاحتياطي (إن أُغلق الإيصال داخل النافذة) — إيصال كبير
/// وزر «مرتجع جديد».
class _DoneSection extends StatelessWidget {
  const _DoneSection({required this.vm, required this.isSale});

  final ReturnFlowVm vm;
  final bool isSale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    final receipt = state.receipt;
    if (receipt == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, size: 48),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: vm.startNewReturn,
              child: Text(l10n.retNewReturn),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        PostedReturnReceiptCard(receipt: receipt),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: vm.startNewReturn,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          icon: const Icon(Icons.post_add_rounded),
          label: Text(l10n.retNewReturn),
        ),
      ],
    );
  }
}
