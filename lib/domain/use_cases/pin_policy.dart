/// سياسة قفل رمز PIN — SRS FR-12-06 / سيناريو القبول AC-15.
///
/// القواعد الملزمة:
/// - بعد **5 محاولات خاطئة**: تأخير متصاعد (30 ثانية → 15 دقيقة).
/// - بعد **10 محاولات خاطئة**: مطالبة بعبارة المرور.
/// - فشل عبارة المرور: خيار مسح كامل بتأكيد مزدوج (+ قيد audit لكل مرحلة).
/// - نجاح أي مسار تحقق: تصفير العدّاد وإزالة القفل.
library;

import '../services/pin_hasher.dart';

/// حالة بوابة PIN أمام مستخدم يحاول الدخول الآن.
enum PinGateStatus {
  /// البوابة مفتوحة — يمكن إدخال PIN.
  open,

  /// مؤقتة انتظار بعد محاولات خاطئة (تُعرض عدّاداً تنازلياً).
  delayed,

  /// عشر محاولات خاطئة — لا PIN؛ عبارة المرور إلزامية.
  passphraseRequired,
}

/// حاسبة سياسة القفل (نقية — قابلة للاختبار بمعزل عن التخزين).
class PinPolicy {
  const PinPolicy._();

  /// أول محاولة يبدأ بعدها التأخير.
  static const int delayThreshold = 5;

  /// المحاولة التي تتحول بعدها البوابة لعبارة المرور.
  static const int passphraseThreshold = 10;

  /// أقصى انتظار في الجدول المتدرج.
  static const Duration maxScheduledDelay = Duration(minutes: 15);

  /// مدة الانتظار بعد المحاولة الخاطئة رقم [failedAttempts].
  ///
  /// - أقل من 5: لا انتظار (محاولة عادية).
  /// - 5 → 30 ثانية، 6 → دقيقتان، 7 → 5 دقائق، 8 → 10 دقائق، 9 → 15 دقيقة.
  /// - 10 فأكثر: لا جدول زمني — البوابة على عبارة المرور.
  static Duration? lockoutDelay(int failedAttempts) {
    if (failedAttempts < delayThreshold) return null;
    if (failedAttempts >= passphraseThreshold) return null;
    return switch (failedAttempts) {
      5 => const Duration(seconds: 30),
      6 => const Duration(minutes: 2),
      7 => const Duration(minutes: 5),
      8 => const Duration(minutes: 10),
      _ => const Duration(minutes: 15),
    };
  }

  /// اللحظة التي تُقفل عندها البوابة بعد محاولة خاطئة رقم [failedAttempts].
  static DateTime? lockedUntilAfter(int failedAttempts, DateTime now) {
    final delay = lockoutDelay(failedAttempts);
    if (delay == null) return null;
    return now.add(delay);
  }

  /// حالة البوابة الآن.
  static PinGateStatus statusFor({
    required int failedAttempts,
    required DateTime now,
    required DateTime? lockedUntil,
  }) {
    if (failedAttempts >= passphraseThreshold) {
      return PinGateStatus.passphraseRequired;
    }
    if (lockedUntil != null && now.isBefore(lockedUntil)) {
      return PinGateStatus.delayed;
    }
    return PinGateStatus.open;
  }

  /// الوقت المتبقي من الانتظار (صفر إن لا انتظار فعلياً).
  static Duration remainingDelay({
    required DateTime now,
    required DateTime? lockedUntil,
  }) {
    if (lockedUntil == null) return Duration.zero;
    if (!now.isBefore(lockedUntil)) return Duration.zero;
    return lockedUntil.difference(now);
  }

  /// تحقق صلاحية شكل PIN (4–6 خانات رقمية) — تفويض إلى [PinHasher].
  static bool isValidPinFormat(String pin) => PinHasher.isValidPinFormat(pin);
}
