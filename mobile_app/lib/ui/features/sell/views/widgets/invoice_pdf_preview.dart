/// فتح معاينة PDF لفاتورة بيع — مسارات البيع الخاصة: النمط القائم من
/// زر PDF في شاشة تفاصيل الفواتير (sales_invoices_screen، الشريحة 7)
/// وإيصال نجاح الكاشير (P0-2): يحمّل تفاصيل الفاتورة المرحّلة من
/// المستودع (بالمعرّف أو محمّلة أصلاً)، يبني مسقط الطباعة عبر بانى
/// بيت الطباعة الموحد ثم يفتح `PdfPreviewDialog` القائم
/// بطباعته/مشاركته/واتسابه.
///
/// **موجة UX-3**: البناء كله يمر عبر [`InvoiceTemplateEngine`] بالقالب
/// النشط من `print_template` (شاشة «الطباعة والفواتير») والشعار من
/// `company.logo_png` — غياب الجدول/الشعار يرد للبسيط الافتراضي بلا
/// انهيار (سلوك ما قبل الترقية).
///
/// دفاعي بالكامل: فشل تحميل التفاصيل = SnackBar عربي ولا انهيار.
///
/// **R20-D1 — توافق المسارات التاريخية**: عائلة بانى المسقط
/// (`buildInvoicePrintDoc` ورفاقه) وعائلة معاينة القالب
/// (`openInvoiceTemplatePreview`) انتقلتا إلى بيت الطباعة الواحد
/// (`printing/docs/invoice_print_doc_builder.dart` و
/// `printing/views/invoice_template_preview.dart`) وتُصدَّران من هنا
/// فلم يتغير مستورد قائم واحد (شاشات البيع واختبارات المسقط).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../data/repositories/sale_repository.dart';
import '../../../../../domain/models/sale.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/session/app_controller.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../printing/docs/invoice_print_doc_builder.dart';
import '../../../printing/templates/invoice_template_engine.dart';
import '../../../printing/views/pdf_preview_dialog.dart';

// الرموز المنقولة إلى بيت الطباعة — تصدير توافقي لمسار الاستيراد
// التاريخي هذا (الشاشات والاختبارات تستورده من هنا).
export '../../../printing/docs/invoice_print_doc_builder.dart';
export '../../../printing/views/invoice_template_preview.dart';

/// يفتح نافذة معاينة الطباعة لفاتورة **محمّلة أصلاً** (تفاصيل الفاتورة
/// في شاشة القائمة) — القيم تُلتقط قبل أي await (لا سياق عبر فجوة
/// غير متزامنة)، وواتساب = واتساب المنشأة وإلا هاتف العميل، ورسالة
/// المشاركة = رقم الفاتورة + إجمالها. البناء عبر المحرك بالقالب النشط.
void openLoadedInvoicePdfPreview(
  BuildContext context,
  SaleInvoiceDetail detail,
) {
  final l10n = AppLocalizations.of(context)!;
  final app = context.read<AppController>();
  final company = app.company;
  final invoice = detail.invoice;
  unawaited(() async {
    final settings = await activeInvoicePrintSettings(app);
    if (!context.mounted) return;
    await showPdfPreviewDialog(
      context,
      title: invoice.invoiceNo,
      build: () => const InvoiceTemplateEngine().build(
        buildInvoicePrintDoc(l10n, detail, company),
        settings: settings,
        logoPng: company?.logoPng,
      ),
      whatsappPhone: company?.whatsapp ?? detail.customerPhone,
      shareMessage: l10n.printingShareMessageInvoice(
        invoice.invoiceNo,
        AmountText.format(invoice.total, invoicePrintDecimals(detail)),
      ),
    );
  }());
}

/// يفتح نافذة معاينة الطباعة لفاتورة **بمعرّفها** — إيصال نجاح الكاشير
/// (P0-2): يحمّل التفاصيل من المستودع ثم يكمل بنمط الزر القائم.
/// فشل التحميل = SnackBar عربي (دفاعي). البناء عبر المحرك بالقالب
/// النشط (UX-3) — مسار «طباعة فاتورة» وإيصال النجاح كلاهما من هنا.
Future<void> openInvoicePdfPreview(
  BuildContext context, {
  required SaleRepository saleRepo,
  required int invoiceId,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final app = context.read<AppController>();
  final company = app.company;
  final messenger = ScaffoldMessenger.of(context);
  SaleInvoiceDetail? detail;
  try {
    detail = await saleRepo.invoiceDetail(invoiceId);
  } catch (_) {
    detail = null;
  }
  if (!context.mounted) return;
  if (detail == null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.sellFixPrintLoadFailed)));
    return;
  }
  final settings = await activeInvoicePrintSettings(app);
  if (!context.mounted) return;
  await showPdfPreviewDialog(
    context,
    title: detail.invoice.invoiceNo,
    build: () => const InvoiceTemplateEngine().build(
      buildInvoicePrintDoc(l10n, detail!, company),
      settings: settings,
      logoPng: company?.logoPng,
    ),
    whatsappPhone: company?.whatsapp ?? detail.customerPhone,
    shareMessage: l10n.printingShareMessageInvoice(
      detail.invoice.invoiceNo,
      AmountText.format(detail.invoice.total, invoicePrintDecimals(detail)),
    ),
  );
}
