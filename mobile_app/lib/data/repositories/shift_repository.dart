/// مستودع الوردية (FR-04-04 — الشريحة 9): فتح/إقفال الوردية بالمعادلة
/// الشاملة على جدول `shift` القائم في المخطط.
///
/// وحدات التنفيذ مستخرجة إلى `shift/` بجواره (R20-D3a — نمط تقسيم
/// R19-D3d): الأنواع النقية وقرارات الشيكات المؤجلة
/// (`shift_models.dart` — تُصدَّر من هنا فكل استيرادات المستوردين
/// التاريخية تحل كما كانت) وقراءات الوردية والمعادلة الشاملة بقراراتها
/// المعمارية (`shift_queries.dart`) وتدفقات الفتح/الإقفال بمعاملاتهما
/// **الكاملة داخل ملف واحد غير مشطورة** (`shift_flow.dart`) — هذا الصنف
/// واجهة تفويض رقيقة بتواقيعه العامة نفسها.
library;

import 'package:sqflite/sqflite.dart';

import '../../domain/core/result.dart';
import 'shift/shift_flow.dart';
import 'shift/shift_models.dart';
import 'shift/shift_queries.dart';

export 'shift/shift_models.dart';

/// مستودع الوردية — فتح/إقفال/معادلة/سجل، فوق قاعدة مفتوحة.
class ShiftRepository {
  ShiftRepository(Database db) : _db = db;

  final Database _db;

  // ─────────────────────────────────────────────────────────────────────
  // دورة الحياة (FR-04-04)
  // ─────────────────────────────────────────────────────────────────────

  /// يفتح وردية على الصندوق برصيد افتتاحي مُعدّ (افتراضي 0) — حارس
  /// الرفض: وردية مفتوحة قائمة على نفس الصندوق.
  Future<Result<ShiftRow, String>> openShift({
    required int cashboxId,
    double? openingCount,
    int? userId,
  }) async => openShiftFlow(
    _db,
    cashboxId: cashboxId,
    openingCount: openingCount,
    userId: userId,
  );

  /// الوردية المفتوحة على الصندوق — `null` إن لا توجد.
  Future<ShiftRow?> currentShift(int cashboxId) async =>
      currentShiftOnBox(_db, cashboxId);

  /// صف وردية بمعرّفها — `null` إن لم توجد.
  Future<ShiftRow?> shiftById(int id) async => shiftRowById(_db, id);

  /// آخر الورديات المقفلة على الصندوق (الأحدث أولاً).
  Future<List<ShiftRow>> recentShifts({
    required int cashboxId,
    int limit = 20,
  }) async => recentClosedShifts(_db, cashboxId: cashboxId, limit: limit);

  // ─────────────────────────────────────────────────────────────────────
  // المعادلة الشاملة (FR-04-04)
  // ─────────────────────────────────────────────────────────────────────

  /// يحسب المعادلة الشاملة لصندوق خلال نافذة [fromIso, toIso] (سلاسل
  /// ISO-UTC) — بعملة الصندوق، مع استبعاد الملغاة/المعاكسة/الافتتاحية
  /// (القرارات 1/3/4 برأس shift_queries.dart).
  Future<ShiftEquation> equationFor({
    required int cashboxId,
    required String fromIso,
    required String toIso,
  }) async => shiftEquationFor(
    _db,
    cashboxId: cashboxId,
    fromIso: fromIso,
    toIso: toIso,
  );

  /// يُقفل الوردية ذرّياً داخل معاملة واحدة: يحسب المعادلة على نافذة
  /// [opened_at, الآن] ثم يحدّث expected/counted/difference/notes
  /// ويكتب قيد التدقيق — فشل أي خطوة يتراجع الكل.
  ///
  /// المتوقع = الرصيد الافتتاحي + Σ الوارد − Σ الصادر (+ أخرى الموقعية)،
  /// والفرق = المعدود − المتوقع (زيادة/عجز — القرار 6 برأس shift_flow).
  Future<Result<ShiftCloseResult, String>> closeShift({
    required int shiftId,
    required double counted,
    String? notes,
  }) async =>
      closeShiftFlow(_db, shiftId: shiftId, counted: counted, notes: notes);
}
