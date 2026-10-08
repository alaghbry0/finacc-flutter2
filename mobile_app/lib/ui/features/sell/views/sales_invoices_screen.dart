/// قائمة فواتير المبيعات — آخر الفواتير برقم/تاريخ/عميل/عملة/إجمالي/
/// مدفوع/متبقي + رقائق الحالة، بحث نصي بسيط، وفتح التفاصيل الكاملة.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/sale.dart';
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
import '../view_models/sales_invoices_view_model.dart';
import 'widgets/invoice_pdf_preview.dart';
import 'widgets/sell_widgets.dart';

/// قائمة فواتير المبيعات (مسار مقترح `/sell/invoices`).
class SalesInvoicesScreen extends StatelessWidget {
  const SalesInvoicesScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً.
  final SalesInvoicesViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final SalesInvoicesViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = SalesInvoicesViewModel(saleRepo: app.sales!);
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<SalesInvoicesViewModel>.value(
      value: vm,
      // تحديث حي عند تبديل التبويب/الرجوع: فاتورة جديدة تُرحَّل في الكاشير
      // (نفس فرع التبويب أو غيره) والقائمة تُستعاد من IndexedStack بلا rebuild.
      child: RefreshOnActive(
        routePattern: RegExp(r'^/sell/invoices$'),
        onActivate: vm.load,
        child: const _SalesInvoicesBody(),
      ),
    );
  }
}

class _SalesInvoicesBody extends StatefulWidget {
  const _SalesInvoicesBody();

  @override
  State<_SalesInvoicesBody> createState() => _SalesInvoicesBodyState();
}

class _SalesInvoicesBodyState extends State<_SalesInvoicesBody> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SalesInvoicesViewModel>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/sell')),
        title: Text(l10n.sellInvoicesTitle),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: TextField(
              key: const Key('sell_invoices_search_field'),
              controller: _searchController,
              onChanged: vm.setFilter,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.sellInvoicesSearchHint,
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

  Widget _buildContent(BuildContext context, SalesInvoicesViewModel vm) {
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
            title: l10n.sellInvoicesEmptyTitle,
            message: l10n.sellInvoicesEmptyBody,
            actionLabel: l10n.sellHomeNewInvoice,
            onAction: () => context.go('/sell/new'),
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
            title: l10n.sellInvoicesNoResultsTitle,
            message: l10n.sellInvoicesNoResultsBody,
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
            child: _InvoiceCard(invoice: invoice),
          ),
      ],
    );
  }
}

/// بطاقة فاتورة واحدة في القائمة.
class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice});

  final SaleInvoiceSummary invoice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final local = invoice.issuedAt.toLocal();

    return FinCard(
      onTap: () => context.go('/sell/invoices/${invoice.id}'),
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
              PayStatusChip(method: invoice.payStatus),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  invoice.customerName ?? l10n.sellCashCustomer,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${sellFormatDate(local)} · ${sellFormatTime(local)}',
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
                      l10n.sellInvoicesPaidLabel,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    AmountText(
                      amount: invoice.paidAmount,
                      sign: FinSign.incoming,
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
                        l10n.sellInvoicesDueLabel,
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
                    l10n.sellInvoicesTotalLabel,
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

/// شاشة تفاصيل فاتورة البيع (مسار مقترح `/sell/invoices/:id`).
class SaleInvoiceDetailScreen extends StatelessWidget {
  const SaleInvoiceDetailScreen({super.key, required this.invoiceId});

  final int invoiceId;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    final vm = SaleInvoiceDetailViewModel(
      saleRepo: app.sales!,
      invoiceId: invoiceId,
    );
    unawaited(vm.load());
    return ChangeNotifierProvider<SaleInvoiceDetailViewModel>.value(
      value: vm,
      child: const _InvoiceDetailBody(),
    );
  }
}

class _InvoiceDetailBody extends StatelessWidget {
  const _InvoiceDetailBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SaleInvoiceDetailViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/sell/invoices')),
        title: Text(
          state.detail?.invoice.invoiceNo ?? l10n.sellInvoiceDetailTitle,
        ),
        actions: [
          // طباعة/مشاركة PDF (الشريحة 7) — متاح فور اكتمال التفاصيل.
          if (state.detail != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              tooltip: l10n.printingPdfTooltip,
              onPressed: () =>
                  openLoadedInvoicePdfPreview(context, state.detail!),
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
          : state.detail == null
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                EmptyState(
                  icon: Icons.receipt_long_rounded,
                  title: l10n.sellInvoiceNotFoundTitle,
                  message: l10n.sellInvoiceNotFoundBody,
                  compact: true,
                ),
              ],
            )
          : _InvoiceDetailContent(detail: state.detail!),
    );
  }
}

class _InvoiceDetailContent extends StatelessWidget {
  const _InvoiceDetailContent({required this.detail});

  final SaleInvoiceDetail detail;

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
                  PayStatusChip(method: invoice.payStatus, dense: false),
                ],
              ),
              const SizedBox(height: 6),
              if (invoice.rateIsFallback) ...[
                const FallbackRateBadge(dense: false),
                const SizedBox(height: 8),
              ],
              Text(
                '${sellFormatDate(local)} · ${sellFormatTime(local)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: FinText.tabularNums,
                ),
              ),
              const SizedBox(height: 8),
              _InfoRow(
                label: l10n.sellDetailCustomer,
                value: detail.customerName ?? l10n.sellCashCustomer,
              ),
              if (detail.customerPhone != null &&
                  detail.customerPhone!.isNotEmpty)
                _InfoRow(
                  label: l10n.sellDetailPhone,
                  value: detail.customerPhone!,
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
        // البنود.
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
        // الإجماليات.
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
                label: l10n.sellInvoicesPaidLabel,
                value: invoice.paidAmount,
                sign: FinSign.incoming,
              ),
              _AmountRow(
                label: l10n.sellInvoicesDueLabel,
                value: invoice.dueAmount,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // ربح الفاتورة (FR-09-11) — قسم إداري صغير أسفل الإجماليات.
        _ManagerProfitCard(invoice: invoice),
        const SizedBox(height: 14),
        // P1-1: مرتجع بيع SRN عن هذه الفاتورة — الربط العميق ?invoice=
        // جاهز في الموجّه (نفس نمط مرتجع الشراء في قائمة الشراء).
        OutlinedButton.icon(
          key: const Key('sell_detail_return_button'),
          onPressed: () =>
              context.go('/purchases/returns/sale?invoice=${invoice.id}'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          icon: const Icon(Icons.assignment_return_rounded, size: 20),
          label: Text(l10n.sellFixDetailReturnAction),
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
          // درع الفيض: القيمة الطويلة تُقتطع بلطف بدل فيض الصف
          // (توحيداً مع صفوف معلومات عرض السعر).
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final SaleInvoiceItemLine item;

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
                  '${l10n.sellDetailQtyLabel} ${sellQtyText(item.qty)} × '
                  '${AmountText.format(item.unitPrice, _decimals(item.unitPrice))}'
                  '${item.discountAmount > 0 ? ' · ${l10n.sellDetailDiscountLabel} ${AmountText.format(item.discountAmount, 2)}' : ''}',
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
                    maxLines: 1,
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

/// قسم ربح الفاتورة الإداري (FR-09-11): التكلفة + الربح + هامش الربح ٪.
///
/// **قرار موثق**: V1 فيها مدير واحد حصراً (بلا أدوار متعددة) → القسم
/// يُعرض **دائماً** في تفاصيل فاتورة البيع (بلا بوابة صلاحيات). الربح
/// = `total_base − cost_total` — كلا الطرفان بالعملة الأساسية أصلاً
/// (cost_total يُجمَّع من line_cost بالأساس — sale_repository 8-د)،
/// والهامش يظهر فقط عند تكلفة موجبة (لا قسمة على صفر).
class _ManagerProfitCard extends StatelessWidget {
  const _ManagerProfitCard({required this.invoice});

  final SaleInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final cost = invoice.costTotal;
    // كلا الطرفين بالعملة الأساسية أصلاً — لا خلط عملات (5.4-7).
    final profit = invoice.totalBase - cost;
    final sign = profit > 0.005
        ? FinSign.incoming
        : profit < -0.005
        ? FinSign.outgoing
        : FinSign.neutral;
    final margin = cost > 0.005 ? profit / cost * 100 : null;
    return FinCard(
      key: const Key('invoice_profit_card'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 16, color: colors.gold),
              const SizedBox(width: 6),
              Text(
                l10n.invoiceProfitSectionTitle,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.invoiceProfitManagerHint,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _InfoRow(
            label: l10n.invoiceCostLabel,
            value: AmountText.format(cost, _decimalsValue(cost)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.invoiceProfitLabel,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                AmountText(
                  amount: profit.abs(),
                  sign: sign,
                  decimals: _decimalsValue(profit),
                ),
              ],
            ),
          ),
          if (margin != null)
            _InfoRow(
              label: l10n.invoiceMarginLabel,
              value: '${margin.toStringAsFixed(1)}%',
            ),
          const SizedBox(height: 6),
          Text(
            l10n.profitBaseCurrencyNote,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  static int _decimalsValue(double value) =>
      value == value.truncateToDouble() ? 0 : 2;
}
