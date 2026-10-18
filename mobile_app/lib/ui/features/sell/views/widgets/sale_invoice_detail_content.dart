/// محتوى تفاصيل فاتورة البيع (الرأس/البنود/الإجماليات/الربح/الإبطال) —
/// مستخرج من sales_invoices_screen (R19-D3b: نقل حرفي بلا أي تغيير سلوكي).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../domain/models/sale.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../core/widgets/void_invoice_confirm.dart';
import '../../view_models/sales_invoices_view_model.dart';
import 'sale_invoice_rows.dart';
import 'sale_manager_profit_card.dart';
import 'sell_widgets.dart';

class SaleInvoiceDetailContent extends StatelessWidget {
  const SaleInvoiceDetailContent({
    super.key,
    required this.detail,
    required this.vm,
  });

  final SaleInvoiceDetail detail;
  final SaleInvoiceDetailViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final invoice = detail.invoice;
    final local = invoice.issuedAt.toLocal();
    final isVoided = invoice.status == 'void';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // رأس الفاتورة.
        FinCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      invoice.invoiceNo,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFeatures: FinText.tabularNums,
                      ),
                    ),
                  ),
                  if (isVoided) ...[
                    const VoidedBadge(dense: false),
                    const SizedBox(width: 6),
                  ],
                  PayStatusChip(method: invoice.payStatus, dense: false),
                ],
              ),
              const SizedBox(height: 6),
              if (isVoided) ...[
                // تنويه الإبطال (FR-02-15): حركاتها معكوسة كاملة والرقم
                // لا يُعاد — الفاتورة تبقى ظاهرة للتدقيق والطباعة بحالتها.
                Text(
                  l10n.invoiceVoidedNote,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: FinColors.of(context).negative,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (invoice.rateIsFallback) ...[
                const FallbackRateBadge(dense: false),
                const SizedBox(height: 8),
              ],
              Text(
                '${sellFormatDate(local)} · ${sellFormatTime(local)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: FinText.tabularNums,
                ),
              ),
              const SizedBox(height: 8),
              SaleInvoiceInfoRow(
                label: l10n.sellDetailCustomer,
                value: detail.customerName ?? l10n.sellCashCustomer,
              ),
              if (detail.customerPhone != null &&
                  detail.customerPhone!.isNotEmpty)
                SaleInvoiceInfoRow(
                  label: l10n.sellDetailPhone,
                  value: detail.customerPhone!,
                ),
              SaleInvoiceInfoRow(
                label: l10n.sellDetailCurrency,
                value:
                    '${detail.currencyCode ?? ''}'
                    '${detail.currencySymbol != null ? ' · ${detail.currencySymbol}' : ''}',
              ),
              if (invoice.exchangeRate != 1)
                SaleInvoiceInfoRow(
                  label: l10n.sellDetailExchangeRate,
                  value: AmountText.format(invoice.exchangeRate, 4),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // البنود.
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
              for (final item in detail.items) SaleInvoiceItemRow(item: item),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // الإجماليات.
        FinCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SaleInvoiceAmountRow(
                label: l10n.sellTotalsSubtotal,
                value: invoice.subtotal,
              ),
              if (invoice.discountAmount > 0)
                SaleInvoiceAmountRow(
                  label: l10n.sellDetailTotalDiscount,
                  value: invoice.discountAmount,
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
                      l10n.sellTotalsGrandTotal,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  AmountText(
                    amount: invoice.total,
                    size: AmountSize.large,
                    decimals: _decimals(invoice.total),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SaleInvoiceAmountRow(
                label: l10n.sellInvoicesPaidLabel,
                value: invoice.paidAmount,
                sign: FinSign.incoming,
              ),
              SaleInvoiceAmountRow(
                label: l10n.sellInvoicesDueLabel,
                value: invoice.dueAmount,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // ربح الفاتورة (FR-09-11) — قسم إداري صغير أسفل الإجماليات.
        SaleManagerProfitCard(invoice: invoice),
        const SizedBox(height: 14),
        // P1-1: مرتجع بيع SRN عن هذه الفاتورة — الربط العميق ?invoice=
        // جاهز في الموجّه (نفس نمط مرتجع الشراء في قائمة الشراء).
        // الملغاة لا تُرتجَع (حركاتها معكوسة أصلاً — FR-02-15).
        if (!isVoided)
          OutlinedButton.icon(
            key: const Key('sell_detail_return_button'),
            onPressed: () =>
                context.go('/purchases/returns/sale?invoice=${invoice.id}'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.assignment_return_rounded, size: 20),
            label: Text(l10n.sellFixDetailReturnAction),
          ),
        // إبطال الفاتورة (FR-02-15 — R17-c): للفاتورة المكتملة فقط،
        // بصلاحية المدير (الجلسة مديرية حصراً في V1 — قرار موثّق بنمط
        // قسم الربح أعلاه)، نمط تدميري (ألوان سالبة + أيقونة block).
        if (!isVoided) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('sell_detail_void_button'),
            onPressed: vm.state.voiding
                ? null
                : () => unawaited(_confirmAndVoidSaleInvoice(context, vm)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              side: BorderSide(
                color: FinColors.of(context).negative.withValues(alpha: 0.5),
              ),
            ),
            icon: vm.state.voiding
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.block_rounded, size: 20),
            label: Text(
              l10n.invoiceVoidButton,
              style: TextStyle(color: FinColors.of(context).negative),
            ),
          ),
        ],
      ],
    );
  }

  static int _decimals(double value) =>
      value == value.truncateToDouble() ? 0 : 2;
}

/// مسار إبطال فاتورة البيع: تأكيد مزدوج (تحذير ← سبب اختياري) ←
/// تنفيذ عبر المتحكم ← رسالة نجاح/فشل بنمط رسائل الشاشات القائمة
/// (ScaffoldMessenger — رسالة المستودع تُعرض كما هي).
Future<void> _confirmAndVoidSaleInvoice(
  BuildContext context,
  SaleInvoiceDetailViewModel vm,
) async {
  final invoiceNo = vm.state.detail?.invoice.invoiceNo ?? '';
  final reason = await showVoidInvoiceConfirm(context, invoiceNo: invoiceNo);
  if (reason == null || !context.mounted) return;
  final ok = await vm.voidInvoice(reason: reason);
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context)!;
  if (ok) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.invoiceVoidedSnackBar(invoiceNo))),
      );
  } else {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(vm.state.voidError ?? l10n.genericErrorTitle)),
      );
  }
}
