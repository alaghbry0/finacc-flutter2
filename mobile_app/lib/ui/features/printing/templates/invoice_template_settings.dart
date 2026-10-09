/// إعدادات قالب فاتورة قابلة للتخصيص (موجة UX-3) — **نموذج نقي** بلا
/// Flutter ولا I/O: هوية القالب + الورق + الألوان ARGB الثلاثة +
/// مفاتيح إظهار/إخفاء عناصر الفاتورة + شارة أصل/صورة.
///
/// يُخزَّن JSON في عمود `print_template.config` (هجرة v4) — التحمل
/// الدفاعي: أي مفتاح غائب/تالف يرد إلى القيمة الافتراضية فلا يكسر
/// التخصيصُ السيئٌ طباعةَ المتجر.
///
/// قاعدة الملزمة المعمارية للقوالب: كل تسمية تصل القالب **مسبقة
/// التعريباً** من المسقط (`InvoicePrintDoc`)، وكل تحويل أرقام (نظام
/// `display.numerals`) يحدث في مرحلة المسقط حصراً — هذا النموذج لا
/// يحمل نصوص واجهة ولا يحوّل أرقاماً.
library;

import 'dart:convert';

/// أكواد القوالب المعتمدة (تطابق بذر هجرة v4).
const String kInvoiceTemplateClassicA4 = 'classic_a4';
const String kInvoiceTemplateSimpleA4 = 'simple_a4';
const String kInvoiceTemplateThermal80 = 'thermal_80';

/// كل الأكواد المعتمدة بترتيب البذر.
const List<String> kInvoiceTemplateCodes = <String>[
  kInvoiceTemplateClassicA4,
  kInvoiceTemplateSimpleA4,
  kInvoiceTemplateThermal80,
];

/// شارة النسخة على الفاتورة (أصل/صورة/بلا).
enum InvoiceBadgeMode {
  none('none'),
  original('original'),
  copy('copy');

  const InvoiceBadgeMode(this.json);

  /// القيمة كما تُخزَّن في JSON الإعدادات.
  final String json;

  static InvoiceBadgeMode fromJson(String? value) => switch (value) {
    'original' => InvoiceBadgeMode.original,
    'copy' => InvoiceBadgeMode.copy,
    _ => InvoiceBadgeMode.none,
  };
}

/// ميزة من ميزات القوالب — يستعلم بها محدد القالب/الشاشة عمّا يوفّره
/// كل قالب فعلياً (الحراري بلا توقيعات/ختم بطبيعته، والبسيط يحافظ على
/// تخطيطه القائم بلا خانات إضافية).
enum TemplateFeature {
  discountColumn,
  unitColumn,
  barcode,
  tax,
  signatures,
  stampArea,
  footer,
  notes,
}

/// هل يوفر القالب الميزة؟
bool templateSupports(String templateId, TemplateFeature feature) {
  switch (feature) {
    case TemplateFeature.discountColumn:
    case TemplateFeature.unitColumn:
    case TemplateFeature.barcode:
    case TemplateFeature.tax:
    case TemplateFeature.footer:
      // الأعمدة/الباركود/الضريبة/التذييل مدعومة في القوالب الثلاثة.
      return true;
    case TemplateFeature.signatures:
    case TemplateFeature.stampArea:
      // خانات التوقيع ومكان الختم من لغة الكلاسيكي الحكومي حصراً
      // (نموذج المالك) — البسيط كما كان والحراري إيصال مختصر.
      return templateId == kInvoiceTemplateClassicA4;
    case TemplateFeature.notes:
      // الكلاسيكي والحراري يرسمان خانة ملاحظات؛ البسيط بلا تغيير.
      return templateId != kInvoiceTemplateSimpleA4;
  }
}

/// إعدادات قالب الفاتورة — نقية وقابلة للتسلسل JSON.
class InvoiceTemplateSettings {
  const InvoiceTemplateSettings({
    this.templateId = kInvoiceTemplateSimpleA4,
    this.tableHeadArgb = 0xFFDFEBE7,
    this.borderArgb = 0xFFDCE7E1,
    this.accentRedArgb = 0xFFC62828,
    this.showDiscountColumn = true,
    this.showUnitColumn = false,
    this.showBarcode = false,
    this.showTax = false,
    this.showSignatures = true,
    this.showStampArea = true,
    this.showFooter = true,
    this.showNotes = true,
    this.badge = InvoiceBadgeMode.none,
  });

  /// هوية القالب (`classic_a4` / `simple_a4` / `thermal_80`).
  final String templateId;

  /// الورق المشتق من القالب (`a4-landscape` / `a4-portrait` / `roll80`).
  String get paper => switch (templateId) {
    kInvoiceTemplateClassicA4 => 'a4-landscape',
    kInvoiceTemplateThermal80 => 'roll80',
    _ => 'a4-portrait',
  };

  /// لون رأس الجدول (ARGB) — أزرق مظلل بنموذج المالك.
  final int tableHeadArgb;

  /// لون حدود الجدول/الإطار (ARGB).
  final int borderArgb;

  /// لون التمييز الأحمر (ARGB) — رقم الفاتورة والمتبقي.
  final int accentRedArgb;

  /// إظهار عمود الخصم في جدول الأصناف.
  final bool showDiscountColumn;

  /// إظهار عمود الوحدة (حين تتوفر أسماء وحدات في المسقط).
  final bool showUnitColumn;

  /// باركود Code128 لرقم الفاتورة.
  final bool showBarcode;

  /// بيانات الضريبة (الرقم الضريبي من بيانات المنشأة).
  final bool showTax;

  /// خانات التوقيع الثلاث (المستلم/المحصل/البائع) — حيث يوفرها القالب.
  final bool showSignatures;

  /// مساحة الختم المحجوزة — حيث يوفرها القالب.
  final bool showStampArea;

  /// تذييل الفاتورة (نص المنشأة + نسبة التطبيق).
  final bool showFooter;

  /// خانة الملاحظات — حيث يوفرها القالب.
  final bool showNotes;

  /// شارة النسخة (أصل/صورة).
  final InvoiceBadgeMode badge;

  /// ينسخ بقيمة معدَّلة — للمفاتيح المنطقية واللونية معاً.
  InvoiceTemplateSettings copyWith({
    String? templateId,
    int? tableHeadArgb,
    int? borderArgb,
    int? accentRedArgb,
    bool? showDiscountColumn,
    bool? showUnitColumn,
    bool? showBarcode,
    bool? showTax,
    bool? showSignatures,
    bool? showStampArea,
    bool? showFooter,
    bool? showNotes,
    InvoiceBadgeMode? badge,
  }) => InvoiceTemplateSettings(
    templateId: templateId ?? this.templateId,
    tableHeadArgb: tableHeadArgb ?? this.tableHeadArgb,
    borderArgb: borderArgb ?? this.borderArgb,
    accentRedArgb: accentRedArgb ?? this.accentRedArgb,
    showDiscountColumn: showDiscountColumn ?? this.showDiscountColumn,
    showUnitColumn: showUnitColumn ?? this.showUnitColumn,
    showBarcode: showBarcode ?? this.showBarcode,
    showTax: showTax ?? this.showTax,
    showSignatures: showSignatures ?? this.showSignatures,
    showStampArea: showStampArea ?? this.showStampArea,
    showFooter: showFooter ?? this.showFooter,
    showNotes: showNotes ?? this.showNotes,
    badge: badge ?? this.badge,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'templateId': templateId,
    'tableHeadArgb': tableHeadArgb,
    'borderArgb': borderArgb,
    'accentRedArgb': accentRedArgb,
    'showDiscountColumn': showDiscountColumn,
    'showUnitColumn': showUnitColumn,
    'showBarcode': showBarcode,
    'showTax': showTax,
    'showSignatures': showSignatures,
    'showStampArea': showStampArea,
    'showFooter': showFooter,
    'showNotes': showNotes,
    'badge': badge.json,
  };

  /// يفكّ JSON بتحمّل دفاعي: القيم التالفة/الغائبة ترد للافتراض.
  factory InvoiceTemplateSettings.fromJson(Map<String, Object?>? json) {
    if (json == null) return const InvoiceTemplateSettings();
    int argb(Object? value, int fallback) =>
        value is int && (value & 0xFF000000) != 0 ? value : fallback;
    bool flag(Object? value, bool fallback) =>
        value is bool ? value : fallback;
    final templateId = switch (json['templateId']) {
      kInvoiceTemplateClassicA4 ||
      kInvoiceTemplateSimpleA4 ||
      kInvoiceTemplateThermal80 => json['templateId']! as String,
      _ => kInvoiceTemplateSimpleA4,
    };
    return InvoiceTemplateSettings(
      templateId: templateId,
      tableHeadArgb: argb(json['tableHeadArgb'], 0xFFDFEBE7),
      borderArgb: argb(json['borderArgb'], 0xFFDCE7E1),
      accentRedArgb: argb(json['accentRedArgb'], 0xFFC62828),
      showDiscountColumn: flag(json['showDiscountColumn'], true),
      showUnitColumn: flag(json['showUnitColumn'], false),
      showBarcode: flag(json['showBarcode'], false),
      showTax: flag(json['showTax'], false),
      showSignatures: flag(json['showSignatures'], true),
      showStampArea: flag(json['showStampArea'], true),
      showFooter: flag(json['showFooter'], true),
      showNotes: flag(json['showNotes'], true),
      badge: InvoiceBadgeMode.fromJson(json['badge'] as String?),
    );
  }

  /// يفكّ سلسلة JSON خام (عمود config) — التلف الكامل يرد للافتراض
  /// لا للاستثناء: طباعة المتجر لا تتوقف أبداً بـJSON سيئ.
  factory InvoiceTemplateSettings.fromJsonString(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const InvoiceTemplateSettings();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const InvoiceTemplateSettings();
      return InvoiceTemplateSettings.fromJson(
        Map<String, Object?>.from(decoded),
      );
    } catch (_) {
      return const InvoiceTemplateSettings();
    }
  }

  /// مساواة بالقيمة (عميقة للمفاتيح): خرائط Dart تُقارن بالهوية
  /// افتراضياً فمقارنة `toJson() == toJson()` كانت تعيد false لقيمتين
  /// متطابقتين — هنا نقارن مفتاحاً مفتاحاً (القيم كلها بدائية).
  @override
  bool operator ==(Object other) {
    if (other is! InvoiceTemplateSettings) return false;
    final mine = toJson();
    final theirs = other.toJson();
    if (mine.length != theirs.length) return false;
    for (final key in mine.keys) {
      if (mine[key] != theirs[key]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(toJson().values.toList());
}
