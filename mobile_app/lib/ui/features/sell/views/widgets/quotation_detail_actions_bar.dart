/// شريط أزرار تفاصيل عرض السعر (تحويل لفاتورة/تعليم مُرسَل/إلغاء بتأكيد)
/// بمساراته الخاصة — مستخرج من quotation_detail_screen (R20-D3b: نقل
/// حرفي بلا أي تغيير سلوكي).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../domain/models/quotation.dart';
import '../../../../../domain/services/credit_limit.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/session/app_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../view_models/print_on_save.dart';
import '../../view_models/quotations_view_model.dart';
import 'invoice_pdf_preview.dart';
import 'payment_sheet.dart';

class QuotationActionsBar extends StatelessWidget {
  const QuotationActionsBar({super.key, required this.vm});

  final QuotationDetailViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final quotation = vm.quotation!;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: FinColors.of(context).cardBorder),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: vm.state.converting
                      ? null
                      : () => _convert(context, vm),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    textStyle: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: Text(l10n.sellQuotationConvertButton),
                ),
              ),
              if (quotation.status == QuotationStatus.draft) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: () => _markSent(context, vm),
                    icon: const Icon(Icons.send_rounded, size: 20),
                    label: Text(l10n.sellQuotationMarkSent),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () => _cancel(context, vm),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FinColors.of(context).negative,
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 20),
                  label: Text(l10n.sellQuotationCancel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _convert(
    BuildContext context,
    QuotationDetailViewModel vm,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final quotation = vm.quotation!;
    final app = context.read<AppController>();
    // P0-2: نفس سلوك الكاشير — print_on_save يحكم أزرار الإيصال هنا.
    final printMode = await resolvePrintOnSave(app.settings);
    if (!context.mounted) return;
    final sales = app.sales;
    final posted = await showPaymentSheet(
      context,
      grandTotal: quotation.total,
      decimals: vm.currency?.decimals ?? 2,
      currencyCode: vm.state.detail?.currencyCode,
      customerName: vm.state.detail?.customerName,
      onConfirm: (paidCash, method) =>
          vm.convertToInvoice(paidCash: paidCash, paymentMethod: method),
      // FR-03-05 (17-c): بوابة حد الائتمان عند تحويل عرض السعر لفاتورة.
      creditGate: () => _resolveCreditGate(app, quotation),
      // P0-2: معاينة PDF للفاتورة الناتجة عن التحويل.
      printOnSave: printMode,
      openInvoicePreview: sales == null
          ? null
          : (receipt) => openInvoicePdfPreview(
              context,
              saleRepo: sales,
              invoiceId: receipt.invoiceId,
            ),
    );
    if (posted && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.sellQuotationConvertedMessage)),
        );
    }
  }

  /// يجلب معطيات بوابة حد الائتمان لعرض السعر المحوَّل — null عند غياب
  /// العميل (عرض نقدي مجهول) أو المستودعات (FR-03-05).
  Future<CreditLimitGate?> _resolveCreditGate(
    AppController app,
    Quotation quotation,
  ) async {
    final customerId = quotation.customerId;
    if (customerId == null) return null;
    final customers = app.customers;
    final settings = app.settings;
    if (customers == null || settings == null) return null;
    final check = await customers.checkCredit(
      customerId,
      quotation.currencyId,
      0,
    );
    final action = await settings.getString(
      'parties.credit_limit_action',
      'warn',
    );
    return CreditLimitGate(
      creditLimit: check.creditLimit,
      action: action,
      currentBalance: check.balance,
    );
  }

  Future<void> _markSent(
    BuildContext context,
    QuotationDetailViewModel vm,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await vm.markSent();
    if (!context.mounted) return;
    if (result.isOk) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.sellQuotationSentMessage)));
      unawaited(vm.load());
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(result.errorOrNull!)));
    }
  }

  Future<void> _cancel(
    BuildContext context,
    QuotationDetailViewModel vm,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.sellQuotationCancelConfirmTitle),
        content: Text(
          l10n.sellQuotationCancelConfirmBody(vm.quotation!.quotationNo),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      final result = await vm.cancel();
      if (!context.mounted) return;
      if (result.isOk) {
        unawaited(vm.load());
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(result.errorOrNull!)));
      }
    }
  }
}
