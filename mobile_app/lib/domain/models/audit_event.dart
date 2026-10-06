/// نموذج حدث التدقيق — صف من `audit_log` (§5.3 / FR-12-04).
///
/// السجل للإضافة فقط (Triggers تمنع UPDATE/DELETE داخل ملف القاعدة) —
/// هذا النموذج للعرض الحصري في «سجل التدقيق» (قراءة صرفة).
library;

/// تصنيف الحدث للعرض (أيقونة/لون/عنوان موحّدان لكل تصنيف).
enum AuditCategory { setup, security, settings, other }

/// حدث تدقيق واحد كما يُعرض في السجل.
class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.action,
    required this.atUtc,
    this.entity,
    this.entityId,
    this.details,
    this.userName,
  });

  final int id;

  /// رمز الحدث الخام كما خُزِّن (`app_setup`، `pin_change`، …).
  final String action;

  /// لحظة الحدث (UTC — ISO 8601 كما في القاعدة).
  final DateTime atUtc;

  /// الجدول المتأثر (`company`، `app_user`، …).
  final String? entity;

  /// معرّف الصف المتأثر.
  final int? entityId;

  /// تفاصيل إضافية خام (مثل `attempts=5` أو مفتاح=قيمة).
  final String? details;

  /// اسم المستخدم المنفّذ (JOIN اختياري — قد يكون فارغاً).
  final String? userName;

  /// التصنيف العرضي المشتق من رمز الحدث.
  AuditCategory get category => switch (action) {
    'app_setup' => AuditCategory.setup,
    'pin_change' ||
    'pin_lockout_delay' ||
    'pin_lockout_passphrase' => AuditCategory.security,
    'settings_change' => AuditCategory.settings,
    _ => AuditCategory.other,
  };

  /// نسخة للعرض بالتوقيت المحلي (المبالغ والأوقات محلية دائماً).
  DateTime get atLocal => atUtc.toLocal();
}
