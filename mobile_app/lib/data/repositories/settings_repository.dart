/// مستودع الإعدادات — جدول `settings` (ملحق هـ — سجل الإعدادات).
///
/// القيم مخزَّنة بصيغة JSON (نص `"on"` أو رقم `5`) وتُقرأ بأنواع صارمة
/// مع افتراضيات مطابقة للسجل — أي مفتاح ليس في السجل يُرفض (FR-13-09).
library;

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

class SettingsRepository {
  SettingsRepository(this._db);

  final Database _db;

  /// المفاتيح المعتمدة (ملحق هـ — مفاتيح V1 + حالة أمنية نظامية +
  /// مفاتيح موجة UX-2a للتخصيص الشامل).
  static const Set<String> knownKeys = <String>{
    'inventory.min_stock_alert',
    'invoicing.tax_mode',
    'invoicing.discount_below_margin',
    'invoicing.print_on_save',
    'invoicing.payment_sheet',
    'sale.over_avail_policy',
    'parties.credit_limit_action',
    'fx.daily_reminder',
    'fx.fallback',
    'display.numerals',
    'display.font_scale',
    'ui.high_contrast',
    'sale.default_payment',
    'sale.show_discounts',
    'sale.free_qty',
    'backup.schedule',
    'backup.retention_count',
    'security.autolock_minutes',
    'dating.max_backdate_days',
    // حالة نظامية (ليست إعداداً قابلاً للضبط — انظر CompanyRepository).
    'security.passphrase_hash',
    // حالة نظامية: لحظة آخر نسخة ناجحة (وحدة 11 — FR-11-04) — تُحدَّث
    // آلياً من خدمة النسخ ولا تُعدَّل من الواجهة.
    'backup.last_backup_at',
    // حالة نظامية: تفضيل وضع الثيم المحفوظ محلياً (الإعداد نفسه
    // نظامي خارج ملحق هـ — يُدار من شاشة الإعدادات ويُخزَّن كنص).
    'ui.theme_mode',
  };

  /// يقرأ قيمة خام (JSON) أو null.
  Future<String?> raw(String key) async {
    final rows = await _db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  /// يكتب قيمة (JSON) — المفتاح يجب أن يكون في السجل.
  Future<void> set(String key, Object value) async {
    if (!knownKeys.contains(key)) {
      throw ArgumentError('مفتاح إعداد غير معتمد في السجل: $key (FR-13-09)');
    }
    await _db.insert('settings', {
      'key': key,
      'value': jsonEncode(value),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// قيمة نصية أو الافتراضي.
  Future<String> getString(String key, String fallback) async {
    final raw = await this.raw(key);
    if (raw == null) return fallback;
    try {
      return jsonDecode(raw) as String;
    } on FormatException {
      return fallback;
    }
  }

  /// قيمة عددية أو الافتراضي.
  Future<int> getInt(String key, int fallback) async {
    final raw = await this.raw(key);
    if (raw == null) return fallback;
    try {
      return (jsonDecode(raw) as num).toInt();
    } on FormatException {
      return fallback;
    }
  }

  // ── موصّلات مُطبَّعة (قيم ملحق هـ) ──

  /// `security.autolock_minutes` — قفل التطبيق بعد الخمول (افتراضي 5).
  Future<int> autolockMinutes() => getInt('security.autolock_minutes', 5);

  /// يثبّت مدة القفل التلقائي — النطاق الملزم 1–60 دقيقة (FR-12-05).
  Future<void> setAutolockMinutes(int minutes) async {
    if (minutes < 1 || minutes > 60) {
      throw ArgumentError('مدة القفل التلقائي خارج النطاق 1–60: $minutes');
    }
    await set('security.autolock_minutes', minutes);
  }

  /// `display.numerals` — western افتراضياً (قاعدة 5.4-9: عرض يمني بلا كسور).
  Future<String> numerals() => getString('display.numerals', 'western');

  /// يثبّت نظام الأرقام (`western` / `arabic_indic` فقط).
  Future<void> setNumerals(String mode) async {
    const allowed = {'western', 'arabic_indic'};
    if (!allowed.contains(mode)) {
      throw ArgumentError('نظام أرقام غير معروف: $mode');
    }
    await set('display.numerals', mode);
  }

  /// `ui.high_contrast` — وضع التباين العالي (FR-13-05).
  Future<bool> highContrast() async =>
      (await getString('ui.high_contrast', 'off')) == 'on';

  /// يثبّت وضع التباين العالي (`on` / `off`).
  Future<void> setHighContrast(bool on) =>
      set('ui.high_contrast', on ? 'on' : 'off');

  // ── موصّلات موجة UX-2a (التخصيص الشامل) ──

  /// `sale.default_payment` — وضع الدفع الذي تُفتح عليه نافذة الدفع
  /// (`cash` / `credit` / `mixed` — افتراضي cash بذر v3).
  Future<String> defaultPayment() => getString('sale.default_payment', 'cash');

  /// يثبّت طريقة الدفع الافتراضية (القيم الثلاث الملزمة حصراً).
  Future<void> setDefaultPayment(String mode) async {
    const allowed = {'cash', 'credit', 'mixed'};
    if (!allowed.contains(mode)) {
      throw ArgumentError('طريقة دفع افتراضية غير معروفة: $mode');
    }
    await set('sale.default_payment', mode);
  }

  /// `sale.show_discounts` — إظهار عناصر الخصم في الكاشير (افتراضي on).
  Future<bool> showDiscounts() async =>
      (await getString('sale.show_discounts', 'on')) == 'on';

  /// يثبّت إظهار/إخفاء الخصومات بالكاشير.
  Future<void> setShowDiscounts(bool show) =>
      set('sale.show_discounts', show ? 'on' : 'off');

  /// `sale.free_qty` — إظهار حقل الكمية المجانية (بونص) ببنود الكاشير
  /// (موجة UX-4 — مزروعة 'off' بهجرة v5: سلوك المتاجر القائمة حتى
  /// يفعّلها المالك). ON = حقل بونص بجوار الكمية؛ OFF = مخفي تماماً
  /// والسلوك كما هو اليوم.
  Future<bool> bonusQtyEnabled() async =>
      (await getString('sale.free_qty', 'off')) == 'on';

  /// يثبّت إظهار/إخفاء حقل البونص بالكاشير.
  Future<void> setBonusQtyEnabled(bool on) =>
      set('sale.free_qty', on ? 'on' : 'off');

  /// `display.font_scale` — حجم خط التطبيق
  /// (`normal` / `large` / `xlarge` — افتراضي normal بذر v3).
  Future<String> fontScale() => getString('display.font_scale', 'normal');

  /// يثبّت حجم الخط (المستويات الثلاثة الملزمة حصراً).
  Future<void> setFontScale(String mode) async {
    const allowed = {'normal', 'large', 'xlarge'};
    if (!allowed.contains(mode)) {
      throw ArgumentError('حجم خط غير معروف: $mode');
    }
    await set('display.font_scale', mode);
  }

  /// `sale.over_avail_policy` — سياسة البيع فوق المتاح (`warn`/`block`).
  /// مزروعة منذ v1 وبلا واجهة حتى UX-2a — الموصّل الموحّد لاستهلاكها.
  Future<String> overAvailPolicy() =>
      getString('sale.over_avail_policy', 'warn');

  /// `parties.credit_limit_action` — سياسة حد الائتمان (`warn`/`block`).
  /// مستهلكة منذ 17-c عبر قراءة نصية مباشرة — الموصّل الموحّد.
  Future<String> creditLimitAction() =>
      getString('parties.credit_limit_action', 'warn');

  /// `invoicing.discount_below_margin` — تحذير البيع تحت التكلفة
  /// (`on`/`off` — مزروعة off منذ v1 وبلا واجهة حتى UX-2a).
  Future<bool> discountBelowMargin() async =>
      (await getString('invoicing.discount_below_margin', 'off')) == 'on';

  /// `dating.max_backdate_days` — سقف التأريخ الرجعي لسندات النقدية
  /// (افتراضي 30 يوماً؛ مزروعة منذ v1 وبلا استهلاك حتى UX-2a).
  Future<int> maxBackdateDays() => getInt('dating.max_backdate_days', 30);

  /// مُتحقق عبارة المرور (حالة أمنية نظامية).
  Future<String?> passphraseHash() async {
    final rawValue = await raw('security.passphrase_hash');
    if (rawValue == null) return null;
    try {
      return jsonDecode(rawValue) as String;
    } on FormatException {
      return null;
    }
  }

  // ── وضع الثيم (حالة نظامية تُحفَظ فوراً) ──

  /// `ui.theme_mode` — `system` / `light` / `dark` (افتراضي system).
  Future<String> themeMode() => getString('ui.theme_mode', 'system');

  /// يثبّت وضع الثيم (يتحقق من القيم الثلاث فقط).
  Future<void> setThemeMode(String mode) async {
    const allowed = {'system', 'light', 'dark'};
    if (!allowed.contains(mode)) {
      throw ArgumentError('وضع ثيم غير معروف: $mode');
    }
    await set('ui.theme_mode', mode);
  }

  // ── النسخ الاحتياطي (وحدة 11 — FR-11-04/05، ملحق هـ) ──

  /// `backup.schedule` — `daily`/`weekly`/`off` (افتراضي weekly).
  Future<String> backupSchedule() => getString('backup.schedule', 'weekly');

  /// يثبّت الجدولة (قيم ملحق هـ حصراً).
  Future<void> setBackupSchedule(String mode) async {
    const allowed = {'daily', 'weekly', 'off'};
    if (!allowed.contains(mode)) {
      throw ArgumentError('جدولة نسخ غير معروفة: $mode');
    }
    await set('backup.schedule', mode);
  }

  /// `backup.retention_count` — عدد النسخ المحفوظة (افتراضي 7، نطاق 1–30).
  Future<int> backupRetentionCount() => getInt('backup.retention_count', 7);

  /// يثبّت عدد النسخ المحفوظة — النطاق الملزم 1–30 (ملحق هـ).
  Future<void> setBackupRetentionCount(int count) async {
    if (count < 1 || count > 30) {
      throw ArgumentError('عدد النسخ المحفوظة خارج النطاق 1–30: $count');
    }
    await set('backup.retention_count', count);
  }

  /// `backup.last_backup_at` (حالة نظامية) — لحظة آخر نسخة ناجحة أو null.
  Future<DateTime?> backupLastBackupAt() async {
    final rawValue = await raw('backup.last_backup_at');
    if (rawValue == null) return null;
    try {
      return DateTime.tryParse(jsonDecode(rawValue) as String);
    } on FormatException {
      return null;
    }
  }

  /// يثبّت لحظة آخر نسخة ناجحة (تستدعيها خدمة النسخ آلياً).
  Future<void> setBackupLastBackupAt(DateTime at) async {
    await set('backup.last_backup_at', at.toUtc().toIso8601String());
  }
}
