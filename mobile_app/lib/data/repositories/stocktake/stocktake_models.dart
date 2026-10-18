/// أنواع الجرد النقية (الاستثناء/المخزن/بند الكشف/الملخص/سجل الجرد) —
/// جزء من تقسيم R20-D3a لمستودع الجرد (نمط R19-D3d): منقولة حرفياً من
/// stocktake_repository.dart — المستودع يُصدِّرها من هنا فكل استيراداته
/// التاريخية تحل كما كانت.
library;

import '../../../domain/core/numbers.dart';
import '../../../domain/services/purchase_pricing.dart' show roundMoney;

/// تفاوت عشري مقبول في مقارنات الكميات (NUMERIC(12,3) في القاعدة).
const double kStocktakeQtyEps = 0.0005;

/// خطأ جرد موصوف بكلمات المستخدم — يرميه [StocktakeRepository.post]
/// (ترحيل الجرد في stocktake_post_flow.dart).
class StocktakeException implements Exception {
  const StocktakeException(this.message);

  /// الرسالة العربية الوصفية (تُعرض كما هي).
  final String message;

  @override
  String toString() => message;
}

/// مستودع مرجعي صغير للمخزن (قائمة اختيار الشاشة).
class StocktakeWarehouse {
  const StocktakeWarehouse({
    required this.id,
    required this.name,
    required this.isDefault,
  });

  final int id;
  final String name;
  final bool isDefault;
}

/// بند كشف الجرد — سطر عدّ لصنف واحد في مخزن واحد.
///
/// [unitCost] لقطة عرض (تكلفة لحظة فتح الكشف) للمعاينة والمراجعة؛
/// اللقطة الملزمة المخزَّنة تُقرأ داخل معاملة الترحيل (القرار 1 في
/// stocktake_post_flow.dart).
class StocktakeLineDraft {
  const StocktakeLineDraft({
    required this.productId,
    required this.name,
    this.unitName,
    required this.bookQty,
    required this.unitCost,
    this.countedQty,
  });

  /// معرّف الصنف في جدول `product`.
  final int productId;

  /// اسم الصنف.
  final String name;

  /// اسم وحدة القياس (إن عُرِّفت للصنف).
  final String? unitName;

  /// الرصيد الدفتري الحالي (stock_level — 0 عند غياب الصف).
  final double bookQty;

  /// لقطة تكلفة الوحدة للعرض (WAC بالعملة الأساسية لحظة الفتح).
  final double unitCost;

  /// الرصيد الفعلي المُعدود — `null` حتى يُدخله المستخدم.
  final double? countedQty;

  /// نسخة بعدّ جديد للسطر (نمط الحالة الثابتة).
  StocktakeLineDraft withCounted(double? qty) => StocktakeLineDraft(
    productId: productId,
    name: name,
    unitName: unitName,
    bookQty: bookQty,
    unitCost: unitCost,
    countedQty: qty,
  );

  /// الفرق = المقيس − الدفتري (`null` ما لم يُعدّ).
  double? get diff {
    final counted = countedQty;
    if (counted == null) return null;
    return roundTo3(counted - bookQty);
  }
}

/// ملخص الجرد الجاري — القيم بالعملة الأساسية (فرق × تكلفة اللقطة).
class StocktakeSummary {
  const StocktakeSummary({
    required this.linesCount,
    required this.countedCount,
    required this.diffsCount,
    required this.surplusValue,
    required this.shortageValue,
  });

  /// عدد أسطر الكشف (كل الأصناف غير الخدمية غير المؤرشفة).
  final int linesCount;

  /// عدد الأسطر المعدودة.
  final int countedCount;

  /// عدد أسطر الفروقات (المعدودة ذات فرق ≠ 0).
  final int diffsCount;

  /// قيمة الزيادات (موجبة دائماً).
  final double surplusValue;

  /// قيمة العجوزات (سالبة دائماً).
  final double shortageValue;

  /// صافي أثر الجرد المالي = زيادات + عجوزات (محسوباً — لا حقل ثابت
  /// حتى يبقى المنشئ const).
  double get netDiffValue => roundMoney(surplusValue + shortageValue);

  /// ملخص فارغ — لا أسطر.
  static const StocktakeSummary empty = StocktakeSummary(
    linesCount: 0,
    countedCount: 0,
    diffsCount: 0,
    surplusValue: 0,
    shortageValue: 0,
  );

  /// يبني الملخص فوق أسطر الكشف (بعدّها الاختياري).
  static StocktakeSummary of(List<StocktakeLineDraft> lines) {
    var counted = 0;
    var diffs = 0;
    var surplus = 0.0;
    var shortage = 0.0;
    for (final line in lines) {
      final diff = line.diff;
      if (diff == null) continue;
      counted++;
      if (diff.abs() <= kStocktakeQtyEps) continue;
      diffs++;
      final value = roundMoney(diff * line.unitCost);
      if (value > 0) {
        surplus = roundMoney(surplus + value);
      } else {
        shortage = roundMoney(shortage + value);
      }
    }
    return StocktakeSummary(
      linesCount: lines.length,
      countedCount: counted,
      diffsCount: diffs,
      surplusValue: surplus,
      shortageValue: shortage,
    );
  }
}

/// صف جرد في السجل — جرد واحد مكتمل.
class StocktakeHistoryRow {
  const StocktakeHistoryRow({
    required this.id,
    required this.countedAt,
    required this.totalDiff,
    required this.notes,
    required this.linesCount,
  });

  factory StocktakeHistoryRow.fromMap(Map<String, Object?> map) =>
      StocktakeHistoryRow(
        id: map['id'] as int,
        countedAt: map['counted_at'] as String?,
        totalDiff: (map['total_diff'] as num?)?.toDouble() ?? 0,
        notes: map['notes'] as String?,
        linesCount: (map['lines_count'] as num?)?.toInt() ?? 0,
      );

  /// معرّف الجرد.
  final int id;

  /// لحظة العدّ (ISO-UTC — بتاريخ المستخدم).
  final String? countedAt;

  /// صافي أثر الجرد المالي (بالعملة الأساسية).
  final double totalDiff;

  /// ملاحظات الجرد (تشمل اسم الجانِد — القرار 4 في الترحيل).
  final String? notes;

  /// عدد أسطر الجرد المخزَّنة.
  final int linesCount;
}
