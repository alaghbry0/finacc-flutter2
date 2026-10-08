/// فتح معاينة PDF لفاتورة بيع — النمط القائم من زر PDF في شاشة تفاصيل
/// الفواتير (sales_invoices_screen، الشريحة 7) مستخرجاً لمشاركته مع
/// إيصال نجاح الكاشير (P0-2): يحمّل تفاصيل الفاتورة المرحّلة من
/// المستودع، يبني مسقط الطباعة `InvoicePrintDoc` (كل تسمية عبر l10n
/// وكل رقم عبر AmountText.format) ثم يفتح `PdfPreviewDialog` القائم
/// بطباعته/مشاركته/واتسابه.
///
/// دفاعي بالكامل: فشل تحميل التفاصيل = SnackBar عربي ولا انهيار.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../data/repositories/sale_repository.dart';
import '../../../../../domain/models/company.dart';
import '../../../../../domain/models/sale.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/session/app_controller.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../printing/print_docs.dart';
import '../../../printing/services/invoice_pdf_builder.dart';
import '../../../printing/views/pdf_preview_dialog.dart';
import 'sell_widgets.dart';

/// منازل العملة للطباعة — قرار المستدعي: YER = 0 (قاعدة 5.4-9) والباقي 2.
int invoicePrintDecimals(SaleInvoiceDetail detail) =>
    detail.currencyCode == 'YER' ? 0 : 2;

/// يبني إسقاط الطباعة من تفاصيل الفاتورة + رأس المنشأة — كل تسمية داخل
/// المستند مسبقة التعريب من l10n، وكل رقم عبر `AmountText.format`
/// (غربي بفواصل آلاف) فيبقى القالب نفسه بلا أي نص.
InvoicePrintDoc buildInvoicePrintDoc(
  AppLocalizations l10n,
  SaleInvoiceDetail detail,
  Company? company,
) {
  final decimals = invoicePrintDecimals(detail);
  final invoice = detail.invoice;
  return InvoicePrintDoc(
    header: PrintHeader(
      name: company?.name ?? '',
      phone: company?.phone,
      address: company?.address,
      footerText: company?.footerText,
    ),
    docNo: invoice.invoiceNo,
    dateLabel: sellFormatDate(invoice.issuedAt.toLocal()),
    partyName: detail.customerName ?? l10n.printingCashCustomer,
    partyPhone: detail.customerPhone,
    currencyCode: detail.currencyCode ?? '',
    decimals: decimals,
    items: [
      for (final item in detail.items)
        InvoicePrintLine(
          desc: item.lineDesc ?? l10n.sellDetailUnknownItem,
          qtyLabel: sellQtyText(item.qty),
          priceLabel: AmountText.format(item.unitPrice, decimals),
          discountLabel: item.discountAmount > 0.005
              ? AmountText.format(item.discountAmount, 2)
              : '—',
          totalLabel: AmountText.format(item.lineTotal, decimals),
        ),
    ],
    subtotal: invoice.subtotal,
    discountAmount: invoice.discountAmount,
    total: invoice.total,
    paidAmount: invoice.paidAmount,
    dueAmount: invoice.dueAmount,
    labels: InvoiceLabels(
      title: l10n.printingInvoiceDocTitle,
      customer: l10n.printingLblCustomer,
      date: l10n.printingLblDate,
      currency: l10n.printingLblCurrency,
      item: l10n.printingLblItem,
      qty: l10n.printingLblQty,
      price: l10n.printingLblPrice,
      discount: l10n.printingLblDiscount,
      subtotal: l10n.printingLblSubtotal,
      totalDiscount: l10n.printingLblTotalDiscount,
      grandTotal: l10n.printingLblGrandTotal,
      paid: l10n.printingLblPaid,
      due: l10n.printingLblDue,
      itemsSection: l10n.printingLblItemsSection,
      footerThanks: l10n.printingFooterThanks,
    ),
  );
}

/// يفتح نافذة معاينة الطباعة لفاتورة **محمّلة أصلاً** (تفاصيل الفاتورة
/// في شاشة القائمة) — القيم تُلتقط قبل أي await (لا سياق عبر فجوة
/// غير متزامنة)، وواتساب = واتساب المنشأة وإلا هاتف العميل، ورسالة
/// المشاركة = رقم الفاتورة + إجمالها.
void openLoadedInvoicePdfPreview(
  BuildContext context,
  SaleInvoiceDetail detail,
) {
  final l10n = AppLocalizations.of(context)!;
  final company = context.read<AppController>().company;
  final invoice = detail.invoice;
  unawaited(
    showPdfPreviewDialog(
      context,
      title: invoice.invoiceNo,
      build: () => const InvoicePdfBuilder().build(
        buildInvoicePrintDoc(l10n, detail, company),
      ),
      whatsappPhone: company?.whatsapp ?? detail.customerPhone,
      shareMessage: l10n.printingShareMessageInvoice(
        invoice.invoiceNo,
        AmountText.format(invoice.total, invoicePrintDecimals(detail)),
      ),
    ),
  );
}

/// يفتح نافذة معاينة الطباعة لفاتورة **بمعرّفها** — إيصال نجاح الكاشير
/// (P0-2): يحمّل التفاصيل من المستودع ثم يكمل بنمط الزر القائم.
/// فشل التحميل = SnackBar عربي (دفاعي).
Future<void> openInvoicePdfPreview(
  BuildContext context, {
  required SaleRepository saleRepo,
  required int invoiceId,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final company = context.read<AppController>().company;
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
  await showPdfPreviewDialog(
    context,
    title: detail.invoice.invoiceNo,
    build: () => const InvoicePdfBuilder().build(
      buildInvoicePrintDoc(l10n, detail!, company),
    ),
    whatsappPhone: company?.whatsapp ?? detail.customerPhone,
    shareMessage: l10n.printingShareMessageInvoice(
      detail.invoice.invoiceNo,
      AmountText.format(detail.invoice.total, invoicePrintDecimals(detail)),
    ),
  );
}
