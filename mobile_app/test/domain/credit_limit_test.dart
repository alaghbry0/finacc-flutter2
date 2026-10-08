/// اختبارات محرك حد الائتمان النقي — FR-03-05 (17-c).
///
/// دلالات الحد الثلاثية (null/0/موجب) + سلوكا warn/block + حدّ المساواة
/// (المساواة بالحد ليست تجاوزاً — التجاوز strictly greater) + تقييم
/// الجزء الآجل حصراً في الدفع المختلط.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/domain/services/credit_limit.dart';

void main() {
  group('دلالة قيمة الحد', () {
    test('حد null (بلا حد): لا تنبيه أبداً مهما كبر الآجل', () {
      final d = evaluateCreditLimit(
        creditLimit: null,
        action: 'block',
        currentBalance: 100000,
        newDue: 50000,
      );
      expect(d.triggered, isFalse);
      expect(d.blocked, isFalse);
    });

    test('حد 0 (منع الآجل): أي دَين ناتج يُفعّل', () {
      final warn = evaluateCreditLimit(
        creditLimit: 0,
        action: 'warn',
        currentBalance: 0,
        newDue: 1,
      );
      expect(warn.triggered, isTrue);
      expect(warn.blocked, isFalse, reason: 'warn لا يمنع');

      final block = evaluateCreditLimit(
        creditLimit: 0,
        action: 'block',
        currentBalance: 0,
        newDue: 10,
      );
      expect(block.triggered, isTrue);
      expect(block.blocked, isTrue);

      // رصيد مسبق الدفع يمتص الآجل: 60− + 10 = 50− لا دَين ناتج
      // (متطابق مع صيغة المستودع checkCredit: -50 > 0 خطأ).
      final prepaid = evaluateCreditLimit(
        creditLimit: 0,
        action: 'block',
        currentBalance: -60,
        newDue: 10,
      );
      expect(prepaid.triggered, isFalse);
    });

    test('آجل صفري (نقدي محض): لا فحص أصلاً', () {
      final d = evaluateCreditLimit(
        creditLimit: 0,
        action: 'block',
        currentBalance: 500,
        newDue: 0,
      );
      expect(d.triggered, isFalse);
    });
  });

  group('حدّ التجاوز (قرار موثق: المساواة ليست تجاوزاً)', () {
    test('الرصيد + الآجل == الحد → غير مفعّل (عند الحد لا فوقه)', () {
      final d = evaluateCreditLimit(
        creditLimit: 100,
        action: 'block',
        currentBalance: 40,
        newDue: 60,
      );
      expect(d.triggered, isFalse);
    });

    test('الرصيد + الآجل > الحد → مفعّل', () {
      final d = evaluateCreditLimit(
        creditLimit: 100,
        action: 'warn',
        currentBalance: 40,
        newDue: 60.01,
      );
      expect(d.triggered, isTrue);
    });

    test('رصيد قائم فوق الحد مسبقاً + أي آجل → مفعّل', () {
      final d = evaluateCreditLimit(
        creditLimit: 100,
        action: 'warn',
        currentBalance: 150,
        newDue: 1,
      );
      expect(d.triggered, isTrue);
      expect(d.resultingBalance, 151);
    });

    test('رصيد سالب (دفع مقدماً) يمتص الآجل', () {
      final d = evaluateCreditLimit(
        creditLimit: 100,
        action: 'block',
        currentBalance: -80,
        newDue: 150,
      );
      expect(d.triggered, isFalse, reason: '−80 + 150 = 70 ≤ 100');
      expect(d.resultingBalance, 70);
    });
  });

  group('سلوك الإعداد parties.credit_limit_action', () {
    test('warn: مفعّل لكن غير مانع (متابعة على أي حال متاحة)', () {
      final d = evaluateCreditLimit(
        creditLimit: 100,
        action: 'warn',
        currentBalance: 90,
        newDue: 50,
      );
      expect(d.triggered, isTrue);
      expect(d.blocked, isFalse);
    });

    test('block: مفعّل ومانع', () {
      final d = evaluateCreditLimit(
        creditLimit: 100,
        action: 'block',
        currentBalance: 90,
        newDue: 50,
      );
      expect(d.triggered, isTrue);
      expect(d.blocked, isTrue);
    });

    test('قيمة غير معروفة تُعامل كالافتراضي warn', () {
      final d = evaluateCreditLimit(
        creditLimit: 100,
        action: 'قيمة-غريبة',
        currentBalance: 90,
        newDue: 50,
      );
      expect(d.triggered, isTrue);
      expect(d.blocked, isFalse);
    });
  });

  group('الدفع المختلط: الجزء الآجل حصراً', () {
    test('صافٍ 150 مدفوع 120 → يقيَّم بالـ30 لا بالـ150', () {
      // حد 100 ورصيد 60: تقييم الصافي كاملاً كان سيفعّل (60+150 > 100)؛
      // تقييم الجزء الآجل (المطابق لسلوك التطبيق) لا يفعّل (60+30 ≤ 100).
      final d = evaluateCreditLimit(
        creditLimit: 100,
        action: 'block',
        currentBalance: 60,
        newDue: 30,
      );
      expect(d.triggered, isFalse);
      expect(d.resultingBalance, 90);
    });
  });
}
