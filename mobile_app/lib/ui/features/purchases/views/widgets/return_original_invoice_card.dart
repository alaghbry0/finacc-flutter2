/// بطاقة فاتورة أصلية واحدة في طور اختيار المرتجع (R19-D3c — مستخرجة
/// حرفياً من `returns_screen.dart` بلا أي تغيير دلالة).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../view_models/returns_view_model.dart';
import 'purchase_format.dart';

/// بطاقة فاتورة أصلية واحدة في طور الاختيار.
class ReturnOriginalInvoiceCard extends StatelessWidget {
  const ReturnOriginalInvoiceCard({
    super.key,
    required this.invoice,
    required this.isSale,
    required this.onTap,
  });

  final ReturnableInvoice invoice;
  final bool isSale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final local = invoice.issuedAt.toLocal();

    return FinCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  invoice.invoiceNo,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: FinText.tabularNums,
                  ),
                ),
              ),
              if (!invoice.hasParty && isSale)
                StatusChip(label: l10n.sellCashCustomer, dense: true),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  invoice.partyName ??
                      (isSale
                          ? l10n.sellCashCustomer
                          : l10n.purSupplierRequired),
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${purFormatDate(local)} · ${purFormatTime(local)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: FinText.tabularNums,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Spacer(),
              AmountText(
                amount: invoice.total,
                decimals: invoice.total == invoice.total.truncateToDouble()
                    ? 0
                    : 2,
              ),
              if (invoice.currencyCode != null) ...[
                const SizedBox(width: 4),
                Text(
                  invoice.currencyCode!,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: colors.gold),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
