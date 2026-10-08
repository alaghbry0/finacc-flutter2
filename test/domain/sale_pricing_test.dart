/// اختبارات محرك التسعير النقي — FR-02-05 / قاعدة 5.4-3 / 5.4-9:
/// خصومات الأسطر (نسبة/مبلغ)، توزيع خصم الرأس pro-rata بتقريب القرش،
/// والتحقق الكامل لقواعد الدفع (نقدي/آجل/مختلط والباقي).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/domain/models/sale.dart';
import 'package:mobile_app/domain/services/sale_pricing.dart';

CartLine line(
  int productId,
  double qty,
  double price, {
  SaleDiscountType type = SaleDiscountType.amount,
  double discount = 0,
}) => CartLine(
  productId: productId,
  qty: qty,
  unitPrice: price,
  lineDiscountType: type,
  lineDiscountValue: discount,
);

void main() {
  group('تسعير الأسطر — بلا خصومات', () {
    test('سطر واحد بلا خصم: gross = net = subtotal', () {
      final cart = SalePricing.priceCart([line(1, 3, 250)]);
      expect(cart.lines.single.gross, 750);
      expect(cart.lines.single.lineDiscountAmount, 0);
      expect(cart.lines.single.netFinal, 750);
      expect(cart.totals.subtotal, 750);
      expect(cart.totals.grandTotal, 750);
      expect(cart.totals.itemsCount, 1);
    });

    test('كمية كسرية: 1.5 × 33.34 = 50.01 (تقريب القرش)', () {
      final cart = SalePricing.priceCart([line(1, 1.5, 33.34)]);
      expect(cart.lines.single.gross, 50.01);
      expect(cart.totals.grandTotal, 50.01);
    });
  });

  group('خصومات الأسطر', () {
    test('خصم نسبة 10%: 4×100 → خصم 40 وصافي 360', () {
      final cart = SalePricing.priceCart([
        line(1, 4, 100, type: SaleDiscountType.percent, discount: 10),
      ]);
      expect(cart.lines.single.lineDiscountAmount, 40);
      expect(cart.lines.single.netFinal, 360);
      expect(cart.totals.lineDiscountsTotal, 40);
      expect(cart.totals.grandTotal, 360);
    });

    test('خصم مبلغ 50: 2×125 → صافي 200', () {
      final cart = SalePricing.priceCart([
        line(1, 2, 125, type: SaleDiscountType.amount, discount: 50),
      ]);
      expect(cart.lines.single.lineDiscountAmount, 50);
      expect(cart.lines.single.netFinal, 200);
    });

    test('خصم نسبة يقرَّب للقرش: 3×33.34 بـ 5% = 5.00', () {
      final cart = SalePricing.priceCart([
        line(1, 3, 33.34, type: SaleDiscountType.percent, discount: 5),
      ]);
      // gross = 100.02؛ 5% = 5.0001 → 5.00
      expect(cart.lines.single.gross, 100.02);
      expect(cart.lines.single.lineDiscountAmount, 5.00);
      expect(cart.lines.single.netFinal, 95.02);
    });
  });

  group('خصم رأس الفاتورة — توزيع pro-rata (قاعدة 5.4-3)', () {
    test('ثلاثة أسطر متساوية وخصم مبلغ 1.00: القرش الأخير للسطر الأخير', () {
      final cart = SalePricing.priceCart(
        [line(1, 1, 10), line(2, 1, 10), line(3, 1, 10)],
        invoiceDiscountType: SaleDiscountType.amount,
        invoiceDiscountValue: 1,
      );
      expect(cart.lines[0].invoiceDiscountAllocated, 0.33);
      expect(cart.lines[1].invoiceDiscountAllocated, 0.33);
      expect(cart.lines[2].invoiceDiscountAllocated, 0.34);
      expect(cart.totals.invoiceDiscount, 1);
      // Σ الموزع = الخصم بالضبط — لا انزياح سنت.
      final allocated = cart.lines.fold<double>(
        0,
        (sum, l) => sum + l.invoiceDiscountAllocated,
      );
      expect(allocated, cart.totals.invoiceDiscount);
      expect(cart.totals.grandTotal, 29);
    });

    test('أسطر غير متساوية وخصم نسبة 10%: 33.33 / 66.67 من 100 صافياً', () {
      final cart = SalePricing.priceCart(
        [line(1, 1, 33.33), line(2, 2, 33.335)],
        invoiceDiscountType: SaleDiscountType.percent,
        invoiceDiscountValue: 10,
      );
      // gross: 33.33 و66.67؛ الخصم 10% من 100 = 10؛ الحصص 3.33 و6.67.
      expect(cart.lines[0].netAfterLineDiscount, 33.33);
      expect(cart.lines[1].netAfterLineDiscount, 66.67);
      expect(cart.totals.invoiceDiscount, 10);
      expect(cart.lines[0].invoiceDiscountAllocated, 3.33);
      expect(cart.lines[1].invoiceDiscountAllocated, 6.67);
      expect(cart.lines[0].netFinal, 30);
      expect(cart.lines[1].netFinal, 60);
      expect(cart.totals.grandTotal, 90);
      // اتساق التخزين: Σ(line_total) = الصافي، وΣ(الخصم الفعلي) = الخصم.
      expect(
        cart.lines.fold<double>(0, (sum, l) => sum + l.netFinal),
        cart.totals.grandTotal,
      );
      expect(
        cart.lines.fold<double>(0, (sum, l) => sum + l.effectiveDiscount),
        cart.totals.totalDiscount,
      );
    });

    test('سطر بخصم 100% لا يستلم نصيباً من خصم الرأس', () {
      final cart = SalePricing.priceCart(
        [
          line(1, 1, 100, type: SaleDiscountType.percent, discount: 100),
          line(2, 1, 100),
        ],
        invoiceDiscountType: SaleDiscountType.amount,
        invoiceDiscountValue: 10,
      );
      expect(cart.lines[0].invoiceDiscountAllocated, 0);
      expect(cart.lines[0].netFinal, 0);
      expect(cart.lines[1].invoiceDiscountAllocated, 10);
      expect(cart.lines[1].netFinal, 90);
      expect(cart.totals.grandTotal, 90);
    });

    test('خلط خصم سطر وخصم رأس: 2×100 بـ10% + 1×100 بخصم 10 + رأس 10%', () {
      final cart = SalePricing.priceCart(
        [
          line(1, 2, 100, type: SaleDiscountType.percent, discount: 10),
          line(2, 1, 100, type: SaleDiscountType.amount, discount: 10),
        ],
        invoiceDiscountType: SaleDiscountType.percent,
        invoiceDiscountValue: 10,
      );
      // بعد خصوم الأسطر: 180 و90 (= 270)؛ رأس 10% = 27 → حصص 18 و9.
      expect(cart.totals.subtotal, 300);
      expect(cart.totals.lineDiscountsTotal, 30);
      expect(cart.totals.invoiceDiscount, 27);
      expect(cart.lines[0].invoiceDiscountAllocated, 18);
      expect(cart.lines[1].invoiceDiscountAllocated, 9);
      expect(cart.lines[0].netFinal, 162);
      expect(cart.lines[1].netFinal, 81);
      expect(cart.totals.grandTotal, 243);
      // الأعمدة المخزنة: خصم فعلي لكل سطر يجمع الخصمين.
      expect(cart.lines[0].effectiveDiscount, 38);
      expect(cart.lines[1].effectiveDiscount, 19);
    });
  });

  group('التحقق من السلة (رسائل عربية)', () {
    test('سلة فارغة', () {
      expect(SalePricing.validateCart([]), isNotNull);
    });

    test('كمية صفرية/سالبة وغير عددية', () {
      expect(
        SalePricing.validateCart([line(1, 0, 10)]),
        contains('أكبر من صفر'),
      );
      expect(
        SalePricing.validateCart([line(1, -2, 10)]),
        contains('أكبر من صفر'),
      );
    });

    test('سعر سالب وخصم سالب ونسبة > 100', () {
      expect(SalePricing.validateCart([line(1, 1, -5)]), contains('سالباً'));
      expect(
        SalePricing.validateCart([
          line(1, 1, 10, type: SaleDiscountType.amount, discount: -1),
        ]),
        contains('سالباً'),
      );
      expect(
        SalePricing.validateCart([
          line(1, 1, 10, type: SaleDiscountType.percent, discount: 150),
        ]),
        contains('100%'),
      );
    });

    test('خصم سطر أكبر من قيمته', () {
      expect(
        SalePricing.validateCart([
          line(1, 1, 30, type: SaleDiscountType.amount, discount: 40),
        ]),
        contains('أكبر من قيمة السطر'),
      );
    });

    test('خصم رأس يجعل الصافي ≤ 0 (FR-02-05)', () {
      expect(
        SalePricing.validateCart(
          [line(1, 1, 400)],
          invoiceDiscountType: SaleDiscountType.amount,
          invoiceDiscountValue: 400,
        ),
        contains('صفراً أو سالباً'),
      );
      expect(
        SalePricing.validateCart(
          [line(1, 1, 400)],
          invoiceDiscountType: SaleDiscountType.percent,
          invoiceDiscountValue: 100,
        ),
        contains('صفراً أو سالباً'),
      );
    });

    test('سلة سليمة لا تنتج رسالة', () {
      expect(
        SalePricing.validateCart(
          [line(1, 2, 50, type: SaleDiscountType.percent, discount: 5)],
          invoiceDiscountType: SaleDiscountType.percent,
          invoiceDiscountValue: 3,
        ),
        isNull,
      );
    });

    test('تسعير سلة فارغة يرمي (لا يُبتلع)', () {
      expect(() => SalePricing.priceCart([]), throwsStateError);
    });
  });

  group('الدفع — نقدي/آجل/مختلط والباقي (FR-02-03)', () {
    test('نقدي تام: paid = total', () {
      expect(
        SalePricing.validatePayment(100, 100, SalePaymentMethod.cash),
        isNull,
      );
      final s = SalePricing.settlePayment(100, 100);
      expect(s.netPaid, 100);
      expect(s.changeDue, 0);
      expect(s.remainingCredit, 0);
      expect(s.payStatus, SalePaymentMethod.cash);
    });

    test('نقدي زائد: الباقي للعميل ولا دين ولا صندوق فوق الصافي', () {
      expect(
        SalePricing.validatePayment(100, 120, SalePaymentMethod.cash),
        isNull,
      );
      final s = SalePricing.settlePayment(100, 120);
      expect(s.netPaid, 100);
      expect(s.changeDue, 20);
      expect(s.remainingCredit, 0);
      expect(s.payStatus, SalePaymentMethod.cash);
    });

    test('آجل كامل: صفر نقدي', () {
      expect(
        SalePricing.validatePayment(100, 0, SalePaymentMethod.credit),
        isNull,
      );
      final s = SalePricing.settlePayment(100, 0);
      expect(s.netPaid, 0);
      expect(s.changeDue, 0);
      expect(s.remainingCredit, 100);
      expect(s.payStatus, SalePaymentMethod.credit);
    });

    test('مختلط: بين صفر والصافي', () {
      expect(
        SalePricing.validatePayment(100, 40, SalePaymentMethod.mixed),
        isNull,
      );
      final s = SalePricing.settlePayment(100, 40);
      expect(s.netPaid, 40);
      expect(s.changeDue, 0);
      expect(s.remainingCredit, 60);
      expect(s.payStatus, SalePaymentMethod.mixed);
    });

    test('تعارض التعلان مع الأرقام → رسائل محددة', () {
      expect(
        SalePricing.validatePayment(100, 40, SalePaymentMethod.cash),
        contains('تسديد الصافي كاملاً'),
      );
      expect(
        SalePricing.validatePayment(100, 5, SalePaymentMethod.credit),
        contains('عدم إدخال أي مبلغ نقدي'),
      );
      expect(
        SalePricing.validatePayment(100, 100, SalePaymentMethod.mixed),
        contains('بين صفر والصافي'),
      );
      expect(
        SalePricing.validatePayment(100, 0, SalePaymentMethod.mixed),
        contains('بين صفر والصافي'),
      );
      expect(
        SalePricing.validatePayment(100, -1, SalePaymentMethod.cash),
        contains('سالباً'),
      );
    });

    test('derivePayStatus عند الحدود', () {
      expect(SalePricing.derivePayStatus(100, 0), SalePaymentMethod.credit);
      expect(SalePricing.derivePayStatus(100, 0.004), SalePaymentMethod.credit);
      expect(SalePricing.derivePayStatus(100, 0.01), SalePaymentMethod.mixed);
      expect(SalePricing.derivePayStatus(100, 99.99), SalePaymentMethod.mixed);
      expect(SalePricing.derivePayStatus(100, 99.996), SalePaymentMethod.cash);
      expect(SalePricing.derivePayStatus(100, 150), SalePaymentMethod.cash);
    });
  });

  group('التقريب الموحد (قاعدة 5.4-9)', () {
    test('roundMoney / roundCost', () {
      expect(roundMoney(333.333), 333.33);
      expect(roundMoney(333.335), 333.34);
      expect(roundMoney(-333.335), -333.34);
      expect(roundCost(1.23456), 1.2346);
      expect(roundCost(1.23454), 1.2345);
    });
  });
}
