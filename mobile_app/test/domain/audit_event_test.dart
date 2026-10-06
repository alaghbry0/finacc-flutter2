/// اختبارات نموذج حدث التدقيق — التصنيف العرضي والتوقيت المحلي.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/domain/models/audit_event.dart';

void main() {
  AuditEvent event(String action) =>
      AuditEvent(id: 1, action: action, atUtc: DateTime.utc(2026, 10, 6, 12));

  test('التصنيف: app_setup → setup', () {
    expect(event('app_setup').category, AuditCategory.setup);
  });

  test('التصنيف: أحداث الأمان (تغيير PIN/التأخير/عبارة المرور) → security', () {
    expect(event('pin_change').category, AuditCategory.security);
    expect(event('pin_lockout_delay').category, AuditCategory.security);
    expect(event('pin_lockout_passphrase').category, AuditCategory.security);
  });

  test('التصنيف: settings_change → settings وغير المعروف → other', () {
    expect(event('settings_change').category, AuditCategory.settings);
    expect(event('backup_run').category, AuditCategory.other);
    expect(event('whatever_new').category, AuditCategory.other);
    expect(
      event('login').category,
      AuditCategory.other,
      reason: 'login غير مدرج في التصنيف الأمني الحالي — other',
    );
  });

  test('atLocal يحول UTC إلى توقيت الجهاز', () {
    final e = AuditEvent(
      id: 2,
      action: 'login',
      atUtc: DateTime.utc(2026, 10, 6, 12),
    );
    expect(e.atLocal, e.atUtc.toLocal());
    expect(e.atLocal.isUtc, isFalse);
  });

  test('الحقول الاختيارية تمر كما هي', () {
    final e = AuditEvent(
      id: 3,
      action: 'settings_change',
      entity: 'settings',
      entityId: null,
      details: 'security.autolock_minutes=15',
      userName: 'أبو نور',
      atUtc: DateTime.utc(2026, 10, 6, 9),
    );
    expect(e.entity, 'settings');
    expect(e.details, 'security.autolock_minutes=15');
    expect(e.userName, 'أبو نور');
  });
}
