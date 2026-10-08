/// اختبارات مستودع الوردية (FR-04-04): المعادلة الشاملة (كل نوع في
/// دلائه الصحيح بعملة الصندوق + تحويل settlement) وحدود النافذة
/// والاستبعادات (ملغى/معاكس/افتتاحي) ودورة الفتح/الإقفال والحراس
/// وترتيب السجل.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/shift_repository.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase app;
  late ShiftRepository repo;
  late int mainBox;
  late int bankBox;
  late int usdBox;

  setUp(() async {
    app = await openUniqueFileApp();
    repo = ShiftRepository(app.db);

    // العملات مبذورة بالهجرات: YER=1 (أساس)، SAR=2، USD=3، AED=4.

    // الصناديق: رئيسي (YER) + «بنك» مسمى بنكاً (YER) + صندوق دولار.
    // حارس صدفة المعرفات: صندوق بذر أولاً بعملة مخالفة حتى **يختلف
    // معرّف الصندوق الرئيسي عن معرّف عملته** — فلتر دلو عملة الصندوق في
    // المعادلة يقرأ currency_id من صف الصندوق، لا معرّف الصندوق (صناديق
    // بأرقام كبيرة في الإنتاج لا تتطابق أبداً مع أرقام عملاتها).
    await app.db.insert('cashbox', {
      'name': 'صندوق بذر الترقيم',
      'currency_id': 3,
      'is_default': 0,
    });
    mainBox = await app.db.insert('cashbox', {
      'name': 'الصندوق الرئيسي',
      'currency_id': 1,
      'is_default': 1,
    });
    bankBox = await app.db.insert('cashbox', {
      'name': 'بنك الكريمي',
      'currency_id': 1,
      'is_default': 0,
    });
    usdBox = await app.db.insert('cashbox', {
      'name': 'درج الدولار',
      'currency_id': 3,
      'is_default': 0,
    });

    // طرف وفواتير مستندية بأنواعها (للتمييز مبيعات نقدية/استردادات).
    await app.db.insert('app_user', {
      'username': 'admin',
      'display_name': 'أبو نور',
      'role': 'admin',
    });
    await app.db.insert('customer', {'name': 'عميل تجريبي'});
    await app.db.insert('supplier', {'name': 'مورد تجريبي'});
    await app.db.insert('warehouse', {'name': 'المخزن', 'is_default': 1});
    await app.db.insert('invoice', {
      'invoice_no': 'INV-2026-000001',
      'doc_type': 'sale',
      'pay_status': 'cash',
      'issued_at': '2026-10-06T10:00:00.000Z',
      'warehouse_id': 1,
      'currency_id': 1,
      'exchange_rate': 1,
      'total': 500,
    });
    await app.db.insert('invoice', {
      'invoice_no': 'PRN-2026-000001',
      'doc_type': 'purchase_return',
      'pay_status': 'cash',
      'issued_at': '2026-10-06T15:00:00.000Z',
      'warehouse_id': 1,
      'currency_id': 1,
      'exchange_rate': 1,
      'total': 120,
    });
    await app.db.insert('invoice', {
      'invoice_no': 'SRN-2026-000001',
      'doc_type': 'sale_return',
      'pay_status': 'cash',
      'issued_at': '2026-10-06T15:15:00.000Z',
      'warehouse_id': 1,
      'currency_id': 1,
      'exchange_rate': 1,
      'total': 60,
    });
  });

  tearDown(() async {
    await app.close();
  });

  /// إدخال حركة نقدية مباشرة بأقل حقول إلزامية.
  Future<void> tx(
    Map<String, Object?> overrides, {
    String at = '2026-10-06T12:00:00.000Z',
  }) async {
    await app.db.insert('cash_tx', {
      'cashbox_id': mainBox,
      'currency_id': 1,
      'amount': 100,
      'exchange_rate': 1,
      'tx_date': at,
      ...overrides,
    });
  }

  test('المعادلة الشاملة: كل نوع في دلائه بعملة الصندوق حصراً', () async {
    const from = '2026-10-06T08:00:00.000Z';
    const to = '2026-10-06T20:00:00.000Z';

    // مبيعات نقدية: سند قبض مرتبط بفاتورة بيع وقت الإصدار.
    await tx({
      'tx_type': 'receipt',
      'amount': 500,
      'ref_type': 'invoice',
      'ref_id': 1,
      'customer_id': null,
    }, at: '2026-10-06T10:00:00.000Z');

    // تحصيلات: سند FIFO (ref_id فارغ) + حر on_account.
    await tx({
      'tx_type': 'receipt',
      'amount': 300,
      'ref_type': 'invoice',
      'ref_id': null,
      'customer_id': null,
    }, at: '2026-10-06T10:30:00.000Z');
    await tx({
      'tx_type': 'receipt',
      'amount': 200,
      'ref_type': 'on_account',
      'customer_id': 1,
    }, at: '2026-10-06T11:00:00.000Z');

    // سند دولار بعملة مخالفة → يُحوَّل بمبلغ settlement بعملة الصندوق.
    await tx({
      'tx_type': 'receipt',
      'amount': 10,
      'currency_id': 3,
      'exchange_rate': 520,
      'settlement_rate': 520,
      'ref_type': 'on_account',
      'customer_id': 1,
    }, at: '2026-10-06T16:30:00.000Z');

    // سند دولار بلا settlement → دلو أجنبي — خارج معادلة عملة الصندوق.
    await tx({
      'tx_type': 'receipt',
      'amount': 50,
      'currency_id': 3,
      'exchange_rate': 520,
      'ref_type': 'on_account',
      'customer_id': 1,
    }, at: '2026-10-06T16:45:00.000Z');

    // إيداع مالك + مدفوعات مورد (FIFO وحر) + مصروف + مسحوبات.
    await tx({
      'tx_type': 'capital_in',
      'amount': 1000,
    }, at: '2026-10-06T11:30:00.000Z');
    await tx({
      'tx_type': 'payment',
      'amount': 400,
      'ref_type': 'invoice',
      'ref_id': null,
      'supplier_id': null,
    }, at: '2026-10-06T12:00:00.000Z');
    await tx({
      'tx_type': 'payment',
      'amount': 250,
      'ref_type': 'on_account',
      'supplier_id': 1,
    }, at: '2026-10-06T12:15:00.000Z');
    await tx({
      'tx_type': 'expense',
      'amount': 150,
    }, at: '2026-10-06T12:30:00.000Z');
    await tx({
      'tx_type': 'owner_draw',
      'amount': 90,
    }, at: '2026-10-06T13:00:00.000Z');

    // تحويل صادر (ساق المصدر بعملة المصدر).
    await tx({
      'tx_type': 'box_transfer',
      'amount': 220,
      'to_cashbox_id': bankBox,
      'ref_type': 'transfer',
    }, at: '2026-10-06T13:30:00.000Z');

    // تحويل وارد من صندوق دولار → المبلغ المحوّل بعملة الهدف.
    await app.db.insert('cash_tx', {
      'tx_type': 'box_transfer',
      'cashbox_id': usdBox,
      'to_cashbox_id': mainBox,
      'currency_id': 3,
      'amount': 100,
      'exchange_rate': 520,
      'settlement_rate': 520,
      'tx_date': '2026-10-06T14:00:00.000Z',
      'ref_type': 'transfer',
    });

    // إيداع بنكي (البنك مجرد صندوق — يُدمج في التحويلات الصادرة).
    await tx({
      'tx_type': 'bank_deposit',
      'amount': 300,
      'to_cashbox_id': bankBox,
      'ref_type': 'transfer',
    }, at: '2026-10-06T14:30:00.000Z');

    // استرداد مرتجع شراء نقدي (قبض مرتبط بمستند purchase_return) وردّ
    // مرتجع بيع نقدي (صرف مرتبط بـ sale_return) — دلو «أخرى» الموقعي.
    await tx({
      'tx_type': 'receipt',
      'amount': 120,
      'ref_type': 'invoice',
      'ref_id': 2,
      'customer_id': null,
    }, at: '2026-10-06T15:00:00.000Z');
    await tx({
      'tx_type': 'payment',
      'amount': 60,
      'ref_type': 'invoice',
      'ref_id': 3,
      'customer_id': null,
    }, at: '2026-10-06T15:15:00.000Z');

    // أنواع رواتب مؤجلة — دلو «أخرى» (سالب).
    await tx({
      'tx_type': 'salary_batch',
      'amount': 700,
    }, at: '2026-10-06T16:00:00.000Z');
    await tx({
      'tx_type': 'employee_advance',
      'amount': 50,
    }, at: '2026-10-06T16:10:00.000Z');

    // مستبعدات: افتتاحي + ملغى + ثنائي معاكس — كلها خارج المعادلة.
    await tx({
      'tx_type': 'opening',
      'amount': 5000,
    }, at: '2026-10-06T09:00:00.000Z');
    await tx({
      'tx_type': 'receipt',
      'amount': 600,
      'is_voided': 1,
    }, at: '2026-10-06T15:45:00.000Z');
    // ثنائي معاكس (FR-04-08): الأصل is_voided=1 + المعاكسة reversal_of —
    // كلاهما مستبعد (أثر الثنائي صفر).
    final original = await app.db.insert('cash_tx', {
      'tx_type': 'receipt',
      'cashbox_id': mainBox,
      'currency_id': 1,
      'amount': 800,
      'exchange_rate': 1,
      'tx_date': '2026-10-06T15:30:00.000Z',
      'is_voided': 1,
    });
    await app.db.insert('cash_tx', {
      'tx_type': 'payment',
      'cashbox_id': mainBox,
      'currency_id': 1,
      'amount': 800,
      'exchange_rate': 1,
      'tx_date': '2026-10-06T15:31:00.000Z',
      'reversal_of': original,
    });

    final eq = await repo.equationFor(
      cashboxId: mainBox,
      fromIso: from,
      toIso: to,
    );

    expect(eq.cashSales, 500, reason: 'مبيعات نقدية');
    expect(eq.collections, 5700, reason: 'تحصيلات 300+200+5200 (USD محوَّل)');
    expect(eq.ownerDeposits, 1000, reason: 'إيداعات مالك');
    expect(eq.transfersIn, 52000, reason: 'تحويل وارد محوَّل 100×520');
    expect(eq.transfersOut, 520, reason: 'تحويل صادر 220 + إيداع بنكي 300');
    expect(eq.supplierPayments, 650, reason: 'مدفوعات موردين 400+250');
    expect(eq.expenses, 150, reason: 'مصاريف');
    expect(eq.ownerDraws, 90, reason: 'مسحوبات مالك');
    expect(eq.other, -690, reason: 'أخرى: +120−60−700−50');
    expect(eq.bankIn, 0, reason: 'بنكي مدمج في الوارد (لا عمود بنك)');
    expect(eq.bankOut, 0, reason: 'بنكي مدمج في الصادر');
    expect(eq.chequesCleared, 0, reason: 'الشيكات مؤجلة V1.1');
    expect(eq.chequesPaid, 0, reason: 'الشيكات مؤجلة V1.1');
    expect(eq.totalIn, 59200);
    expect(eq.totalOut, 1410);
    expect(eq.expectedDelta, 57100, reason: 'Σ وارد − Σ صادر + أخرى');
  });

  test(
    'حدود النافذة: الداخل محسوب والخارج مستبعد (مقارنة ISO حرفية)',
    () async {
      const from = '2026-10-06T08:00:00.000Z';
      const to = '2026-10-06T20:00:00.000Z';
      Future<void> at(String iso, double amount) => tx({
        'tx_type': 'receipt',
        'amount': amount,
        'ref_type': 'on_account',
        'customer_id': 1,
      }, at: iso);

      await at('2026-10-06T08:00:00.000Z', 110); // حد البداية — داخل.
      await at('2026-10-06T20:00:00.000Z', 220); // حد النهاية — داخل.
      await at('2026-10-06T07:59:59.999Z', 30); // قبله — خارج.
      await at('2026-10-06T20:00:00.001Z', 440); // بعده — خارج.

      final eq = await repo.equationFor(
        cashboxId: mainBox,
        fromIso: from,
        toIso: to,
      );
      expect(eq.collections, 330, reason: '110 + 220 فقط — الحدود مغلقة');
      expect(eq.totalIn, 330);
      expect(eq.expectedDelta, 330);
    },
  );

  test('دورة الحياة: فتح ← معادلة حية ← إقفال يسجّل المتوقع والفرق', () async {
    final opened = await repo.openShift(
      cashboxId: mainBox,
      openingCount: 2000,
      userId: 1,
    );
    expect(opened.isOk, isTrue, reason: 'فتح الوردية ينجح');
    final row = opened.valueOrNull!;
    expect(row.openingCount, 2000);
    expect(row.isOpen, isTrue);

    final current = await repo.currentShift(mainBox);
    expect(current?.id, row.id, reason: 'currentShift يعيد المفتوحة');

    // حركتان بعد الفتح (داخل نافذة [opened_at, now]).
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await tx({
      'tx_type': 'receipt',
      'amount': 500,
      'ref_type': 'on_account',
      'customer_id': 1,
      'tx_date': nowIso,
    });
    await tx({'tx_type': 'expense', 'amount': 200, 'tx_date': nowIso});

    final closed = await repo.closeShift(
      shiftId: row.id,
      counted: 2250,
      notes: '  عجز بسيط  ',
    );
    expect(closed.isOk, isTrue, reason: 'الإقفال ينجح');
    final result = closed.valueOrNull!;
    expect(result.shift.openingCount, 2000);
    expect(result.shift.expected, 2300, reason: '2000 + 500 − 200');
    expect(result.shift.counted, 2250);
    expect(result.shift.difference, -50, reason: 'المعدود − المتوقع = عجز');
    expect(result.shift.notes, 'عجز بسيط', reason: 'تقليم الفراغات');
    expect(result.equation.collections, 500);
    expect(result.equation.expenses, 200);
    expect(result.shift.isOpen, isFalse);

    final persisted = await repo.shiftById(row.id);
    expect(persisted?.expected, 2300);
    expect(persisted?.difference, -50);
    expect(persisted?.closedAt, isNotNull);

    expect(
      await repo.currentShift(mainBox),
      isNull,
      reason: 'لا وردية مفتوحة بعد الإقفال',
    );
  });

  test(
    'الحراس: لا فتح مزدوج على الصندوق + إقفال المجهول/المقفلة مرفوض',
    () async {
      final first = await repo.openShift(cashboxId: mainBox);
      expect(first.isOk, isTrue);

      final second = await repo.openShift(cashboxId: mainBox);
      expect(second.isErr, isTrue, reason: 'حارس الرفض للفتح المزدوج');
      expect(second.errorOrNull, contains('مفتوحة'));

      // صندوق آخر يجوز أن تفتح عليه وردية بالتوازي.
      final other = await repo.openShift(cashboxId: bankBox);
      expect(other.isOk, isTrue, reason: 'الحارس لكل صندوق على حدة');

      expect(
        (await repo.closeShift(shiftId: 999, counted: 0)).isErr,
        isTrue,
        reason: 'وردية غير موجودة',
      );

      final closed = await repo.closeShift(
        shiftId: first.valueOrNull!.id,
        counted: 0,
      );
      expect(closed.isOk, isTrue);
      final again = await repo.closeShift(
        shiftId: first.valueOrNull!.id,
        counted: 0,
      );
      expect(again.isErr, isTrue, reason: 'لا إقفال مرتين');
      expect(again.errorOrNull, contains('مقفلة'));
    },
  );

  test('recentShifts: المقفلات فقط وبالأحدث أولاً', () async {
    Future<int> closeOne() async {
      final opened = await repo.openShift(cashboxId: mainBox, openingCount: 0);
      final id = opened.valueOrNull!.id;
      final closed = await repo.closeShift(shiftId: id, counted: 0);
      expect(closed.isOk, isTrue);
      return id;
    }

    final older = await closeOne();
    final newer = await closeOne();
    // وردية مفتوحة لا تظهر في السجل.
    await repo.openShift(cashboxId: mainBox);

    final rows = await repo.recentShifts(cashboxId: mainBox);
    expect(rows.map((r) => r.id).toList(), [newer, older]);
    expect(rows.every((r) => !r.isOpen), isTrue);
  });
}
