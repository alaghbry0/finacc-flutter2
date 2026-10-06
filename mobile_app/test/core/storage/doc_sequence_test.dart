/// اختبارات الترقيم الذرّي doc_sequence — المساران (UPSERT والاحتياطي).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/core/storage/doc_sequence.dart';

import '../../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  void runSuite(String label, {bool forceLegacy = false}) {
    group('مسار $label — ', () {
      late AppDatabase app;
      late DocSequenceService seq;

      setUp(() async {
        app = await openUniqueFileApp();
        seq = DocSequenceService(app.db, forceLegacyPath: forceLegacy);
      });

      tearDown(() async {
        await app.close();
      });

      test('أول رقم = 1 ثم تسلسل متصل 2،3،4', () async {
        expect(await seq.nextNumber(DocSequenceType.invoice, 2026), 1);
        expect(await seq.nextNumber(DocSequenceType.invoice, 2026), 2);
        expect(await seq.nextNumber(DocSequenceType.invoice, 2026), 3);
        expect(await seq.nextNumber(DocSequenceType.invoice, 2026), 4);
      });

      test('عدّادات مستقلة لكل نوع مستند ولكل سنة', () async {
        expect(await seq.nextNumber(DocSequenceType.invoice, 2026), 1);
        expect(await seq.nextNumber(DocSequenceType.purchase, 2026), 1);
        expect(await seq.nextNumber(DocSequenceType.invoice, 2027), 1);
        expect(await seq.nextNumber(DocSequenceType.invoice, 2026), 2);
        expect(await seq.nextNumber(DocSequenceType.purchase, 2026), 2);
        expect(await seq.lastIssuedNumber(DocSequenceType.invoice, 2027), 1);
      });

      test('lastIssuedNumber يقرأ دون استهلاك (0 عند البداية)', () async {
        expect(await seq.lastIssuedNumber(DocSequenceType.invoice, 2026), 0);
        await seq.nextNumber(DocSequenceType.invoice, 2026);
        await seq.nextNumber(DocSequenceType.invoice, 2026);
        expect(await seq.lastIssuedNumber(DocSequenceType.invoice, 2026), 2);
        expect(
          await seq.lastIssuedNumber(DocSequenceType.invoice, 2026),
          2,
          reason: 'القراءة لا تستهلك',
        );
      });

      test('setStartNumber: قبل أول إصدار فقط (FR-13-02)', () async {
        await seq.setStartNumber(DocSequenceType.invoice, 2026, 100);
        expect(await seq.nextNumber(DocSequenceType.invoice, 2026), 100);
        expect(
          () => seq.setStartNumber(DocSequenceType.invoice, 2026, 200),
          throwsA(isA<StateError>()),
          reason: 'تعديل رقم البداية بعد أول إصدار محرم دائماً',
        );
        expect(
          () => seq.setStartNumber(DocSequenceType.invoice, 2026, 0),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('ذرّية تحت 100 استدعاء متوازٍ — لا فجوات ولا ازدواج', () async {
        const count = 100;
        final results = await Future.wait(
          List.generate(
            count,
            (_) => seq.nextNumber(DocSequenceType.invoice, 2026),
          ),
        );
        final sorted = results.toList()..sort();
        expect(
          sorted,
          List.generate(count, (i) => i + 1),
          reason: 'الأرقام يجب أن تكون 1..100 بلا فجوات أو تكرار',
        );
      });

      test('الاستهلاك داخل معاملة المتصل يرث ذرّيتها', () async {
        // نفس النمط الملزم عند إصدار مستند حقيقي لاحقاً.
        final numbers = <int>[];
        await app.db.transaction((txn) async {
          final inner = DocSequenceService(txn, forceLegacyPath: forceLegacy);
          numbers.add(
            await inner.nextNumber(DocSequenceType.receiptVoucher, 2026),
          );
          numbers.add(
            await inner.nextNumber(DocSequenceType.receiptVoucher, 2026),
          );
        });
        expect(numbers, [1, 2]);
      });
    });
  }

  runSuite('UPSERT (SQLite ≥ 3.24)');
  runSuite('الاحتياطي (أندرويد 8/9)', forceLegacy: true);
}
