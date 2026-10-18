/// إيصال النجاح بنافذة رد قيمة المرتجع (مرتجع جديد/إغلاق) — مستخرج من
/// return_refund_sheet (R20-D3b: نقل حرفي بلا أي تغيير سلوكي).
library;

import 'package:flutter/material.dart';

import '../../../../../data/repositories/return_repository.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/fin_sheet_drag_handle.dart';
import 'posted_return_receipt_card.dart';

class ReturnRefundReceiptView extends StatelessWidget {
  const ReturnRefundReceiptView({super.key, required this.receipt});

  final ReturnPostedReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FinSheetDragHandle(),
        const SizedBox(height: 8),
        PostedReturnReceiptCard(receipt: receipt),
        const SizedBox(height: 18),
        FilledButton.icon(
          key: const Key('ret_receipt_new'),
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          icon: const Icon(Icons.post_add_rounded),
          label: Text(l10n.retNewReturn),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.commonDone),
        ),
      ],
    );
  }
}
