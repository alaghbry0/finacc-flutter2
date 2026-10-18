/// قائمة فواتير الشراء + شاشة تفاصيل فاتورة الشراء — مرآة قائمة فواتير
/// المبيعات: بطاقات برقم PUR/المورد/العملة/الإجمالي/المدفوع/المتبقي
/// ورقائق الحالة، بحث نصي، وفتح التفاصيل الكاملة (الرأس + البنود بتكاليفها
/// والدفعات + المدفوعات + إجراء «إرجاع للمورد» PRN).
///
/// البطاقة والمحتوى التفصيلي وصفوفه مستخرجة إلى `widgets/` (R19-D3c —
/// مرآة تفكيك sales_invoices_screen من R19-D3b).
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
import '../view_models/purchases_list_view_model.dart';
import 'widgets/purchase_detail_content.dart';
import 'widgets/purchase_invoice_card.dart';

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
            child: FinSearchField(
              fieldKey: const Key('pur_invoices_search_field'),
              controller: _searchController,
              onChanged: vm.setFilter,
              hint: l10n.purInvoicesSearchHint,
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
            child: PurchaseInvoiceCard(invoice: invoice),
          ),
      ],
    );
  }
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
      companyRepo: app.companies!,
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
          : PurchaseDetailContent(detail: state.detail!, vm: vm),
    );
  }
}
