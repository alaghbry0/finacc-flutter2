/// بانر تذكير النسخ الاحتياطي (FR-11-04) — نتيجة النسخة التلقائية أو
/// تنبيه الاستحقاق، بزر فتح شاشة النسخ وزر إخفاء لبقية الجلسة.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../domain/services/numerals.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/numerals_scope.dart';
import '../../view_models/home_view_model.dart';

class BackupReminderBanner extends StatelessWidget {
  const BackupReminderBanner({
    super.key,
    required this.reminder,
    required this.onDismiss,
  });

  final BackupReminder reminder;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final arabicIndic = NumeralsScope.of(context);

    final (bg, fg, icon) = switch (reminder.kind) {
      BackupReminderKind.autoDone => (
        colors.positiveContainer.withValues(alpha: 0.6),
        colors.onPositiveContainer,
        Icons.cloud_done_rounded,
      ),
      BackupReminderKind.autoFailed => (
        colors.negativeContainer.withValues(alpha: 0.6),
        colors.onNegativeContainer,
        Icons.cloud_off_rounded,
      ),
      BackupReminderKind.webDue => (
        colors.warningContainer.withValues(alpha: 0.6),
        colors.onWarningContainer,
        Icons.cloud_upload_rounded,
      ),
    };

    final message = switch (reminder.kind) {
      BackupReminderKind.autoDone => l10n.backupBannerAutoDone(
        _timeText(reminder.at?.toLocal(), arabicIndic),
      ),
      BackupReminderKind.autoFailed => l10n.backupBannerAutoFailed,
      BackupReminderKind.webDue => l10n.backupBannerWebDue,
    };

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface,
                // w600 غير متوفر في Almarai — التصحيح إلى w700 (UX-2b).
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.go('/more/backup'),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: fg,
            ),
            child: Text(l10n.backupBannerOpen),
          ),
          SizedBox(
            width: 34,
            height: 34,
            child: IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              padding: EdgeInsets.zero,
              iconSize: 16,
              color: scheme.onSurfaceVariant,
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    );
  }

  /// وقت النسخة «HH:mm» بأرقام النظام الحي.
  static String _timeText(DateTime? local, bool arabicIndic) {
    final text = local == null
        ? DateFormat('HH:mm').format(DateTime.now())
        : DateFormat('HH:mm').format(local);
    return arabicIndic ? Numerals.toArabicIndic(text) : text;
  }
}
