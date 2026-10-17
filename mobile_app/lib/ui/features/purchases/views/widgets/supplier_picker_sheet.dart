/// نافذة اختيار المورد لفاتورة الشراء — بحث بالاسم/الهاتف مع رصيد المورد
/// بعملته (معلوماتي: «ما ندين له به») — لا خيار مجهول: المورد إلزامي.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../data/repositories/supplier_repository.dart';
import '../../../../../domain/models/party.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fin_search_field.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/fin_sheet_drag_handle.dart';
import '../../../../core/widgets/party_balance_row.dart';
import '../../view_models/supplier_picker_view_model.dart';

/// اختيار مورد من النافذة — [onPick] عند الاختيار.
Future<void> showSupplierPickerSheet(
  BuildContext context, {
  required SupplierRepository supplierRepo,
  required ValueChanged<PartyBalance> onPick,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // فوق شريط التبويبات (متصفح الفرع) — لا من أسفل الشاشة خلفه.
    useRootNavigator: false,
    builder: (_) => ChangeNotifierProvider<SupplierPickerViewModel>(
      create: (_) {
        final vm = SupplierPickerViewModel(supplierRepo: supplierRepo);
        unawaited(vm.search(''));
        return vm;
      },
      child: _SupplierPickerSheet(onPick: onPick),
    ),
  );
}

class _SupplierPickerSheet extends StatefulWidget {
  const _SupplierPickerSheet({required this.onPick});

  final ValueChanged<PartyBalance> onPick;

  @override
  State<_SupplierPickerSheet> createState() => _SupplierPickerSheetState();
}

class _SupplierPickerSheetState extends State<_SupplierPickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SupplierPickerViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final height = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: height * 0.85,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FinSheetDragHandle(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.purSupplierPickerTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.commonCancel,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FinSearchField(
                fieldKey: const Key('pur_supplier_search_field'),
                controller: _searchController,
                onChanged: vm.onQueryChanged,
                hint: l10n.purSupplierPickerSearchHint,
                onCleared: () {
                  _searchController.clear();
                  unawaited(vm.search(''));
                },
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildList(context, vm)),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: Text(
                    l10n.sellCustomerPickerFooterNote,
                    style: Theme.of(context).textTheme.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, SupplierPickerViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    if (state.loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    if (state.error != null) {
      return Center(
        child: ErrorState(
          title: l10n.genericErrorTitle,
          message: l10n.dbOpenErrorMessage,
          technicalDetails: state.error.toString(),
          retryLabel: l10n.commonRetry,
          onRetry: () => vm.search(state.query),
          compact: true,
        ),
      );
    }
    if (state.matches.isEmpty) {
      return Center(
        child: state.query.isEmpty
            ? EmptyState(
                icon: Icons.local_shipping_rounded,
                title: l10n.purSupplierPickerEmptyTitle,
                message: l10n.purSupplierPickerEmptyBody,
                compact: true,
              )
            : EmptyState(
                icon: Icons.search_off_rounded,
                title: l10n.purSupplierPickerNoResultsTitle,
                message: l10n.purSupplierPickerNoResultsBody,
                compact: true,
              ),
      );
    }
    return ListView.builder(
      key: const Key('pur_supplier_results'),
      itemCount: state.matches.length,
      itemBuilder: (context, index) {
        final match = state.matches[index];
        final balanceColor = _supplierBalanceColor(context, match.balance);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PartyBalanceRow(
            name: match.name,
            phone: match.phone,
            balance: match.balance,
            currencyCode: match.currencyCode,
            label: _supplierBalanceLabel(context, match.balance),
            labelColor: balanceColor,
            currencyColor: balanceColor,
            onTap: () {
              widget.onPick(match);
              Navigator.of(context).pop();
            },
          ),
        );
      },
    );
  }
}

/// دلالة رصيد المورد — موجب: دَين لنا في ذمته (ندين له)، سالب: دائن،
/// صفر: خالص.
String _supplierBalanceLabel(BuildContext context, double balance) {
  final l10n = AppLocalizations.of(context)!;
  return balance > 0
      ? l10n.purSupplierOwes
      : balance < 0
      ? l10n.purSupplierCredit
      : l10n.sellCustomerClear;
}

/// لون دلالة رصيد المورد (تحذيري/إيجابي/محايد).
Color _supplierBalanceColor(BuildContext context, double balance) {
  final colors = FinColors.of(context);
  return balance > 0
      ? colors.warning
      : balance < 0
      ? colors.positive
      : Theme.of(context).colorScheme.onSurfaceVariant;
}
