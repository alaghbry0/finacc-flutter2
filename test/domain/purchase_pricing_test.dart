/// اختبارات محرك تسعير الشراء النقي — FR-02-08 + قاعدة 5.4-3/5.4-9.
///
/// يغطي حرفياً: مثال SRS النصي (شراء 10 وحدات @100 بخصم رأس 10% →
/// التكلفة الفعلية 90 لا 100)، توزيع خصم الرأس pro-rata بنسبة وبمبلغ
/// (Σ الموزَّع = الخصم بالضبط)، استقرار القرش الأخير في آخر سطر موجب،
/// دمج خصم السطر مع خصم الرأس، ومنع الصافي ≤ 0، وتحقق الدفع
/// (نقدي/آجل/مختلط/زائد) وفصل الدفعة.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/domain/models/purchase.dart';
import 'package:mobile_app/domain/services/purchase_pricing.dart';

void main() {
  PurchaseLine line(
    int productId,
    double qty,
    double unitCost, {
    PurchaseDiscountType type = PurchaseDiscountType.amount,
    double discount = 0,
    String? batchNo,
    DateTime? expiry,
  }) => PurchaseLine(
    productId: productId,
    qty: qty,
    unitCost: unitCost,
    lineDiscountType: type,
    lineDiscountValue: discount,
    batchNo: batchNo,
    expiryDate: expiry,
  );

  group('validateCart', () {
    test('سلة فارغة → خطأ', () {
      expect(PurchasePricing.validateCart([]), contains('بنداً واحداً'));
    });

    test('كمية ≤ 0 → خطأ يسمّي البند', () {
      expect(
        PurchasePricing.validateCart([line(1, 0, 50)]),
        contains('يجب أن تكون أكبر من صفر'),
      );
      expect(
        PurchasePricing.validateCart([line(1, -2, 50)]),
        contains('أكبر من صفر'),
      );
    });

    test('تكلفة سالبة → خطأ', () {
      expect(
        PurchasePricing.validateCart([line(1, 1, -5)]),
        contains('سالباً'),
      );
    });

    test('خصم سطر أكبر من قيمته → خطأ', () {
      expect(
        PurchasePricing.validateCart([line(1, 2, 100, discount: 500)]),
        contains('أكبر من قيمة البند'),
      );
    });

    test('نسبة خصم سطر/رأس فوق 100% → خطأ', () {
      expect(
        PurchasePricing.validateCart([
          line(1, 1, 100, type: PurchaseDiscountType.percent, discount: 150),
        ]),
        contains('تتجاوز 100%'),
      );
      expect(
        PurchasePricing.validateCart(
          [line(1, 1, 100)],
          invoiceDiscountType: PurchaseDiscountType.percent,
          invoiceDiscountValue: 120,
        ),
        contains('تتجاوز 100%'),
      );
    });

    test('الخصومات تجعل الصافي صفراً → خطأ (FR-02-05)', () {
      expect(
        PurchasePricing.validateCart([
          line(1, 1, 100),
        ], invoiceDiscountValue: 100),
        contains('صفراً أو سالباً'),
      );
    });

    test('رقم دفعة بلا تاريخ صلاحية → خطأ (عمود expiry NOT NULL)', () {
      expect(
        PurchasePricing.validateCart([line(1, 1, 100, batchNo: 'B-1')]),
        contains('تاريخ الصلاحية'),
      );
      expect(
        PurchasePricing.validateCart([
          line(1, 1, 100, batchNo: 'B-1', expiry: DateTime(2027, 1, 1)),
        ]),
        isNull,
      );
    });
  });

  group('priceCart — مثال SRS الحرفي (قاعدة 5.4-3)', () {
    test('شراء 10 وحدات @100 بخصم رأس 10% → التكلفة الفعلية 90 لا 100', () {
      final priced = PurchasePricing.priceCart(
        [line(1, 10, 100)],
        invoiceDiscountType: PurchaseDiscountType.percent,
        invoiceDiscountValue: 10,
      );
      expect(priced.totals.subtotal, 1000);
      expect(priced.totals.invoiceDiscount, 100);
      expect(priced.totals.grandTotal, 900);
      final only = priced.lines.single;
      expect(only.gross, 1000);
      expect(only.netFinal, 900);
      // التكلفة الفعلية للوحدة — التي تدخل WAC (بعد تحويلها للأساس):
      expect(only.unitCostEffective, 90);
      expect(only.effectiveDiscount, 100);
    });

    test('خصم رأس بمبلغ ثابت يعطي نفس النتيجة النسبية', () {
      final priced = PurchasePricing.priceCart(
        [line(1, 10, 100)],
        invoiceDiscountValue: 100, // مبلغ = 10% هنا.
      );
      expect(priced.lines.single.unitCostEffective, 90);
      expect(priced.totals.grandTotal, 900);
    });
  });

  group('توزيع خصم الرأس pro-rata (قاعدة 5.4-3)', () {
    test('بمبلغ: 60/40 على سطرين قيمتهما 600 و400 — Σ الموزَّع = 100', () {
      final priced = PurchasePricing.priceCart([
        line(1, 6, 100),
        line(2, 4, 100),
      ], invoiceDiscountValue: 100);
      expect(priced.lines[0].invoiceDiscountAllocated, 60);
      expect(priced.lines[1].invoiceDiscountAllocated, 40);
      expect(
        priced.lines.fold<double>(
          0,
          (sum, l) => sum + l.invoiceDiscountAllocated,
        ),
        100, // بالضبط — لا انزياح سنت.
      );
      expect(priced.totals.grandTotal, 900);
      // التكلفة الفعلية لكل وحدة بعد التوزيع:
      expect(priced.lines[0].unitCostEffective, 90); // (600−60)/6.
      expect(priced.lines[1].unitCostEffective, 90); // (400−40)/4.
    });

    test('بنسبة 10%: نفس التوزيع النسبي', () {
      final priced = PurchasePricing.priceCart(
        [line(1, 6, 100), line(2, 4, 100)],
        invoiceDiscountType: PurchaseDiscountType.percent,
        invoiceDiscountValue: 10,
      );
      expect(priced.lines[0].invoiceDiscountAllocated, 60);
      expect(priced.lines[1].invoiceDiscountAllocated, 40);
      expect(priced.totals.grandTotal, 900);
    });

    test('توزيع غير قابل للقسمة: القرش الأخير يستقر في آخر سطر موجب', () {
      // ثلاثة أسطر 333/333/334 ومجموعها 1000 وخصم 100 → حصص 33.3/33.3
      // والباقي 33.4 لآخر سطر.
      final priced = PurchasePricing.priceCart([
        line(1, 333, 1),
        line(2, 333, 1),
        line(3, 334, 1),
      ], invoiceDiscountValue: 100);
      expect(priced.lines[0].invoiceDiscountAllocated, 33.3);
      expect(priced.lines[1].invoiceDiscountAllocated, 33.3);
      expect(priced.lines[2].invoiceDiscountAllocated, 33.4);
      expect(
        priced.lines.fold<double>(
          0,
          (sum, l) => sum + l.invoiceDiscountAllocated,
        ),
        100,
      );
      // Σ(line_total) = الصافي الكلي بالضبط.
      expect(
        priced.lines.fold<double>(0, (sum, l) => sum + l.netFinal),
        priced.totals.grandTotal,
      );
      expect(priced.totals.grandTotal, 900);
    });

    test('خصم يطابق صافي الأسطر كاملاً → كل سطر يصفر', () {
      final priced = PurchasePricing.priceCart([
        line(1, 1, 600),
        line(2, 1, 400),
      ], invoiceDiscountValue: 1000);
      expect(priced.totals.grandTotal, 0);
      expect(priced.lines[0].invoiceDiscountAllocated, 600);
      expect(priced.lines[1].invoiceDiscountAllocated, 400);
      expect(priced.lines[0].unitCostEffective, 0);
    });
  });

  group('دمج خصم السطر مع خصم الرأس', () {
    test('خصم سطر نسبة + خصم رأس مبلغ — التوزيع على الصافي بعد خصم السطر', () {
      // السطر أ: 10×100 بخصم سطر 10% → صافي 900؛ السطر ب: 5×100 → 500.
      // خصم رأس 200 → أ: 200×900/1400 = 128.57، ب: 71.43 (القرش الأخير
      // يستقر في آخر سطر موجب: 200 − 128.57 = 71.43).
      final priced = PurchasePricing.priceCart([
        line(1, 10, 100, type: PurchaseDiscountType.percent, discount: 10),
        line(2, 5, 100),
      ], invoiceDiscountValue: 200);
      expect(priced.totals.subtotal, 1500);
      expect(priced.totals.lineDiscountsTotal, 100);
      expect(priced.lines[0].netAfterLineDiscount, 900);
      expect(priced.lines[0].invoiceDiscountAllocated, 128.57);
      expect(priced.lines[1].invoiceDiscountAllocated, 71.43);
      expect(priced.lines[0].netFinal, 771.43);
      expect(priced.lines[1].netFinal, 428.57);
      expect(priced.totals.grandTotal, 1200);
      // تكلفة الوحدة الفعلية:
      expect(priced.lines[0].unitCostEffective, 77.143); // 771.43/10.
      expect(priced.lines[1].unitCostEffective, 85.714); // 428.57/5.
      // Σ(discount) + Σ(line_total) = subtotal بالضبط:
      expect(
        priced.lines.fold<double>(0, (s, l) => s + l.effectiveDiscount) +
            priced.totals.grandTotal,
        1500,
      );
    });
  });

  group('validatePayment / settlePayment (FR-02-03 باتجاه الشراء)', () {
    test('نقدي كامل/آجل/مختلط تُقبل عند التطابق', () {
      expect(
        PurchasePricing.validatePayment(1000, 1000, PurchasePaymentMethod.cash),
        isNull,
      );
      expect(
        PurchasePricing.validatePayment(1000, 0, PurchasePaymentMethod.credit),
        isNull,
      );
      expect(
        PurchasePricing.validatePayment(1000, 400, PurchasePaymentMethod.mixed),
        isNull,
      );
    });

    test('الدفع الزائد فوق الصافي مرفوض — لا «باقٍ» في الشراء', () {
      final error = PurchasePricing.validatePayment(
        1000,
        1200,
        PurchasePaymentMethod.cash,
      );
      expect(error, contains('يتجاوز صافي الفاتورة'));
      expect(error, contains('اترك الباقي آجلاً'));
    });

    test('تعارض التعلان مع الأرقام → رسالة تسمّي المطلوب', () {
      expect(
        PurchasePricing.validatePayment(1000, 400, PurchasePaymentMethod.cash),
        contains('تسديد الصافي كاملاً'),
      );
      expect(
        PurchasePricing.validatePayment(
          1000,
          400,
          PurchasePaymentMethod.credit,
        ),
        contains('عدم إدخال أي مبلغ نقدي'),
      );
      expect(
        PurchasePricing.validatePayment(
          1000,
          1000,
          PurchasePaymentMethod.mixed,
        ),
        contains('بين صفر والصافي'),
      );
    });

    test('settlePayment يفصل المدفوع من الآجل', () {
      final full = PurchasePricing.settlePayment(1000, 1000);
      expect(full.netPaid, 1000);
      expect(full.remainingCredit, 0);
      expect(full.payStatus, PurchasePaymentMethod.cash);

      final none = PurchasePricing.settlePayment(1000, 0);
      expect(none.netPaid, 0);
      expect(none.remainingCredit, 1000);
      expect(none.payStatus, PurchasePaymentMethod.credit);

      final mixed = PurchasePricing.settlePayment(1000, 350.5);
      expect(mixed.netPaid, 350.5);
      expect(mixed.remainingCredit, 649.5);
      expect(mixed.payStatus, PurchasePaymentMethod.mixed);
    });
  });

  group('التقريب (قاعدة 5.4-9)', () {
    test('roundMoney منزلتان و roundCost أربع منازل (النصف بعيداً)', () {
      expect(roundMoney(10.005), 10.01);
      expect(roundMoney(10.004), 10.0);
      expect(roundCost(90.00005), 90.0001);
      expect(roundCost(90.00004), 90.0);
      expect(roundCost(106.666666), 106.6667);
    });

    test('كمية غير قابلة للقسمة: unitCostEffective بأربع منازل', () {
      // gross = round2(3 × 33.3333) = 100 → التكلفة الفعلية 100/3.
      final priced = PurchasePricing.priceCart([line(1, 3, 33.3333)]);
      expect(priced.lines.single.netFinal, 100);
      expect(priced.lines.single.unitCostEffective, 33.3333);
    });
  });
}
