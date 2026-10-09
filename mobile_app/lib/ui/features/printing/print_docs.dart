/// مساقيط مستندات الطباعة (الشريحة 7 — FR-10-01/05) — إسقاطات **نقية**
/// تُحوَّلها قوالب PDF إلى ورق: لا Flutter ولا I/O هنا إطلاقاً.
///
/// قاعدة الملزمة المعمارية: كل نص يظهر داخل ملف PDF يمر عبر هذه
/// المساقيط كتسمية **مسبقة التعريب** (يبنيها المستدعي من l10n) —
/// قوالب PDF نفسها بلا أي نص حرفي قابل للترجمة. الأرقام تُنسَّق عند
/// المستدعي عبر `AmountText.format` (غربية بفواصل آلاف) وتصل هنا
/// سلاسل جاهزة، ما عدا إجماليات الفاتورة (دوبل + `decimals`) لأن
/// القالب ينسّقها بنفس مُنسِّق التطبيق.
library;

/// نسبة التطبيق المطبوعة في تذييل كل مستند — اسم المنتج الثابت
/// («المُحاسِب الشخصي») كعلامة تجارية لا يُترجم (كاسم أي منتج مطبوع)،
/// وليس نص واجهة قابل للتعريب.
const String kPrintAppCredit = 'المُحاسِب الشخصي';

/// رأس المنشأة المطبوع أعلى كل مستند (FR-10-01).
class PrintHeader {
  const PrintHeader({
    required this.name,
    this.phone,
    this.address,
    this.footerText,
  });

  /// اسم المنشأة (من `AppController.company`).
  final String name;

  /// الهاتف (اختياري).
  final String? phone;

  /// العنوان (اختياري).
  final String? address;

  /// نص التذييل الخاص بالمنشأة (اختياري).
  final String? footerText;
}

/// سطر بند فاتورة مُنسَّق مسبقاً — كل القيم سلاسل جاهزة للعرض.
class InvoicePrintLine {
  const InvoicePrintLine({
    required this.desc,
    required this.qtyLabel,
    required this.priceLabel,
    required this.discountLabel,
    required this.totalLabel,
    this.unitLabel,
  });

  /// وصف البند (اسم الصنف لحظة البيع).
  final String desc;

  /// الكمية منسَّقة (سلسلة جاهزة).
  final String qtyLabel;

  /// سعر الوحدة منسَّق (سلسلة جاهزة).
  final String priceLabel;

  /// خصم السطر منسَّق («—» إن لم يوجد خصم).
  final String discountLabel;

  /// صافي السطر منسَّق (سلسلة جاهزة).
  final String totalLabel;

  /// اسم وحدة البيع (اختياري — عمود الوحدة بالقوالب القابلة للتخصيص
  /// UX-3: يظهر فقط حين يوفره المسقط ويطلب المالك العمود).
  final String? unitLabel;
}

/// كل تسميات مستند الفاتورة داخل الـPDF — مبنية من l10n عند المستدعي.
class InvoiceLabels {
  const InvoiceLabels({
    required this.title,
    required this.customer,
    required this.date,
    required this.currency,
    required this.item,
    required this.qty,
    required this.price,
    required this.discount,
    required this.subtotal,
    required this.totalDiscount,
    required this.grandTotal,
    required this.paid,
    required this.due,
    required this.itemsSection,
    required this.footerThanks,
  });

  /// عنوان المستند (فاتورة مبيعات…).
  final String title;

  /// تسمية حقل العميل.
  final String customer;

  /// تسمية حقل التاريخ.
  final String date;

  /// تسمية حقل العملة.
  final String currency;

  /// تسمية عمود الصنف.
  final String item;

  /// تسمية عمود الكمية.
  final String qty;

  /// تسمية عمود السعر.
  final String price;

  /// تسمية عمود الخصم.
  final String discount;

  /// تسمية سطر الإجمالي قبل الخصم.
  final String subtotal;

  /// تسمية سطر إجمالي الخصم.
  final String totalDiscount;

  /// تسمية الإجمالي النهائي (وعمود صافي السطر).
  final String grandTotal;

  /// تسمية المدفوع.
  final String paid;

  /// تسمية المتبقي.
  final String due;

  /// تسمية قسم البنود.
  final String itemsSection;

  /// عبارة الشكر في التذييل.
  final String footerThanks;
}

/// تسميات عناصر القوالب القابلة للتخصيص (UX-3) — مبنية من l10n عند
/// المستدعي مثل [InvoiceLabels]. حقول اختيارية التمرير: القوالب ترسم
/// العنصر المقابل فقط إذا وصلتها تسميته **وطلب المالك إظهاره**.
class InvoiceTemplateLabels {
  const InvoiceTemplateLabels({
    this.unitCol,
    this.notesTitle,
    this.signatureReceiver,
    this.signatureCollector,
    this.signatureSeller,
    this.stampArea,
    this.taxNumber,
    this.badgeOriginal,
    this.badgeCopy,
  });

  /// تسمية عمود الوحدة.
  final String? unitCol;

  /// تسمية خانة الملاحظات.
  final String? notesTitle;

  /// تسمية خانة توقيع المستلم.
  final String? signatureReceiver;

  /// تسمية خانة توقيع المحصّل.
  final String? signatureCollector;

  /// تسمية خانة توقيع البائع.
  final String? signatureSeller;

  /// تسمية مساحة الختم المحجوزة.
  final String? stampArea;

  /// تسمية سطر الرقم الضريبي.
  final String? taxNumber;

  /// نص شارة «أصل».
  final String? badgeOriginal;

  /// نص شارة «صورة».
  final String? badgeCopy;
}

/// مستند فاتورة قابل للطباعة (FR-10-01) — يغذي قالب A4.
class InvoicePrintDoc {
  const InvoicePrintDoc({
    required this.header,
    required this.docNo,
    required this.dateLabel,
    required this.partyName,
    this.partyPhone,
    required this.currencyCode,
    required this.decimals,
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    required this.total,
    required this.paidAmount,
    required this.dueAmount,
    required this.labels,
    this.payStatusLabel,
    this.taxNumber,
    this.notesPrinted,
    this.templateLabels,
  });

  /// رأس المنشأة.
  final PrintHeader header;

  /// رقم الفاتورة الكامل `INV-YYYY-NNNNN`.
  final String docNo;

  /// التاريخ منسَّقاً (سلسلة جاهزة).
  final String dateLabel;

  /// اسم العميل (أو «عميل نقدي»).
  final String partyName;

  /// هاتف العميل (اختياري).
  final String? partyPhone;

  /// رمز العملة الدولي (YER / SAR / USD…).
  final String currencyCode;

  /// منازل العملة للعرض (YER = 0 — قرار المستدعي، قاعدة 5.4-9).
  final int decimals;

  /// البنود منسَّقة مسبقاً.
  final List<InvoicePrintLine> items;

  /// الإجمالي قبل الخصم (بعملة الفاتورة).
  final double subtotal;

  /// إجمالي الخصم (سطر + رأس — موجب).
  final double discountAmount;

  /// الإجمالي النهائي.
  final double total;

  /// المدفوع.
  final double paidAmount;

  /// المتبقي.
  final double dueAmount;

  /// كل تسميات المستند (مسبقة التعريب).
  final InvoiceLabels labels;

  /// وضع الدفع معرّباً مسبقاً («فاتورة مبيعات نقد/آجل…») — يملأ صندوق
  /// العنوان الملون بالكلاسيكي وعنوان الإيصال الحراري (UX-3).
  final String? payStatusLabel;

  /// الرقم الضريبي للمنشأة (اختياري — يُعرض بطلب المالك فقط).
  final String? taxNumber;

  /// الملاحظات المطبوعة للفاتورة (اختياري — خانة ملاحظات القوالب).
  final String? notesPrinted;

  /// تسميات عناصر القوالب القابلة للتخصيص (اختياري — غيابه يسقط
  /// العناصر الجديدة بلا كسر البناة القديمة).
  final InvoiceTemplateLabels? templateLabels;
}

/// كل تسميات مستند السند داخل الـPDF — مبنية من l10n عند المستدعي.
class VoucherLabels {
  const VoucherLabels({
    required this.titleReceipt,
    required this.titlePayment,
    required this.party,
    required this.date,
    required this.amount,
    required this.description,
    required this.box,
    required this.signature,
    required this.footerThanks,
  });

  /// عنوان سند القبض.
  final String titleReceipt;

  /// عنوان سند الصرف.
  final String titlePayment;

  /// تسمية حقل الطرف.
  final String party;

  /// تسمية حقل التاريخ.
  final String date;

  /// تسمية المبلغ البطل.
  final String amount;

  /// تسمية البيان.
  final String description;

  /// تسمية الصندوق.
  final String box;

  /// تسمية سطر التوقيع.
  final String signature;

  /// عبارة الشكر في التذييل.
  final String footerThanks;
}

/// مستند سند مرقَّم قابل للطباعة (FR-04-10 + FR-10-05) — يغذي قالب A5.
class VoucherPrintDoc {
  const VoucherPrintDoc({
    required this.header,
    required this.isReceipt,
    required this.voucherNo,
    required this.dateLabel,
    this.partyName,
    required this.amountLabel,
    required this.currencyCode,
    this.description,
    required this.boxName,
    required this.labels,
  });

  /// رأس المنشأة.
  final PrintHeader header;

  /// سند قبض (RVT) أم صرف (PMT)؟
  final bool isReceipt;

  /// رقم السند الكامل `RVT-YYYY-NNNNN`.
  final String voucherNo;

  /// التاريخ منسَّقاً (سلسلة جاهزة).
  final String dateLabel;

  /// اسم الطرف (عميل/مورد — اختياري).
  final String? partyName;

  /// المبلغ منسَّقاً (سلسلة جاهزة — كبيرة وعريضة في القالب).
  final String amountLabel;

  /// رمز العملة الدولي.
  final String currencyCode;

  /// البيان (اختياري).
  final String? description;

  /// اسم الصندوق.
  final String boxName;

  /// كل تسميات المستند (مسبقة التعريب).
  final VoucherLabels labels;
}
