/// أنواع التدفق الداخلية لمحرك المشتريات — أسماء داخلية (لا تُصدَّر من
/// الواجهة). جزء من تقسيم R18-D3a — مستخرج حرفياً.
library;

import 'package:sqflite/sqflite.dart';

/// فشل تدفق داخلي برسالة عربية نظيفة — رميه داخل المعاملة يتراجعها
/// كاملة (لا `return Err` داخلها أبداً بعد أول كتابة).
class PurchaseFlowError implements Exception {
  const PurchaseFlowError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// معلومات صنف مطلوبة للترحيل (حمولة قراءة خفيفة) — مرآة البيع.
class PurchaseProductInfo {
  const PurchaseProductInfo({
    required this.id,
    required this.name,
    required this.isService,
    required this.trackBatches,
    required this.isArchived,
    this.unitId,
  });
  final int id;
  final String name;
  final bool isService;
  final bool trackBatches;

  /// المؤرشف لا يُشترى (نفس سلوك البيع مع الأرشفة — FR-01-15).
  final bool isArchived;
  final int? unitId;
}

/// هل الخطأ خرقاً لقيد CHECK؟ (لا مساعد جاهز في sqflite — نقرأ الرسالة).
bool isPurchaseCheckFailure(DatabaseException e) =>
    e.toString().toUpperCase().contains('CHECK');
