/// محتوى تفاصيل فاتورة الشراء (R19-D3c — مستخرج حرفياً من
/// `purchases_list_screen.dart` بلا أي تغيير دلالة): الرأس والبنود
/// والإجماليات وزرا المرتجع والإبطال ومسار تأكيد الإبطال.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../core/widgets/void_invoice_confirm.dart';
import '../../../../../domain/models/purchase.dart';
import '../../view_models/purchases_list_view_model.dart';
import 'purchase_detail_rows.dart';
import 'purchase_format.dart';
import 'purchase_pay_status_chip.dart';

class PurchaseDetailContent extends StatelessWidget {
  const PurchaseDetailContent({
    super.key,
    required this.detail,
    required this.vm,
  });

  final PurchaseInvoiceDetail detail;
  final PurchaseDetailViewModel vm;

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
                  PurchasePayStatusChip(
                    method: invoice.payStatus,
                    dense: false,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (isVoided) ...[
                // تنويه الإبطال (FR-02-15): الوارد والمخزون وWAC والصندوق
                // ودين المورد عُكست كاملة — الفاتورة تبقى للتدقيق.
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
                const PurchaseFallbackRateBadge(dense: false),
                const SizedBox(height: 8),
              ],
              Text(
                '${purFormatDate(local)} · ${purFormatTime(local)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: FinText.tabularNums,
                ),
              ),
              const SizedBox(height: 8),
              PurchaseInfoRow(
                label: l10n.purDetailSupplier,
                value: detail.supplierName ?? l10n.purSupplierRequired,
              ),
              if (detail.supplierPhone != null &&
                  detail.supplierPhone!.isNotEmpty)
                PurchaseInfoRow(
                  label: l10n.sellDetailPhone,
                  value: detail.supplierPhone!,
                ),
              PurchaseInfoRow(
                label: l10n.sellDetailCurrency,
                value:
                    '${detail.currencyCode ?? ''}'
                    '${detail.currencySymbol != null ? ' · ${detail.currencySymbol}' : ''}',
              ),
              if (invoice.exchangeRate != 1)
                PurchaseInfoRow(
                  label: l10n.sellDetailExchangeRate,
                  value: AmountText.format(invoice.exchangeRate, 4),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // البنود بتكاليفها.
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
              for (final item in detail.items) PurchaseItemRow(item: item),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // الإجماليات والمدفوعات.
        FinCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PurchaseAmountRow(
                label: l10n.sellTotalsSubtotal,
                value: invoice.subtotal,
              ),
              if (invoice.discountAmount > 0)
                PurchaseAmountRow(
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
              PurchaseAmountRow(
                label: l10n.purInvoicesPaidLabel,
                value: invoice.paidAmount,
                sign: FinSign.outgoing,
              ),
              PurchaseAmountRow(
                label: l10n.purInvoicesDueLabel,
                value: invoice.dueAmount,
                sign: FinSign.outgoing,
              ),
              const SizedBox(height: 8),
              Divider(
                height: 18,
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
              // قيمة الوارد بالتكلفة (بالعملة الأساسية) — WAC الداخات.
              PurchaseAmountRow(
                label: l10n.purDetailStockValue,
                value: invoice.costTotal,
              ),
              Text(
                l10n.purDetailStockValueNote,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // الإجراءات — مرتجع شراء PRN عن هذه الفاتورة (الملغاة لا
        // تُرتجَع — حركاتها معكوسة أصلاً FR-02-15).
        if (!isVoided)
          OutlinedButton.icon(
            key: const Key('pur_detail_return_button'),
            onPressed: () => context.go(
              '/purchases/returns/purchase?purchase=${invoice.id}',
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.assignment_return_rounded, size: 20),
            label: Text(l10n.purDetailReturnAction),
          ),
        // إبطال فاتورة الشراء (FR-02-15 — R17-c): للمكتملة فقط، بصلاحية
        // المدير (الجلسة مديرية حصراً في V1)، نمط تدميري سالب.
        if (!isVoided) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('pur_detail_void_button'),
            onPressed: vm.state.voiding
                ? null
                : () => unawaited(_confirmAndVoidPurchaseInvoice(context, vm)),
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

/// مسار إبطال فاتورة الشراء: تأكيد مزدوج (تحذير ← سبب اختياري) ←
/// تنفيذ عبر المتحكم ← رسالة نجاح/فشل (ScaffoldMessenger — رسالة
/// المستودع تُعرض كما هي بنمط الشاشات القائمة).
Future<void> _confirmAndVoidPurchaseInvoice(
  BuildContext context,
  PurchaseDetailViewModel vm,
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
