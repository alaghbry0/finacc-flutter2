/// حوار الاستعادة: فحص → تحذير → تنفيذ → نتيجة (FR-11-02) — البوابة
/// المشتركة للاستعادة من السجل ومن ملف خارجي.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../data/services/backup/backup_service.dart';
import '../../../../../domain/services/backup_format.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../view_models/backup_view_model.dart';
import 'backup_restore_content.dart';

/// يفتح تدفق الاستعادة فوق الملف المفحوص.
Future<void> openBackupRestoreFlow(
  BuildContext context,
  BackupViewModel vm,
  BackupInspected inspected,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) =>
        BackupRestoreFlowDialog(vm: vm, inspected: inspected),
  );
}

/// رسالة خطأ الفحص (ملف غير صالح/تالف) — SnackBar عربي.
void showBackupInspectError(BuildContext context, BackupFormatError error) {
  final l10n = AppLocalizations.of(context)!;
  final message = switch (error) {
    BackupFormatError.checksumMismatch => l10n.backupErrChecksum,
    _ => l10n.backupErrNotFile,
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class BackupRestoreFlowDialog extends StatefulWidget {
  const BackupRestoreFlowDialog({
    super.key,
    required this.vm,
    required this.inspected,
  });

  final BackupViewModel vm;
  final BackupInspected inspected;

  @override
  State<BackupRestoreFlowDialog> createState() =>
      _BackupRestoreFlowDialogState();
}

enum _RestoreStage { confirm, running, success, failure }

class _BackupRestoreFlowDialogState extends State<BackupRestoreFlowDialog> {
  _RestoreStage _stage = _RestoreStage.confirm;
  RestoreResult? _result;

  Future<void> _run() async {
    setState(() => _stage = _RestoreStage.running);
    final result = await widget.vm.performRestore(
      widget.inspected.bytes,
      sourceName: widget.inspected.inspection.fileName,
    );
    if (!mounted) return;
    setState(() {
      _result = result;
      _stage = result is RestoreSuccess
          ? _RestoreStage.success
          : _RestoreStage.failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      // أثناء التنفيذ لا إغلاق — بقية المراحل قابلة للإغلاق.
      canPop: _stage != _RestoreStage.running,
      child: AlertDialog(
        title: Text(switch (_stage) {
          _RestoreStage.success => l10n.backupRestoreSuccessTitle,
          _RestoreStage.failure => l10n.backupRestoreFailedTitle,
          _ => l10n.backupRestoreDialogTitle,
        }),
        content: switch (_stage) {
          _RestoreStage.confirm => BackupConfirmContent(
            inspection: widget.inspected.inspection,
          ),
          _RestoreStage.running => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(strokeWidth: 3),
              const SizedBox(height: 16),
              Text(l10n.backupRestoreRunning),
            ],
          ),
          _RestoreStage.success => BackupSuccessContent(
            inspection: widget.inspected.inspection,
          ),
          _RestoreStage.failure => BackupFailureContent(result: _result),
        },
        actions: switch (_stage) {
          _RestoreStage.confirm => [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => unawaited(_run()),
              child: Text(l10n.backupRestoreConfirm),
            ),
          ],
          _RestoreStage.running => null,
          _ => [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.backupRestoreClose),
            ),
          ],
        },
      ),
    );
  }
}
