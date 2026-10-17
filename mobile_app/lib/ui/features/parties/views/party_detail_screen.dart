/// شاشتا تفاصيل الطرف — العميل والمورد (دليل 06/… و05/05): بطاقة
/// البيانات وشارات حد الائتمان والأرشفة، توزيع الرصيد **لكل عملة على
/// حدة**، وكشف الحساب (FR-03-04) بعملة وفترة ورصيد رأسي متحرك في
/// خط زمني بأيقونات دلالية لكل قيد.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/info_note.dart';
import '../../../core/widgets/fin_section_title.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/refresh_on_return.dart';
import '../view_models/party_detail_view_model.dart';
import '../view_models/party_kind.dart';
import '../view_models/party_lookup.dart';
import '../view_models/party_repo_gate.dart';
import 'widgets/party_detail_balances_card.dart';
import 'widgets/party_detail_info_card.dart';
import 'widgets/party_detail_statement_card.dart';
import 'widgets/party_statement_pdf.dart';

/// شاشة تفاصيل العميل.
class CustomerDetailScreen extends StatelessWidget {
  const CustomerDetailScreen({super.key, this.viewModel, this.customerId});

  /// Seam اختبار: نموذج محمّل مسبقاً.
  final PartyDetailViewModel? viewModel;

  /// معرّف العميل.
  final int? customerId;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final PartyDetailViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = PartyDetailViewModel(
        gate: CustomerRepoGate(app.customers!),
        companyRepo: app.companies!,
        partyLookup: PartyLookup(app.database!.db),
        partyKind: PartyKind.customer,
        id: customerId ?? -1,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<PartyDetailViewModel>.value(
      value: vm,
      // تحديث التفاصيل عند العودة من مسار التعديل الفرعي (:id/edit).
      child: RefreshOnReturn(
        onReappear: vm.load,
        child: const _PartyDetailBody(),
      ),
    );
  }
}

/// شاشة تفاصيل المورد (دليل 05/05 — كشف الحساب والتقرير).
class SupplierDetailScreen extends StatelessWidget {
  const SupplierDetailScreen({super.key, this.viewModel, this.supplierId});

  /// Seam اختبار: نموذج محمّل مسبقاً.
  final PartyDetailViewModel? viewModel;

  /// معرّف المورد.
  final int? supplierId;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final PartyDetailViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = PartyDetailViewModel(
        gate: SupplierRepoGate(app.suppliers!),
        companyRepo: app.companies!,
        partyLookup: PartyLookup(app.database!.db),
        partyKind: PartyKind.supplier,
        id: supplierId ?? -1,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<PartyDetailViewModel>.value(
      value: vm,
      child: RefreshOnReturn(
        onReappear: vm.load,
        child: const _PartyDetailBody(),
      ),
    );
  }
}

class _PartyDetailBody extends StatelessWidget {
  const _PartyDetailBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PartyDetailViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    final record = state.record;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(record?.name ?? ''),
        actions: [
          // طباعة/مشاركة كشف الحساب PDF (الشريحة 7 — مستند #3) — متاح
          // فور اكتمال الكشف المعروض (بعملته وفترته كما اختيرا أعلاه).
          IconButton(
            tooltip: l10n.printingPdfTooltip,
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed:
                record == null ||
                    state.statement == null ||
                    state.loadingStatement
                ? null
                : () => openPartyStatementPdf(context, state),
          ),
          // تعديل الطرف — يفتح النموذج بنفس المعرّف (مسار :id/edit).
          IconButton(
            tooltip: l10n.partyDetailEditAction,
            icon: const Icon(Icons.edit_outlined),
            onPressed: record == null
                ? null
                : () => context.go(
                    state.kind.isCustomer
                        ? '/parties/customers/${state.partyId}/edit'
                        : '/parties/suppliers/${state.partyId}/edit',
                  ),
          ),
        ],
      ),
      body: _buildBody(context, vm, l10n, state),
    );
  }

  /// جسم الشاشة — حرّاس خروج مبكرين: تحميل ← خطأ ← غير موجود ← المحتوى.
  Widget _buildBody(
    BuildContext context,
    PartyDetailViewModel vm,
    AppLocalizations l10n,
    PartyDetailState state,
  ) {
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
    if (state.notFound) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          EmptyState(
            icon: Icons.person_off_rounded,
            title: l10n.partyDetailNotFoundTitle,
            message: l10n.partyDetailNotFoundBody,
            compact: true,
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        if (state.record!.archived) ...[
          InfoNote(
            icon: Icons.archive_rounded,
            message: l10n.partyDetailArchivedBanner,
            warning: true,
          ),
          const SizedBox(height: 14),
        ],
        PartyDetailInfoCard(state: state),
        const SizedBox(height: 18),
        FinSectionTitle(
          icon: Icons.account_balance_wallet_rounded,
          title: l10n.partyDetailBalancesSection,
        ),
        const SizedBox(height: 8),
        PartyDetailBalancesCard(state: state),
        const SizedBox(height: 18),
        FinSectionTitle(
          icon: Icons.receipt_long_rounded,
          title: l10n.partyDetailStatementSection,
        ),
        const SizedBox(height: 8),
        PartyDetailStatementCard(state: state),
      ],
    );
  }
}
