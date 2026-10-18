/// أنواع الوردية النقية (الصف/المعادلة الشاملة/ناتج الإقفال) — جزء من
/// تقسيم R20-D3a لمستودع الوردية (نمط R19-D3d): منقولة حرفياً من
/// shift_repository.dart — المستودع يُصدِّرها من هنا فكل استيراداته
/// التاريخية تحل كما كانت.
///
/// ## المعادلة الشاملة (SRS حرفياً):
/// المتوقع = رصيد افتتاحي + Σ الوارد خلال النافذة − Σ الصادر:
/// - **وارد (+)**: مبيعات نقدية + تحصيلات + إيداعات مالك + تحويلات
///   واردة + إيداعات بنكية + شيكات محصّلة.
/// - **صادر (−)**: مدفوعات موردين + مصاريف + مسحوبات مالك + تحويلات
///   صادرة + سحب بنكي + شيكات مصروفة محصّلة.
///
/// **الشيكات مؤجلة لوحدة V1.1 (§11)**: `chequesCleared`/`chequesPaid`
/// = 0 دائماً في V1 — تظهر صفرية في الواجهة والتقرير (القرار 3 من رأس
/// المستودع الأصلي — منقول هنا لأن حقوله في [ShiftEquation]).
library;

import '../../../domain/services/purchase_pricing.dart' show roundMoney;

/// صف الوردية — مرآة جدول `shift` في المخطط (لا تعديل عليه).
class ShiftRow {
  const ShiftRow({
    required this.id,
    required this.cashboxId,
    this.userId,
    required this.openedAt,
    this.closedAt,
    this.openingCount,
    this.expected,
    this.counted,
    this.difference,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory ShiftRow.fromMap(Map<String, Object?> map) => ShiftRow(
    id: map['id'] as int,
    cashboxId: map['cashbox_id'] as int,
    userId: map['user_id'] as int?,
    openedAt: map['opened_at'] as String,
    closedAt: map['closed_at'] as String?,
    openingCount: (map['opening_count'] as num?)?.toDouble(),
    expected: (map['expected'] as num?)?.toDouble(),
    counted: (map['counted'] as num?)?.toDouble(),
    difference: (map['difference'] as num?)?.toDouble(),
    notes: map['notes'] as String?,
    createdAt: map['created_at'] as String?,
    updatedAt: map['updated_at'] as String?,
  );

  final int id;
  final int cashboxId;
  final int? userId;
  final String openedAt;
  final String? closedAt;
  final double? openingCount;
  final double? expected;
  final double? counted;
  final double? difference;
  final String? notes;
  final String? createdAt;
  final String? updatedAt;

  /// هل الوردية ما تزال مفتوحة؟
  bool get isOpen => closedAt == null;

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'cashbox_id': cashboxId,
    'user_id': userId,
    'opened_at': openedAt,
    'closed_at': closedAt,
    'opening_count': openingCount,
    'expected': expected,
    'counted': counted,
    'difference': difference,
    'notes': notes,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}

/// بنود المعادلة الشاملة — كل مكون **بعملة الصندوق** (دلو nativeBalance).
///
/// مكونات الوارد والصادر قيم موجبة (مقادير)، و`other` موقعي صافٍ
/// (موجب = صافي وارد) — انظر القرار 4 برأس ملف التدفق.
class ShiftEquation {
  const ShiftEquation({
    required this.cashSales,
    required this.collections,
    required this.ownerDeposits,
    required this.transfersIn,
    required this.bankIn,
    required this.chequesCleared,
    required this.supplierPayments,
    required this.expenses,
    required this.ownerDraws,
    required this.transfersOut,
    required this.bankOut,
    required this.chequesPaid,
    required this.other,
  });

  /// معادلة صفرية — وردية بلا أي حركة.
  const ShiftEquation.empty()
    : cashSales = 0,
      collections = 0,
      ownerDeposits = 0,
      transfersIn = 0,
      bankIn = 0,
      chequesCleared = 0,
      supplierPayments = 0,
      expenses = 0,
      ownerDraws = 0,
      transfersOut = 0,
      bankOut = 0,
      chequesPaid = 0,
      other = 0;

  /// مبيعات نقدية — سندات قبض فواتير البيع وقت الإصدار.
  final double cashSales;

  /// تحصيلات — سندات قبض العملاء (FIFO/على الحساب).
  final double collections;

  /// إيداعات المالك (`capital_in`).
  final double ownerDeposits;

  /// تحويلات واردة — ساق الهدف لكل ذات الساقين (بعملة الهدف).
  final double transfersIn;

  /// إيداعات بنكية — دائماً 0 في V1: **لا عمود بنك في جدول cashbox**
  /// فالساقات البنكية مدمجة في [transfersIn] (القرار 2 برأس ملف التدفق).
  final double bankIn;

  /// شيكات محصّلة — مؤجلة إلى V1.1 (وحدة الشيكات §11) — دائماً 0.
  final double chequesCleared;

  /// مدفوعات موردين (`payment` غير مرتبطة بردّ مرتجع بيع).
  final double supplierPayments;

  /// مصاريف (`expense`).
  final double expenses;

  /// مسحوبات المالك (`owner_draw`).
  final double ownerDraws;

  /// تحويلات صادرة — ساق المصدر لكل ذات الساقين (بعملة المصدر).
  final double transfersOut;

  /// سحب بنكي — دائماً 0 في V1: مدمج في [transfersOut] (القرار 2).
  final double bankOut;

  /// شيكات مصروفة محصّلة — مؤجلة إلى V1.1 — دائماً 0.
  final double chequesPaid;

  /// استردادات مرتجعات الشراء النقدية (+) وردود مرتجعات البيع (−)
  /// وأنواع الرواتب المؤجلة (−) — موقعاً صافياً حتى لا يختفي شيء من
  /// المعادلة الشاملة (القرار 4).
  final double other;

  /// إجمالي الوارد (مقادير موجبة).
  double get totalIn =>
      cashSales +
      collections +
      ownerDeposits +
      transfersIn +
      bankIn +
      chequesCleared;

  /// إجمالي الصادر (مقادير موجبة).
  double get totalOut =>
      supplierPayments +
      expenses +
      ownerDraws +
      transfersOut +
      bankOut +
      chequesPaid;

  /// صافي التدفق المتوقع خلال النافذة = Σ الوارد − Σ الصادر + أخرى.
  double get expectedDelta => roundMoney(totalIn - totalOut + other);
}

/// ناتج الإقفال — الصف المحدَّث + المعادلة التي أُقفل عليها.
class ShiftCloseResult {
  const ShiftCloseResult({required this.shift, required this.equation});

  /// صف الوردية بعد الإقفال (expected/counted/difference مسجَّلة).
  final ShiftRow shift;

  /// المعادلة لحظة الإقفال (نافذة [opened_at, closed_at]).
  final ShiftEquation equation;
}
