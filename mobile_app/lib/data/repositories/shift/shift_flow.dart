/// تدفقات دورة حياة الوردية (فتح/إقفال) — جزء من تقسيم R20-D3a لمستودع
/// الوردية (نمط R19-D3d): منقولة حرفياً من shift_repository.dart —
/// **كل معاملة db.transaction كاملة داخل هذا الملف الواحد غير مشطورة**
/// (الواجهة العامة والسلوك ثابتان — المستودع يفوِّض بتواقيعه نفسها).
///
/// **الفارق** عند الإقفال = المعدود − المتوقع (موجب = زيادة، سالب = عجز)
/// — يُسجَّل ولا يُمنع شيء أبداً (نفس فلسفة الرصيد السالب FR-04-09 —
/// القرار 6 من رأس المستودع الأصلي، منقول هنا لأنه سلوك الإقفال).
library;

import 'package:sqflite/sqflite.dart';

import '../../../domain/core/result.dart';
import '../../../domain/services/purchase_pricing.dart' show roundMoney;
import 'shift_models.dart';
import 'shift_queries.dart';

/// يفتح وردية على الصندوق برصيد افتتاحي مُعدّ (افتراضي 0) — حارس
/// الرفض: وردية مفتوحة قائمة على نفس الصندوق.
Future<Result<ShiftRow, String>> openShiftFlow(
  Database db, {
  required int cashboxId,
  double? openingCount,
  int? userId,
}) async {
  try {
    final at = DateTime.now().toUtc().toIso8601String();
    return await db.transaction((txn) async {
      final open = await txn.query(
        'shift',
        columns: ['id'],
        where: 'cashbox_id = ? AND closed_at IS NULL',
        whereArgs: [cashboxId],
        limit: 1,
      );
      if (open.isNotEmpty) {
        return const Err(
          'توجد وردية مفتوحة على هذا الصندوق بالفعل — أقفلها قبل فتح '
          'وردية جديدة.',
        );
      }
      final id = await txn.insert('shift', {
        'cashbox_id': cashboxId,
        'user_id': userId,
        'opened_at': at,
        'opening_count': openingCount ?? 0,
        'created_at': at,
        'updated_at': at,
      });
      await txn.insert('audit_log', {
        'user_id': userId,
        'action': 'shift_open',
        'entity': 'shift',
        'entity_id': id,
        'details': 'box=$cashboxId opening=${openingCount ?? 0}',
        'at': at,
      });
      return Ok<ShiftRow, String>(
        ShiftRow(
          id: id,
          cashboxId: cashboxId,
          userId: userId,
          openedAt: at,
          openingCount: openingCount ?? 0,
          createdAt: at,
          updatedAt: at,
        ),
      );
    });
  } on DatabaseException catch (e) {
    return Err(_describeDbError(e, 'فتح الوردية'));
  }
}

/// يُقفل الوردية ذرّياً داخل معاملة واحدة: يحسب المعادلة على نافذة
/// [opened_at, الآن] ثم يحدّث expected/counted/difference/notes
/// ويكتب قيد التدقيق — فشل أي خطوة يتراجع الكل.
///
/// المتوقع = الرصيد الافتتاحي + Σ الوارد − Σ الصادر (+ أخرى الموقعية)،
/// والفرق = المعدود − المتوقع (زيادة/عجز — القرار 6 برأس الملف).
Future<Result<ShiftCloseResult, String>> closeShiftFlow(
  Database db, {
  required int shiftId,
  required double counted,
  String? notes,
}) async {
  if (counted.isNaN || counted.isInfinite) {
    return const Err('المبلغ المعدود غير صالح — أدخل رقماً صحيحاً.');
  }
  try {
    return await db.transaction((txn) async {
      final rows = await txn.query(
        'shift',
        where: 'id = ?',
        whereArgs: [shiftId],
        limit: 1,
      );
      if (rows.isEmpty) {
        return Err('الوردية رقم #$shiftId غير موجودة.');
      }
      final current = ShiftRow.fromMap(rows.first);
      if (current.isOpen) {
        final now = _nowIso();
        final equation = await shiftEquationFor(
          txn,
          cashboxId: current.cashboxId,
          fromIso: current.openedAt,
          toIso: now,
        );
        final opening = current.openingCount ?? 0;
        final expected = roundMoney(opening + equation.expectedDelta);
        final difference = roundMoney(counted - expected);
        final cleanNotes = (notes ?? '').trim();
        final updated = await txn.update(
          'shift',
          {
            'closed_at': now,
            'expected': expected,
            'counted': roundMoney(counted),
            'difference': difference,
            'notes': cleanNotes.isEmpty ? null : cleanNotes,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [shiftId],
        );
        if (updated == 0) {
          return const Err('تعذّر إقفال الوردية — أعد المحاولة.');
        }
        await txn.insert('audit_log', {
          'user_id': current.userId,
          'action': 'shift_close',
          'entity': 'shift',
          'entity_id': shiftId,
          'details':
              'box=${current.cashboxId} expected=$expected '
              'counted=${roundMoney(counted)} difference=$difference',
          'at': now,
        });
        return Ok<ShiftCloseResult, String>(
          ShiftCloseResult(
            shift: ShiftRow(
              id: current.id,
              cashboxId: current.cashboxId,
              userId: current.userId,
              openedAt: current.openedAt,
              closedAt: now,
              openingCount: opening,
              expected: expected,
              counted: roundMoney(counted),
              difference: difference,
              notes: cleanNotes.isEmpty ? null : cleanNotes,
              createdAt: current.createdAt,
              updatedAt: now,
            ),
            equation: equation,
          ),
        );
      }
      return const Err('هذه الوردية مقفلة مسبقاً — لا تُقفل مرتين.');
    });
  } on DatabaseException catch (e) {
    return Err(_describeDbError(e, 'إقفال الوردية'));
  }
}

// ─────────────────────────────────────────────────────────────────────
// مساعدات خاصة
// ─────────────────────────────────────────────────────────────────────

String _nowIso() => DateTime.now().toUtc().toIso8601String();

String _describeDbError(DatabaseException e, String action) {
  if (e.isUniqueConstraintError()) {
    return 'قيمة مكررة تخالف قيد التفرد أثناء $action';
  }
  if (e.toString().toUpperCase().contains('CHECK')) {
    return 'قيمة تخالف قيد سلامة محاسبي في القاعدة أثناء $action';
  }
  return 'تعذر $action في القاعدة: $e';
}
