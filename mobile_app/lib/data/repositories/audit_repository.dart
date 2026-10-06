/// مستودع سجل التدقيق — قراءة صرفة من `audit_log` (FR-12-04).
///
/// السجل محمي بـ Triggers ضد التعديل والحذف من أي جهة — هذا المستودع
/// يعرضه فقط: ترتيب تنازلي بالزمن، صفحة بعد صفحة، مع اسم المنفّذ،
/// وتصفية اختيارية بالتصنيف العرضي (أمني/إعدادات/تأسيس/أخرى).
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

/// مستودع القراءة الحصرية لسجل التدقيق.
class AuditRepository {
  AuditRepository(this._db);

  final Database _db;

  /// رموز الأحداث المعروفة لكل تصنيف (يطابق `AuditEvent.category`).
  static const Map<AuditCategory, List<String>> _categoryActions = {
    AuditCategory.setup: ['app_setup'],
    AuditCategory.security: [
      'pin_change',
      'pin_lockout_delay',
      'pin_lockout_passphrase',
    ],
    AuditCategory.settings: ['settings_change'],
  };

  /// كل الرموز المعروفة (لتعريف «أخرى» بالنفي).
  static const List<String> _knownActions = [
    'app_setup',
    'pin_change',
    'pin_lockout_delay',
    'pin_lockout_passphrase',
    'settings_change',
  ];

  /// يقرأ صفحة أحداث (الأحدث أولاً) مع إجمالي السجل — بتصفية اختيارية.
  Future<AuditPage> page({
    int limit = 40,
    int offset = 0,
    AuditCategory? category,
  }) async {
    final where = _whereFor(category);
    final rows = await _db.rawQuery(
      '''
      SELECT a.id AS a_id, a.action AS a_action, a.entity AS a_entity,
             a.entity_id AS a_entity_id, a.details AS a_details, a.at AS a_at,
             u.display_name AS u_name
      FROM audit_log AS a
      LEFT JOIN app_user AS u ON u.id = a.user_id
      $where
      ORDER BY a.at DESC, a.id DESC
      LIMIT ? OFFSET ?
    ''',
      [limit, offset],
    );
    final countRows = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM audit_log AS a $where',
    );
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

  /// عدّادات الأحداث لكل تصنيف (شارات التصفية) + الإجمالي.
  Future<Map<AuditCategory, int>> counts() async {
    final rows = await _db.rawQuery('''
      SELECT CASE
        WHEN action = 'app_setup' THEN 0
        WHEN action IN ('pin_change','pin_lockout_delay','pin_lockout_passphrase') THEN 1
        WHEN action = 'settings_change' THEN 2
        ELSE 3
      END AS cat, COUNT(*) AS n
      FROM audit_log GROUP BY cat
    ''');
    const byIndex = {
      0: AuditCategory.setup,
      1: AuditCategory.security,
      2: AuditCategory.settings,
      3: AuditCategory.other,
    };
    return {
      for (final row in rows)
        byIndex[row['cat'] as int] ?? AuditCategory.other:
            (row['n'] as int?) ?? 0,
    };
  }

  /// شرط WHERE المطابق للتصنيف (فارغ = الكل).
  ///
  /// القيم ثوابت مصدرية (لا مدخلات مستخدم) فالدمج النصي آمن.
  static String _whereFor(AuditCategory? category) {
    if (category == null) return '';
    if (category == AuditCategory.other) {
      return 'WHERE a.action NOT IN '
          "(${_knownActions.map((a) => "'$a'").join(', ')})";
    }
    final actions = _categoryActions[category]!;
    return 'WHERE a.action IN (${actions.map((a) => "'$a'").join(', ')})';
  }
}
