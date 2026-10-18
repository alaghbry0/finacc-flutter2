/// إيصال النجاح بنافذة الدفع (أزرار الطباعة/المشاركة + فاتورة جديدة) —
/// مستخرج من payment_sheet (R19-D3b: نقل حرفي بلا أي تغيير سلوكي).
library;

import 'package:flutter/material.dart';

import '../../../../../domain/models/sale.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/fin_sheet_drag_handle.dart';
import 'posted_receipt_card.dart';

class PaymentReceiptView extends StatelessWidget {
  const PaymentReceiptView({
    super.key,
    required this.receipt,
    required this.currencyCode,
    required this.printAvailable,
    required this.onOpenPreview,
  });

  final SalePostedReceipt receipt;
  final String? currencyCode;
  final bool printAvailable;
  final Future<void> Function() onOpenPreview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FinSheetDragHandle(),
        const SizedBox(height: 8),
        PostedReceiptCard(
          receipt: receipt,
          currencyCode: currencyCode,
          // P0-2: زرا الطباعة/المشاركة داخل البطاقة (وضعا ask/always).
          onPrint: printAvailable ? onOpenPreview : null,
          onShare: printAvailable ? onOpenPreview : null,
        ),
        const SizedBox(height: 18),
        // P2-1: الزران متمايزان — الأساسي «طباعة + فاتورة جديدة» عند
        // توافر الطباعة (يفتح المعاينة ثم يغلق)، وإلا «فاتورة جديدة» فقط؛
        // والثانوي «إغلاق» (ينهي بلا طباعة).
        FilledButton.icon(
          key: const Key('sell_receipt_primary_action'),
          onPressed: () async {
            if (printAvailable) await onOpenPreview();
            if (!context.mounted) return;
            Navigator.of(context).pop(true);
          },
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          icon: Icon(printAvailable ? Icons.print_rounded : Icons.post_add),
          label: Text(
            printAvailable
                ? l10n.sellFixPrintAndNewInvoice
                : l10n.sellReceiptNewInvoice,
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('sell_receipt_close_action'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.sellFixClose),
        ),
      ],
    );
  }
}
