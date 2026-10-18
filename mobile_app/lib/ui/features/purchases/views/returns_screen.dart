/// شاشتا المرتجعات المرتبطة (المرحلة 5 — FR-02-07/08):
/// - **مرتجع البيع SRN** (`/purchases/returns/sale`): اختيار فاتورة بيع
///   مكتملة → بنودها القابلة للإرجاع بكميات → اتجاه رد القيمة → ترحيل
///   ذرّي (الكمية تعود للمخزون بتكلفتها الأصلية — لا WAC يُلمس).
/// - **مرتجع الشراء PRN** (`/purchases/returns/purchase`): اختيار فاتورة
///   شراء مكتملة → البنود والكميات → ترحيل ذرّي (WAC يُعاد حسابه على
///   المتبقي بتكلفة الشراء الأصلية Snapshot + فحص تغطية المخزون).
///
/// الأقسام المشتركة (تعمل فوق أي من النموذجين عبر الواجهة الموحَّدة
/// ReturnFlowVm) مستخرجة إلى `widgets/` (R19-D3c): طور اختيار الفاتورة
/// وبطاقتها، طور البنود ورأسها وبطاقاتها وشريط الترحيل، وطور الإنجاز.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/refresh_on_active.dart';
import '../view_models/returns_view_model.dart';
import 'widgets/return_done_section.dart';
import 'widgets/return_invoice_picker_section.dart';
import 'widgets/return_lines_section.dart';

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
        onActivate: () => vm.load(),
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
        children: const [ListSkeleton()],
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
            onRetry: () => vm.load(),
            compact: true,
          ),
        ],
      );
    }
    switch (state.phase) {
      case ReturnPhase.pickingInvoice:
        return ReturnInvoicePickerSection(vm: vm, isSale: true);
      case ReturnPhase.pickingLines:
        return ReturnLinesSection(vm: vm, isSale: true);
      case ReturnPhase.done:
        return ReturnDoneSection(vm: vm, isSale: true);
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
        onActivate: () => vm.load(),
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
        children: const [ListSkeleton()],
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
            onRetry: () => vm.load(),
            compact: true,
          ),
        ],
      );
    }
    switch (state.phase) {
      case ReturnPhase.pickingInvoice:
        return ReturnInvoicePickerSection(vm: vm, isSale: false);
      case ReturnPhase.pickingLines:
        return ReturnLinesSection(vm: vm, isSale: false);
      case ReturnPhase.done:
        return ReturnDoneSection(vm: vm, isSale: false);
    }
  }
}
