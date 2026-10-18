/// قسم ربح الفاتورة الإداري (FR-09-11) — مستخرج من sales_invoices_screen
/// (R19-D3b: نقل حرفي بلا أي تغيير سلوكي).
library;

import 'package:flutter/material.dart';

import '../../../../../domain/models/sale.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import 'sale_invoice_rows.dart';

/// قسم ربح الفاتورة الإداري (FR-09-11): التكلفة + الربح + هامش الربح ٪.
///
/// **قرار موثق**: V1 فيها مدير واحد حصراً (بلا أدوار متعددة) → القسم
/// يُعرض **دائماً** في تفاصيل فاتورة البيع (بلا بوابة صلاحيات). الربح
/// = `total_base − cost_total` — كلا الطرفان بالعملة الأساسية أصلاً
/// (cost_total يُجمَّع من line_cost بالأساس — sale_repository 8-د)،
/// والهامش يظهر فقط عند تكلفة موجبة (لا قسمة على صفر).
class SaleManagerProfitCard extends StatelessWidget {
  const SaleManagerProfitCard({super.key, required this.invoice});

  final SaleInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final cost = invoice.costTotal;
    // كلا الطرفين بالعملة الأساسية أصلاً — لا خلط عملات (5.4-7).
    final profit = invoice.totalBase - cost;
    final sign = profit > 0.005
        ? FinSign.incoming
        : profit < -0.005
        ? FinSign.outgoing
        : FinSign.neutral;
    final margin = cost > 0.005 ? profit / cost * 100 : null;
    return FinCard(
      key: const Key('invoice_profit_card'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 16, color: colors.gold),
              const SizedBox(width: 6),
              Text(
                l10n.invoiceProfitSectionTitle,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.invoiceProfitManagerHint,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SaleInvoiceInfoRow(
            label: l10n.invoiceCostLabel,
            value: AmountText.format(cost, _decimalsValue(cost)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.invoiceProfitLabel,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                AmountText(
                  amount: profit.abs(),
                  sign: sign,
                  decimals: _decimalsValue(profit),
                ),
              ],
            ),
          ),
          if (margin != null)
            SaleInvoiceInfoRow(
              label: l10n.invoiceMarginLabel,
              value: '${margin.toStringAsFixed(1)}%',
            ),
          const SizedBox(height: 6),
          Text(
            l10n.profitBaseCurrencyNote,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  static int _decimalsValue(double value) =>
      value == value.truncateToDouble() ? 0 : 2;
}
