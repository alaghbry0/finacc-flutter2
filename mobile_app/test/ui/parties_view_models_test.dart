/// اختبارات نماذج عرض الأطراف (المرحلة 3 — FR-03/FR-08): قوائم العملاء
/// والموردين بالبحث والتصفية والأرشفة (بلا حركات تنجح/مع حركات تُرفض)،
/// نموذج الطرف (فرض الاسم، دلالات حد الائتمان الثلاث، افتتاحي بلا عملة
/// يُرفض، تعطيل الافتتاحي بعد الحركات مع حفظ القيم الأصلية)، كشف الحساب
/// يظهر الافتتاحي، أسعار الصرف اليومية (حفظ اليوم + latestBefore غداً)،
/// وفصل العملات في قائمة الأرصدة (سطر لكل عملة بلا خلط).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/data/repositories/customer_repository.dart';
import 'package:mobile_app/data/repositories/exchange_rate_repository.dart';
import 'package:mobile_app/data/repositories/supplier_repository.dart';
import 'package:mobile_app/domain/core/result.dart';
import 'package:mobile_app/domain/models/party.dart';
import 'package:mobile_app/ui/features/parties/view_models/exchange_rates_view_model.dart';
import 'package:mobile_app/ui/features/parties/view_models/party_balances_view_model.dart';
import 'package:mobile_app/ui/features/parties/view_models/party_detail_view_model.dart';
import 'package:mobile_app/ui/features/parties/view_models/party_form_view_model.dart';
import 'package:mobile_app/ui/features/parties/view_models/party_kind.dart';
import 'package:mobile_app/ui/features/parties/view_models/party_list_view_model.dart';
import 'package:mobile_app/ui/features/parties/view_models/party_lookup.dart';
import 'package:mobile_app/ui/features/parties/view_models/party_repo_gate.dart';
import 'package:mobile_app/ui/features/parties/view_models/parties_home_view_model.dart';

import '../helpers/app_for_tests.dart';

/// لحظة مرجعية موحّدة «اليوم» في كل الاختبارات.
final DateTime _today = DateTime(2026, 10, 6, 12);

/// حزمة مستودعات فوق قاعدة مؤسّسة.
final class _Repos {
  _Repos(this.db, this.customers, this.suppliers, this.fx, this.companies);

  final AppDatabase db;
  final CustomerRepository customers;
  final SupplierRepository suppliers;
  final ExchangeRateRepository fx;
  final CompanyRepository companies;

  Future<int> userId() async => await companies.findAdminUserId() ?? 1;

  /// معرّف عملة برمزها من قاعدة الاختبار.
  Future<int> currencyId(String code) async {
    final rows = await db.db.query(
      'currency',
      columns: ['id'],
      where: 'code = ?',
      whereArgs: [code],
      limit: 1,
    );
    return rows.first['id'] as int;
  }

  Future<Map<String, Object?>> customerRow(int id) async {
    final rows = await db.db.query(
      'customer',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.first;
  }
}

Future<_Repos> _open() async {
  final seeded = await openSeededApp();
  addTearDown(seeded.$1.close);
  return _Repos(
    seeded.$1,
    CustomerRepository(seeded.$1.db),
    SupplierRepository(seeded.$1.db),
    ExchangeRateRepository(seeded.$1.db),
    seeded.$2,
  );
}

/// ينشئ عميلاً — رصيد افتتاحي اختياري بعملته (سعر 1 للاختبار).
Future<Customer> _createCustomer(
  _Repos repos,
  String name, {
  String? phone,
  double opening = 0,
  String? currencyCode,
  double? creditLimit,
}) async {
  final currencyId = currencyCode == null || opening == 0
      ? null
      : await repos.currencyId(currencyCode);
  final result = await repos.customers.createCustomer(
    CustomerDraft(
      name: name,
      phone: phone,
      creditLimit: creditLimit,
      openingBalance: opening,
      openingBalanceCurrencyId: currencyId,
      openingBalanceRate: currencyId == null ? null : 1,
      openingBalanceDate: opening == 0 ? null : _today,
    ),
    userId: await repos.userId(),
    now: _today,
  );
  final ok = result as Ok<int, String>;
  final lookup = PartyLookup(repos.db.db);
  return (await lookup.customer(ok.value))!;
}

Future<Supplier> _createSupplier(
  _Repos repos,
  String name, {
  double opening = 0,
  String? currencyCode,
}) async {
  final currencyId = currencyCode == null || opening == 0
      ? null
      : await repos.currencyId(currencyCode);
  final result = await repos.suppliers.createSupplier(
    SupplierDraft(
      name: name,
      openingBalance: opening,
      openingBalanceCurrencyId: currencyId,
      openingBalanceRate: currencyId == null ? null : 1,
      openingBalanceDate: opening == 0 ? null : _today,
    ),
    userId: await repos.userId(),
    now: _today,
  );
  final ok = result as Ok<int, String>;
  final lookup = PartyLookup(repos.db.db);
  return (await lookup.supplier(ok.value))!;
}

PartyFormViewModel _formVm(_Repos repos, {int? editId}) =>
    PartyFormViewModel(
      customerRepo: repos.customers,
      supplierRepo: repos.suppliers,
      companyRepo: repos.companies,
      fxRepo: repos.fx,
      partyLookup: PartyLookup(repos.db.db),
      partyKind: PartyKind.customer,
      reference: _today,
      editPartyId: editId,
    );

PartyListViewModel _listVm(_Repos repos, PartyKind kind) => PartyListViewModel(
  gate: kind == PartyKind.customer
      ? CustomerRepoGate(repos.customers)
      : SupplierRepoGate(repos.suppliers),
  companyRepo: repos.companies,
  partyKind: kind,
);

PartyDetailViewModel _detailVm(_Repos repos, PartyKind kind, int id) =>
    PartyDetailViewModel(
      gate: kind == PartyKind.customer
          ? CustomerRepoGate(repos.customers)
          : SupplierRepoGate(repos.suppliers),
      companyRepo: repos.companies,
      partyLookup: PartyLookup(repos.db.db),
      partyKind: kind,
      id: id,
);

void main() {
  setUpAll(initFfiForTests);

  group('PartyListViewModel — البحث والتصفية والأرشفة', () {
    test('البحث بالاسم يرشّح، والرقائق تفلتر، والأرشفة بلا حركات تنجح',
        () async {
      final repos = await _open();
      final noMovements = await _createCustomer(repos, 'عبدالله السامعي');
      final withSar = await _createCustomer(
        repos,
        'بهاء الدين',
        opening: 5000,
        currencyCode: 'SAR',
      );

      final vm = _listVm(repos, PartyKind.customer);
      await vm.load();

      // الكل: طرفان (الأول سطر صفري بعملة القاعدة).
      expect(vm.state.rows, hasLength(2));
      expect(vm.state.distinctParties, 2);

      // بأرصدة: سطر بهاء فقط (٥٠٠٠ SAR).
      await vm.setFilter(PartyListFilter.withBalance);
      expect(vm.state.rows, hasLength(1));
      expect(vm.state.rows.first.name, 'بهاء الدين');
      expect(vm.state.rows.first.currencyCode, 'SAR');
      expect(vm.state.rows.first.balance, 5000);

      // بدون أرصدة: عبدالله (بلا حركات).
      await vm.setFilter(PartyListFilter.zeroBalance);
      expect(vm.state.rows, hasLength(1));
      expect(vm.state.rows.first.name, 'عبدالله السامعي');

      // البحث باسم غير موجود يفرّغ.
      await vm.setFilter(PartyListFilter.all);
      await vm.setQuery('zzz');
      expect(vm.state.rows, isEmpty);

      // البحث بهاتف بهاء يرشّح له.
      await _createCustomer(repos, 'هاتف مجهول', phone: '777999888');
      await vm.setQuery('777999888');
      expect(vm.state.rows, hasLength(1));
      await vm.setQuery('');

      // أرشفة بلا حركات تنجح ويختفي من القائمة.
      final outcome = await vm.archive(noMovements.id);
      expect(outcome, PartyArchiveOutcome.done);
      expect(
        vm.state.rows.map((r) => r.partyId),
        isNot(contains(noMovements.id)),
      );

      // أرشفة من له رصيد افتتاحي (حركة) تُرفض.
      final blocked = await vm.archive(withSar.id);
      expect(blocked, PartyArchiveOutcome.blocked);
      vm.dispose();
    });

    test('تصفية المؤرشفين تعرضه بشارة، ومرآة الموردين تعمل', () async {
      final repos = await _open();
      final supplier = await _createSupplier(repos, 'مصنع ماء فين');
      final vm = _listVm(repos, PartyKind.supplier);
      await vm.load();
      expect(vm.state.rows, hasLength(1));

      // أرشفة المورد بلا حركات ثم إظهاره في «مؤرشفون».
      expect(await vm.archive(supplier.id), PartyArchiveOutcome.done);
      await vm.setFilter(PartyListFilter.archived);
      expect(vm.state.rows, hasLength(1));
      expect(vm.state.rows.first.name, 'مصنع ماء فين');
      vm.dispose();
    });
  });

  group('PartyFormViewModel — التحقق والدلالات الثلاث والافتتاحي', () {
    test('الاسم إلزامي، وحد الائتمان الثلاث يُخزَّن بدلالاته الصحيحة',
        () async {
      final repos = await _open();

      // 1) الاسم الفارغ يُرفض فوراً.
      var vm = _formVm(repos);
      await vm.load();
      expect(await vm.save(), isFalse);
      expect(vm.state.validationError, PartyFormError.nameRequired);

      // 2) حد فارغ = بلا حد (NULL).
      vm.setName('عميل بلا حد');
      expect(await vm.save(), isTrue);
      final unlimited = await repos.customerRow(1);
      expect(unlimited['credit_limit'], isNull);

      // 3) صفر = منع الآجل.
      vm = _formVm(repos);
      await vm.load();
      vm.setName('عميل آجل ممنوع');
      vm.setCreditLimitText('0');
      expect(vm.state.parsedCreditLimit, 0);
      expect(await vm.save(), isTrue);
      final forbidden = await repos.customerRow(2);
      expect(forbidden['credit_limit'], 0);

      // 4) رقم = الحد نفسه.
      vm = _formVm(repos);
      await vm.load();
      vm.setName('عميل بحد');
      vm.setCreditLimitText('5000');
      expect(vm.state.parsedCreditLimit, 5000);
      expect(await vm.save(), isTrue);
      final limited = await repos.customerRow(3);
      expect(limited['credit_limit'], 5000);
      vm.dispose();
    });

    test('افتتاحي غير صفري بلا عملة يُرفض؛ وبعملة يُحفظ بها', () async {
      final repos = await _open();
      final vm = _formVm(repos);
      await vm.load();

      vm.setName('عميل افتتاحي');
      vm.setOpeningText('250');
      vm.setOpeningCurrency(null); // مسح العملة.
      expect(await vm.save(), isFalse);
      expect(
        vm.state.validationError,
        PartyFormError.openingCurrencyRequired,
      );

      // العملة الأساسية = سعر 1 بلا بحث.
      vm.setOpeningCurrency(await repos.currencyId('YER'));
      expect(await vm.save(), isTrue);
      final row = await repos.customerRow(1);
      expect(row['opening_balance'], 250);
      expect(row['opening_balance_currency_id'], await repos.currencyId('YER'));
      expect(row['opening_balance_rate'], 1);
      vm.dispose();
    });

    test('افتتاحي بعملة غير الأساس بلا سعر معروف يُرفض (FR-08-09)',
        () async {
      final repos = await _open();
      final vm = _formVm(repos);
      await vm.load();
      vm.setName('عميل دولار');
      vm.setOpeningText('100');
      vm.setOpeningCurrency(await repos.currencyId('USD'));
      // لا سعر مسجّل للدولار إطلاقاً — يُمنع الحفظ.
      expect(await vm.save(), isFalse);
      expect(vm.state.validationError, PartyFormError.noRate);
      vm.dispose();
    });

    test('التعديل بعد حركات: الافتتاحي مقفل وتُحفظ قيمه الأصلية', () async {
      final repos = await _open();
      final customer = await _createCustomer(
        repos,
        'بهاء الدين',
        opening: 5000,
        currencyCode: 'SAR',
      );

      final vm = _formVm(repos, editId: customer.id);
      await vm.load();
      expect(vm.state.editMode, isTrue);
      expect(vm.state.openingLocked, isTrue); // الافتتاحي نفسه حركة.

      // محاولة تعديل (لن تصل من الواجهة — الحقول معطلة) لا تغير المخزن.
      vm.setOpeningText('99999');
      vm.setName('بهاء الدين المعدّل');
      expect(await vm.save(), isTrue);
      final row = await repos.customerRow(customer.id);
      expect(row['opening_balance'], 5000); // الأصل محفوظ.
      expect(row['opening_balance_currency_id'], await repos.currencyId('SAR'));
      expect(row['name'], 'بهاء الدين المعدّل'); // بقية الحقول تعدّلت.

      // طرف بلا حركات: الافتتاحي قابل للإضافة عند التعديل.
      final fresh = await _createCustomer(repos, 'عميل جديد بلا افتتاحي');
      final vm2 = _formVm(repos, editId: fresh.id);
      await vm2.load();
      expect(vm2.state.openingLocked, isFalse);
      // سعر معروف لليوم شرط للحفظ بافتتاحي بعملة غير الأساس (FR-08-09).
      final sarId = await repos.currencyId('SAR');
      await repos.fx.setRate(
        currencyId: sarId,
        date: _today,
        rate: 215,
        userId: await repos.userId(),
        now: _today,
      );
      vm2.setOpeningText('750');
      vm2.setOpeningCurrency(sarId);
      expect(await vm2.save(), isTrue);
      final freshRow = await repos.customerRow(fresh.id);
      expect(freshRow['opening_balance'], 750);
      vm.dispose();
      vm2.dispose();
    });
  });

  group('PartyDetailViewModel — كشف الحساب يظهر الافتتاحي', () {
    test('عمليل برصيد SAR: أول قيد افتتاحي والرصيد النهائي يطابق', () async {
      final repos = await _open();
      final customer = await _createCustomer(
        repos,
        'بهاء الدين',
        opening: 5000,
        currencyCode: 'SAR',
      );

      final vm = _detailVm(repos, PartyKind.customer, customer.id);
      await vm.load();

      // عملة الكشف الافتراضية = عملة الافتتاحي.
      expect(vm.state.statementCurrencyId, await repos.currencyId('SAR'));
      final statement = vm.state.statement!;
      expect(statement.entries, hasLength(1));
      expect(statement.entries.first.code, StatementEntryCode.opening);
      expect(statement.entries.first.amount, 5000);
      expect(statement.entries.first.runningBalance, 5000);
      expect(statement.finalBalance, 5000);
      expect(
        statement.finalBalance,
        await repos.customers.balanceInCurrency(
          customer.id,
          await repos.currencyId('SAR'),
        ),
      );

      // فترة تبدأ بعد الافتتاحي → «رصيد ماضٍ» وحيد.
      await vm.setFrom(DateTime(2026, 10, 10));
      final carried = vm.state.statement!;
      expect(carried.entries, hasLength(1));
      expect(carried.entries.first.code, StatementEntryCode.carryIn);
      expect(carried.openingBalance, 5000);

      // مسح الفترة يعيد الافتتاحي قيداً داخل الكشف.
      await vm.clearPeriod();
      expect(vm.state.from, isNull);
      expect(vm.state.statement!.entries.first.code, StatementEntryCode.opening);

      // الأرصدة مفصولة بكل عملة.
      expect(vm.state.balances, hasLength(1));
      expect(vm.state.balances.first.currencyCode, 'SAR');
      vm.dispose();
    });

    test('مورد: المرآة كاملة بالافتتاحي وكشف بعملته', () async {
      final repos = await _open();
      final supplier = await _createSupplier(
        repos,
        'مصنع ماء فين',
        opening: 2500,
        currencyCode: 'SAR',
      );
      final vm = _detailVm(repos, PartyKind.supplier, supplier.id);
      await vm.load();
      expect(vm.state.record!.name, 'مصنع ماء فين');
      expect(vm.state.statement!.entries.first.code, StatementEntryCode.opening);
      expect(vm.state.statement!.finalBalance, 2500);
      vm.dispose();
    });
  });

  group('ExchangeRatesViewModel — سعر اليوم يعمل غداً (latestBefore)',
      () {
    test('الحفظ والتحديث (UPSERT) وحالة الإكمال والفشل الرقمي', () async {
      final repos = await _open();
      final vm = ExchangeRatesViewModel(
        companyRepo: repos.companies,
        fxRepo: repos.fx,
        now: _today,
      );
      await vm.load();

      // ثلاث عملات غير الأساس (SAR/USD/AED) — الأساس غائب تماماً.
      expect(vm.state.entries, hasLength(3));
      expect(
        vm.state.entries.map((e) => e.currency.code),
        containsAll(['SAR', 'USD', 'AED']),
      );
      expect(vm.state.baseCurrency!.code, 'YER');
      expect(vm.state.complete, isFalse);

      // نص غير صالح → خطأ حقل بلا كتابة.
      final sarId = await repos.currencyId('SAR');
      expect(await vm.setRateFor(sarId, 'abc'), isFalse);
      expect(
        vm.state.entries.firstWhere((e) => e.currency.id == sarId).fieldError,
        isTrue,
      );

      // حفظ سعر اليوم.
      expect(await vm.setRateFor(sarId, '215'), isTrue);
      final sarEntry = vm.state.entries
          .firstWhere((e) => e.currency.id == sarId);
      expect(sarEntry.enteredToday, isTrue);
      expect(sarEntry.todayRate, 215);
      expect(sarEntry.latest!.rate, 215);

      // التحديث لنفس اليوم = نفس الصف (UPSERT) لا تكرار.
      expect(await vm.setRateFor(sarId, '220'), isTrue);
      final after = vm.state.entries
          .firstWhere((e) => e.currency.id == sarId);
      expect(after.todayRate, 220);
      expect(after.history, hasLength(1));

      // غداً: latestBefore يجد السعر، وrateFor لغد لا يجده.
      final tomorrow = _today.add(const Duration(days: 1));
      expect(await repos.fx.latestBefore(sarId, tomorrow), 220);
      expect(await repos.fx.rateFor(sarId, tomorrow), isNull);
      expect(await repos.fx.hasRateFor(sarId, _today), isTrue);

      // إكمال الثلاث يقلب الحالة إلى مكتملة.
      await vm.setRateFor(await repos.currencyId('USD'), '530');
      await vm.setRateFor(await repos.currencyId('AED'), '68');
      expect(vm.state.complete, isTrue);
      expect(vm.state.missing, isFalse);
      vm.dispose();
    });
  });

  group('PartyBalancesViewModel — فصل العملات بلا خلط', () {
    test('مجموعة لكل عملة بإجماليها، والبحث محلي', () async {
      final repos = await _open();
      await _createCustomer(repos, 'بهاء الدين', opening: 5000,
          currencyCode: 'SAR');
      await _createCustomer(repos, 'سالم الحضرمي', opening: 3000,
          currencyCode: 'SAR');
      await _createCustomer(repos, 'محمد الجابري', opening: 200,
          currencyCode: 'USD');

      final vm = PartyBalancesViewModel(
        gate: CustomerRepoGate(repos.customers),
        companyRepo: repos.companies,
        partyKind: PartyKind.customer,
        reference: _today,
      );
      await vm.load();

      // مجموعتان مستقلتان — لا رقم واحد يجمع SAR مع USD.
      expect(vm.state.groups, hasLength(2));
      final sar = vm.state.groups.firstWhere((g) => g.currencyCode == 'SAR');
      final usd = vm.state.groups.firstWhere((g) => g.currencyCode == 'USD');
      expect(sar.rows, hasLength(2));
      expect(sar.total, 8000);
      expect(usd.rows, hasLength(1));
      expect(usd.total, 200);
      expect(sar.decimals, 2);
      expect(usd.decimals, 2);
      expect(vm.state.hasAnyDues, isTrue);

      // بحث محلي باسم — مجموعة SAR وحدها بمجموع مصغّر.
      vm.setQuery('بهاء');
      expect(vm.state.groups, hasLength(1));
      expect(vm.state.groups.first.total, 5000);
      expect(vm.state.groups.first.rows.first.name, 'بهاء الدين');
      vm.dispose();
    });

    test('مرآة الموردين: payables مجمّعة بكل عملة', () async {
      final repos = await _open();
      await _createSupplier(repos, 'مورد دولاري', opening: 400,
          currencyCode: 'USD');
      final vm = PartyBalancesViewModel(
        gate: SupplierRepoGate(repos.suppliers),
        companyRepo: repos.companies,
        partyKind: PartyKind.supplier,
        reference: _today,
      );
      await vm.load();
      expect(vm.state.groups, hasLength(1));
      expect(vm.state.groups.first.currencyCode, 'USD');
      expect(vm.state.groups.first.total, 400);
      vm.dispose();
    });
  });

  group('PartiesHomeViewModel — العدّادات وحالة أسعار اليوم', () {
    test('العدّادات والإجماليات لكل عملة وشارة النقص/الاكتمال', () async {
      final repos = await _open();
      await _createCustomer(repos, 'بهاء الدين', opening: 5000,
          currencyCode: 'SAR');
      await _createCustomer(repos, 'عبدالله بلا حركات');
      await _createSupplier(repos, 'مورد دولار', opening: 300,
          currencyCode: 'USD');
      await repos.fx.setRate(
        currencyId: await repos.currencyId('SAR'),
        date: _today,
        rate: 215,
        userId: await repos.userId(),
      );

      final vm = PartiesHomeViewModel(
        customerRepo: repos.customers,
        supplierRepo: repos.suppliers,
        companyRepo: repos.companies,
        fxRepo: repos.fx,
        reference: _today,
      );
      await vm.load();

      expect(vm.state.customersCount, 2);
      expect(vm.state.suppliersCount, 1);
      expect(vm.state.receivableParties, 1);
      expect(vm.state.payableParties, 1);
      expect(vm.state.receivableTotals, hasLength(1));
      expect(vm.state.receivableTotals.first.currency.code, 'SAR');
      expect(vm.state.receivableTotals.first.total, 5000);
      expect(vm.state.payableTotals.first.currency.code, 'USD');
      expect(vm.state.payableTotals.first.total, 300);
      expect(vm.state.isEmpty, isFalse);

      // أسعار اليوم: 1 من 3 → ناقصة باثنتين.
      expect(vm.state.ratesEnteredToday, 1);
      expect(vm.state.ratesMissingCount, 2);
      expect(vm.state.ratesComplete, isFalse);
      vm.dispose();
    });
  });
}
