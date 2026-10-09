/// فتح معاينة PDF لفاتورة بيع — النمط القائم من زر PDF في شاشة تفاصيل
/// الفواتير (sales_invoices_screen، الشريحة 7) مستخرجاً لمشاركته مع
/// إيصال نجاح الكاشير (P0-2): يحمّل تفاصيل الفاتورة المرحّلة من
/// المستودع، يبني مسقط الطباعة `InvoicePrintDoc` (كل تسمية عبر l10n
/// وكل رقم عبر AmountText.format) ثم يفتح `PdfPreviewDialog` القائم
/// بطباعته/مشاركته/واتسابه.
///
/// **موجة UX-3**: البناء كله يمر عبر [`InvoiceTemplateEngine`] بالقالب
/// النشط من `print_template` (شاشة «الطباعة والفواتير») والشعار من
/// `company.logo_png` — غياب الجدول/الشعار يرد للبسيط الافتراضي بلا
/// انهيار (سلوك ما قبل الترقية).
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
import '../../../printing/templates/invoice_template_engine.dart';
import '../../../printing/templates/invoice_template_settings.dart';
import '../../../printing/views/pdf_preview_dialog.dart';
import 'sell_widgets.dart';

/// منازل العملة للطباعة — قرار المستدعي: YER = 0 (قاعدة 5.4-9) والباقي 2.
int invoicePrintDecimals(SaleInvoiceDetail detail) =>
    detail.currencyCode == 'YER' ? 0 : 2;

/// عنوان وضع الدفع معرّباً (صندوق الكلاسيكي وعنوان الإيصال الحراري).
String _payStatusLabel(AppLocalizations l10n, SalePaymentMethod payStatus) =>
    switch (payStatus) {
      SalePaymentMethod.cash => l10n.tmplTitleCash,
      SalePaymentMethod.credit => l10n.tmplTitleCredit,
      SalePaymentMethod.mixed => l10n.tmplTitleMixed,
    };

/// تسميات عناصر القوالب القابلة للتخصيص من l10n — تصل القوالب مسبقة
/// التعريب (قاعدة الملزمة: القوالب بلا نصوص).
InvoiceTemplateLabels invoiceTemplateLabelsFor(AppLocalizations l10n) =>
    InvoiceTemplateLabels(
      unitCol: l10n.tmplUnitCol,
      notesTitle: l10n.tmplNotesTitle,
      signatureReceiver: l10n.tmplSignReceiver,
      signatureCollector: l10n.tmplSignCollector,
      signatureSeller: l10n.tmplSignSeller,
      stampArea: l10n.tmplStampArea,
      taxNumber: l10n.tmplTaxNumber,
      badgeOriginal: l10n.tmplBadgeOriginal,
      badgeCopy: l10n.tmplBadgeCopy,
    );

/// يبني إسقاط الطباعة من تفاصيل الفاتورة + رأس المنشأة — كل تسمية داخل
/// المستند مسبقة التعريب من l10n، وكل رقم عبر `AmountText.format`
/// (غربي بفواصل آلاف) فيبقى القالب نفسه بلا أي نص. (UX-3: الرقم
/// الضريبي والملاحظات المطبوعة واسم الوحدة ووضع الدفع.)
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
          // UX-4: لاحقة «(+N مجاني)» بجوار الكمية عند وجود بونص — تصل
          // القوالب عبر المسقط فترسمها مع الكمية (qtyCellLabel).
          freeQtyLabel: item.freeQty > 0.000001
              ? l10n.bonusPrintSuffix(sellQtyText(item.freeQty))
              : null,
          priceLabel: AmountText.format(item.unitPrice, decimals),
          discountLabel: item.discountAmount > 0.005
              ? AmountText.format(item.discountAmount, 2)
              : '—',
          totalLabel: AmountText.format(item.lineTotal, decimals),
          unitLabel: item.unitName,
        ),
    ],
    subtotal: invoice.subtotal,
    discountAmount: invoice.discountAmount,
    total: invoice.total,
    paidAmount: invoice.paidAmount,
    dueAmount: invoice.dueAmount,
    // R17 — الفاتورة الملغاة تطبع حالتها لا وضع دفعها: «ملغاة» مكان
    // «نقدي/آجل/مختلط» حتى لا يستلم العميل مستنداً ملغىً يوحي بذمم
    // قائمة (وضع الدفع الأصلي يبقى ظاهراً بشاشة التفاصيل والقوائم).
    payStatusLabel: invoice.status == 'void'
        ? l10n.invoiceVoidBadge
        : _payStatusLabel(l10n, invoice.payStatus),
    taxNumber: company?.taxNumber,
    notesPrinted: invoice.notesPrinted,
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

/// إعدادات القالب النشط لفواتير البيع — دفاعي: بلا مستودع/بلا صف
/// افتراضي/JSON تالف = البسيط الافتراضي (سلوك ما قبل UX-3).
Future<InvoiceTemplateSettings> activeInvoicePrintSettings(
  AppController app,
) async {
  final repo = app.printTemplates;
  if (repo == null) return const InvoiceTemplateSettings();
  try {
    final row = await repo.activeFor('sale');
    if (row == null) return const InvoiceTemplateSettings();
    return row.config;
  } catch (_) {
    return const InvoiceTemplateSettings();
  }
}

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
  unawaited(
    () async {
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
    }(),
  );
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

// ─────────────────────────────────────────────────────────────────────
// معاينة حية لشاشة «الطباعة والفواتير» (UX-3)
// ─────────────────────────────────────────────────────────────────────

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
    build: () =>
        const InvoiceTemplateEngine().build(doc, settings: settings, logoPng: company?.logoPng),
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
InvoicePrintDoc dummyInvoicePrintDoc(
  AppLocalizations l10n,
  Company? company,
) {
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
