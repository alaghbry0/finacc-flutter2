/// كيان المنشأة — SRS §5.3 (جدول company) + FR-13-01.
library;

import 'dart:typed_data';

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
    this.logoPng,
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

  /// مسار الشعار المحلي (اختياري — قديم، غير مستهلك بالطباعة).
  final String? logoPath;

  /// بايتات الشعار PNG من هجرة v3 (UX-2a) — مخزنة داخل القاعدة لتنجو
  /// مع النسخة الاحتياطية (قرار المنسق UX-audit-synthesis).
  final Uint8List? logoPng;

  /// الرقم الضريبي (اختياري).
  final String? taxNumber;

  /// نسبة الضريبة — 0% افتراضياً للسوق اليمني (FR-13-01).
  final double taxRate;

  /// بادئة ترقيم الفواتير — `INV` افتراضياً.
  final String invoicePrefix;

  /// نص تذييل الفاتورة (اختياري).
  final String? footerText;

  /// نسخة بحقول محدّثة — تُترك الحقول غير الممررة كما هي (محرر
  /// بيانات المنشأة في UX-2a يبني الكيان الجديد للحفظ).
  Company copyWith({
    String? name,
    String? phone,
    String? whatsapp,
    String? address,
    String? logoPath,
    Object? logoPng = _sentinel,
    String? taxNumber,
    double? taxRate,
    String? invoicePrefix,
    String? footerText,
  }) => Company(
    id: id,
    name: name ?? this.name,
    currencyId: currencyId,
    phone: phone ?? this.phone,
    whatsapp: whatsapp ?? this.whatsapp,
    address: address ?? this.address,
    logoPath: logoPath ?? this.logoPath,
    logoPng: identical(logoPng, _sentinel)
        ? this.logoPng
        : logoPng as Uint8List?,
    taxNumber: taxNumber ?? this.taxNumber,
    taxRate: taxRate ?? this.taxRate,
    invoicePrefix: invoicePrefix ?? this.invoicePrefix,
    footerText: footerText ?? this.footerText,
  );

  /// قيمة حراسة للحقول القابلة للتصفير في [copyWith].
  static const Object _sentinel = Object();

  /// ينشئ نسخة من صف قاعدة البيانات.
  factory Company.fromRow(Map<String, Object?> row) => Company(
    id: row['id'] as int,
    name: row['name'] as String,
    currencyId: row['currency_id'] as int,
    phone: row['phone'] as String?,
    whatsapp: row['whatsapp'] as String?,
    address: row['address'] as String?,
    logoPath: row['logo_path'] as String?,
    logoPng: row['logo_png'] as Uint8List?,
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
