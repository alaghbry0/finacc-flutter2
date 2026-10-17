/// أنواع التدفق الداخلية لمحرك المبيعات — أسماء داخلية (لا تُصدَّر من
/// الواجهة). جزء من تقسيم R18-D3a — مستخرج حرفياً.
library;

import 'package:sqflite/sqflite.dart';

/// فشل تدفق داخلي برسالة عربية نظيفة — رميه داخل المعاملة يتراجعها
/// كاملة (لا `return Err` داخلها أبداً بعد أول كتابة).
class SaleFlowError implements Exception {
  const SaleFlowError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// صيغة ملاحظة حركة الدفعة — نفس صيغة الترحيل أعلاه حرفياً؛ يقرؤها
/// الإبطال لرد الكميات إلى دفعات البيع الأصلية (رأس § الإبطال).
final RegExp saleBatchNotePattern = RegExp(
  r'رقم الدفعة (.+?) \(تنتهي (\d{4}-\d{2}-\d{2})\)',
);

/// معلومات صنف مطلوبة للترحيل (حمولة قراءة خفيفة).
class SaleProductInfo {
  const SaleProductInfo({
    required this.id,
    required this.name,
    required this.costPrice,
    required this.isService,
    required this.trackBatches,
    required this.isArchived,
    this.unitId,
  });
  final int id;
  final String name;
  final double costPrice;
  final bool isService;
  final bool trackBatches;

  /// المؤرشف لا يُباع (البحث يستثنيه — نفس السلوك هنا عند الإدخال المباشر).
  final bool isArchived;
  final int? unitId;
}

/// هل الخطأ خرقاً لقيد CHECK؟ (لا مساعد جاهز في sqflite — نقرأ الرسالة).
bool isSaleCheckFailure(DatabaseException e) =>
    e.toString().toUpperCase().contains('CHECK');
