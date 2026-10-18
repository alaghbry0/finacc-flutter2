/// بانى مسقط مستند طباعة فاتورة البيع — «بيت الطباعة الواحد» (R20-D1).
///
/// كان هذا العمل داخل `sell/views/widgets/invoice_pdf_preview.dart`
/// ونُقل هنا لأن مستهلكه الثاني (شاشة «الطباعة والفواتير» بالمركز)
/// يحتاجه بلا أي اقتران على ميزة البيع — فأُغلقت الحافة العابرة الوحيدة
/// غير الطباعية (settings→sell). ما يبنيه هذا الملف:
///
/// - [buildInvoicePrintDoc]: الإسقاط من تفاصيل الفاتورة + رأس المنشأة —
///   كل تسمية مسبقة التعريب من l10n وكل رقم عبر `AmountText.format`
///   (غربي بفواصل آلاف) فيبقى القالب نفسه بلا أي نص (UX-3: الرقم
///   الضريبي والملاحظات المطبوعة واسم الوحدة ووضع الدفع).
/// - [invoiceTemplateLabelsFor]: تسميات عناصر القوالب القابلة للتخصيص.
/// - [invoicePrintDecimals]: منازل العملة للطباعة (قاعدة 5.4-9).
/// - [activeInvoicePrintSettings]: إعدادات القالب النشط — دفاعي.
///
/// ملف البيع الأصلي يصدّر هذا الملف (re-export) فبقيت مسارات
/// الاستيراد التاريخية كلها تعمل بلا تعديل.
library;

import '../../../../../data/models/invoice_template_settings.dart';
import '../../../../../domain/models/company.dart';
import '../../../../../domain/models/sale.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/fin_format_helpers.dart';
import 'print_docs.dart';

/// منازل العملة للطباعة (يفوّض إلى `AmountText.decimalsFor` — قاعدة 5.4-9
/// بمصدرها الموحد؛ الخرج مطابق حرفياً).
int invoicePrintDecimals(SaleInvoiceDetail detail) =>
    AmountText.decimalsFor(detail.currencyCode);

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
