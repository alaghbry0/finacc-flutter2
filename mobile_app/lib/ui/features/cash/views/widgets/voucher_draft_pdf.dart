/// إسقاط طباعة **مسودة** سند القبض/الصرف من شاشة السند نفسها (V6-C):
/// زرا «إرسال»/«طباعة» بشريط الإجراءات السفلي SIM يفتحان معاينة PDF
/// للورقة الحية قبل الترحيل — بنمط `movement_voucher_pdf.dart` حرفياً
/// (نفس البنية والتسميات المسبقة التعريب من l10n) مع **وسم صادق
/// «مسودة — لم تُرحّل»** يمنع التباس ورقة معاينة بسند مرقّم مُرحّل.
///
/// ## قرار آلية وسم المسودة (موثق)
/// رقم السند هنا **معاينة لا استهلاكاً** (`previewVoucherNo` — V6-A) فلا
/// يجوز تشويهه بلاحقة، والحقول الموجودة في `VoucherPrintDoc` لا تحمل
/// مفهوم المسودة؛ لذا أُضيف حقل اختياري واحد `draftLabel` إلى
/// `VoucherLabels` (بلا كسر — null افتراضياً لكل البناة القائمة) يرسم
/// القالب (`VoucherPdfBuilder`) عند حضوره شريط وسم ذهبياً رفيعاً تحت
/// العنوان — شرط عرض واحد لا يغيّر أي مخرج قائم. مراجع تخصيص FIFO
/// (previewPlan) لا مكان لها بحقول المسقط فلا تُحوَّق داخل الوصف.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../domain/models/company.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/session/app_controller.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../printing/docs/print_docs.dart';
import '../../../printing/services/voucher_pdf_builder.dart';
import '../../../printing/views/pdf_preview_dialog.dart';
import '../../view_models/voucher_view_model.dart';
import 'cash_widgets.dart';

/// يبني إسقاط مسودة السند من بيانات الشاشة الحية — كل تسمية مسبقة
/// التعريب من l10n والمبلغ عبر `AmountText.format` بمنازل عملة السند
/// (قاعدة 5.4-9). [isDraft] يضيف وسم «مسودة — لم تُرحّل» (والقيمة
/// معاينة للرقم القادم — لا تسلسل مستهلك). [company] اختياري لرأس
/// المنشأة بنمط `movementVoucherPrintDoc` حرفياً. [amountWords]
/// (مراجعة 🟡-3) سطر التفقيط من قارئ النموذج — يحضر كتلة
/// «المبلغ بالكلمات» تحت المبلغ البطل بالقالب عند توفره.
VoucherPrintDoc buildVoucherDraftPrintDoc(
  AppLocalizations l10n, {
  required bool isReceipt,
  required String voucherNo,
  required String dateLabel,
  String? partyName,
  required String amountLabel,
  required String currencyCode,
  String? description,
  required String boxName,
  required bool isDraft,
  Company? company,
  String? amountWords,
}) {
  return VoucherPrintDoc(
    header: PrintHeader(
      name: company?.name ?? '',
      phone: company?.phone,
      address: company?.address,
      footerText: company?.footerText,
    ),
    isReceipt: isReceipt,
    voucherNo: voucherNo,
    dateLabel: dateLabel,
    partyName: partyName,
    amountLabel: amountLabel,
    currencyCode: currencyCode,
    description: description,
    boxName: boxName,
    amountWords: amountWords,
    labels: VoucherLabels(
      titleReceipt: l10n.printingVoucherReceiptTitle,
      titlePayment: l10n.printingVoucherPaymentTitle,
      party: l10n.printingLblParty,
      date: l10n.printingLblDate,
      amount: l10n.printingLblAmount,
      description: l10n.printingLblDescription,
      box: l10n.printingLblBox,
      signature: l10n.printingLblSignature,
      footerThanks: l10n.printingFooterThanks,
      draftLabel: isDraft ? l10n.simRcptDraftBadge : null,
      wordsLabel: l10n.printingLblAmountWords,
    ),
  );
}

/// يفتح نافذة معاينة PDF لمسودة السند الحية — نمط `openInvoicePdfPreview`
/// (sell/views/widgets/invoice_pdf_preview.dart): **القيم تُلتقط قبل أي
/// await** (لا سياق عبر فجوة غير متزامنة)، وواتساب من المنشأة، ورسالة
/// المشاركة = رقم السند + المبلغ. الإرسال/الطباعة الحقيقية من أزرار
/// النافذة نفسها (طباعة/مشاركة/واتساب) — زرا الشريط مجرد مدخلين لها.
void openVoucherDraftPdfPreview(BuildContext context, VoucherViewModel vm) {
  final l10n = AppLocalizations.of(context)!;
  final app = context.read<AppController>();
  final company = app.company;
  // لقطة المسودة الحية قبل أي عمل غير متزامن.
  final isReceipt = vm.isReceipt;
  final voucherNo = vm.previewVoucherNo ?? (isReceipt ? 'RVT' : 'PMT');
  final dateLabel = cashFormatDate(vm.txDate);
  final partyName = vm.partyName;
  // مراجعة 🟡-3 — المنازل والتفقيط من قارئي النموذج (مصدر واحد مع
  // معاينة الشاشة — كانا محسوبين هنا على حدة حرفياً).
  final decimals = vm.voucherDecimals;
  final amountWords = vm.amountWords;
  final amountLabel = AmountText.format(vm.amount ?? 0, decimals);
  final currencyCode = vm.voucherCurrencyCode ?? '';
  final description = vm.notes.trim().isEmpty ? null : vm.notes.trim();
  final boxName = vm.selectedBox?.box.name ?? '';
  final whatsappPhone = company?.whatsapp;
  final shareMessage = l10n.printingShareMessageVoucher(voucherNo, amountLabel);
  unawaited(
    showPdfPreviewDialog(
      context,
      title: voucherNo,
      build: () => const VoucherPdfBuilder().build(
        buildVoucherDraftPrintDoc(
          l10n,
          isReceipt: isReceipt,
          voucherNo: voucherNo,
          dateLabel: dateLabel,
          partyName: partyName,
          amountLabel: amountLabel,
          currencyCode: currencyCode,
          description: description,
          boxName: boxName,
          isDraft: true,
          company: company,
          amountWords: amountWords,
        ),
      ),
      whatsappPhone: whatsappPhone,
      shareMessage: shareMessage,
    ),
  );
}
