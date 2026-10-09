/// شاشتا الأرصدة المستحقة — «المبالغ المتبقية عند العملاء» (دليل 06/05)
/// و«المبالغ المتبقية للموردين» (دليل 05/03): قائمة مجمّعة مفصولة بكل
/// عملة (سطر لكل طرف بكل عملة — لا خلط أبداً)، رأس مستقل بإجمالي كل
/// عملة، بحث، وشريحة «متأخر منذ X يوماً» للأعمال المتعثرة (FR-03-06).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/party.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/status_chip.dart';
import '../view_models/party_balances_view_model.dart';
import '../view_models/party_kind.dart';
import '../view_models/party_repo_gate.dart';
import 'widgets/parties_widgets.dart';

/// شاشة «المبالغ المتبقية عند العملاء» (دليل 06/05).
class ReceivablesScreen extends StatelessWidget {
  const ReceivablesScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً.
  final PartyBalancesViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final PartyBalancesViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = PartyBalancesViewModel(
        gate: CustomerRepoGate(app.customers!),
        companyRepo: app.companies!,
        partyKind: PartyKind.customer,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<PartyBalancesViewModel>.value(
      value: vm,
      child: const _PartyBalancesBody(),
    );
  }
}

/// شاشة «المبالغ المتبقية للموردين» (دليل 05/03).
class PayablesScreen extends StatelessWidget {
  const PayablesScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً.
  final PartyBalancesViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final PartyBalancesViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = PartyBalancesViewModel(
        gate: SupplierRepoGate(app.suppliers!),
        companyRepo: app.companies!,
        partyKind: PartyKind.supplier,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<PartyBalancesViewModel>.value(
      value: vm,
      child: const _PartyBalancesBody(),
    );
  }
}

class _PartyBalancesBody extends StatefulWidget {
  const _PartyBalancesBody();

  @override
  State<_PartyBalancesBody> createState() => _PartyBalancesBodyState();
}

class _PartyBalancesBodyState extends State<_PartyBalancesBody> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PartyBalancesViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    final isCustomer = state.kind == PartyKind.customer;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(isCustomer ? l10n.receivablesTitle : l10n.payablesTitle),
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
                vm.setQuery('');
              },
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: _buildContent(context, vm)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, PartyBalancesViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    final isCustomer = state.kind == PartyKind.customer;
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
    if (!state.hasAnyDues) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          EmptyState(
            icon: isCustomer ? Icons.task_alt_rounded : Icons.handshake_rounded,
            title: l10n.receivablesEmptyTitle,
            message: isCustomer
                ? l10n.receivablesEmptyBody
                : l10n.payablesEmptyBody,
            compact: true,
          ),
        ],
      );
    }
    if (state.groups.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          EmptyState(
            icon: Icons.search_off_rounded,
            title: l10n.partiesBalancesSearchEmptyTitle,
            message: l10n.partiesBalancesSearchEmptyBody,
            compact: true,
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        PartiesInfoNote(
          icon: Icons.currency_exchange_rounded,
          message: l10n.partiesNoMixNote,
        ),
        const SizedBox(height: 14),
        for (final group in state.groups) ...[
          _GroupHeader(group: group),
          const SizedBox(height: 10),
          for (var i = 0; i < group.rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DueRow(
                key: Key('due_row_${group.currencyCode}_$i'),
                row: group.rows[i],
                decimals: group.decimals,
                isCustomer: isCustomer,
              ),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// رأس مجموعة عملة — الإجمالي بهذه العملة وحدها + عدد الأطراف.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});

  final PartyCurrencyGroup group;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return FinCard(
      accent: colors.gold,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          CurrencyCodePill(code: group.currencyCode),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.partiesDuesCount(
                group.rows.map((row) => row.partyId).toSet().length,
              ),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                l10n.partiesBalancesTotalLabel,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              PartyBalanceText(
                balance: group.total,
                decimals: group.decimals,
                size: AmountSize.large,
                showChip: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// سطر مستحق واحد — الاسم والهاتف وشريحة التأخير والرصيد.
class _DueRow extends StatelessWidget {
  const _DueRow({
    super.key,
    required this.row,
    required this.decimals,
    required this.isCustomer,
  });

  final PartyBalance row;
  final int decimals;
  final bool isCustomer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final phone = row.phone;
    final daysLate = row.daysLate;
    final lastPayment = row.lastPaymentDate;

    return FinCard(
      onTap: () => context.go(
        isCustomer
            ? '/parties/customers/${row.partyId}'
            : '/parties/suppliers/${row.partyId}',
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PartyAvatar(kind: _kind, name: row.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if ((phone ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  PartyPhoneText(phone!),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (daysLate != null && daysLate > 0)
                      StatusChip(
                        label: l10n.partiesDaysLateChip(daysLate),
                        tone: ChipTone.warning,
                        icon: Icons.hourglass_bottom_rounded,
                        dense: true,
                      ),
                    if (lastPayment != null)
                      StatusChip(
                        label: l10n.partiesLastPaymentLabel(
                          partyFormatDate(context, lastPayment),
                        ),
                        tone: ChipTone.neutral,
                        dense: true,
                      ),
                  ],
                ),
                if (daysLate == null || daysLate <= 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    _sinceText(context, l10n),
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PartyBalanceText(balance: row.balance, decimals: decimals),
              const SizedBox(height: 2),
              CurrencyCodePill(code: row.currencyCode, accent: colors.gold),
            ],
          ),
        ],
      ),
    );
  }

  PartyKind get _kind => isCustomer ? PartyKind.customer : PartyKind.supplier;

  /// سطر أقدم فاتورة آجلة مفتوحة (أو فارغ).
  String _sinceText(BuildContext context, AppLocalizations l10n) {
    final oldest = row.oldestOpenInvoiceDate;
    if (oldest == null) return '';
    return '${l10n.statementKindInvoice}: ${partyFormatDate(context, oldest)}';
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
          key: const Key('parties_balances_search_field'),
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.partiesBalancesSearchHint,
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
