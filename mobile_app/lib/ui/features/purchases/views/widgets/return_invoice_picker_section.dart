/// طور اختيار الفاتورة الأصلية للمرتجع — بحث + بطاقات فواتير مكتملة
/// (R19-D3c — مستخرج حرفياً من `returns_screen.dart` بلا أي تغيير دلالة).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fin_search_field.dart';
import '../../view_models/returns_view_model.dart';
import 'return_original_invoice_card.dart';

/// طور اختيار الفاتورة الأصلية — بحث + بطاقات فواتير مكتملة.
class ReturnInvoicePickerSection extends StatefulWidget {
  const ReturnInvoicePickerSection({
    super.key,
    required this.vm,
    required this.isSale,
  });

  /// النموذج خلف الواجهة الموحَّدة (بيع أو شراء).
  final ReturnFlowVm vm;

  /// مرتجع بيع؟ (للنصوص: الفاتورة الأصلية بيع/شراء).
  final bool isSale;

  @override
  State<ReturnInvoicePickerSection> createState() =>
      _ReturnInvoicePickerSectionState();
}

class _ReturnInvoicePickerSectionState
    extends State<ReturnInvoicePickerSection> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    final query = state.filterQuery.trim();
    final visible = query.isEmpty
        ? state.invoices
        : [
            for (final invoice in state.invoices)
              if (invoice.invoiceNo.contains(query) ||
                  (invoice.partyName ?? '').contains(query))
                invoice,
          ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: FinSearchField(
            fieldKey: const Key('ret_invoice_search_field'),
            controller: _searchController,
            onChanged: vm.setFilter,
            hint: widget.isSale
                ? l10n.retPickInvoiceSearchHint
                : l10n.retPickPurchaseSearchHint,
            onCleared: () {
              _searchController.clear();
              vm.setFilter('');
            },
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: visible.isEmpty
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  children: [
                    EmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: state.invoices.isEmpty
                          ? l10n.retPickInvoiceEmptyTitle
                          : l10n.sellInvoicesNoResultsTitle,
                      message: state.invoices.isEmpty
                          ? l10n.retPickInvoiceEmptyBody
                          : l10n.sellInvoicesNoResultsBody,
                      compact: true,
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  children: [
                    for (final invoice in visible)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ReturnOriginalInvoiceCard(
                          invoice: invoice,
                          isSale: widget.isSale,
                          onTap: () => vm.selectInvoice(invoice.id),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
