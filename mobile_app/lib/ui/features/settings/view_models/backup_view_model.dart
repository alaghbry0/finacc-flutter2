/// نموذج عرض شاشة «النسخ الاحتياطي والاستعادة» — FR-11 (وحدة 11).
///
/// يجمع حالة الشاشة كاملة (الجدولة/الاحتفاظ/السجل/آخر نسخة) ويغلف
/// عمليات الخدمة (إنشاء/فحص/استعادة/مشاركة) — الاستعادة تمر عبر
/// [AppController.restoreBackupFromBytes] لأنها حدث دورة حياة جلسة كامل
/// (تبديل القاعدة والمستودعات وإعادة تحديد الطور).
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../../../data/services/backup/backup_service.dart';
import '../../../../domain/services/backup_format.dart';
import '../../../../domain/services/backup_policy.dart';
import '../../../core/session/app_controller.dart';

/// حالة شاشة النسخ الاحتياطي.
class BackupScreenState {
  const BackupScreenState({
    required this.loading,
    required this.schedule,
    required this.retentionCount,
    required this.entries,
    this.lastBackupAt,
    this.error,
    this.creating = false,
    this.restoring = false,
  });

  final bool loading;
  final Object? error;

  /// الجدولة الحالية (`backup.schedule`).
  final BackupSchedule schedule;

  /// عدد النسخ المحفوظة (`backup.retention_count`).
  final int retentionCount;

  /// لحظة آخر نسخة ناجحة (`backup.last_backup_at` — حالة نظامية).
  final DateTime? lastBackupAt;

  /// سجل النسخ (FR-11-06).
  final List<BackupListEntry> entries;

  /// جارٍ إنشاء نسخة الآن (مؤشر الزر).
  final bool creating;

  /// جارٍ تنفيذ استعادة (قفل تفاعلي).
  final bool restoring;

  BackupScreenState copyWith({
    bool? loading,
    Object? error,
    BackupSchedule? schedule,
    int? retentionCount,
    DateTime? lastBackupAt,
    List<BackupListEntry>? entries,
    bool? creating,
    bool? restoring,
  }) => BackupScreenState(
    loading: loading ?? this.loading,
    error: error,
    schedule: schedule ?? this.schedule,
    retentionCount: retentionCount ?? this.retentionCount,
    lastBackupAt: lastBackupAt ?? this.lastBackupAt,
    entries: entries ?? this.entries,
    creating: creating ?? this.creating,
    restoring: restoring ?? this.restoring,
  );
}

/// ناتج فحص ملف نسخة (قبل حوار التأكيد).
sealed class BackupInspectionOutcome {
  const BackupInspectionOutcome();
}

/// ملف سليم جاهز لعرض الفحص — يحمل البايتات لتغذية الاستعادة مباشرة.
class BackupInspected extends BackupInspectionOutcome {
  const BackupInspected({required this.inspection, required this.bytes});

  final BackupInspection inspection;
  final Uint8List bytes;
}

/// ملف معيب — السبب مفهرس لترجمته بمفاتيح l10n.
class BackupInspectFailed extends BackupInspectionOutcome {
  const BackupInspectFailed(this.error);

  final BackupFormatError error;
}

/// نموذج عرض النسخ الاحتياطي.
class BackupViewModel extends ChangeNotifier {
  BackupViewModel({required AppController app}) : _controller = app;

  final AppController _controller;

  BackupScreenState _state = const BackupScreenState(
    loading: true,
    schedule: BackupSchedule.weekly,
    retentionCount: 7,
    entries: <BackupListEntry>[],
  );

  BackupScreenState get state => _state;

  BackupService? get _service => _controller.backupEngine;

  /// هل ملفات النسخ مدعومة هنا؟ (الويب = معاينة فقط).
  bool get filesSupported => _service?.isSupported ?? false;

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  /// تحميل كامل (عند الفتح وبعد كل عملية جوهرية) — مع تهيئة المحرك إن
  /// لم يكن جاهزاً (شبكة أمان فوق تهيئة الإقلاع).
  Future<void> load() async {
    _state = _state.copyWith(loading: true);
    notifyListeners();
    try {
      await _controller.ensureBackupEngine();
      final settings = _controller.settings;
      final svc = _service;
      if (settings == null) {
        throw StateError('المستودعات غير مهيأة');
      }
      final schedule = parseBackupSchedule(await settings.backupSchedule());
      final retentionCount = await settings.backupRetentionCount();
      final lastBackupAt = await settings.backupLastBackupAt();
      final entries = svc != null && svc.isSupported
          ? await svc.listEntries()
          : const <BackupListEntry>[];
      if (_isDisposed) return;
      _state = _state.copyWith(
        loading: false,
        schedule: schedule,
        retentionCount: retentionCount,
        lastBackupAt: lastBackupAt,
        entries: entries,
      );
    } catch (error) {
      if (_isDisposed) return;
      _state = _state.copyWith(loading: false, error: error);
    }
    notifyListeners();
  }

  // ── إعدادات النسخ (FR-13-04 — الجدولة والاحتفاظ) ──

  /// يثبّت الجدولة (`backup.schedule`) — تحديث متفائل مع تراجع عند الفشل.
  Future<bool> setSchedule(BackupSchedule schedule) async {
    final previous = _state.schedule;
    if (schedule == previous) return true;
    _state = _state.copyWith(schedule: schedule);
    notifyListeners();
    try {
      await _controller.settings!.setBackupSchedule(
        backupScheduleTag(schedule),
      );
      return true;
    } catch (_) {
      if (!_isDisposed) {
        _state = _state.copyWith(schedule: previous);
        notifyListeners();
      }
      return false;
    }
  }

  /// يثبّت عدد النسخ المحفوظة (`backup.retention_count`).
  Future<bool> setRetentionCount(int count) async {
    if (!isValidBackupRetentionCount(count)) return false;
    final previous = _state.retentionCount;
    if (count == previous) return true;
    _state = _state.copyWith(retentionCount: count);
    notifyListeners();
    try {
      await _controller.settings!.setBackupRetentionCount(count);
      return true;
    } catch (_) {
      if (!_isDisposed) {
        _state = _state.copyWith(retentionCount: previous);
        notifyListeners();
      }
      return false;
    }
  }

  // ── الإنشاء والمشاركة (FR-11-01/08) ──

  /// «إنشاء نسخة الآن» — يعيد نتيجة المحاولة للعرض (Snackbar).
  Future<BackupRunResult?> createBackupNow() async {
    final svc = _service;
    if (svc == null || !svc.isSupported || _state.creating) return null;
    _state = _state.copyWith(creating: true);
    notifyListeners();
    final result = await svc.createBackup(kind: BackupKind.manual);
    if (!_isDisposed) {
      _state = _state.copyWith(creating: false);
      notifyListeners();
      if (result.ok) {
        await _reloadAfterRun();
      }
    }
    return result;
  }

  /// يشارك ملف نسخة عبر نظام التشغيل (FR-11-08).
  Future<bool> shareBackup(String fileName) async {
    final svc = _service;
    if (svc == null || !svc.isSupported) return false;
    return svc.shareBackupFile(fileName);
  }

  // ── الفحص والاستعادة (FR-11-02) ──

  /// يقرأ ويفحص نسخة محفوظة من القائمة (زر الاستعادة لكل نسخة).
  Future<BackupInspectionOutcome> inspectStoredBackup(String fileName) async {
    final svc = _service;
    if (svc == null || !svc.isSupported) {
      return const BackupInspectFailed(BackupFormatError.notArchive);
    }
    try {
      final bytes = await svc.readStoredBytes(fileName);
      final inspection = await svc.inspectBytes(bytes, fileName: fileName);
      return BackupInspected(inspection: inspection, bytes: bytes);
    } on BackupFormatException catch (error) {
      return BackupInspectFailed(error.error);
    } catch (_) {
      return const BackupInspectFailed(BackupFormatError.notArchive);
    }
  }

  /// يفتح منتقي الملفات لنسخة خارجية ويفحصه — null = ألغى المستخدم.
  Future<BackupInspectionOutcome?> pickExternalBackup() async {
    final svc = _service;
    if (svc == null || !svc.isSupported) return null;
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['finbak'],
    );
    if (files.isEmpty) return null; // إلغاء المستخدم.
    final file = files.single;
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      return const BackupInspectFailed(BackupFormatError.notArchive);
    }
    try {
      final inspection = await svc.inspectBytes(bytes, fileName: file.name);
      return BackupInspected(inspection: inspection, bytes: bytes);
    } on BackupFormatException catch (error) {
      return BackupInspectFailed(error.error);
    } catch (_) {
      return const BackupInspectFailed(BackupFormatError.notArchive);
    }
  }

  /// ينفّذ الاستعادة عبر متحكم الجلسة — النجاح يقفل الجلسة (PIN النسخة
  /// المستعادة) والفشل يعاد لعرضه في نفس الحوار.
  Future<RestoreResult> performRestore(
    Uint8List bytes, {
    required String sourceName,
  }) async {
    _state = _state.copyWith(restoring: true);
    notifyListeners();
    final result = await _controller.restoreBackupFromBytes(
      bytes,
      sourceName: sourceName,
    );
    // بعد النجاح تُفكك الشاشة (تحويل القفل) — يهم غير المُتخلَّص فقط.
    if (!_isDisposed && result is RestoreFailure) {
      _state = _state.copyWith(restoring: false);
      notifyListeners();
      await load();
    }
    return result;
  }

  // ─────────────────────────────────────────────────────────────────────

  /// يعيد تحميل السجل وآخر نسخة بعد عملية ناجحة (بلا وميض تحميل كامل).
  Future<void> _reloadAfterRun() async {
    final svc = _service;
    if (svc == null || !svc.isSupported) return;
    try {
      final entries = await svc.listEntries();
      final last = await _controller.settings!.backupLastBackupAt();
      if (_isDisposed) return;
      _state = _state.copyWith(entries: entries, lastBackupAt: last);
      notifyListeners();
    } catch (_) {
      // السجل وحده تعذّر — البيانات الأساسية سليمة.
    }
  }
}
