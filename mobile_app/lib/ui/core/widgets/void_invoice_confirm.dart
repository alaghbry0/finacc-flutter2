/// حوار تأكيد الإبطال المدمِّر المزدوج (FR-02-15 — R17-c).
///
/// **النمط**: حوارا تأكيد متتاليان على مسار المسح المحروس القائم
/// (`confirm_word_dialog.dart` — تحذير ← تأكيد نهائي) مع **حقل سبب
/// اختياري** في التأكيد النهائي بنمط حوار إبطال حركة الصندوق
/// (`movements_screen._confirmVoid`). مستند واحد (بيع/شراء) — نفس
/// الحوار للاثنين.
///
/// يعيد سبب الإبطال (نصاً — قد يكون فارغاً) عند التأكيد النهائي،
/// أو `null` عند الإلغاء في أي مرحلة.
library;

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// يعرض مسار التأكيد المزدوج ويعيد السبب (أو null عند الإلغاء).
Future<String?> showVoidInvoiceConfirm(
  BuildContext context, {
  required String invoiceNo,
}) async {
  final l10n = AppLocalizations.of(context)!;

  // (1) حوار التحذير الأول — عواقب الإبطال بصيغة المستخدم.
  final warned = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.invoiceVoidConfirmTitle),
      content: Text(l10n.invoiceVoidConfirmBody(invoiceNo)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.invoiceVoidConfirmContinue),
        ),
      ],
    ),
  );
  if (warned != true || !context.mounted) return null;

  // (2) التأكيد النهائي + سبب اختياري (نمط إبطال حركة الصندوق).
  final reasonController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.invoiceVoidFinalTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.invoiceVoidFinalBody(invoiceNo)),
          const SizedBox(height: 12),
          TextField(
            controller: reasonController,
            maxLines: 2,
            maxLength: 120,
            decoration: InputDecoration(labelText: l10n.invoiceVoidReasonLabel),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.invoiceVoidConfirmAction),
        ),
      ],
    ),
  );
  if (confirmed != true) {
    reasonController.dispose();
    return null;
  }
  final reason = reasonController.text.trim();
  reasonController.dispose();
  return reason;
}
