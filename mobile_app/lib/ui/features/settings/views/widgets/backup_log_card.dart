/// بطاقة سجل النسخ (FR-11-06) — قائمة بارتفاع محدود وتمرير + استعادة
/// ومشاركة لكل نسخة (FR-11-02/08).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../data/services/backup/backup_service.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/fin_tokens.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../view_models/backup_view_model.dart';
import 'backup_format.dart';
import 'backup_policy_cards.dart';
import 'backup_restore_dialog.dart';

/// بطاقة سجل النسخ (FR-11-06) — قائمة بارتفاع محدود وتمرير.
class BackupLogCard extends StatelessWidget {
  const BackupLogCard({super.key, required this.vm});

  final BackupViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    return FinCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BackupSectionTitle(
            icon: Icons.history_rounded,
            title: l10n.backupLogTitle,
          ),
          const SizedBox(height: 10),
          if (state.entries.isEmpty)
            const _LogEmptyState()
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: state.entries.length,
                separatorBuilder: (context, index) => const SizedBox(height: 6),
                itemBuilder: (context, index) =>
                    BackupLogRow(vm: vm, entry: state.entries[index]),
              ),
            ),
        ],
      ),
    );
  }
}

/// حالة فراغ سجل النسخ.
class _LogEmptyState extends StatelessWidget {
  const _LogEmptyState();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(
          Icons.inventory_2_outlined,
          size: 44,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(height: 10),
        Text(
          l10n.backupLogEmptyTitle,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.backupLogEmptyBody,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// سطر سجل نسخة: تاريخ/نوع/حجم/حالة + استعادة ومشاركة (إن وُجد الملف).
class BackupLogRow extends StatelessWidget {
  const BackupLogRow({super.key, required this.vm, required this.entry});

  final BackupViewModel vm;
  final BackupListEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final kind = entry.kind;
    final icon = switch (kind) {
      BackupKind.manual => Icons.back_hand_outlined,
      BackupKind.auto => Icons.autorenew_rounded,
      BackupKind.preRestore => Icons.health_and_safety_outlined,
      null => Icons.archive_outlined,
    };
    final kindLabel = switch (kind) {
      BackupKind.manual => l10n.backupKindManual,
      BackupKind.auto => l10n.backupKindAuto,
      BackupKind.preRestore => l10n.backupKindSafety,
      null => l10n.backupKindGeneric,
    };
    final sizeText = backupFormatSize(context, entry.sizeBytes);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: entry.statusOk
                  ? scheme.primaryContainer.withValues(alpha: 0.55)
                  : colors.negativeContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(FinRadius.control),
            ),
            child: Icon(
              icon,
              size: 20,
              color: entry.statusOk
                  ? scheme.onPrimaryContainer
                  : colors.onNegativeContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  backupFormatDateTime(context, entry.atUtc.toLocal()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$kindLabel • $sizeText',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          entry.fileExists && entry.statusOk
              ? StatusChip(label: l10n.backupStatusOk, tone: ChipTone.positive)
              : StatusChip(
                  label: entry.statusOk
                      ? l10n.backupFileMissing
                      : l10n.backupStatusFailed,
                  tone: ChipTone.negative,
                  dense: true,
                ),
          if (entry.fileExists) ...[
            const SizedBox(width: 4),
            _RowAction(
              tooltip: l10n.backupRestoreTooltip,
              icon: Icons.settings_backup_restore_rounded,
              onTap: () =>
                  unawaited(_restoreFromEntry(context, vm, entry.fileName!)),
            ),
            _RowAction(
              tooltip: l10n.backupShareTooltip,
              icon: Icons.ios_share_rounded,
              onTap: () => unawaited(_share(context, vm, entry.fileName!)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _restoreFromEntry(
    BuildContext context,
    BackupViewModel vm,
    String fileName,
  ) async {
    final outcome = await vm.inspectStoredBackup(fileName);
    if (!context.mounted) return;
    switch (outcome) {
      case final BackupInspected inspected:
        await openBackupRestoreFlow(context, vm, inspected);
      case final BackupInspectFailed failed:
        showBackupInspectError(context, failed.error);
    }
  }

  Future<void> _share(
    BuildContext context,
    BackupViewModel vm,
    String fileName,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final shared = await vm.shareBackup(fileName);
    if (!context.mounted || shared) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.backupShareFailed)));
  }
}

/// زر أيقوني مضغوط لسطر السجل.
class _RowAction extends StatelessWidget {
  const _RowAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        iconSize: 20,
        color: scheme.primary,
        onPressed: onTap,
        icon: Icon(icon),
      ),
    );
  }
}
