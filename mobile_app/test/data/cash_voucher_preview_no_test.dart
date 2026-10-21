/// اختبارات معاينة رقم السند القادم (V6-A) — `previewNextVoucherNo`.
///
/// قراءة بلا استهلاك بنمط `previewSaleInvoiceNo`: قاعدة FFI عبر مصنع
/// الاختبارات القياسي (قاعدة فريدة لكل اختبار + تأسيس جاهز) —
/// فراغ → RVT-2026-00001، التقدم بعد الترحيل، استقلال السنتين
/// واستقلال RVT عن PMT، عدم الاستهلاك، والسنة من `txDate` لا `now`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/cash_repository.dart';
import 'package:mobile_app/data/repositories/customer_repository.dart';
import 'package:mobile_app/data/repositories/supplier_repository.dart';
import 'package:mobile_app/domain/models/cash.dart';
import 'package:mobile_app/domain/models/party.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase handle;
  late CashRepository cash;
  late int customerId;
  late int supplierId;
  late int cashboxId;
  late int baseCurrencyId;
  late int userId;
  final at = DateTime.utc(2026, 10, 6, 12);

  setUp(() async {
    final seeded = await openSeededApp();
    handle = seeded.$1;
    cash = CashRepository(handle.db);
    final customers = CustomerRepository(handle.db);
    final suppliers = SupplierRepository(handle.db);
    userId =
        (await handle.db.rawQuery('SELECT id FROM app_user LIMIT 1'))
                .first['id']
            as int;
    baseCurrencyId =
        (await handle.db.rawQuery('SELECT id FROM currency WHERE is_base = 1'))
                .first['id']
            as int;
    cashboxId =
        (await handle.db.rawQuery(
              'SELECT id FROM cashbox WHERE is_default = 1',
            )).first['id']
            as int;
    final customer = await customers.createCustomer(
      const CustomerDraft(name: 'عميل معاينة السندات'),
      userId: userId,
      now: at,
    );
    customerId = customer.valueOrNull!;
    final supplier = await suppliers.createSupplier(
      const SupplierDraft(name: 'مورد معاينة السندات'),
      userId: userId,
      now: at,
    );
    supplierId = supplier.valueOrNull!;
  });

  tearDown(() async {
    await handle.close();
  });

  // سند قبض حر (على الحساب) — لا يتطلب فواتير مفتوحة.
  Future<String> postReceipt({DateTime? txDate}) async {
    final result = await cash.createVoucher(
      VoucherDraft(
        partyType: VoucherPartyType.customer,
        partyId: customerId,
        cashboxId: cashboxId,
        amount: 250,
        currencyId: baseCurrencyId,
        txDate: txDate ?? at,
        allocateFifo: false,
      ),
      userId: userId,
      now: at,
    );
    expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
    return result.valueOrNull!.voucherNo;
  }

  // سند صرف حر (على الحساب) لمورد.
  Future<String> postPayment({DateTime? txDate}) async {
    final result = await cash.createVoucher(
      VoucherDraft(
        partyType: VoucherPartyType.supplier,
        partyId: supplierId,
        cashboxId: cashboxId,
        amount: 120,
        currencyId: baseCurrencyId,
        txDate: txDate ?? at,
        allocateFifo: false,
      ),
      userId: userId,
      now: at,
    );
    expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
    return result.valueOrNull!.voucherNo;
  }

  test('قاعدة فراغ: أول قبض RVT-2026-00001 وأول صرف PMT-2026-00001', () async {
    expect(
      await cash.previewNextVoucherNo(isReceipt: true, year: 2026),
      'RVT-2026-00001',
    );
    expect(
      await cash.previewNextVoucherNo(isReceipt: false, year: 2026),
      'PMT-2026-00001',
    );
  });

  test('بعد ترحيل سند قبض واحد تتقدم المعاينة إلى 00002', () async {
    expect(await postReceipt(), 'RVT-2026-00001');
    expect(
      await cash.previewNextVoucherNo(isReceipt: true, year: 2026),
      'RVT-2026-00002',
    );
  });

  test('سنتان مستقلتان: عدّان منفصلان لا يتقاسان التقدم', () async {
    expect(
      await cash.previewNextVoucherNo(isReceipt: true, year: 2025),
      'RVT-2025-00001',
    );
    // ترحيل سند واحد بتاريخ 2025 يستهلك تسلسل 2025 وحده.
    expect(
      await postReceipt(txDate: DateTime.utc(2025, 3, 9)),
      'RVT-2025-00001',
    );
    expect(
      await cash.previewNextVoucherNo(isReceipt: true, year: 2025),
      'RVT-2025-00002',
    );
    expect(
      await cash.previewNextVoucherNo(isReceipt: true, year: 2026),
      'RVT-2026-00001',
    );
  });

  test('RVT وPMT تسلسلان مستقلان تماماً', () async {
    expect(await postReceipt(), 'RVT-2026-00001');
    // القبض تقدّم تسلسل RVT وحده — الصرف لم يُصدر بعد.
    expect(
      await cash.previewNextVoucherNo(isReceipt: true, year: 2026),
      'RVT-2026-00002',
    );
    expect(
      await cash.previewNextVoucherNo(isReceipt: false, year: 2026),
      'PMT-2026-00001',
    );
    expect(await postPayment(), 'PMT-2026-00001');
    expect(
      await cash.previewNextVoucherNo(isReceipt: false, year: 2026),
      'PMT-2026-00002',
    );
    expect(
      await cash.previewNextVoucherNo(isReceipt: true, year: 2026),
      'RVT-2026-00002',
    );
  });

  test(
    'قراءتان متتاليتان نفس القيمة (لا استهلاك) والترحيل التالي يلتقطها',
    () async {
      final first = await cash.previewNextVoucherNo(
        isReceipt: true,
        year: 2026,
      );
      final second = await cash.previewNextVoucherNo(
        isReceipt: true,
        year: 2026,
      );
      expect(second, first);
      expect(first, 'RVT-2026-00001');
      // المعاينة لم تستهلك: أول سند حقيقي يأخذ الرقم المعروض نفسه.
      expect(await postReceipt(), first);
    },
  );

  test(
    'السنة من txDate لا من now: سند بتاريخ 2027 يستهلك تسلسل 2027 وحده',
    () async {
      // ترحيل بسند مؤرخ في المستقبل (2027) بينما now = 2026-10-06.
      final voucherNo = await postReceipt(txDate: DateTime.utc(2027, 6, 15));
      expect(voucherNo, 'RVT-2027-00001');
      expect(
        await cash.previewNextVoucherNo(isReceipt: true, year: 2027),
        'RVT-2027-00002',
      );
      // سنة اليوم (من now) لم تُستهلك بشيء.
      expect(
        await cash.previewNextVoucherNo(isReceipt: true, year: 2026),
        'RVT-2026-00001',
      );
    },
  );
}
