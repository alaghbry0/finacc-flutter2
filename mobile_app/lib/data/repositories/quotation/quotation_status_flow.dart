/// حالات مستند عرض السعر (تعليم مُرسَلاً/إلغاء) — جزء من تقسيم R20-D3a
/// لمستودع عروض الأسعار (نمط R19-D3d): منقول حرفياً من
/// quotation_repository.dart — **المعاملة كاملة داخل هذا الملف الواحد
/// غير مشطورة** (الواجهة العامة والسلوك ثابتان — المستودع يفوِّض
/// بتواقيعه نفسها).
///
/// قرار منقول من رأس المستودع الأصلي: الإلغاء من draft/sent فقط —
/// **خرائط المخطط المجمد**: قيد CHECK على `quotation.status` لا يشمل
/// `cancelled`، فيُخزّن الإلغاء كـ `rejected` (أقرب دلالة متاحة بلا
/// هجرة) — الفرق الدلالي (إلغاء بيد البائع مقابل رفض العميل) يوثّق
/// في قيد التدقيق `quotation_cancel`.
library;

import 'package:sqflite/sqflite.dart';

import '../../../domain/core/result.dart';
import '../../../domain/models/quotation.dart';
import 'quotation_helpers.dart';

/// نقل حالة عرض السعر ذرّياً (تعليم مُرسَلاً/إلغاء) + قيد تدقيق —
/// حارس الحالة: لا نقل إلا من [from] المسموح.
Future<Result<Quotation, String>> quotationChangeStatus(
  Database db,
  int id, {
  required List<String> from,
  required QuotationStatus to,
  required String action,
  required int userId,
  DateTime? now,
}) async {
  final at = now ?? DateTime.now();
  final iso = at.toUtc().toIso8601String();
  try {
    return await db.transaction((txn) async {
      final updated = await txn.update(
        'quotation',
        {'status': to.code, 'updated_at': iso},
        where:
            'id = ? AND status IN (${List.filled(from.length, '?').join(',')})',
        whereArgs: [id, ...from],
      );
      if (updated == 0) {
        final rows = await txn.query(
          'quotation',
          columns: ['status'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (rows.isEmpty) return Err('عرض السعر رقم #$id غير موجود.');
        return Err(
          'لا يمكن نقل العرض من حالته الحالية '
          '«${rows.first['status']}» إلى «${to.code}».',
        );
      }
      await txn.insert('audit_log', {
        'user_id': userId,
        'action': action,
        'entity': 'quotation',
        'entity_id': id,
        'details': 'status=${to.code}',
        'at': iso,
      });
      final rows = await txn.query(
        'quotation',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return Ok<Quotation, String>(Quotation.fromRow(rows.first));
    });
  } on DatabaseException catch (e) {
    return Err(quotationDescribeDbError(e));
  }
}
