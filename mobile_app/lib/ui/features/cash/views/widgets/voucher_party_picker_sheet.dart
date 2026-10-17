/// منتقي الطرف لشاشة السند — بحث حي عبر النموذج (عملاء للقبض / موردين
/// للصرف)، سطر لكل طرف×عملة مع رصيده.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../domain/models/party.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fin_search_field.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/party_balance_row.dart';
import '../../view_models/voucher_view_model.dart';
import 'cash_widgets.dart';

/// منتقي الطرف — بحث حي عبر النموذج (عملاء للقبض / موردين للصرف)، سطر
/// لكل طرف×عملة مع رصيده.
class VoucherPartyPickerSheet extends StatefulWidget {
  const VoucherPartyPickerSheet({super.key, required this.vm});

  final VoucherViewModel vm;

  @override
  State<VoucherPartyPickerSheet> createState() =>
      _VoucherPartyPickerSheetState();
}

class _VoucherPartyPickerSheetState extends State<VoucherPartyPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<PartyBalance> _matches = const <PartyBalance>[];
  bool _loading = true;
  Object? _error;
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    unawaited(_search(''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    _debounce?.cancel();
    _query = query;
    try {
      final matches = await widget.vm.searchParties(query);
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  void _onQueryChanged(String value) {
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_search(value));
    });
  }

  @override
  Widget build(BuildContext context) {
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
              const CashSheetDragHandle(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.cashVoucherPickerTitle,
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
                controller: _searchController,
                onChanged: _onQueryChanged,
                hint: l10n.cashVoucherPickerSearchHint,
                onCleared: () {
                  _searchController.clear();
                  unawaited(_search(''));
                },
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildList(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    if (_error != null) {
      return Center(
        child: ErrorState(
          title: l10n.genericErrorTitle,
          message: l10n.dbOpenErrorMessage,
          technicalDetails: _error.toString(),
          retryLabel: l10n.commonRetry,
          onRetry: () => unawaited(_search(_query)),
          compact: true,
        ),
      );
    }
    if (_matches.isEmpty) {
      return Center(
        child: _query.isEmpty
            ? EmptyState(
                icon: widget.vm.isReceipt
                    ? Icons.person_search_rounded
                    : Icons.local_shipping_rounded,
                title: l10n.cashVoucherPickerEmptyTitle,
                message: l10n.cashVoucherPickerEmptyBody,
                compact: true,
              )
            : EmptyState(
                icon: Icons.search_off_rounded,
                title: l10n.cashVoucherPickerNoResultsTitle,
                message: l10n.cashVoucherPickerNoResultsBody,
                compact: true,
              ),
      );
    }
    return ListView.builder(
      itemCount: _matches.length,
      itemBuilder: (context, index) {
        final match = _matches[index];
        final (label, color) = _voucherBalanceMeaning(
          context,
          widget.vm.isReceipt,
          match.balance,
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PartyBalanceRow(
            name: match.name,
            phone: match.phone,
            balance: match.balance,
            currencyCode: match.currencyCode,
            label: label,
            labelColor: color,
            currencyColor: FinColors.of(context).gold,
            onTap: () {
              widget.vm.setParty(match);
              Navigator.of(context).pop();
            },
          ),
        );
      },
    );
  }
}

/// دلالة رصيد طرف السند بلونها — موجب = طرف مدينة لنا (عميل مدين/
/// مورد ندين له)؛ الإشارة تتبدّل حسب نوع السند (قبض من عميل/صرف لمورد).
(String, Color) _voucherBalanceMeaning(
  BuildContext context,
  bool isReceipt,
  double balance,
) {
  final l10n = AppLocalizations.of(context)!;
  final scheme = Theme.of(context).colorScheme;
  final colors = FinColors.of(context);
  final label = isReceipt
      ? (balance > 0
            ? l10n.cashVoucherPartyOwesYou
            : balance < 0
            ? l10n.cashVoucherPartyCredit
            : l10n.sellCustomerClear)
      : (balance > 0
            ? l10n.cashVoucherPartyWeOwe
            : balance < 0
            ? l10n.cashVoucherPartyCredit
            : l10n.sellCustomerClear);
  final color = balance > 0
      ? (isReceipt ? colors.positive : colors.warning)
      : balance < 0
      ? (isReceipt ? colors.neutral : colors.positive)
      : scheme.onSurfaceVariant;
  return (label, color);
}
