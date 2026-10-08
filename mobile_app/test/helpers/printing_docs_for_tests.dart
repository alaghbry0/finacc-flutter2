/// مستندات طباعة جاهزة لاختبارات بناة PDF (موجة 1-a — إصلاح عيوب
/// العربية في PDF): تسميات حقيقية من l10n (كما تبنيها الشاشات نفسها)
/// وقيم بأسماء «كاسرة» من تجربة /tmp/pdfprobe.
///
/// لماذا هذه الأسماء تحديداً؟ قبل إصلاح `textDirection.rtl` على قيم
/// `_kvLine` كان subsetter خطوط حزمة pdf ينهار `Bad state: No element`
/// (TtfWriter.withChars) حين يجتمع عربي غير مشكل (القيمة) بعربي مشكل
/// (التسميات) في نفس المستند — 9 من 17 اسماً شائعاً كانت تكسر بناء PDF
/// أصغر من الفاتورة (pdfprobe/names2). هذه الاختبارات تحرس الإصلاح.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/features/printing/print_docs.dart';
import 'package:mobile_app/ui/features/printing/shift_print_doc.dart';
import 'package:mobile_app/ui/features/printing/statement_print_doc.dart';

/// الأسماء السبعة عشر من تجربة pdfprobe/names2 (بينها 9 كاسرة مؤكدة:
/// فاطمة/سالم/النور/عبدالله…) + لاتيني خالص + عربي بأرقام + مختلط —
/// تغطية مسارات BiDi والـ subsetter كلها.
const List<String> kPdfProbeNames = [
  'أحمد',
  'محمد علي',
  'علي',
  'فاطمة',
  'سالم',
  'النور',
  'أحمد محمد',
  'محمد',
  'عبدالله',
  'يحيى',
  'أمين',
  'خالد سعيد',
  'متجر النور للأدوية',
  'عميل نقدي',
  'أحمد محمد الشرعبي',
  'شركة النور للتجارة',
  'مؤسسة الصفوة',
  'zain.al abadin Drag.s',
  'شامبو كلير 400 مل',
  'عميل 2 INV-2026',
];

/// عدد صفحات PDF من بايتاته — قاموسات كائنات حزمة pdf غير مضغوطة
/// فكل صفحة تحمل `/Type/Page` (والشجرة `/Type/Pages` — مستثناة).
int pdfPageCount(Uint8List bytes) =>
    RegExp(r'/Type/Page(?!s)')
        .allMatches(latin1.decode(bytes, allowInvalid: true))
        .length;

/// رأس منشأة موحد لكل مستندات الاختبار (عربي + هاتف + عنوان).
PrintHeader probeHeader() => const PrintHeader(
  name: 'متجر النور للأدوية',
  phone: '777123456',
  address: 'تعز - شارع جمال',
  footerText: 'الأسعار شاملة الضريبة',
);

/// فاتورة اختبار — التسميات من l10n كما في sales_invoices_screen،
/// واسم العميل قابل للتبديل لاختبار الأسماء الكاسرة.
InvoicePrintDoc invoiceDocForTests(
  AppLocalizations l10n, {
  String partyName = 'أحمد محمد الشرعبي',
  int itemCount = 2,
}) {
  return InvoicePrintDoc(
    header: probeHeader(),
    docNo: 'INV-2026-00012',
    dateLabel: '08/10/2026 14:30',
    partyName: partyName,
    partyPhone: '777123456',
    currencyCode: 'YER',
    decimals: 0,
    items: [
      for (var i = 1; i <= itemCount; i++)
        InvoicePrintLine(
          desc: 'شامبو كلير 400 مل — زيت Head & Shoulders 250مل رقم $i',
          qtyLabel: '3',
          priceLabel: '1,500',
          discountLabel: '0',
          totalLabel: '4,500',
        ),
    ],
    subtotal: 12500,
    discountAmount: 200,
    total: 12300,
    paidAmount: 5000,
    dueAmount: 7300,
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

/// كشف حساب اختبار — التسميات من l10n كما في statement_print_doc.
StatementPrintDoc statementDocForTests(
  AppLocalizations l10n, {
  String partyName = 'أحمد محمد الشرعبي',
  int lineCount = 4,
}) {
  return StatementPrintDoc(
    header: probeHeader(),
    partyName: partyName,
    partyPhone: '777123456',
    generatedAtLabel: '08/10/2026',
    periodLabel: l10n.printingStatementPeriodRange('01/10/2026', '08/10/2026'),
    currencyCode: 'YER',
    decimals: 0,
    lines: [
      for (var i = 1; i <= lineCount; i++)
        StatementPrintLine(
          dateLabel: '0$i/10/2026',
          descLabel: 'فاتورة مبيعات INV-2026-0000$i',
          debitLabel: '1,500',
          creditLabel: '—',
          balanceLabel: '${i * 1500}',
        ),
    ],
    totalDebit: 4500,
    totalCredit: 0,
    closingBalance: 4500,
    labels: StatementLabels(
      title: l10n.printingStatementDocTitle,
      party: l10n.printingLblParty,
      generatedAt: l10n.printingLblGeneratedAt,
      period: l10n.printingLblPeriod,
      currency: l10n.printingLblCurrency,
      dateCol: l10n.printingLblDate,
      descCol: l10n.printingLblDescription,
      debitCol: l10n.printingStatementDebit,
      creditCol: l10n.printingStatementCredit,
      balanceCol: l10n.printingStatementBalance,
      totalDebit: l10n.printingStatementTotalDebit,
      totalCredit: l10n.printingStatementTotalCredit,
      closing: l10n.printingStatementClosing,
      emptyBody: l10n.printingStatementEmpty,
      footerThanks: l10n.printingFooterThanks,
    ),
  );
}

/// سند اختبار — التسميات من l10n كما في movements_screen، والطرف
/// (والصندوق عبر [boxName]) قابلان للتبديل لاختبار الأسماء الكاسرة.
VoucherPrintDoc voucherDocForTests(
  AppLocalizations l10n, {
  String partyName = 'أحمد محمد الشرعبي',
  String boxName = 'الصندوق الرئيسي',
  bool isReceipt = true,
}) {
  return VoucherPrintDoc(
    header: probeHeader(),
    isReceipt: isReceipt,
    voucherNo: isReceipt ? 'RVT-2026-00007' : 'PMT-2026-00003',
    dateLabel: '08/10/2026 14:30',
    partyName: partyName,
    amountLabel: '1,500',
    currencyCode: 'YER',
    description: 'دفعة على الحساب — سند اختباري',
    boxName: boxName,
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
    ),
  );
}

/// تقرير وردية اختبار — التسميات من l10n كما في shift_print_doc، مع
/// فرق زيادة 250 (صف «250 · زيادة» المختلط من تدقيق UX-audit A4).
ShiftPrintDoc shiftDocForTests(
  AppLocalizations l10n, {
  String userName = 'خالد سعيد',
  String boxName = 'الصندوق الرئيسي',
  double difference = 250,
}) {
  return ShiftPrintDoc(
    header: probeHeader(),
    boxName: boxName,
    userName: userName,
    openedAtLabel: '07/10/2026 08:00',
    closedAtLabel: '07/10/2026 23:45',
    currencyCode: 'YER',
    decimals: 0,
    lines: [
      ShiftEquationLine(
        itemLabel: 'المبيعات النقدية',
        directionLabel: 'وارد (+)',
        valueLabel: '12,500',
      ),
      ShiftEquationLine(
        itemLabel: 'التحصيلات',
        directionLabel: 'وارد (+)',
        valueLabel: '3,000',
      ),
      ShiftEquationLine(
        itemLabel: 'المصاريف',
        directionLabel: 'صادر (−)',
        valueLabel: '1,000',
      ),
    ],
    openingCount: 500,
    totalIn: 15500,
    totalOut: 1000,
    expected: 15000,
    counted: 15000 + difference,
    difference: difference,
    notes: 'لا ملاحظات على الإقفال',
    labels: ShiftLabels(
      title: l10n.shiftPrintTitle,
      box: l10n.shiftPrintBox,
      user: l10n.shiftPrintUser,
      opened: l10n.shiftPrintOpened,
      closed: l10n.shiftPrintClosed,
      itemCol: l10n.shiftPrintItemCol,
      directionCol: l10n.shiftPrintDirectionCol,
      valueCol: l10n.shiftPrintValueCol,
      dirIn: l10n.shiftPrintDirIn,
      dirOut: l10n.shiftPrintDirOut,
      dirNone: '—',
      openingCount: l10n.shiftOpeningCountLabel,
      totalIn: l10n.shiftPrintTotalIn,
      totalOut: l10n.shiftPrintTotalOut,
      expected: l10n.shiftExpectedLabel,
      counted: l10n.shiftCountedLabel,
      difference: l10n.shiftDifferenceLabel,
      surplus: l10n.shiftSurplus,
      deficit: l10n.shiftDeficit,
      matched: l10n.shiftMatched,
      notesRow: l10n.shiftPrintNotesRow,
      chequesNote: l10n.shiftChequesDeferredNote,
      footerThanks: l10n.printingFooterThanks,
    ),
  );
}
