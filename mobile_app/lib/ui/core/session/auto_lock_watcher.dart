/// مراقب القفل التلقائي بعد الخمول (FR-12-05 — `security.autolock_minutes`).
///
/// فصل R20-D1 (الفرصة 1 من تحليل R19-D1): المؤقّت الدوري (كل 15 ثانية)
/// ولحظة آخر نشاط وعلم اختفاء التطبيق ومدة القفل — وحدة واحدة يملكها
/// `AppController` بدل أربعة حقول متفرقة به.
///
/// الجلسة (الطور و`notifyListeners`) تبقى عند `AppController` حصراً —
/// المراقب يستقبل حالة الجاهزية وفعل القفل نداءين محقونين فلا يعرف
/// شيئاً عن الأطوار أو الإخطار، ولا يستورد أي Flutter.
library;

import 'dart:async';

/// يراقب الخمول ويطلب القفل عند بلوغ المدة المحددة.
class AutoLockWatcher {
  /// [isSessionReady] تُقرأ لحظة كل فحص (الجلسة جاهزة؟) و[onLock] فعل
  /// القفل عند بلوغ الحد — كلاهما يملكه المتحكم المستضيف.
  AutoLockWatcher({required this.isSessionReady, required this.onLock});

  /// هل الجلسة جاهزة؟ — يُقرأ لحظة كل فحص.
  final bool Function() isSessionReady;

  /// فعل القفل عند بلوغ الحد.
  final void Function() onLock;

  DateTime _lastActivity = DateTime.now();
  DateTime? _hiddenAt;
  Timer? _idleTicker;
  int _autolockMinutes = 5;

  /// مدة القفل التلقائي الحالية بالدقائق.
  int get autolockMinutes => _autolockMinutes;

  /// يثبّت المدة (بلا تحقق — التحقق من النطاق والاستمرار في القاعدة
  /// عند `AppController.setAutolockMinutes`).
  void setAutolockMinutes(int minutes) {
    _autolockMinutes = minutes;
  }

  /// لحظة آخر نشاط (يجدّدها [touch]).
  DateTime get lastActivity => _lastActivity;

  /// لمس أي عنصر — تجديد النشاط.
  void touch() {
    _lastActivity = DateTime.now();
  }

  /// يبدأ المراقبة الدورية (كل 15 ثانية) — يلغي أي مؤقّت سابق أولاً؛
  /// يُستدعى عند دخول الجلسة (unlock/إتمام التأسيس).
  void startWatch() {
    _idleTicker?.cancel();
    _idleTicker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!isSessionReady()) return;
      final idleFor = DateTime.now().difference(_lastActivity);
      if (idleFor.inMinutes >= _autolockMinutes) {
        onLock();
      }
    });
  }

  /// يوقف المراقبة (قفل/مسح/استعادة/إتلاف) — آمن للتكرار.
  void stopWatch() {
    _idleTicker?.cancel();
    _idleTicker = null;
  }

  /// التطبيق صار خلفياً — يبدأ عدّ الغياب.
  void appHidden() {
    _hiddenAt ??= DateTime.now();
  }

  /// عاد التطبيق للأمام — قفل إن تجاوز الغياب الحد، وإلا تجديد النشاط.
  void appResumed() {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (hiddenAt == null) return;
    if (!isSessionReady()) return;
    final away = DateTime.now().difference(hiddenAt);
    if (away.inMinutes >= _autolockMinutes) {
      onLock();
    } else {
      touch();
    }
  }
}
