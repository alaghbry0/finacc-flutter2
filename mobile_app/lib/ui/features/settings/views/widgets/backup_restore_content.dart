/// محتويات مراحل حوار الاستعادة — التأكيد (فحص الملف + التحذير)،
/// النجاح، والفشل (FR-11-02).
library;

import 'package:flutter/material.dart';

import '../../../../../data/services/backup/backup_service.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import 'backup_format.dart';

/// محتوى التأكيد: فحص الملف (اسم/تاريخ/حجم/مخطط/بصمة) + التحذير.
class BackupConfirmContent extends StatelessWidget {
  const BackupConfirmContent({super.key, required this.inspection});

  final BackupInspection inspection;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final manifest = inspection.manifest;
    final checksum = manifest.dbSha256.length > 16
        ? manifest.dbSha256.substring(0, 16)
        : manifest.dbSha256;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InspectRow(
            label: l10n.backupInspectFile,
            value: inspection.fileName,
            ltrValue: true,
          ),
          _InspectRow(
            label: l10n.backupInspectCreated,
            value: backupFormatDateTime(
              context,
              manifest.createdAtUtc.toLocal(),
            ),
          ),
          _InspectRow(
            label: l10n.backupInspectSize,
            value: backupFormatSize(context, inspection.fileSizeBytes),
          ),
          _InspectRow(
            label: l10n.backupInspectSchema,
            value:
                'v${backupFormatDigits(context, '${manifest.schemaVersion}')}',
            ltrValue: true,
          ),
          _InspectRow(
            label: l10n.backupInspectChecksum,
            value: checksum,
            ltrValue: true,
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.negativeContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.negative.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: colors.negative,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.backupRestoreWarnBody,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// صف بيانات فحص.
class _InspectRow extends StatelessWidget {
  const _InspectRow({
    required this.label,
    required this.value,
    this.ltrValue = false,
  });

  final String label;
  final String value;

  /// قيمة لاتينية الاتجاه (اسم ملف/بصمة) — تُعرض LTR.
  final bool ltrValue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              textDirection: ltrValue ? TextDirection.ltr : null,
              textAlign: ltrValue ? TextAlign.right : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// محتوى النجاح — التطبيق انتقل لشاشة القفل خلف الحوار.
class BackupSuccessContent extends StatelessWidget {
  const BackupSuccessContent({super.key, required this.inspection});

  final BackupInspection inspection;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: colors.positiveContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle_rounded,
            size: 36,
            color: colors.onPositiveContainer,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          inspection.fileName,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.backupRestoreSuccessBody,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// محتوى الفشل — السبب مفهرساً بمفاتيح l10n + تفاصيل تقنية صغيرة.
class BackupFailureContent extends StatelessWidget {
  const BackupFailureContent({super.key, required this.result});

  final RestoreResult? result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final failure = switch (result) {
      final RestoreFailure failed => failed,
      _ => null,
    };
    final (title, body) = switch (failure?.reason) {
      null => (l10n.backupRestoreFailedTitle, l10n.backupErrNotFile),
      RestoreFailureReason.unsupportedPlatform => (
        l10n.backupRestoreFailedTitle,
        l10n.backupErrUnsupported,
      ),
      RestoreFailureReason.notBackupFile => (
        l10n.backupRestoreFailedTitle,
        l10n.backupErrNotFile,
      ),
      RestoreFailureReason.checksumMismatch => (
        l10n.backupRestoreFailedTitle,
        l10n.backupErrChecksum,
      ),
      RestoreFailureReason.newerSchema => (
        l10n.backupRestoreFailedTitle,
        l10n.backupErrNewerSchema(
          failure?.fileSchemaVersion ?? 0,
          failure?.appSchemaVersion ?? 0,
        ),
      ),
      RestoreFailureReason.safetyBackupFailed => (
        l10n.backupRestoreFailedTitle,
        l10n.backupErrSafety,
      ),
      RestoreFailureReason.openFailed => (
        l10n.backupRestoreFailedTitle,
        l10n.backupErrOpenFailed,
      ),
    };
    final details = failure?.details;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: colors.negativeContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.error_outline_rounded,
            size: 36,
            color: colors.onNegativeContainer,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (details != null && details.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            details,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ],
    );
  }
}
