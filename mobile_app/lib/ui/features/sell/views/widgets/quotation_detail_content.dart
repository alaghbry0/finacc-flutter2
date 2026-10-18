/// محتوى تفاصيل عرض السعر (رأس الفاتورة/البنود/الإجماليات/الملاحظات) —
/// مستخرج من quotation_detail_screen (R20-D3b: نقل حرفي بلا أي تغيير
/// سلوكي).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/quotations_view_model.dart';
import '../quotations_screen.dart' show QuotationStatusChip;
import 'quotation_detail_rows.dart';
import 'sell_format.dart';

class QuotationDetailContent extends StatelessWidget {
  const QuotationDetailContent({super.key, required this.vm});

  final QuotationDetailViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final detail = vm.state.detail!;
    final quotation = detail.quotation;
    final local = quotation.issuedAt.toLocal();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        FinCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      quotation.quotationNo,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFeatures: FinText.tabularNums,
                      ),
                    ),
                  ),
                  QuotationStatusChip(status: quotation.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${sellFormatDate(local)} · ${sellFormatTime(local)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: FinText.tabularNums,
                ),
              ),
              const SizedBox(height: 8),
              QuotationInfoRow(
                label: l10n.sellDetailCustomer,
                value: detail.customerName ?? l10n.sellCashCustomer,
              ),
              if (detail.customerPhone != null &&
                  detail.customerPhone!.isNotEmpty)
                QuotationInfoRow(
                  label: l10n.sellDetailPhone,
                  value: detail.customerPhone!,
                ),
              // العملة والسعر صفّان مستقلان — الدمج في قيمة واحدة فاض
              // العرض 116px على 390dp (فحص P2-5).
              QuotationInfoRow(
                label: l10n.sellDetailCurrency,
                value: detail.currencyCode ?? '',
              ),
              QuotationInfoRow(
                label: l10n.sellQuotationRateLabel,
                value: AmountText.format(quotation.exchangeRate, 4),
              ),
              if (quotation.validUntil != null)
                QuotationInfoRow(
                  label: l10n.sellQuotationValidUntilLabel,
                  value: sellFormatDate(quotation.validUntil!.toLocal()),
                ),
              if (quotation.convertedInvoiceId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  // P2-5: رقم الفاتورة الحقيقي INV-… (لا المعرّف الداخلي)
                  // + شريحة قابلة للنقر تفتح تفاصيل الفاتورة.
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: QuotationConvertedInvoiceChip(
                      invoiceId: quotation.convertedInvoiceId!,
                      invoiceNo:
                          vm.state.convertedInvoiceNo ??
                          '#${quotation.convertedInvoiceId}',
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FinCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.sellDetailItemsSection,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              for (final item in detail.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.lineDesc ?? l10n.sellDetailUnknownItem,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${l10n.sellDetailQtyLabel} '
                              '${sellQtyText(item.qty)} × '
                              '${AmountText.format(item.unitPrice, item.unitPrice == item.unitPrice.truncateToDouble() ? 0 : 2)}'
                              '${item.discountAmount > 0 ? ' · ${l10n.sellDetailDiscountLabel} ${AmountText.format(item.discountAmount, 2)}' : ''}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontFeatures: FinText.tabularNums,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: AmountText(
                            amount: item.lineTotal,
                            decimals:
                                item.lineTotal ==
                                    item.lineTotal.truncateToDouble()
                                ? 0
                                : 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FinCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              QuotationAmountRow(
                label: l10n.sellTotalsSubtotal,
                value: quotation.subtotal,
              ),
              if (quotation.discountAmount > 0)
                QuotationAmountRow(
                  label: l10n.sellDetailTotalDiscount,
                  value: quotation.discountAmount,
                  sign: FinSign.outgoing,
                ),
              Divider(
                height: 18,
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.sellQuotationNetTotal,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  AmountText(
                    amount: quotation.total,
                    size: AmountSize.large,
                    decimals:
                        quotation.total == quotation.total.truncateToDouble()
                        ? 0
                        : 2,
                  ),
                ],
              ),
            ],
          ),
        ),
        if ((quotation.notesPrinted ?? '').isNotEmpty) ...[
          const SizedBox(height: 14),
          FinCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.sellQuotationPrintedNotes,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  quotation.notesPrinted!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
