/// قائمة فواتير الشراء + شاشة تفاصيل فاتورة الشراء — مرآة قائمة فواتير
/// المبيعات: بطاقات برقم PUR/المورد/العملة/الإجمالي/المدفوع/المتبقي
/// ورقائق الحالة، بحث نصي، وفتح التفاصيل الكاملة (الرأس + البنود بتكاليفها
/// والدفعات + المدفوعات + إجراء «إرجاع للمورد» PRN).
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
import '../../../core/widgets/refresh_on_active.dart';
import '../view_models/purchases_list_view_model.dart';
import 'widgets/purchase_widgets.dart';

/// قائمة فواتير الشراء (مسار `/purchases/invoices`).
class PurchasesListScreen extends StatelessWidget {
  const PurchasesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final PurchasesListViewModel vm;
    vm = PurchasesListViewModel(purchaseRepo: app.purchases!);
    unawaited(vm.load());
    return ChangeNotifierProvider<PurchasesListViewModel>.value(
      value: vm,
      // تحديث حي عند العودة من ترحيل شراء أو مرتجع (قاعدة §10).
      child: RefreshOnActive(
        routePattern: RegExp(r'^/purchases/invoices$'),
        onActivate: vm.load,
        child: const _PurchasesListBody(),
      ),
    );
  }
}

class _PurchasesListBody extends StatefulWidget {
  const _PurchasesListBody();

  @override
  State<_PurchasesListBody> createState() => _PurchasesListBodyState();
}

class _PurchasesListBodyState extends State<_PurchasesListBody> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PurchasesListViewModel>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/purchases')),
        title: Text(l10n.purInvoicesTitle),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: TextField(
              key: const Key('pur_invoices_search_field'),
              controller: _searchController,
              onChanged: vm.setFilter,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.purInvoicesSearchHint,
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
          Expanded(child: _buildContent(context, vm)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, PurchasesListViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    if (state.loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: const [ListSkeleton(rows: 7)],
      );
    }
    if (state.error != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
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
    if (state.invoices.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          EmptyState(
            icon: Icons.receipt_long_rounded,
            title: l10n.purInvoicesEmptyTitle,
            message: l10n.purInvoicesEmptyBody,
            actionLabel: l10n.purHomeNewInvoice,
            onAction: () => context.go('/purchases/new'),
            compact: true,
          ),
        ],
      );
    }
    final visible = state.visible;
    if (visible.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          EmptyState(
            icon: Icons.search_off_rounded,
            title: l10n.purInvoicesNoResultsTitle,
            message: l10n.purInvoicesNoResultsBody,
            compact: true,
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        for (final invoice in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PurchaseCard(invoice: invoice),
          ),
      ],
    );
  }
}

/// بطاقة فاتورة شراء واحدة في القائمة.
class _PurchaseCard extends StatelessWidget {
  const _PurchaseCard({required this.invoice});

  final PurchaseInvoiceSummary invoice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final local = invoice.issuedAt.toLocal();

    return FinCard(
      onTap: () => context.go('/purchases/invoices/${invoice.id}'),
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
              PurchasePayStatusChip(method: invoice.payStatus),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  invoice.supplierName ?? l10n.purSupplierRequired,
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
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.purInvoicesPaidLabel,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    AmountText(
                      amount: invoice.paidAmount,
                      sign: FinSign.outgoing,
                      decimals: _decimals(invoice.paidAmount),
                    ),
                  ],
                ),
              ),
              if (invoice.dueAmount > 0)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.purInvoicesDueLabel,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      AmountText(
                        amount: invoice.dueAmount,
                        sign: FinSign.outgoing,
                        decimals: _decimals(invoice.dueAmount),
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
                        amount: invoice.total,
                        decimals: _decimals(invoice.total),
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
                  Text(
                    l10n.purInvoicesTotalLabel,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static int _decimals(double value) =>
      value == value.truncateToDouble() ? 0 : 2;
}

/// شاشة تفاصيل فاتورة الشراء (مسار `/purchases/invoices/:id`).
class PurchaseDetailScreen extends StatelessWidget {
  const PurchaseDetailScreen({super.key, required this.invoiceId});

  final int invoiceId;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    final vm = PurchaseDetailViewModel(
      purchaseRepo: app.purchases!,
      invoiceId: invoiceId,
    );
    unawaited(vm.load());
    return ChangeNotifierProvider<PurchaseDetailViewModel>.value(
      value: vm,
      child: const _PurchaseDetailBody(),
    );
  }
}

class _PurchaseDetailBody extends StatelessWidget {
  const _PurchaseDetailBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PurchaseDetailViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/purchases/invoices')),
        title: Text(state.detail?.invoice.invoiceNo ?? l10n.purDetailTitle),
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
          : state.detail == null
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                EmptyState(
                  icon: Icons.receipt_long_rounded,
                  title: l10n.purDetailNotFoundTitle,
                  message: l10n.purDetailNotFoundBody,
                  compact: true,
                ),
              ],
            )
          : _PurchaseDetailContent(detail: state.detail!),
    );
  }
}

class _PurchaseDetailContent extends StatelessWidget {
  const _PurchaseDetailContent({required this.detail});

  final PurchaseInvoiceDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final invoice = detail.invoice;
    final local = invoice.issuedAt.toLocal();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // رأس الفاتورة.
        FinCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      invoice.invoiceNo,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFeatures: FinText.tabularNums,
                      ),
                    ),
                  ),
                  PurchasePayStatusChip(
                    method: invoice.payStatus,
                    dense: false,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (invoice.rateIsFallback) ...[
                const PurchaseFallbackRateBadge(dense: false),
                const SizedBox(height: 8),
              ],
              Text(
                '${purFormatDate(local)} · ${purFormatTime(local)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: FinText.tabularNums,
                ),
              ),
              const SizedBox(height: 8),
              _InfoRow(
                label: l10n.purDetailSupplier,
                value: detail.supplierName ?? l10n.purSupplierRequired,
              ),
              if (detail.supplierPhone != null &&
                  detail.supplierPhone!.isNotEmpty)
                _InfoRow(
                  label: l10n.sellDetailPhone,
                  value: detail.supplierPhone!,
                ),
              _InfoRow(
                label: l10n.sellDetailCurrency,
                value:
                    '${detail.currencyCode ?? ''}'
                    '${detail.currencySymbol != null ? ' · ${detail.currencySymbol}' : ''}',
              ),
              if (invoice.exchangeRate != 1)
                _InfoRow(
                  label: l10n.sellDetailExchangeRate,
                  value: AmountText.format(invoice.exchangeRate, 4),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // البنود بتكاليفها.
        FinCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.sellDetailItemsSection,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              for (final item in detail.items) _ItemRow(item: item),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // الإجماليات والمدفوعات.
        FinCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AmountRow(
                label: l10n.sellTotalsSubtotal,
                value: invoice.subtotal,
              ),
              if (invoice.discountAmount > 0)
                _AmountRow(
                  label: l10n.sellDetailTotalDiscount,
                  value: invoice.discountAmount,
                  sign: FinSign.outgoing,
                ),
              Divider(
                height: 18,
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.sellTotalsGrandTotal,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  AmountText(
                    amount: invoice.total,
                    size: AmountSize.large,
                    decimals: _decimals(invoice.total),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _AmountRow(
                label: l10n.purInvoicesPaidLabel,
                value: invoice.paidAmount,
                sign: FinSign.outgoing,
              ),
              _AmountRow(
                label: l10n.purInvoicesDueLabel,
                value: invoice.dueAmount,
                sign: FinSign.outgoing,
              ),
              const SizedBox(height: 8),
              Divider(
                height: 18,
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
              // قيمة الوارد بالتكلفة (بالعملة الأساسية) — WAC الداخات.
              _AmountRow(
                label: l10n.purDetailStockValue,
                value: invoice.costTotal,
              ),
              Text(
                l10n.purDetailStockValueNote,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // الإجراءات — مرتجع شراء PRN عن هذه الفاتورة.
        OutlinedButton.icon(
          key: const Key('pur_detail_return_button'),
          onPressed: () =>
              context.go('/purchases/returns/purchase?purchase=${invoice.id}'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          icon: const Icon(Icons.assignment_return_rounded, size: 20),
          label: Text(l10n.purDetailReturnAction),
        ),
      ],
    );
  }

  static int _decimals(double value) =>
      value == value.truncateToDouble() ? 0 : 2;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final PurchaseInvoiceItemLine item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.lineDesc ?? l10n.sellDetailUnknownItem,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${l10n.sellDetailQtyLabel} ${purQtyText(item.qty)} × '
                  '${AmountText.format(item.unitCost, _decimals(item.unitCost))}'
                  '${item.discountAmount > 0 ? ' · ${l10n.sellDetailDiscountLabel} ${AmountText.format(item.discountAmount, 2)}' : ''}'
                  // R16-a: البونص يظهر بجوار الكمية «+N مجاني» عند
                  // وجوده فقط (ديناميكي بلا أي إعدادات).
                  '${item.freeQty > 0.000001 ? ' · ${l10n.bonusDetailSuffix(purQtyText(item.freeQty))}' : ''}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: FinText.tabularNums,
                  ),
                ),
                if ((item.notes ?? '').isNotEmpty)
                  Text(
                    item.notes!,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: colors.gold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AmountText(
                amount: item.lineTotal,
                decimals: _decimals(item.lineTotal),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static int _decimals(double value) =>
      value == value.truncateToDouble() ? 0 : 2;
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.sign = FinSign.neutral,
  });

  final String label;
  final double value;
  final FinSign sign;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          AmountText(
            amount: value,
            sign: sign,
            decimals: value == value.truncateToDouble() ? 0 : 2,
          ),
        ],
      ),
    );
  }
}
