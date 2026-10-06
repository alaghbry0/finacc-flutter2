/// مستودع المستخدم والأمان — جداول `app_user` و`audit_log` (§5.3).
///
/// يملك التحقق من PIN وفق سياسة القفل الكاملة (FR-12-06 / AC-15):
/// العدّاد، التأخير المتصاعد، التحويل لعبارة المرور بعد 10 محاولات،
/// والتصفير عند النجاح — كل تحقق بحد ذاته ذرّي (قراءة + كتابة عدّاد).
library;

import 'package:sqflite/sqflite.dart';

import '../../domain/services/pin_hasher.dart';
import '../../domain/use_cases/pin_policy.dart';
import 'settings_repository.dart';

/// نتيجة محاولة إدخال PIN.
enum PinVerifyOutcome {
  /// PIN صحيح — فُتح التطبيق وصُفّر العدّاد.
  success,

  /// PIN خاطئ — زاد العدّاد (وقد يبدأ بعده تأخير).
  wrong,

  /// داخل نافذة انتظار — لا يقبل PIN الآن.
  delayed,

  /// عشر محاولات خاطئة — عبارة المرور إلزامية.
  passphraseRequired,
}

class UserRepository {
  UserRepository(this._db, {SettingsRepository? settingsRepository})
    : _settings = settingsRepository ?? SettingsRepository(_db);

  final Database _db;
  final SettingsRepository _settings;

  /// هل ضُبط PIN للمدير؟ (بعد Onboarding دائماً).
  Future<bool> hasPin() async {
    final rows = await _db.rawQuery(
      'SELECT EXISTS(SELECT 1 FROM app_user WHERE pin_hash IS NOT NULL) AS ok',
    );
    return (rows.first['ok'] as int) == 1;
  }

  /// يحاول إدخال PIN — يحدّث العدّاد والقفل ذرّياً ويعيد الحالة.
  Future<PinVerifyOutcome> verifyPin(String pin, {DateTime? now}) async {
    final at = (now ?? DateTime.now());
    return _db.transaction((txn) async {
      final rows = await txn.query(
        'app_user',
        where: "role = 'admin' AND is_active = 1",
        limit: 1,
      );
      if (rows.isEmpty || (rows.first['pin_hash'] as String?) == null) {
        return PinVerifyOutcome.passphraseRequired;
      }
      final userId = rows.first['id'] as int;
      final storedHash = rows.first['pin_hash'] as String;
      final failedAttempts = (rows.first['failed_attempts'] as int?) ?? 0;
      final lockedUntilText = rows.first['locked_until'] as String?;

      // داخل نافذة انتظار؟ لا نستهلك محاولة.
      final status = PinPolicy.statusFor(
        failedAttempts: failedAttempts,
        now: at,
        lockedUntil: lockedUntilText == null
            ? null
            : DateTime.tryParse(lockedUntilText),
      );
      if (status == PinGateStatus.delayed) return PinVerifyOutcome.delayed;
      if (status == PinGateStatus.passphraseRequired) {
        return PinVerifyOutcome.passphraseRequired;
      }

      if (PinHasher.verify(pin, storedHash)) {
        // نجاح: تصفير العدّاد + تسجيل الدخول الأخير.
        await txn.update(
          'app_user',
          {
            'failed_attempts': 0,
            'locked_until': null,
            'last_login_at': at.toUtc().toIso8601String(),
            'updated_at': at.toUtc().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [userId],
        );
        return PinVerifyOutcome.success;
      }

      // خاطئ: زيادة العدّاد وضبط القفل إن بلغ العتبة.
      final newAttempts = failedAttempts + 1;
      final lockedUntil = PinPolicy.lockedUntilAfter(newAttempts, at);
      await txn.update(
        'app_user',
        {
          'failed_attempts': newAttempts,
          'locked_until': lockedUntil?.toUtc().toIso8601String(),
          'updated_at': at.toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [userId],
      );
      // قيد audit عند بلوغ عتبات السياسة (AC-15: قيد لكل مرحلة).
      if (newAttempts == PinPolicy.delayThreshold ||
          newAttempts == PinPolicy.passphraseThreshold) {
        await txn.insert('audit_log', {
          'user_id': userId,
          'action': newAttempts == PinPolicy.passphraseThreshold
              ? 'pin_lockout_passphrase'
              : 'pin_lockout_delay',
          'entity': 'app_user',
          'entity_id': userId,
          'details': 'attempts=$newAttempts',
          'at': at.toUtc().toIso8601String(),
        });
      }
      if (newAttempts >= PinPolicy.passphraseThreshold) {
        return PinVerifyOutcome.passphraseRequired;
      }
      return PinVerifyOutcome.wrong;
    });
  }

  /// يتحقق من عبارة المرور (قفل 10 محاولات — AC-15).
  Future<bool> verifyPassphrase(String passphrase) async {
    final stored = await _settings.passphraseHash();
    if (stored == null) return false;
    return PinHasher.verify(passphrase, stored);
  }

  /// يصفّر عدّاد PIN بعد نجاح عبارة المرور (استرداد الوصول).
  Future<void> resetLockout({DateTime? now}) async {
    final at = (now ?? DateTime.now()).toUtc().toIso8601String();
    await _db.update('app_user', {
      'failed_attempts': 0,
      'locked_until': null,
      'updated_at': at,
    }, where: "role = 'admin'");
  }

  /// قيد تدقيق عام (الإضافة فقط — محمي بـ triggers داخل الملف).
  Future<void> audit(
    String action, {
    String? entity,
    int? entityId,
    String? details,
    int? userId,
    DateTime? at,
  }) async {
    await _db.insert('audit_log', {
      'user_id': userId,
      'action': action,
      'entity': entity,
      'entity_id': entityId,
      'details': details,
      'at': (at ?? DateTime.now()).toUtc().toIso8601String(),
    });
  }

  /// الإدارة الحالية (اسم العرض للترحيب).
  Future<String?> adminDisplayName() async {
    final rows = await _db.query(
      'app_user',
      columns: ['display_name'],
      where: "role = 'admin'",
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['display_name'] as String?;
  }

  /// عدّاد المحاولات الخاطئة الحالية للمدير (لعرض شاشة القفل).
  Future<int> currentFailedAttempts() async {
    final rows = await _db.query(
      'app_user',
      columns: ['failed_attempts'],
      where: "role = 'admin'",
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return (rows.first['failed_attempts'] as int?) ?? 0;
  }

  /// لحظة انتهاء نافذة الانتظار الحالية (إن وُجدت).
  Future<DateTime?> currentLockedUntil() async {
    final rows = await _db.query(
      'app_user',
      columns: ['locked_until'],
      where: "role = 'admin'",
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final text = rows.first['locked_until'] as String?;
    if (text == null) return null;
    return DateTime.tryParse(text);
  }
}
