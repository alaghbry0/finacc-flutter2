/// بطاقة الاستعادة من ملف خارجي (FR-11-02 — منتقي المستندات).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/backup_view_model.dart';
import 'backup_policy_cards.dart';
import 'backup_restore_dialog.dart';

/// بطاقة الاستعادة من ملف خارجي (FR-11-02 — منتقي المستندات).
class BackupExternalRestoreCard extends StatelessWidget {
  const BackupExternalRestoreCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final vm = context.read<BackupViewModel>();
    return FinCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BackupSectionTitle(
            icon: Icons.settings_backup_restore_rounded,
            title: l10n.backupRestoreFromFile,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.backupRestoreFromFileDesc,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: colors.warning,
                side: BorderSide(color: colors.warning.withValues(alpha: 0.6)),
              ),
              onPressed: () => unawaited(_pickAndRestore(context, vm)),
              icon: const Icon(Icons.upload_file_rounded, size: 20),
              label: Text(l10n.backupRestoreFromFile),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndRestore(BuildContext context, BackupViewModel vm) async {
    final outcome = await vm.pickExternalBackup();
    if (!context.mounted) return;
    switch (outcome) {
      case null:
        return; // ألغى المستخدم.
      case final BackupInspected inspected:
        await openBackupRestoreFlow(context, vm, inspected);
      case final BackupInspectFailed failed:
        showBackupInspectError(context, failed.error);
    }
  }
}
