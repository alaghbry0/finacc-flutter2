/// محرك تسعير البيع النقي — FR-02-05 + قاعدة 5.4-3/5.4-9.
///
/// **نقي بلا قاعدة بيانات** — قابل للاختبار المباشر ومشترك بين الفاتورة
/// (`SaleRepository.postSale`) وعرض السعر (`QuotationRepository`).
///
/// ## خطة الحساب الملزمة (موثقة — قاعدة 5.4-9):
/// 1. سطر: `gross = round2(qty × unitPrice)` ثم خصم السطر (٪ →
///    `round2(gross × pct/100)` / مبلغ كما هو) ثم `net = gross − خصم`.
/// 2. رأس الفاتورة: خصم رأس (٪ من Σ الأسطر الصافية / مبلغ) **يوزَّع
///    على الأسطر نسبةً لصافي كل سطر (pro-rata)** — مثل توزيع خصم رأس
///    الشراء في قاعدة 5.4-3 — لتثبيت أسطر صافية دقيقة.
/// 3. **تقريب القرش**: كل مبلغ ظاهري بمنزلتين؛ التوزيع يقرَّب سطراً
///    سطراً ثم **يستقر الفارغ (القرش الأخير) في آخر سطر ذي صافٍ موجب**
///    فتتحقق Σ(الخصوم الموزعة) = خصم الرأس بالضبط و
///    Σ(line_total) = الصافي الكلي بالضبط — لا انزياح سنت أبداً.
/// 4. التكاليف/WAC بأربع منازل (`roundCost`) — خارج هذا الملف (المستودع).
library;

import '../models/sale.dart';

/// تفاوت عشري مقبول في مقارنات المال (نصف قرش).
const double moneyEpsilon = 0.005;

/// يقرب مبلغاً ظاهرياً إلى منزلتين (القرش — قاعدة 5.4-9).
double roundMoney(double value) => _roundTo(value, 0.01);

/// يقرب تكلفة/WAC إلى أربع منازل (قاعدة 5.4-9 — دقة التكاليف).
double roundCost(double value) => _roundTo(value, 0.0001);

/// تقريب عشري موحّد: أقرب مضاعف لـ [step] (النصف بعيداً عن الصفر —
/// السلوك المحاسبي المعتاد)، مع تمرير NaN/∞ كما هي لتلتقطها التحققات.
///
/// التنفيذ: (القيمة × مقلوب الخطوة) تُقرَّب لعدد صحيح ثم تُقسم عليه —
/// القسمة الأخيرة **مقرَّبة صحيحاً** فتعيد «المضاعف القانوني» الأقرب
/// للقيمة العشرية (تجنّب تراكم ضجيج الضرب بـ 0.01 الثنائي).
double _roundTo(double value, double step) {
  if (value.isNaN || value.isInfinite) return value;
  final inverse = 1 / step;
  return (value * inverse).round() / inverse;
}

/// أداة التسعير النقية لسلة البيع — بلا أي وصول لقاعدة بيانات.
class SalePricing {
  const SalePricing();

  // ───────────────────────────────────────────────────────────────────
  // التحقق (رسائل عربية بكلمات المستخدم — §6.3)
  // ───────────────────────────────────────────────────────────────────

  /// يتحقق من السلة والخصومات (كميات/أسعار/خصوم/صافٍ > 0) — FR-02-05.
  ///
  /// يعيد رسالة الخطأ أو `null` عند السلامة. لا يتحقق من الدفع
  /// (انظر [validatePayment]) ولا من المخزون (مسؤولية المستودع — 5.4-5).
  ///
  /// **البونص** (موجة UX-4): يتحقق من سلامة `freeQty` حصراً (رقم سليم /
  /// غير سالب / لا أدق من ثلاث منازل NUMERIC(12,3)) — **ولا يغيّر أي حساب
  /// إطلاقاً**: gross والخصومات والصافي كلها من `qty` المدفوعة وحدها
  /// (الإيراد من المدفوع حصراً — القرار التحاسبي UX-audit-invoice §3؛
  /// البونص يُحسب مخزونياً في `SaleRepository.postSale`).
  static String? validateCart(
    List<CartLine> lines, {
    SaleDiscountType invoiceDiscountType = SaleDiscountType.amount,
    double invoiceDiscountValue = 0,
  }) {
    if (lines.isEmpty) return 'أضف بنداً واحداً على الأقل إلى الفاتورة.';
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final no = i + 1;
      if (_isBadNumber(line.qty)) {
        return 'كمية السطر $no غير صالحة — أدخل رقماً سليماً.';
      }
      if (line.qty <= 0) {
        return 'كمية السطر $no يجب أن تكون أكبر من صفر.';
      }
      if (_isBadNumber(line.freeQty)) {
        return 'كمية البونص للسطر $no غير صالحة — أدخل رقماً سليماً.';
      }
      if (line.freeQty < 0) {
        return 'كمية البونص للسطر $no لا يمكن أن تكون سالبة.';
      }
      // دقة NUMERIC(12,3): يقبل ثالث منزلة كاملة (مع تفاوت ضجيج النقطة
      // العائمة: 0.333×1000 = 332.99999…94) ويرفض الرابعة فصاعداً
      // (2.0005×1000 = 2000.5 — نصف خطوة بعيد عن أي مضاعف).
      if (((line.freeQty * 1000).roundToDouble() - line.freeQty * 1000)
              .abs() >
          0.001) {
        return 'كمية البونص للسطر $no لا تقبل دقة أعلى من ثلاث منازل '
            'عشرية — راجع الكمية.';
      }
      if (_isBadNumber(line.unitPrice) || line.unitPrice < 0) {
        return 'سعر وحدة السطر $no لا يمكن أن يكون سالباً.';
      }
      if (_isBadNumber(line.lineDiscountValue) || line.lineDiscountValue < 0) {
        return 'خصم السطر $no لا يمكن أن يكون سالباً.';
      }
      if (line.lineDiscountType == SaleDiscountType.percent &&
          line.lineDiscountValue > 100) {
        return 'نسبة خصم السطر $no لا يمكن أن تتجاوز 100%.';
      }
      final gross = roundMoney(line.qty * line.unitPrice);
      final lineDiscount = _lineDiscountAmount(gross, line);
      if (gross - lineDiscount < -moneyEpsilon) {
        return 'خصم السطر $no أكبر من قيمة السطر نفسه — راجع الخصم.';
      }
    }
    if (_isBadNumber(invoiceDiscountValue) || invoiceDiscountValue < 0) {
      return 'خصم الفاتورة لا يمكن أن يكون سالباً.';
    }
    if (invoiceDiscountType == SaleDiscountType.percent &&
        invoiceDiscountValue > 100) {
      return 'نسبة خصم الفاتورة لا يمكن أن تتجاوز 100%.';
    }
    // صافي الفاتورة > 0 إلزامي (FR-02-05 + CHECK(total > 0) بالمخطط).
    final priced = priceCart(
      lines,
      invoiceDiscountType: invoiceDiscountType,
      invoiceDiscountValue: invoiceDiscountValue,
    );
    if (priced.totals.grandTotal <= 0) {
      return 'الخصومات تجعل صافي الفاتورة صفراً أو سالباً — راجع الخصومات.';
    }
    return null;
  }

  /// يتحقق من اتساق الدفع المعلن مع المبالغ — FR-02-03.
  ///
  /// القواعد: النقدي يسدد الصافي كاملاً (والزيادة **باقٍ للعميل** لا
  /// ديناً)؛ الآجل صفر نقدي؛ المختلط بينهما (0 < نقدي < صافٍ).
  static String? validatePayment(
    double grandTotal,
    double paidCash,
    SalePaymentMethod declared,
  ) {
    if (_isBadNumber(paidCash) || paidCash < 0) {
      return 'المبلغ النقدي المدفوع لا يمكن أن يكون سالباً.';
    }
    final derived = derivePayStatus(grandTotal, paidCash);
    if (derived == declared) return null;
    switch (declared) {
      case SalePaymentMethod.cash:
        return 'الحفظ النقدي يتطلب تسديد الصافي كاملاً ($grandTotal) — '
            'أو اختر الدفع المختلط/الآجل.';
      case SalePaymentMethod.credit:
        return 'الحفظ الآجل يتطلب عدم إدخال أي مبلغ نقدي — المدخل $paidCash.';
      case SalePaymentMethod.mixed:
        return 'الدفع المختلط يتطلب مبلغاً نقدياً بين صفر والصافي '
            '($grandTotal) حصراً — المدخل $paidCash.';
    }
  }

  // ───────────────────────────────────────────────────────────────────
  // الحساب
  // ───────────────────────────────────────────────────────────────────

  /// يستنتج حالة الدفع من الأرقام (لا من التعلان):
  /// نقدي عند تسديد الصافي كاملاً (أو زيادة = باقٍ)، آجل عند الصفر،
  /// مختلط بينهما.
  static SalePaymentMethod derivePayStatus(double grandTotal, double paidCash) {
    if (paidCash <= moneyEpsilon) return SalePaymentMethod.credit;
    if (paidCash >= grandTotal - moneyEpsilon) return SalePaymentMethod.cash;
    return SalePaymentMethod.mixed;
  }

  /// يفصل الدفعة: الصافي المدفوع فعلاً + الباقي للعميل + الجزء الآجل.
  ///
  /// - `netPaid = min(paidCash, grandTotal)` (ما يدخل الصندوق).
  /// - `changeDue = max(0, paidCash − grandTotal)` (يخرجه الكاشير يدوياً —
  ///   لا يدخل الصندوق ولا الدين).
  /// - `remainingCredit = grandTotal − netPaid` (دين بعملة الفاتورة).
  static ({
    double netPaid,
    double changeDue,
    double remainingCredit,
    SalePaymentMethod payStatus,
  })
  settlePayment(double grandTotal, double paidCash) {
    final netPaid = roundMoney(paidCash < grandTotal ? paidCash : grandTotal);
    final changeDue = roundMoney(
      paidCash > grandTotal ? paidCash - grandTotal : 0,
    );
    final remainingCredit = roundMoney(grandTotal - netPaid);
    return (
      netPaid: netPaid,
      changeDue: changeDue,
      remainingCredit: remainingCredit,
      payStatus: derivePayStatus(grandTotal, paidCash),
    );
  }

  /// **قلب التسعير**: يسعّر السلة كاملة — الأسطر + الإجماليات — بالتوزيع
  /// pro-rata لخصم الرأس (قاعدة 5.4-3) وتقريب القرش الموثق أعلاه.
  ///
  /// يفترض سلة سليمة ([validateCart] قبلها)؛ الطلبات الشاذة (سلة فارغة
  /// أو صافٍ ≤ 0) ترمي [StateError] — لا تُبتلع أبداً.
  static PricedCart priceCart(
    List<CartLine> lines, {
    SaleDiscountType invoiceDiscountType = SaleDiscountType.amount,
    double invoiceDiscountValue = 0,
  }) {
    if (lines.isEmpty) {
      throw StateError('لا يمكن تسعير سلة فارغة');
    }

    // (1) الأسطر: gross → خصم السطر → صافي السطر (منزلتان).
    var subtotal = 0.0;
    var lineDiscountsTotal = 0.0;
    var afterLines = 0.0;
    final grossList = <double>[];
    final lineDiscountList = <double>[];
    final netList = <double>[];
    for (final line in lines) {
      final gross = roundMoney(line.qty * line.unitPrice);
      final lineDiscount = _lineDiscountAmount(gross, line);
      final net = roundMoney(gross - lineDiscount);
      grossList.add(gross);
      lineDiscountList.add(lineDiscount);
      netList.add(net);
      subtotal += gross;
      lineDiscountsTotal += lineDiscount;
      afterLines += net;
    }
    subtotal = roundMoney(subtotal);
    lineDiscountsTotal = roundMoney(lineDiscountsTotal);
    afterLines = roundMoney(afterLines);

    // (2) خصم الرأس: ٪ من صافي الأسطر أو مبلغ — مقرَّباً لمنزلتين.
    var invoiceDiscount = invoiceDiscountType == SaleDiscountType.percent
        ? roundMoney(afterLines * invoiceDiscountValue / 100)
        : roundMoney(invoiceDiscountValue);
    if (invoiceDiscount > afterLines) invoiceDiscount = afterLines;
    if (invoiceDiscount < 0) invoiceDiscount = 0;
    if (afterLines <= 0 && invoiceDiscount > 0) {
      throw StateError('صافي الفاتورة ≤ 0 — لا يوزَّع خصم على صافٍ معدوم');
    }

    // (3) التوزيع pro-rata: سطراً سطراً بقرش مقرَّب، والفارغ للآخر موجب.
    final allocations = List<double>.filled(lines.length, 0);
    if (invoiceDiscount > 0 && afterLines > 0) {
      var remainingToAllocate = invoiceDiscount;
      var lastPositiveIndex = -1;
      for (var i = 0; i < lines.length; i++) {
        if (netList[i] > moneyEpsilon) lastPositiveIndex = i;
      }
      for (var i = 0; i < lines.length; i++) {
        if (remainingToAllocate <= 0) break;
        if (i == lastPositiveIndex) continue; // يستقر فيه الفارغ أخيراً.
        var share = roundMoney(invoiceDiscount * netList[i] / afterLines);
        if (share > remainingToAllocate) share = remainingToAllocate;
        if (share > netList[i]) share = netList[i];
        if (share < 0) share = 0;
        allocations[i] = roundMoney(share);
        remainingToAllocate = roundMoney(remainingToAllocate - share);
      }
      if (lastPositiveIndex >= 0 && remainingToAllocate > 0) {
        allocations[lastPositiveIndex] = roundMoney(
          allocations[lastPositiveIndex] + remainingToAllocate,
        );
        remainingToAllocate = 0;
      }
      // (حارس نظري) أي كسر متبقٍ رغم كل شيء يُحمَّل على الخصم الكلي.
      invoiceDiscount = roundMoney(
        invoiceDiscount - remainingToAllocate < 0
            ? 0
            : invoiceDiscount - remainingToAllocate,
      );
    }

    // (4) الصوغ النهائي: line_total لكل سطر والإجماليات من مجموعها —
    //     تطابق تام بين صفوف القاعدة ورأسها.
    final pricedLines = <PricedCartLine>[];
    var grandTotal = 0.0;
    for (var i = 0; i < lines.length; i++) {
      final netFinal = roundMoney(netList[i] - allocations[i]);
      grandTotal += netFinal;
      pricedLines.add(
        PricedCartLine(
          line: lines[i],
          gross: grossList[i],
          lineDiscountAmount: lineDiscountList[i],
          netAfterLineDiscount: netList[i],
          invoiceDiscountAllocated: allocations[i],
          netFinal: netFinal,
        ),
      );
    }
    grandTotal = roundMoney(grandTotal);

    return PricedCart(
      lines: pricedLines,
      totals: CartTotals(
        subtotal: subtotal,
        lineDiscountsTotal: lineDiscountsTotal,
        invoiceDiscount: invoiceDiscount,
        grandTotal: grandTotal,
        itemsCount: lines.length,
      ),
    );
  }

  /// خصم السطر المحسوب من نوعه (٪ من gross / مبلغ) — بمنزلتين.
  static double _lineDiscountAmount(double gross, CartLine line) {
    if (line.lineDiscountType == SaleDiscountType.percent) {
      return roundMoney(gross * line.lineDiscountValue / 100);
    }
    return roundMoney(line.lineDiscountValue);
  }

  static bool _isBadNumber(double v) => v.isNaN || v.isInfinite;
}
