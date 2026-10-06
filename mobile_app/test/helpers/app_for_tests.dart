/// مساعدات الاختبارات — قاعدة فريدة لكل اختبار + تأسيس جاهز + تغليف l10n.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/data/repositories/settings_repository.dart';
import 'package:mobile_app/data/repositories/user_repository.dart';
import 'package:mobile_app/domain/services/pin_hasher.dart';
import 'package:mobile_app/domain/use_cases/setup_company.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// تهيئة مصنع FFI (آمنة للتكرار).
bool _ffiReady = false;

void initFfiForTests() {
  if (_ffiReady) return;
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  _ffiReady = true;
}

var _dbCounter = 0;

/// يفتح قاعدة في ملف مؤقت فريد — `:memory:` تتشارك عبر singleInstance
/// فتتعارض البذور بين الاختبارات.
Future<AppDatabase> openUniqueFileApp() async {
  final dir = await Directory.systemTemp.createTemp('finacc_test');
  final path = '${dir.path}/test_${_dbCounter++}.db';
  addTearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {
      // الملف قد يبقى مفتوحاً على بعض الأنظمة — تجاهل بأمان.
    }
  });
  return AppDatabase.openWith(databaseFactory, path);
}

/// مسودة تأسيس قياسية للاختبارات (PIN خام — يُهشَّر هنا).
Future<SetupCompanyDraft> testDraft({
  String name = 'متجر النور للأدوات المنزلية',
  String? phone = '777123456',
  String currencyCode = 'YER',
  String pin = '1234',
  String passphrase = 'Passphrase-2026',
}) async {
  final now = DateTime.utc(2026, 10, 6, 12);
  return SetupCompanyDraft(
    companyName: name,
    phone: phone,
    currencyCode: currencyCode,
    taxRate: 0,
    warehouseName: 'المخزن الرئيسي',
    cashboxName: 'الصندوق الرئيسي',
    adminDisplayName: 'أبو نور',
    pinHash: await PinHasher.hash(pin),
    passphraseHash: await PinHasher.hash(passphrase),
    fiscalYear: now.year,
    fiscalStart: DateTime(now.year, 1, 1),
    fiscalEnd: DateTime(now.year, 12, 31),
  );
}

/// يفتح قاعدة ويؤسسها كاملة (جاهزة للاستخدام مباشرة).
Future<
  (
    AppDatabase,
    CompanyRepository,
    UserRepository,
    SettingsRepository,
  )
>
openSeededApp() async {
  final app = await openUniqueFileApp();
  final companies = CompanyRepository(app.db);
  final users = UserRepository(app.db);
  final settings = SettingsRepository(app.db);
  await companies.executeSetup(
    await testDraft(),
    DateTime.utc(2026, 10, 6, 12),
  );
  return (app, companies, users, settings);
}

/// تغليف عنصر داخل تطبيق مترجم (عربي RTL افتراضياً) — للاختبارات البصرية.
Widget wrapWithL10n(Widget child, {bool arabic = true}) {
  final locale = arabic ? const Locale('ar') : const Locale('en');
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Directionality(
      textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(body: child),
    ),
  );
}

/// مضخّات محدودة بدل pumpAndSettle — الحركات المتكررة (Shimmer) لا تستقر.
Future<void> pumpQuietly(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
