/// رأس الفاتورة الأصلية المختارة للمرتجع + زر تغييرها (R19-D3c —
/// مستخرج حرفياً من `returns_screen.dart` بلا أي تغيير دلالة).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/returns_view_model.dart';
import 'purchase_format.dart';

/// رأس الفاتورة الأصلية المختارة + زر تغييرها.
class ReturnSelectedInvoiceHeader extends StatelessWidget {
  const ReturnSelectedInvoiceHeader({
    super.key,
    required this.invoice,
    required this.isSale,
    required this.onChange,
  });

  final ReturnableInvoice invoice;
  final bool isSale;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final local = invoice.issuedAt.toLocal();
    return FinCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isSale
                    ? Icons.receipt_long_rounded
                    : Icons.local_shipping_rounded,
                color: scheme.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  invoice.invoiceNo,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: FinText.tabularNums,
                  ),
                ),
              ),
              TextButton.icon(
                key: const Key('ret_change_invoice_button'),
                onPressed: onChange,
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: Text(l10n.retChangeInvoice),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${invoice.partyName ?? (isSale ? l10n.sellCashCustomer : l10n.purSupplierRequired)} · ${purFormatDate(local)} · ${purFormatTime(local)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: FinText.tabularNums,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
