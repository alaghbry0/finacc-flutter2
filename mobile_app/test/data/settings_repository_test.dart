/// اختبارات مستودع الإعدادات — سجل المفاتيح + الموصّلات + الحراسات.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/settings_repository.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  test(
    'الافتراضيات قبل أي كتابة: numerals=western وautolock=5 وtheme=system',
    () async {
      final app = await openUniqueFileApp();
      addTearDown(app.close);
      final settings = SettingsRepository(app.db);

      expect(await settings.numerals(), 'western');
      expect(await settings.autolockMinutes(), 5);
      expect(await settings.themeMode(), 'system');
      expect(await settings.highContrast(), isFalse);
    },
  );

  test('كتابة/قراءة جولة كاملة لكل الموصلات المطبّعة', () async {
    final app = await openUniqueFileApp();
    addTearDown(app.close);
    final settings = SettingsRepository(app.db);

    await settings.setNumerals('arabic_indic');
    await settings.setAutolockMinutes(15);
    await settings.setThemeMode('dark');
    expect(await settings.numerals(), 'arabic_indic');
    expect(await settings.autolockMinutes(), 15);
    expect(await settings.themeMode(), 'dark');

    await settings.setNumerals('western');
    await settings.setThemeMode('light');
    expect(await settings.numerals(), 'western');
    expect(await settings.themeMode(), 'light');
  });

  test('حراسة القيم: نظام أرقام/ثيم غير معروف يرفض', () async {
    final app = await openUniqueFileApp();
    addTearDown(app.close);
    final settings = SettingsRepository(app.db);

    expect(() => settings.setNumerals('roman'), throwsArgumentError);
    expect(() => settings.setThemeMode('neon'), throwsArgumentError);
    expect(() => settings.setAutolockMinutes(0), throwsArgumentError);
    expect(() => settings.setAutolockMinutes(61), throwsArgumentError);
  });

  test('حراسة السجل: مفتاح غير معتمد يرفض (FR-13-09)', () async {
    final app = await openUniqueFileApp();
    addTearDown(app.close);
    final settings = SettingsRepository(app.db);

    expect(() => settings.set('unknown.key', 'x'), throwsArgumentError);
    // المفاتيح الجديدة من الميزات موجودة في السجل.
    expect(
      SettingsRepository.knownKeys,
      containsAll(<String>[
        'display.numerals',
        'ui.theme_mode',
        'security.autolock_minutes',
        'security.passphrase_hash',
        'ui.high_contrast',
      ]),
    );
  });

  test('raw يخزن JSON خام — والقراءة النصية تفكّ الترميز', () async {
    final app = await openUniqueFileApp();
    addTearDown(app.close);
    final settings = SettingsRepository(app.db);

    await settings.set('display.numerals', 'arabic_indic');
    expect(await settings.raw('display.numerals'), '"arabic_indic"');
    expect(await settings.getString('display.numerals', 'x'), 'arabic_indic');
    expect(await settings.raw('missing.key'), isNull);
    expect(await settings.getString('missing.key', 'fallback'), 'fallback');
    expect(await settings.getInt('missing.key', 7), 7);
  });

  test('getInt يتعافى من قيمة تالفة بالافتراضي', () async {
    final app = await openUniqueFileApp();
    addTearDown(app.close);
    final settings = SettingsRepository(app.db);

    await app.db.insert('settings', {
      'key': 'backup.retention_count',
      'value': 'not-json{',
      'updated_at': '2026-10-06T00:00:00Z',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    expect(await settings.getInt('backup.retention_count', 3), 3);
  });

  test('بذور ملحق هـ: القيم الأولية الـ15 قابلة للقراءة فور الفتح', () async {
    final app = await openUniqueFileApp();
    addTearDown(app.close);
    final settings = SettingsRepository(app.db);

    expect(await settings.raw('invoicing.tax_mode'), '"on_total"');
    expect(await settings.raw('invoicing.print_on_save'), '"ask"');
    expect(await settings.getInt('dating.max_backdate_days', 0), 30);
    expect(await settings.getInt('backup.retention_count', 0), 7);
  });

  test('passphraseHash: null قبل التأسيس وقيمة مهشّرة بعده', () async {
    final app = await openUniqueFileApp();
    final settings = SettingsRepository(app.db);
    expect(await settings.passphraseHash(), isNull);
    await app.close();

    final seeded = await openSeededApp();
    addTearDown(seeded.$1.close);
    expect(await seeded.$4.passphraseHash(), isNotNull);
    expect(
      (await seeded.$4.passphraseHash())!.startsWith('pbkdf2-sha256\$'),
      isTrue,
    );
  });

  test('القيم تبقى بعد إغلاق وإعادة فتح نفس الملف', () async {
    final dir = await Directory.systemTemp.createTemp('finacc_settings');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/settings.db';

    final first = await AppDatabase.openWith(databaseFactory, path);
    final settings = SettingsRepository(first.db);
    await settings.setNumerals('arabic_indic');
    await settings.setAutolockMinutes(30);
    await first.close();

    final second = await AppDatabase.openWith(databaseFactory, path);
    final reopened = SettingsRepository(second.db);
    expect(await reopened.numerals(), 'arabic_indic');
    expect(await reopened.autolockMinutes(), 30);
    await second.close();
  });

  // ── موصّلات موجة UX-2a (التخصيص الشامل) ──

  test(
    'UX-2a: الافتراضيات — دفع نقدي، خصومات ظاهرة، خط عادي، تباين مكتوم',
    () async {
      final app = await openUniqueFileApp();
      addTearDown(app.close);
      final settings = SettingsRepository(app.db);

      expect(await settings.defaultPayment(), 'cash');
      expect(await settings.showDiscounts(), isTrue);
      expect(await settings.fontScale(), 'normal');
      expect(await settings.highContrast(), isFalse);
      expect(await settings.overAvailPolicy(), 'warn');
      expect(await settings.creditLimitAction(), 'warn');
      expect(await settings.discountBelowMargin(), isFalse);
      expect(await settings.maxBackdateDays(), 30);
    },
  );

  test('UX-2a: كتابة/قراءة جولة كاملة للموصّلات الجديدة', () async {
    final app = await openUniqueFileApp();
    addTearDown(app.close);
    final settings = SettingsRepository(app.db);

    await settings.setDefaultPayment('credit');
    await settings.setShowDiscounts(false);
    await settings.setFontScale('xlarge');
    await settings.setHighContrast(true);
    await settings.set('sale.over_avail_policy', 'block');
    await settings.set('parties.credit_limit_action', 'block');
    await settings.set('invoicing.discount_below_margin', 'on');

    expect(await settings.defaultPayment(), 'credit');
    expect(await settings.showDiscounts(), isFalse);
    expect(await settings.fontScale(), 'xlarge');
    expect(await settings.highContrast(), isTrue);
    expect(await settings.overAvailPolicy(), 'block');
    expect(await settings.creditLimitAction(), 'block');
    expect(await settings.discountBelowMargin(), isTrue);

    // رجوع للقيم الافتراضية.
    await settings.setDefaultPayment('mixed');
    await settings.setShowDiscounts(true);
    await settings.setFontScale('large');
    await settings.setHighContrast(false);
    expect(await settings.defaultPayment(), 'mixed');
    expect(await settings.showDiscounts(), isTrue);
    expect(await settings.fontScale(), 'large');
    expect(await settings.highContrast(), isFalse);
  });

  test('UX-2a: حراسة القيم — الوضع غير المعروف يرفض', () async {
    final app = await openUniqueFileApp();
    addTearDown(app.close);
    final settings = SettingsRepository(app.db);

    expect(() => settings.setDefaultPayment('barter'), throwsArgumentError);
    expect(() => settings.setFontScale('huge'), throwsArgumentError);
  });

  test('UX-2a: سجل المفاتيح يضم مفاتيح التخصيص الجديدة (FR-13-09)', () async {
    expect(
      SettingsRepository.knownKeys,
      containsAll(<String>[
        'sale.default_payment',
        'sale.show_discounts',
        'display.font_scale',
        'sale.over_avail_policy',
        'parties.credit_limit_action',
        'invoicing.discount_below_margin',
        'dating.max_backdate_days',
        'ui.high_contrast',
      ]),
    );
  });
}
