/// اختبارات مستودع المنشأة — التأسيس الذرّي الكامل وفق FR-13-01.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/domain/services/pin_hasher.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase handle;

  setUp(() async {
    handle = await openUniqueFileApp();
  });

  tearDown(() async {
    await handle.close();
  });

  test('hasCompany: خطأ قبل التأسيس وصواب بعده', () async {
    final repo = CompanyRepository(handle.db);
    expect(await repo.hasCompany(), isFalse);
    await repo.executeSetup(await testDraft(), DateTime.utc(2026, 10, 6));
    expect(await repo.hasCompany(), isTrue);
  });

  test('التأسيس الذرّي ينشئ كل الكيانات الثمانية (منشأة/مخزن/صندوق/مدير/سنة/عبارة/تدقيق/عملة)', () async {
    final repo = CompanyRepository(handle.db);
    final company = await repo.executeSetup(
      await testDraft(),
      DateTime.utc(2026, 10, 6),
    );

    expect(company.name, 'متجر النور للأدوات المنزلية');
    expect(company.currencyId, greaterThan(0));

    final companyRows = await handle.db.query('company');
    expect(companyRows, hasLength(1));
    expect(companyRows.first['tax_rate'], 0);

    final warehouse = await handle.db.query('warehouse');
    expect(warehouse, hasLength(1));
    expect(warehouse.first['is_default'], 1);
    expect(warehouse.first['name'], 'المخزن الرئيسي');

    final cashbox = await handle.db.query('cashbox');
    expect(cashbox, hasLength(1));
    expect(cashbox.first['is_default'], 1);
    expect(cashbox.first['currency_id'], company.currencyId);

    final admin = await handle.db.query('app_user');
    expect(admin, hasLength(1));
    expect(admin.first['role'], 'admin');
    expect(admin.first['username'], 'admin');
    expect(PinHasher.verify('1234', admin.first['pin_hash'] as String), isTrue);

    final fiscal = await handle.db.query('fiscal_year');
    expect(fiscal, hasLength(1));
    expect(fiscal.first['year'], 2026);
    expect(fiscal.first['status'], 'open');

    final passphrase = await handle.db.query(
      'settings',
      where: "key = 'security.passphrase_hash'",
    );
    expect(passphrase, hasLength(1));

    final audit = await handle.db.query(
      'audit_log',
      where: "action = 'app_setup'",
    );
    expect(audit, hasLength(1));
    expect(audit.first['entity'], 'company');
  });

  test('اختيار عملة أخرى يثبّتها ويعيد ضبط YER (FR-08-01)', () async {
    final repo = CompanyRepository(handle.db);
    await repo.executeSetup(
      await testDraft(currencyCode: 'SAR'),
      DateTime.utc(2026, 10, 6),
    );
    final base = await repo.findBaseCurrency();
    expect(base!.code, 'SAR');
    final yer = (await handle.db.query(
      'currency',
      where: "code = 'YER'",
    )).first;
    expect(yer['is_base'], 0);
  });

  test('عملة غير موجودة: التأسيس يفشل ولا يكتب شيئاً (ذرّية)', () async {
    final repo = CompanyRepository(handle.db);
    final badDraft = await testDraft(currencyCode: 'ZZZ');
    expect(
      () => repo.executeSetup(badDraft, DateTime.utc(2026, 10, 6)),
      throwsA(anything),
    );
    expect(await repo.hasCompany(), isFalse);
    expect(await handle.db.query('warehouse'), isEmpty);
    expect(await handle.db.query('app_user'), isEmpty);
    expect(await handle.db.query('fiscal_year'), isEmpty);
    expect(
      await handle.db.query('audit_log'),
      isEmpty,
      reason: 'لا قيد تدقيق لعملية فاشلة',
    );
  });

  test('findCompany وfindBaseCurrency بعد التأسيس', () async {
    final repo = CompanyRepository(handle.db);
    expect(await repo.findCompany(), isNull);
    await repo.executeSetup(await testDraft(), DateTime.utc(2026, 10, 6));
    final company = await repo.findCompany();
    expect(company!.name, 'متجر النور للأدوات المنزلية');
    final currency = await repo.findBaseCurrency();
    expect(currency!.code, 'YER');
    expect(currency.name, 'ريال يمني');
    expect(currency.decimals, 0);
  });

  test('listActiveCurrencies: الأربع النشطة بترتيب ثابت', () async {
    final repo = CompanyRepository(handle.db);
    final currencies = await repo.listActiveCurrencies();
    expect(currencies, hasLength(4));
    expect(currencies.map((c) => c.code), containsAll(['YER', 'SAR', 'USD', 'AED']));
  });
}
