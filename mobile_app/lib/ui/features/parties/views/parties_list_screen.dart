/// شاشتا قائمة الأطراف — «جميع العملاء» و«جميع الموردين» (دليل 06/04
/// و05/08): بحث فوري مؤجَّل، رقائق تصفية (الكل/بأرصدة/بدون أرصدة/
/// مؤرشفون)، سطر لكل (طرف × عملة) برصيد ملوّن بعلامة غير لونية،
/// وسحب للأرشفة مع تأكيد للطرف بلا حركات فقط (FR-03-09).
/// V5: الترويسة والبانر والصفوف بنمط Simple Invoice Manager — يتسق مع
/// شاشة التبويبات الجديدة عند العودة من نموذج الإضافة.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/party.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_search_field.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/refresh_on_return.dart';
import '../../../core/widgets/sim_list_widgets.dart';
import '../view_models/party_kind.dart';
import '../view_models/party_list_view_model.dart';
import '../view_models/party_repo_gate.dart';
import 'widgets/parties_filter_bar.dart';
import 'widgets/sim_client_row.dart';

/// شاشة «جميع العملاء» (دليل 06/04).
class CustomersListScreen extends StatelessWidget {
  const CustomersListScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً.
  final PartyListViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final PartyListViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = PartyListViewModel(
        gate: CustomerRepoGate(app.customers!),
        companyRepo: app.companies!,
        partyKind: PartyKind.customer,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<PartyListViewModel>.value(
      value: vm,
      // تحديث السطور عند العودة من نموذج الإضافة (maybePop) — بلا
      // rebuild للعنصر المستعاد من المكدس كان يظل «لا عملاء بعد».
      child: RefreshOnReturn(
        onReappear: vm.refresh,
        child: const _PartiesListBody(),
      ),
    );
  }
}

/// شاشة «جميع الموردين» (دليل 05/08).
class SuppliersListScreen extends StatelessWidget {
  const SuppliersListScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً.
  final PartyListViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final PartyListViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = PartyListViewModel(
        gate: SupplierRepoGate(app.suppliers!),
        companyRepo: app.companies!,
        partyKind: PartyKind.supplier,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<PartyListViewModel>.value(
      value: vm,
      child: RefreshOnReturn(
        onReappear: vm.refresh,
        child: const _PartiesListBody(),
      ),
    );
  }
}

class _PartiesListBody extends StatefulWidget {
  const _PartiesListBody();

  @override
  State<_PartiesListBody> createState() => _PartiesListBodyState();
}

class _PartiesListBodyState extends State<_PartiesListBody> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PartyListViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    final isCustomer = state.kind == PartyKind.customer;

    final subtitle = isCustomer
        ? l10n.partiesCountCustomers(state.distinctParties)
        : l10n.partiesCountSuppliers(state.distinctParties);
    final formRoute = isCustomer
        ? '/parties/customers/form'
        : '/parties/suppliers/form';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SimSubHeader(
              title: isCustomer
                  ? l10n.partiesListCustomersTitle
                  : l10n.partiesListSuppliersTitle,
              onBack: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/parties');
                }
              },
              actions: [
                SimSubHeaderAction(
                  icon: Icons.add_rounded,
                  tooltip: l10n.partiesListAddTooltip,
                  onPressed: () => context.go(formRoute),
                ),
              ],
            ),
            // العدّاد تحت العنوان — ميزة القائمة الأصلية.
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: FinSearchField(
                controller: _searchController,
                onChanged: vm.onQueryChanged,
                fieldKey: const Key('parties_search_field'),
                hint: l10n.partiesListSearchHint,
                onCleared: () {
                  _searchController.clear();
                  unawaited(vm.setQuery(''));
                },
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: PartiesFilterBar(
                selected: state.filter,
                onSelect: vm.setFilter,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(child: _buildContent(context, vm)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, PartyListViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    final isCustomer = state.kind == PartyKind.customer;
    if (state.loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
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
    final filtered =
        state.query.trim().isNotEmpty || state.filter != PartyListFilter.all;
    if (state.rows.isEmpty) {
      if (filtered) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            EmptyState(
              icon: Icons.search_off_rounded,
              title: l10n.partiesListSearchEmptyTitle,
              message: l10n.partiesListSearchEmptyBody,
              compact: true,
            ),
          ],
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          EmptyState(
            icon: isCustomer
                ? Icons.person_rounded
                : Icons.local_shipping_rounded,
            title: isCustomer
                ? l10n.partiesListEmptyCustomersTitle
                : l10n.partiesListEmptySuppliersTitle,
            message: isCustomer
                ? l10n.partiesListEmptyCustomersBody
                : l10n.partiesListEmptySuppliersBody,
            actionLabel: isCustomer
                ? l10n.partiesListAddCustomersAction
                : l10n.partiesListAddSuppliersAction,
            onAction: () => context.go(
              isCustomer
                  ? '/parties/customers/form'
                  : '/parties/suppliers/form',
            ),
            compact: true,
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        for (final row in state.rows)
          SimClientRow(
            row: row,
            kind: state.kind,
            showArchivedBadge: state.filter == PartyListFilter.archived,
            decimals: state.decimalsFor(row.currencyCode),
            onArchive: () => _confirmArchive(context, vm, row),
          ),
      ],
    );
  }

  /// تأكيد الأرشفة ثم تنفيذها — يعيد true إذا أُزيل السطر (نجحت الأرشفة
  /// للطرف بلا حركات) وfalse إذا بقي (رفض أو حركات).
  Future<bool> _confirmArchive(
    BuildContext context,
    PartyListViewModel vm,
    PartyBalance row,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.partiesArchiveConfirmTitle(row.name)),
        content: Text(l10n.partiesArchiveConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.partiesSwipeArchiveLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;
    final outcome = await vm.archive(row.partyId);
    if (!mounted) return false;
    if (outcome == PartyArchiveOutcome.done) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.partiesArchivedDone)));
      return true;
    }
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.partiesArchiveHasMovements(row.name))),
    );
    return false;
  }
}
