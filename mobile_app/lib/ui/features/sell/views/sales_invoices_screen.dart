/// قائمة فواتير المبيعات — آخر الفواتير برقم/تاريخ/عميل/عملة/إجمالي/
/// مدفوع/متبقي + رقائق الحالة، بحث نصي بسيط، وفتح التفاصيل الكاملة.
/// بطاقة القائمة والتفاصيل الكاملة بملفاتها المركزّة بجوارها (R19-D3b).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_search_field.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/refresh_on_active.dart';
import '../view_models/sales_invoices_view_model.dart';
import 'widgets/invoice_pdf_preview.dart';
import 'widgets/sale_invoice_detail_content.dart';
import 'widgets/sales_invoice_card.dart';

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
            child: FinSearchField(
              fieldKey: const Key('sell_invoices_search_field'),
              controller: _searchController,
              onChanged: vm.setFilter,
              hint: l10n.sellInvoicesSearchHint,
              onCleared: () {
                _searchController.clear();
                vm.setFilter('');
              },
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: const [ListSkeleton(rows: 7)],
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
    if (state.invoices.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        for (final invoice in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SalesInvoiceCard(invoice: invoice),
          ),
      ],
    );
  }
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
      companyRepo: app.companies!,
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
          : SaleInvoiceDetailContent(detail: state.detail!, vm: vm),
    );
  }
}
