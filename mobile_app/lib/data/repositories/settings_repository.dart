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

  /// المفاتيح المعتمدة (ملحق هـ — مفاتيح V1 + حالة أمنية نظامية).
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
    'ui.high_contrast',
    'backup.schedule',
    'backup.retention_count',
    'security.autolock_minutes',
    'dating.max_backdate_days',
    // حالة نظامية (ليست إعداداً قابلاً للضبط — انظر CompanyRepository).
    'security.passphrase_hash',
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

  /// `display.numerals` — western افتراضياً (قاعدة 5.4-9: عرض يمني بلا كسور).
  Future<String> numerals() => getString('display.numerals', 'western');

  /// `ui.high_contrast` — وضع التباين العالي (FR-13-05).
  Future<bool> highContrast() async =>
      (await getString('ui.high_contrast', 'off')) == 'on';

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
}
