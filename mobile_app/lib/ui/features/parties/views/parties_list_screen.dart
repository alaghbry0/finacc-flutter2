/// شاشتا قائمة الأطراف — «جميع العملاء» و«جميع الموردين» (دليل 06/04
/// و05/08): بحث فوري مؤجَّل، رقائق تصفية (الكل/بأرصدة/بدون أرصدة/
/// مؤرشفون)، سطر لكل (طرف × عملة) برصيد ملوّن بعلامة غير لونية،
/// وسحب للأرشفة مع تأكيد للطرف بلا حركات فقط (FR-03-09).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/party.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/refresh_on_return.dart';
import '../../../core/widgets/status_chip.dart';
import '../view_models/party_kind.dart';
import '../view_models/party_list_view_model.dart';
import '../view_models/party_repo_gate.dart';
import 'widgets/parties_widgets.dart';

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
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCustomer
                  ? l10n.partiesListCustomersTitle
                  : l10n.partiesListSuppliersTitle,
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.partiesListAddTooltip,
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.go(formRoute),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('parties_list_fab'),
        onPressed: () => context.go(formRoute),
        icon: const Icon(Icons.person_add_rounded),
        label: Text(
          isCustomer
              ? l10n.partiesListAddCustomersAction
              : l10n.partiesListAddSuppliersAction,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: _SearchField(
              controller: _searchController,
              onChanged: vm.onQueryChanged,
              onCleared: () {
                _searchController.clear();
                unawaited(vm.setQuery(''));
              },
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: _FilterBar(selected: state.filter, onSelect: vm.setFilter),
          ),
          const SizedBox(height: 10),
          Expanded(child: _buildContent(context, vm)),
        ],
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      children: [
        for (final row in state.rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PartyRow(
              row: row,
              kind: state.kind,
              showArchivedBadge: state.filter == PartyListFilter.archived,
              decimals: state.decimalsFor(row.currencyCode),
              onArchive: () => _confirmArchive(context, vm, row),
            ),
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

/// حقل البحث — بادئة بحث ولاحقة مسح.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onCleared,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          key: const Key('parties_search_field'),
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.partiesListSearchHint,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: onCleared,
                  ),
          ),
        );
      },
    );
  }
}

/// شريط رقائق التصفية الأربع.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelect});

  final PartyListFilter selected;
  final ValueChanged<PartyListFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          _FilterChip(
            key: const Key('parties_filter_all'),
            label: l10n.partiesFilterAll,
            selected: selected == PartyListFilter.all,
            onTap: () => onSelect(PartyListFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            key: const Key('parties_filter_with_balance'),
            label: l10n.partiesFilterWithBalance,
            selected: selected == PartyListFilter.withBalance,
            onTap: () => onSelect(PartyListFilter.withBalance),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            key: const Key('parties_filter_zero_balance'),
            label: l10n.partiesFilterZeroBalance,
            selected: selected == PartyListFilter.zeroBalance,
            onTap: () => onSelect(PartyListFilter.zeroBalance),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            key: const Key('parties_filter_archived'),
            label: l10n.partiesFilterArchived,
            selected: selected == PartyListFilter.archived,
            onTap: () => onSelect(PartyListFilter.archived),
          ),
        ],
      ),
    );
  }
}

/// رقاقة تصفية واحدة — حركة اختيار متحركة.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effective = scheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Material(
        color: selected
            ? effective.withValues(alpha: 0.14)
            : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: selected
              ? BorderSide(color: effective.withValues(alpha: 0.55), width: 1.4)
              : BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? effective : scheme.onSurface,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// سطر طرف واحد — سحب للأرشفة (بلا حركات فقط) + بطاقة بالنوع والرصيد.
class _PartyRow extends StatelessWidget {
  const _PartyRow({
    required this.row,
    required this.kind,
    required this.showArchivedBadge,
    required this.decimals,
    required this.onArchive,
  });

  final PartyBalance row;

  /// نوع الطرف — للأيقونة ومسار التفاصيل.
  final PartyKind kind;

  /// إظهار شارة «مؤرشف» (في تصفية المؤرشفين).
  final bool showArchivedBadge;

  final int decimals;

  /// يؤكد وينفّذ الأرشفة — يعيد true إذا أُزيل السطر.
  final Future<bool> Function() onArchive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return Dismissible(
      key: ValueKey('party_row_${row.partyId}_${row.currencyCode}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: colors.negativeContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.archive_rounded, color: colors.onNegativeContainer),
            const SizedBox(width: 8),
            Text(
              l10n.partiesSwipeArchiveLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.onNegativeContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) => onArchive(),
      onDismissed: (_) {},
      child: FinCard(
        onTap: () => context.go(
          kind == PartyKind.customer
              ? '/parties/customers/${row.partyId}'
              : '/parties/suppliers/${row.partyId}',
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PartyAvatar(kind: kind, name: row.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.name,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (showArchivedBadge) ...[
                        const SizedBox(width: 6),
                        StatusChip(
                          label: l10n.partiesArchivedBadge,
                          tone: ChipTone.neutral,
                          icon: Icons.archive_rounded,
                          dense: true,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  if ((row.phone ?? '').isNotEmpty)
                    PartyPhoneText(row.phone!)
                  else
                    Text(
                      l10n.partiesNoPhone,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  const SizedBox(height: 8),
                  CurrencyCodePill(code: row.currencyCode),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PartyBalanceText(balance: row.balance, decimals: decimals),
                const SizedBox(height: 2),
                Text(
                  l10n.partiesBalanceLabel,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
