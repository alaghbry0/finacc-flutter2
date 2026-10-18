/// معاينة حية لقالب فاتورة البيع — «بيت الطباعة الواحد» (R20-D1).
///
/// كان هذا التدفق داخل `sell/views/widgets/invoice_pdf_preview.dart`
/// ونُقل هنا ليُغلق الاقتران العابر الوحيد غير الطباعي (settings→sell):
/// شاشة «الطباعة والفواتير» بالمركز تستورد [openInvoiceTemplatePreview]
/// من بيت الطباعة مباشرة بدل استيراد ملف من ميزة البيع لأجلها وحدها.
/// المعاينة تلتقط **آخر فاتورة بيع** مرحّلة (وإلا بيانات نموذجية عبر
/// [dummyInvoicePrintDoc]) وتبنيها عبر المحرك بالإعدادات الجارية نفسها
/// المعروضة على الشاشة، ثم تفتح `PdfPreviewDialog` القائم
/// بطباعته/مشاركته/واتسابه.
///
/// ملف البيع الأصلي يصدّر هذا الملف (re-export) فبقيت مسارات
/// الاستيراد التاريخية كلها تعمل بلا تعديل.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../data/models/invoice_template_settings.dart';
import '../../../../../domain/models/company.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/amount_text.dart';
import '../docs/invoice_print_doc_builder.dart';
import '../docs/print_docs.dart';
import '../templates/invoice_template_engine.dart';
import 'pdf_preview_dialog.dart';

/// يفتح معاينة حية للإعدادات الجارية: **آخر فاتورة بيع** وإلا بيانات
/// نموذجية — عبر المحرك بالإعدادات نفسها المعروضة على الشاشة.
Future<void> openInvoiceTemplatePreview(
  BuildContext context, {
  required InvoiceTemplateSettings settings,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final app = context.read<AppController>();
  final company = app.company;
  final messenger = ScaffoldMessenger.of(context);
  InvoicePrintDoc doc;
  try {
    doc = await _sampleInvoicePrintDoc(l10n, app, company);
  } catch (_) {
    if (!context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.sellFixPrintLoadFailed)));
    return;
  }
  if (!context.mounted) return;
  await showPdfPreviewDialog(
    context,
    title: doc.docNo,
    build: () => const InvoiceTemplateEngine().build(
      doc,
      settings: settings,
      logoPng: company?.logoPng,
    ),
    whatsappPhone: company?.whatsapp,
    shareMessage: l10n.printingShareMessageInvoice(
      doc.docNo,
      AmountText.format(doc.total, doc.decimals),
    ),
  );
}

/// مستند المعاينة: آخر فاتورة بيع مرحّلة، وإلا [dummyInvoicePrintDoc].
Future<InvoicePrintDoc> _sampleInvoicePrintDoc(
  AppLocalizations l10n,
  AppController app,
  Company? company,
) async {
  final saleRepo = app.sales;
  if (saleRepo != null) {
    final recent = await saleRepo.recentSales(limit: 1);
    if (recent.isNotEmpty) {
      final detail = await saleRepo.invoiceDetail(recent.first.id);
      if (detail != null) {
        return buildInvoicePrintDoc(l10n, detail, company);
      }
    }
  }
  return dummyInvoicePrintDoc(l10n, company);
}

/// فاتورة نموذجية للمعاينة حين لا توجد أي فاتورة مرحّلة بعد — تسميات
/// l10n نفسها وأرقام بأرقام غربية بفواصل آلاف (قاعدة المسقط).
InvoicePrintDoc dummyInvoicePrintDoc(AppLocalizations l10n, Company? company) {
  return InvoicePrintDoc(
    header: PrintHeader(
      name: company?.name ?? 'متجر النور للأدوية',
      phone: company?.phone ?? '777123456',
      address: company?.address ?? 'تعز - شارع جمال',
      footerText: company?.footerText ?? 'الأسعار شاملة الضريبة',
    ),
    docNo: 'INV-2026-00059',
    dateLabel: '08/10/2026 14:30',
    partyName: 'أحمد محمد الشرعبي',
    partyPhone: '777123456',
    currencyCode: 'YER',
    decimals: 0,
    items: const [
      InvoicePrintLine(
        desc: 'شامبو كلير 400 مل',
        qtyLabel: '3',
        priceLabel: '1,500',
        discountLabel: '0',
        totalLabel: '4,500',
        unitLabel: 'علبة',
      ),
      InvoicePrintLine(
        desc: 'زيت زيتون بكر 1 لتر',
        qtyLabel: '2',
        priceLabel: '5,000',
        discountLabel: '500',
        totalLabel: '9,500',
        unitLabel: 'كرتونة',
      ),
      InvoicePrintLine(
        desc: 'مسحوق بريل 2 كجم',
        qtyLabel: '1',
        priceLabel: '3,500',
        discountLabel: '0',
        totalLabel: '3,500',
        unitLabel: 'كيس',
      ),
    ],
    subtotal: 17500,
    discountAmount: 500,
    total: 17000,
    paidAmount: 10000,
    dueAmount: 7000,
    payStatusLabel: l10n.tmplTitleMixed,
    taxNumber: company?.taxNumber,
    notesPrinted: 'البضاعة المبوعة لا ترد بعد 48 ساعة.',
    templateLabels: invoiceTemplateLabelsFor(l10n),
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
