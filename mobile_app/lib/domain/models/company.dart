/// كيان المنشأة — SRS §5.3 (جدول company) + FR-13-01.
library;

/// منشأة واحدة لكل قاعدة بيانات (§11: تعدد الشركات خارج النطاق).
class Company {
  const Company({
    required this.id,
    required this.name,
    required this.currencyId,
    this.phone,
    this.whatsapp,
    this.address,
    this.logoPath,
    this.taxNumber,
    this.taxRate = 0,
    this.invoicePrefix = 'INV',
    this.footerText,
  });

  /// المعرّف في جدول `company`.
  final int id;

  /// اسم المنشأة (إلزامي).
  final String name;

  /// العملة الأساسية — تُثبَّت بعد الإعداد الأول (FR-08-01).
  final int currencyId;

  /// الهاتف (اختياري — لدعم واتساب لاحقاً).
  final String? phone;

  /// واتساب (اختياري).
  final String? whatsapp;

  /// العنوان (اختياري).
  final String? address;

  /// مسار الشعار المحلي (اختياري).
  final String? logoPath;

  /// الرقم الضريبي (اختياري).
  final String? taxNumber;

  /// نسبة الضريبة — 0% افتراضياً للسوق اليمني (FR-13-01).
  final double taxRate;

  /// بادئة ترقيم الفواتير — `INV` افتراضياً.
  final String invoicePrefix;

  /// نص تذييل الفاتورة (اختياري).
  final String? footerText;

  /// ينشئ نسخة من صف قاعدة البيانات.
  factory Company.fromRow(Map<String, Object?> row) => Company(
    id: row['id'] as int,
    name: row['name'] as String,
    currencyId: row['currency_id'] as int,
    phone: row['phone'] as String?,
    whatsapp: row['whatsapp'] as String?,
    address: row['address'] as String?,
    logoPath: row['logo_path'] as String?,
    taxNumber: row['tax_number'] as String?,
    taxRate: (row['tax_rate'] as num?)?.toDouble() ?? 0,
    invoicePrefix: (row['invoice_prefix'] as String?) ?? 'INV',
    footerText: row['footer_text'] as String?,
  );
}

/// عملة مرجعية — جدول `currency` (§5.3).
class Currency {
  const Currency({
    required this.id,
    required this.code,
    required this.name,
    required this.isBase,
    required this.decimals,
  });

  final int id;

  /// الرمز الدولي: YER / SAR / USD / AED.
  final String code;

  /// الاسم العربي الكامل.
  final String name;

  /// هل هي العملة الأساسية؟
  final bool isBase;

  /// عدد المنازل العشرية للعرض (YER = 0 — قاعدة 5.4-9).
  final int decimals;

  factory Currency.fromRow(Map<String, Object?> row) => Currency(
    id: row['id'] as int,
    code: row['code'] as String,
    name: row['name'] as String,
    isBase: (row['is_base'] as int? ?? 0) == 1,
    decimals: (row['decimals'] as int? ?? 2),
  );
}
