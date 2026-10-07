/// محرك تسعير الشراء النقي — FR-02-08 + قاعدة 5.4-3/5.4-9 (المرحلة 5).
///
/// **نقي بلا قاعدة بيانات** — قابل للاختبار المباشر، وتوقيعه مرآة
/// تامة لـ `sale_pricing.dart` (نمط الموجة 4 الملزم): نفس خطة الحساب
/// ونفس تقريب القرش ونفس بذرة التوزيع pro-rata.
///
/// ## خطة الحساب الملزمة (موثقة — قاعدة 5.4-9 و5.4-3):
/// 1. سطر: `gross = round2(qty × unitCost)` ثم خصم السطر (٪ →
///    `round2(gross × pct/100)` / مبلغ كما هو) ثم `net = gross − خصم`.
/// 2. رأس الفاتورة: خصم رأس (٪ من Σ الأسطر الصافية / مبلغ) **يوزَّع
///    على البنود نسبةً لصافي كل سطر (pro-rata)** — قاعدة 5.4-3:
///    «خصم رأس فاتورة الشراء يوزَّع على البنود نسبةً لقيمتها **قبل
///    تحديث WAC**» — توزيعٌ يثبّت تكلفة وحدة فعلية دقيقة لكل بند.
/// 3. **تقريب القرش**: كل مبلغ ظاهري بمنزلتين؛ التوزيع يقرَّب سطراً
///    سطراً ثم **يستقر الفارق (القرش الأخير) في آخر سطر ذي صافٍ
///    موجب** فتتحقق Σ(الخصوم الموزعة) = خصم الرأس بالضبط و
///    Σ(line_total) = الصافي الكلي بالضبط — لا انزياح سنت أبداً.
/// 4. **unitCostEffective** = `round4(netFinal / qty)` بعملة الفاتورة —
///    التكلفة الفعلية للوحدة بعد كل الخصومات؛ يحوّلها المستودع للعملة
///    الأساسية بسعر يوم الشراء قبل إدخالها صيغة WAC (دقة 4 منازل).
///
/// فرق وحيد عن البيع (موثَّق): **لا «باقٍ» في الشراء** — الدفع النقدي
/// محصور بين 0 والصافي حصراً، فالزيادة فوق الصافي تُرفض لا أن تصبح
/// باقياً (دفع زائد لمورد = تسوية دائنة مستقبلية خارج نطاق V1).
library;

import '../models/purchase.dart';

/// تفاوت عشري مقبول في مقارنات المال (نصف قرش) — مرآة sale_pricing.
const double moneyEpsilon = 0.005;

/// يقرب مبلغاً ظاهرياً إلى منزلتين (القرش — قاعدة 5.4-9).
double roundMoney(double value) => _roundTo(value, 0.01);

/// يقرب تكلفة/WAC إلى أربع منازل (قاعدة 5.4-9 — دقة التكاليف).
double roundCost(double value) => _roundTo(value, 0.0001);

/// تقريب عشري موحّد: أقرب مضاعف لـ [step] (النصف بعيداً عن الصفر —
/// السلوك المحاسبي المعتاد)، مع تمرير NaN/∞ كما هي لتلتقطها التحققات.
double _roundTo(double value, double step) {
  if (value.isNaN || value.isInfinite) return value;
  final inverse = 1 / step;
  return (value * inverse).round() / inverse;
}

/// أداة تسعير الشراء النقية — بلا أي وصول لقاعدة بيانات.
class PurchasePricing {
  const PurchasePricing();

  // ───────────────────────────────────────────────────────────────────
  // التحقق (رسائل عربية بكلمات المستخدم — §6.3)
  // ───────────────────────────────────────────────────────────────────

  /// يتحقق من بنود الشراء والخصومات (كميات/تكاليف/خصوم/صافٍ > 0 +
  /// اتساق حقول الدفعة الواردة) — FR-02-05 / FR-02-08.
  ///
  /// يعيد رسالة الخطأ أو `null` عند السلامة. لا يتحقق من الدفع
  /// (انظر [validatePayment]) ولا من وجود الأصناف (مسؤولية المستودع).
  static String? validateCart(
    List<PurchaseLine> lines, {
    PurchaseDiscountType invoiceDiscountType = PurchaseDiscountType.amount,
    double invoiceDiscountValue = 0,
  }) {
    if (lines.isEmpty) {
      return 'أضف بنداً واحداً على الأقل إلى فاتورة الشراء.';
    }
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final no = i + 1;
      if (_isBadNumber(line.qty)) {
        return 'كمية البند $no غير صالحة — أدخل رقماً سليماً.';
      }
      if (line.qty <= 0) {
        return 'كمية البند $no يجب أن تكون أكبر من صفر.';
      }
      if (_isBadNumber(line.unitCost) || line.unitCost < 0) {
        return 'تكلفة وحدة البند $no لا يمكن أن تكون سالباً.';
      }
      if (_isBadNumber(line.lineDiscountValue) || line.lineDiscountValue < 0) {
        return 'خصم البند $no لا يمكن أن يكون سالباً.';
      }
      if (line.lineDiscountType == PurchaseDiscountType.percent &&
          line.lineDiscountValue > 100) {
        return 'نسبة خصم البند $no لا يمكن أن تتجاوز 100%.';
      }
      final gross = roundMoney(line.qty * line.unitCost);
      final lineDiscount = _lineDiscountAmount(gross, line);
      if (gross - lineDiscount < -moneyEpsilon) {
        return 'خصم البند $no أكبر من قيمة البند نفسه — راجع الخصم.';
      }
      // الدفعة الواردة: رقم بلا صلاحية مرفوض (عمود expiry NOT NULL).
      final batchNo = line.batchNo?.trim() ?? '';
      if (batchNo.isNotEmpty && line.expiryDate == null) {
        return 'البند $no يحمل رقم دفعة («$batchNo») بلا تاريخ صلاحية — '
            'أدخل تاريخ الصلاحية أو احذف رقم الدفعة.';
      }
    }
    if (_isBadNumber(invoiceDiscountValue) || invoiceDiscountValue < 0) {
      return 'خصم الفاتورة لا يمكن أن يكون سالباً.';
    }
    if (invoiceDiscountType == PurchaseDiscountType.percent &&
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
      return 'الخصومات تجعل صافي فاتورة الشراء صفراً أو سالباً — '
          'راجع الخصومات.';
    }
    return null;
  }

  /// يتحقق من اتساق الدفع المعلن مع المبالغ — FR-02-03 باتجاه الشراء.
  ///
  /// القواعد: النقدي يسدد الصافي كاملاً؛ الآجل صفر نقدي؛ المختلط بينهما
  /// حصراً (0 < نقدي < صافٍ). **الزيادة فوق الصافي مرفوضة** — لا «باقٍ»
  /// في الشراء (دفع زائد لمورد خارج نطاق V1 — قرار موثَّق برأس الملف).
  static String? validatePayment(
    double grandTotal,
    double paidCash,
    PurchasePaymentMethod declared,
  ) {
    if (_isBadNumber(paidCash) || paidCash < 0) {
      return 'المبلغ النقدي المدفوع للمورد لا يمكن أن يكون سالباً.';
    }
    if (paidCash > grandTotal + moneyEpsilon) {
      return 'المبلغ النقدي المدفوع ($paidCash) يتجاوز صافي الفاتورة '
          '($grandTotal) — الشراء لا يقبل الدفع الزائد؛ اترك الباقي آجلاً.';
    }
    final derived = derivePayStatus(grandTotal, paidCash);
    if (derived == declared) return null;
    switch (declared) {
      case PurchasePaymentMethod.cash:
        return 'الحفظ النقدي يتطلب تسديد الصافي كاملاً ($grandTotal) — '
            'أو اختر الدفع المختلط/الآجل.';
      case PurchasePaymentMethod.credit:
        return 'الحفظ الآجل يتطلب عدم إدخال أي مبلغ نقدي — المدخل '
            '$paidCash.';
      case PurchasePaymentMethod.mixed:
        return 'الدفع المختلط يتطلب مبلغاً نقدياً بين صفر والصافي '
            '($grandTotal) حصراً — المدخل $paidCash.';
    }
  }

  // ───────────────────────────────────────────────────────────────────
  // الحساب
  // ───────────────────────────────────────────────────────────────────

  /// يستنتج حالة الدفع من الأرقام (لا من التعلان):
  /// نقدي عند تسديد الصافي كاملاً، آجل عند الصفر، مختلط بينهما.
  static PurchasePaymentMethod derivePayStatus(
    double grandTotal,
    double paidCash,
  ) {
    if (paidCash <= moneyEpsilon) return PurchasePaymentMethod.credit;
    if (paidCash >= grandTotal - moneyEpsilon) {
      return PurchasePaymentMethod.cash;
    }
    return PurchasePaymentMethod.mixed;
  }

  /// يفصل الدفعة: المدفوع نقدياً الآن + الجزء الآجل (دين المورد).
  ///
  /// - `netPaid = paidCash` (ما يخرج من الصندوق — الدفع الزائد مرفوض
  ///   سلفاً في [validatePayment] فلا حاجة لقصّه هنا).
  /// - `remainingCredit = grandTotal − netPaid` (دين بعملة الفاتورة).
  static ({
    double netPaid,
    double remainingCredit,
    PurchasePaymentMethod payStatus,
  })
  settlePayment(double grandTotal, double paidCash) {
    final netPaid = roundMoney(
      paidCash < grandTotal ? paidCash : grandTotal,
    );
    final remainingCredit = roundMoney(grandTotal - netPaid);
    return (
      netPaid: netPaid,
      remainingCredit: remainingCredit,
      payStatus: derivePayStatus(grandTotal, paidCash),
    );
  }

  /// **قلب التسعير**: يسعّر فاتورة الشراء كاملة — البنود + الإجماليات —
  /// بتوزيع خصم الرأس pro-rata (قاعدة 5.4-3) وتقريب القرش الموثق أعلاه،
  /// ويكشف `unitCostEffective` لكل بند (تكلفة الوحدة التي تدخل WAC بعد
  /// تحويلها للعملة الأساسية في المستودع).
  ///
  /// يفترض فاتورة سليمة ([validateCart] قبلها)؛ الطلبات الشاذة (سلة
  /// فارغة أو صافٍ ≤ 0) ترمي [StateError] — لا تُبتلع أبداً.
  static PricedPurchaseCart priceCart(
    List<PurchaseLine> lines, {
    PurchaseDiscountType invoiceDiscountType = PurchaseDiscountType.amount,
    double invoiceDiscountValue = 0,
  }) {
    if (lines.isEmpty) {
      throw StateError('لا يمكن تسعير فاتورة شراء بلا بنود');
    }

    // (1) البنود: gross → خصم السطر → صافي السطر (منزلتان).
    var subtotal = 0.0;
    var lineDiscountsTotal = 0.0;
    var afterLines = 0.0;
    final grossList = <double>[];
    final lineDiscountList = <double>[];
    final netList = <double>[];
    for (final line in lines) {
      final gross = roundMoney(line.qty * line.unitCost);
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

    // (2) خصم الرأس: ٪ من صافي البنود أو مبلغ — مقرَّباً لمنزلتين.
    var invoiceDiscount = invoiceDiscountType == PurchaseDiscountType.percent
        ? roundMoney(afterLines * invoiceDiscountValue / 100)
        : roundMoney(invoiceDiscountValue);
    if (invoiceDiscount > afterLines) invoiceDiscount = afterLines;
    if (invoiceDiscount < 0) invoiceDiscount = 0;
    if (afterLines <= 0 && invoiceDiscount > 0) {
      throw StateError('صافي الفاتورة ≤ 0 — لا يوزَّع خصم على صافٍ معدوم');
    }

    // (3) التوزيع pro-rata: بنداً بنداً بقرش مقرَّب، والفارق للآخر موجب.
    //     (نفس بذرة sale_pricing حرفياً — خطة 5.4-9 الموثقة أعلاه.)
    final allocations = List<double>.filled(lines.length, 0);
    if (invoiceDiscount > 0 && afterLines > 0) {
      var remainingToAllocate = invoiceDiscount;
      var lastPositiveIndex = -1;
      for (var i = 0; i < lines.length; i++) {
        if (netList[i] > moneyEpsilon) lastPositiveIndex = i;
      }
      for (var i = 0; i < lines.length; i++) {
        if (remainingToAllocate <= 0) break;
        if (i == lastPositiveIndex) continue; // يستقر فيه الفارق أخيراً.
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

    // (4) الصوغ النهائي: line_total لكل بند والإجماليات من مجموعها —
    //     تطابق تام بين صفوف القاعدة ورأسها + تكلفة الوحدة الفعلية.
    final pricedLines = <PricedPurchaseLine>[];
    var grandTotal = 0.0;
    for (var i = 0; i < lines.length; i++) {
      final netFinal = roundMoney(netList[i] - allocations[i]);
      grandTotal += netFinal;
      pricedLines.add(
        PricedPurchaseLine(
          line: lines[i],
          gross: grossList[i],
          lineDiscountAmount: lineDiscountList[i],
          netAfterLineDiscount: netList[i],
          invoiceDiscountAllocated: allocations[i],
          netFinal: netFinal,
          unitCostEffective: roundCost(netFinal / lines[i].qty),
        ),
      );
    }
    grandTotal = roundMoney(grandTotal);

    return PricedPurchaseCart(
      lines: pricedLines,
      totals: PurchaseTotals(
        subtotal: subtotal,
        lineDiscountsTotal: lineDiscountsTotal,
        invoiceDiscount: invoiceDiscount,
        grandTotal: grandTotal,
        itemsCount: lines.length,
      ),
    );
  }

  /// خصم البند المحسوب من نوعه (٪ من gross / مبلغ) — بمنزلتين.
  static double _lineDiscountAmount(double gross, PurchaseLine line) {
    if (line.lineDiscountType == PurchaseDiscountType.percent) {
      return roundMoney(gross * line.lineDiscountValue / 100);
    }
    return roundMoney(line.lineDiscountValue);
  }

  static bool _isBadNumber(double v) => v.isNaN || v.isInfinite;
}
