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
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
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
    final scheme = Theme.of(context).colorScheme;
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
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
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
              TextField(
                key: const Key('pur_supplier_search_field'),
                controller: _searchController,
                onChanged: vm.onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.purSupplierPickerSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            unawaited(vm.search(''));
                          },
                        ),
                ),
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
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _SupplierRow(
            match: match,
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

class _SupplierRow extends StatelessWidget {
  const _SupplierRow({required this.match, required this.onTap});

  final PartyBalance match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    // موجب = دَين لنا في ذمة المورد (ندين له) — تحذيري.
    final balanceColor = match.balance > 0
        ? colors.warning
        : match.balance < 0
        ? colors.positive
        : scheme.onSurfaceVariant;
    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.cardBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    match.name.trim().isEmpty
                        ? '؟'
                        : match.name.trim().characters.first,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.name,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (match.phone != null && match.phone!.isNotEmpty)
                      Text(
                        match.phone!,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(fontFeatures: FinText.tabularNums),
                        maxLines: 1,
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
                        amount: match.balance.abs(),
                        size: AmountSize.row,
                        decimals: 2,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        match.currencyCode,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: balanceColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    match.balance > 0
                        ? l10n.purSupplierOwes
                        : match.balance < 0
                        ? l10n.purSupplierCredit
                        : l10n.sellCustomerClear,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: balanceColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
