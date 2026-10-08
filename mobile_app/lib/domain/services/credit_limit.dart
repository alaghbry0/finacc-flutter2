/// محرك حد الائتمان النقي — FR-03-05 (تنبيه/منع البيع الآجل فوق الحد).
///
/// **نقي بلا قاعدة بيانات** — قابل للاختبار المباشر، يستهلكه حوار
/// PaymentSheet لحظة تأكيد الدفع (17-c) بعد جلب الرصيد الجاري من
/// `CustomerRepository.balanceInCurrency` (صيغة FR-03-02 بعملة الفاتورة).
///
/// ## دلالة القيم (مطابقة لملحق 3-01 وCustomerRepository.checkCredit):
/// - `credit_limit = null` → **بلا حد**: لا تنبيه أبداً.
/// - `credit_limit = 0` → **منع الآجل**: أي دَين ناتج (الرصيد + الآجل > 0)
///   يُطلق التنبيه — رصيد مسبق الدفع يمتص الآجل فلا تنبيه (نفس صيغة
///   المستودع حرفياً).
/// - قيمة موجبة → التنبيه عند (الرصيد + الآجل الجديد) **> الحد حصراً** —
///   المساواة تعني «عند الحد» لا «فوقه» فلا تنبيه (قرار موثق 17-c،
///   متطابق مع `checkCredit` في المستودع ليكون الحوار والحارس النهائي
///   على الحد نفسه دائماً).
///
/// ## السلوك (إعداد `parties.credit_limit_action` — افتراضي warn):
/// - `warn`: حوار «متابعة على أي حال / إلغاء» — المستخدم يقرر.
/// - `block`: الحوار يرفض المتابعة («رجوع» حصراً).
/// - أي قيمة أخرى غير معروفة تُعامل كالافتراضي `warn`.
library;

/// معطيات البوابة لحظة التأكيد — تُجمع من المستودعات (رصيد + حد +
/// سلوك الإعداد) ويبقى التقييم النقي هنا (قابل للاختبار بلا I/O).
class CreditLimitGate {
  const CreditLimitGate({
    required this.creditLimit,
    required this.action,
    required this.currentBalance,
  });

  /// حد ائتمان العميل بعملة الفاتورة (null = بلا حد، 0 = منع الآجل).
  final double? creditLimit;

  /// قيمة إعداد `parties.credit_limit_action` كما قُرئت ('warn'/'block').
  final String action;

  /// الرصيد القائم للعميل بعملة الفاتورة (صيغة FR-03-02).
  final double currentBalance;
}

/// نتيجة تقييم حد الائتمان لبيع آجل/مختلط جديد.
class CreditLimitDecision {
  const CreditLimitDecision({
    required this.triggered,
    required this.blocked,
    required this.resultingBalance,
  });

  /// هل تجاوزت الفاتورة الحد؟ (false → لا حوار أصلاً).
  final bool triggered;

  /// عند التفعيل: هل المتابعة ممنوعة (block) أم تحذير قابل للتجاوز؟
  final bool blocked;

  /// الرصيد المتوقع بعد الفاتورة (الرصيد الحالي + الجزء الآجل الجديد).
  final double resultingBalance;
}

/// يقيّم حد الائتمان لجزء آجل جديد [newDue] على رصيد [currentBalance].
///
/// [newDue] هو **الجزء الآجل حصراً** (الصافي − المدفوع نقداً) — الدفع
/// المختلط يقيَّم بجزؤه الآجل لا بكامل الفاتورة (FR-03-05).
CreditLimitDecision evaluateCreditLimit({
  double? creditLimit,
  required String action,
  required double currentBalance,
  required double newDue,
}) {
  final resulting = currentBalance + newDue;
  // بلا حد (null) → لا تنبيه أبداً، أي كان الرصيد.
  final triggered =
      creditLimit != null && newDue > 0 && resulting > creditLimit;
  return CreditLimitDecision(
    triggered: triggered,
    blocked: triggered && action == 'block',
    resultingBalance: resulting,
  );
}
