/// بطاقة فاتورة شراء واحدة في قائمة المشتريات (R19-D3c — مستخرجة حرفياً
/// من `purchases_list_screen.dart` بلا أي تغيير دلالة).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../../domain/models/purchase.dart';
import 'purchase_format.dart';
import 'purchase_pay_status_chip.dart';

/// بطاقة فاتورة شراء واحدة في القائمة.
class PurchaseInvoiceCard extends StatelessWidget {
  const PurchaseInvoiceCard({super.key, required this.invoice});

  final PurchaseInvoiceSummary invoice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final local = invoice.issuedAt.toLocal();

    return FinCard(
      onTap: () => context.go('/purchases/invoices/${invoice.id}'),
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
              // FR-02-15: الملغاة تبقى ظاهرة بالقائمة بشارة «ملغاة»
              // (بطاقتها لا تُحذف — حركاتها معكوسة والرقم لا يُعاد).
              if (invoice.status == 'void') ...[
                const VoidedBadge(),
                const SizedBox(width: 6),
              ],
              PurchasePayStatusChip(method: invoice.payStatus),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  invoice.supplierName ?? l10n.purSupplierRequired,
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
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.purInvoicesPaidLabel,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    AmountText(
                      amount: invoice.paidAmount,
                      sign: FinSign.outgoing,
                      decimals: _decimals(invoice.paidAmount),
                    ),
                  ],
                ),
              ),
              if (invoice.dueAmount > 0)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.purInvoicesDueLabel,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      AmountText(
                        amount: invoice.dueAmount,
                        sign: FinSign.outgoing,
                        decimals: _decimals(invoice.dueAmount),
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
                        amount: invoice.total,
                        decimals: _decimals(invoice.total),
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
                  Text(
                    l10n.purInvoicesTotalLabel,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static int _decimals(double value) =>
      value == value.truncateToDouble() ? 0 : 2;
}
