/// بطاقة الحالة لشاشة النسخ الاحتياطي — آخر نسخة ناجحة + عدد النسخ +
/// زر الإنشاء (FR-11-01).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/fin_tokens.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/backup_view_model.dart';
import 'backup_format.dart';

/// بطاقة الحالة: آخر نسخة ناجحة + عدد النسخ + زر الإنشاء (FR-11-01).
class BackupStatusCard extends StatelessWidget {
  const BackupStatusCard({super.key, required this.vm});

  final BackupViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final state = vm.state;
    final supported = vm.filesSupported;

    return FinCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primary,
                      Color.lerp(scheme.primary, Colors.black, 0.25)!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(FinRadius.control),
                ),
                child: Icon(
                  Icons.cloud_done_outlined,
                  color: scheme.onPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.backupScreenTitle,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.schedule_rounded,
            label: l10n.backupLastBackupLabel,
            value: state.lastBackupAt == null
                ? l10n.backupLastNever
                : backupFormatDateTime(context, state.lastBackupAt!.toLocal()),
          ),
          _InfoRow(
            icon: Icons.folder_copy_outlined,
            label: l10n.backupSavedCountLabel,
            value: backupFormatDigits(
              context,
              '${state.entries.where((e) => e.fileExists).length}',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              // الويب: تعطيل دفاعي — الإنشاء يحتاج ملفات الجهاز.
              onPressed: supported && !state.creating
                  ? () => unawaited(_create(context, vm))
                  : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: state.creating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Icon(Icons.add_task_rounded, size: 20),
              label: Text(
                state.creating ? l10n.backupCreating : l10n.backupCreateNow,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.backupCreateHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context, BackupViewModel vm) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await vm.createBackupNow();
    if (!context.mounted || result == null) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    if (result.ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.backupCreateSuccess(result.fileName ?? ''),
            textAlign: TextAlign.start,
          ),
        ),
      );
    } else {
      messenger.showSnackBar(SnackBar(content: Text(l10n.backupCreateFailed)));
    }
  }
}

/// صف معلومة (تسمية + قيمة) — نمط بطاقة المنشأة في الإعدادات.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
