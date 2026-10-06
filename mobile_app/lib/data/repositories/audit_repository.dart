/// مستودع سجل التدقيق — قراءة صرفة من `audit_log` (FR-12-04).
///
/// السجل محمي بـ Triggers ضد التعديل والحذف من أي جهة — هذا المستودع
/// يعرضه فقط: ترتيب تنازلي بالزمن، صفحة بعد صفحة، مع اسم المنفّذ.
library;

import 'package:sqflite/sqflite.dart';

import '../../domain/models/audit_event.dart';

/// صفحة من أحداث التدقيق + الإجمالي (للترقيم).
class AuditPage {
  const AuditPage({
    required this.events,
    required this.totalCount,
    required this.hasMore,
  });

  final List<AuditEvent> events;
  final int totalCount;

  /// هل بقي المزيد بعد هذه الصفحة؟ (offset + طول الصفحة مقابل الإجمالي).
  final bool hasMore;
}

class AuditRepository {
  AuditRepository(this._db);

  final Database _db;

  /// يقرأ صفحة أحداث (الأحدث أولاً) مع إجمالي السجل.
  Future<AuditPage> page({int limit = 40, int offset = 0}) async {
    final rows = await _db.rawQuery(
      '''
      SELECT a.id AS a_id, a.action AS a_action, a.entity AS a_entity,
             a.entity_id AS a_entity_id, a.details AS a_details, a.at AS a_at,
             u.display_name AS u_name
      FROM audit_log AS a
      LEFT JOIN app_user AS u ON u.id = a.user_id
      ORDER BY a.at DESC, a.id DESC
      LIMIT ? OFFSET ?
    ''',
      [limit, offset],
    );
    final countRows = await _db.rawQuery('SELECT COUNT(*) AS n FROM audit_log');
    final total = (countRows.first['n'] as int?) ?? 0;
    return AuditPage(
      events: rows
          .map(
            (r) => AuditEvent(
              id: r['a_id'] as int,
              action: r['a_action'] as String,
              entity: r['a_entity'] as String?,
              entityId: r['a_entity_id'] as int?,
              details: r['a_details'] as String?,
              atUtc: DateTime.parse(r['a_at'] as String),
              userName: r['u_name'] as String?,
            ),
          )
          .toList(),
      totalCount: total,
      hasMore: offset + rows.length < total,
    );
  }
}
