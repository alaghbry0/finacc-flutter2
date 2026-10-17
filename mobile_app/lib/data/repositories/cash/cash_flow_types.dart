/// أنواع التدفق الداخلية لمحرك النقدية — أسماء داخلية (لا تُصدَّر من
/// الواجهة). جزء من تقسيم R18-D3a — مستخرج حرفياً.
library;

import '../../../domain/models/cash.dart';

/// فشل تدفق داخلي برسالة عربية نظيفة — رميه داخل المعاملة يتراجعها
/// كاملة (نمط المستودعات القائمة).
class CashFlowError implements Exception {
  const CashFlowError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// سعر يوم مع سياسة الاحتياط — مخرج محلل الأسعار.
class CashDayRate {
  const CashDayRate(this.rate, this.fallback);
  final double rate;
  final bool fallback;
}

/// تجميع دلاء صندوق واحد أثناء القراءة.
class CashBoxAgg {
  CashBoxAgg(this.box);
  final CashboxInfo box;
  final Map<int, double> buckets = <int, double>{};
}
