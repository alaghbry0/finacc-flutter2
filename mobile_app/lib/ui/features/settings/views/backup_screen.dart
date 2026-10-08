/// شاشة «النسخ الاحتياطي والاستعادة» — FR-11 (وحدة 11، الشريحة 8):
/// بطاقة الحالة بزر «إنشاء نسخة الآن» (FR-11-01)، إعدادات الجدولة
/// (FR-11-04) والاحتفاظ (FR-11-05)، سجل النسخ بكل بياناته (FR-11-06)
/// بزر استعادة ومشاركة لكل نسخة (FR-11-02/08)، واستعادة من ملف خارجي —
/// مع حوار فحص الملف وتحذير الاستبدال قبل التنفيذ.
library;

import 'dart:async';

import 'package:flutter/material.dart';
// إخفاء TextDirection الخاصة بintl (قيمها LTR/RTL كبيرة) كي لا تحجب
// TextDirection الخاصة بFlutter (قيمها ltr/rtl صغيرة) — مطلوبة أدناه.
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../../../data/services/backup/backup_service.dart';
import '../../../../domain/services/backup_format.dart';
import '../../../../domain/services/backup_policy.dart';
import '../../../../domain/services/numerals.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/numerals_scope.dart';
import '../../../core/widgets/refresh_on_active.dart';
import '../../../core/widgets/status_chip.dart';
import '../view_models/backup_view_model.dart';

/// يفتح شاشة النسخ الاحتياطي.
class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً — عند غيابه تُنشئ الشاشة نموذجها.
  final BackupViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final BackupViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = BackupViewModel(app: app);
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<BackupViewModel>.value(
      value: vm,
      // شاشة قائمة داخل فرع «المزيد» — تحديث عند عودة نشاط المسار.
      child: RefreshOnActive(
        routePattern: RegExp(r'^/more/backup$'),
        onActivate: vm.load,
        child: const _BackupBody(),
      ),
    );
  }
}

class _BackupBody extends StatelessWidget {
  const _BackupBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BackupViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.backupScreenTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (state.loading)
            const ListSkeleton(rows: 6)
          else if (state.error != null)
            ErrorState(
              title: l10n.genericErrorTitle,
              message: l10n.dbOpenErrorMessage,
              technicalDetails: state.error.toString(),
              retryLabel: l10n.commonRetry,
              onRetry: vm.load,
              compact: true,
            )
          else ...[
            if (!vm.filesSupported) ...[
              const _WebPreviewBanner(),
              const SizedBox(height: 16),
            ],
            _StatusCard(vm: vm),
            const SizedBox(height: 16),
            _ScheduleCard(vm: vm),
            const SizedBox(height: 16),
            _RetentionCard(vm: vm),
            const SizedBox(height: 16),
            _LogCard(vm: vm),
            if (vm.filesSupported) ...[
              const SizedBox(height: 16),
              const _ExternalRestoreCard(),
            ],
          ],
        ],
      ),
    );
  }
}

/// بانر المعاينة على الويب — الميزة الكاملة على أندرويد.
class _WebPreviewBanner extends StatelessWidget {
  const _WebPreviewBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return FinCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.warningContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.devices_rounded,
              color: colors.onWarningContainer,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.backupWebPreviewTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.onWarningContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.backupWebPreviewBody,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة الحالة: آخر نسخة ناجحة + عدد النسخ + زر الإنشاء (FR-11-01).
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.vm});

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
                  borderRadius: BorderRadius.circular(13),
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
                : _formatDateTime(context, state.lastBackupAt!.toLocal()),
          ),
          _InfoRow(
            icon: Icons.folder_copy_outlined,
            label: l10n.backupSavedCountLabel,
            value: _formatDigits(
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

/// بطاقة الجدولة (FR-11-04) — رقائق اختيار يومي/أسبوعي/إيقاف.
class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.vm});

  final BackupViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    return FinCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.event_repeat_rounded,
            title: l10n.backupScheduleTitle,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.backupScheduleDesc,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _OptionChip(
                  label: l10n.backupScheduleDaily,
                  icon: Icons.today_rounded,
                  selected: state.schedule == BackupSchedule.daily,
                  onTap: () => unawaited(vm.setSchedule(BackupSchedule.daily)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OptionChip(
                  label: l10n.backupScheduleWeekly,
                  icon: Icons.date_range_rounded,
                  selected: state.schedule == BackupSchedule.weekly,
                  onTap: () => unawaited(vm.setSchedule(BackupSchedule.weekly)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OptionChip(
                  label: l10n.backupScheduleOff,
                  icon: Icons.pause_circle_outline_rounded,
                  selected: state.schedule == BackupSchedule.off,
                  onTap: () => unawaited(vm.setSchedule(BackupSchedule.off)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// بطاقة الاحتفاظ (FR-11-05) — آخر N نسخ محفوظة.
class _RetentionCard extends StatelessWidget {
  const _RetentionCard({required this.vm});

  final BackupViewModel vm;

  static const List<int> _options = [3, 7, 14, 30];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    final arabicIndic = NumeralsScope.of(context);
    return FinCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.auto_delete_outlined,
            title: l10n.backupRetentionTitle,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.backupRetentionDesc(state.retentionCount),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final option in _options) ...[
                Expanded(
                  child: _OptionChip(
                    label: arabicIndic
                        ? Numerals.toArabicIndic('$option')
                        : '$option',
                    selected: state.retentionCount == option,
                    onTap: () => unawaited(vm.setRetentionCount(option)),
                  ),
                ),
                if (option != _options.last) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// بطاقة سجل النسخ (FR-11-06) — قائمة بارتفاع محدود وتمرير.
class _LogCard extends StatelessWidget {
  const _LogCard({required this.vm});

  final BackupViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    return FinCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.history_rounded,
            title: l10n.backupLogTitle,
          ),
          const SizedBox(height: 10),
          if (state.entries.isEmpty)
            _LogEmptyState()
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: state.entries.length,
                separatorBuilder: (context, index) => const SizedBox(height: 6),
                itemBuilder: (context, index) =>
                    _LogRow(vm: vm, entry: state.entries[index]),
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
class _LogRow extends StatelessWidget {
  const _LogRow({required this.vm, required this.entry});

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
    final sizeText = _formatSize(context, entry.sizeBytes);

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
              borderRadius: BorderRadius.circular(11),
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
                  _formatDateTime(context, entry.atUtc.toLocal()),
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
        await _openRestoreFlow(context, vm, inspected);
      case final BackupInspectFailed failed:
        _showInspectError(context, failed.error);
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

/// بطاقة الاستعادة من ملف خارجي (FR-11-02 — منتقي المستندات).
class _ExternalRestoreCard extends StatelessWidget {
  const _ExternalRestoreCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final vm = context.read<BackupViewModel>();
    return FinCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
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
        await _openRestoreFlow(context, vm, inspected);
      case final BackupInspectFailed failed:
        _showInspectError(context, failed.error);
    }
  }
}

/// عنوان قسم بأيقونة مصبوغة — نمط شاشة الإعدادات.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: scheme.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface),
        ),
      ],
    );
  }
}

/// رقاقة اختيار (جدولة/احتفاظ).
class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 46,
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: selected
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? scheme.onPrimaryContainer : null,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 4),
              Icon(Icons.check_circle_rounded, size: 15, color: scheme.primary),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// حوار الاستعادة: فحص → تحذير → تنفيذ → نتيجة (FR-11-02)
// ─────────────────────────────────────────────────────────────────────

/// يفتح تدفق الاستعادة فوق الملف المفحوص.
Future<void> _openRestoreFlow(
  BuildContext context,
  BackupViewModel vm,
  BackupInspected inspected,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) =>
        _RestoreFlowDialog(vm: vm, inspected: inspected),
  );
}

/// رسالة خطأ الفحص (ملف غير صالح/تالف) — SnackBar عربي.
void _showInspectError(BuildContext context, BackupFormatError error) {
  final l10n = AppLocalizations.of(context)!;
  final message = switch (error) {
    BackupFormatError.checksumMismatch => l10n.backupErrChecksum,
    _ => l10n.backupErrNotFile,
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _RestoreFlowDialog extends StatefulWidget {
  const _RestoreFlowDialog({required this.vm, required this.inspected});

  final BackupViewModel vm;
  final BackupInspected inspected;

  @override
  State<_RestoreFlowDialog> createState() => _RestoreFlowDialogState();
}

enum _RestoreStage { confirm, running, success, failure }

class _RestoreFlowDialogState extends State<_RestoreFlowDialog> {
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
          _RestoreStage.confirm => _ConfirmContent(
            inspection: widget.inspected.inspection,
          ),
          _RestoreStage.running => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(strokeWidth: 2.6),
              const SizedBox(height: 16),
              Text(l10n.backupRestoreRunning),
            ],
          ),
          _RestoreStage.success => _SuccessContent(
            inspection: widget.inspected.inspection,
          ),
          _RestoreStage.failure => _FailureContent(result: _result),
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

/// محتوى التأكيد: فحص الملف (اسم/تاريخ/حجم/مخطط/بصمة) + التحذير.
class _ConfirmContent extends StatelessWidget {
  const _ConfirmContent({required this.inspection});

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
            value: _formatDateTime(context, manifest.createdAtUtc.toLocal()),
          ),
          _InspectRow(
            label: l10n.backupInspectSize,
            value: _formatSize(context, inspection.fileSizeBytes),
          ),
          _InspectRow(
            label: l10n.backupInspectSchema,
            value: 'v${_formatDigits(context, '${manifest.schemaVersion}')}',
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
                      fontWeight: FontWeight.w600,
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
class _SuccessContent extends StatelessWidget {
  const _SuccessContent({required this.inspection});

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
class _FailureContent extends StatelessWidget {
  const _FailureContent({required this.result});

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

// ─────────────────────────────────────────────────────────────────────
// مساعدات التنسيق
// ─────────────────────────────────────────────────────────────────────

/// تاريخ/وقت مقروء بأرقام النظام الحي.
String _formatDateTime(BuildContext context, DateTime local) {
  final formatted = DateFormat('yyyy/MM/dd • HH:mm').format(local);
  return NumeralsScope.of(context)
      ? Numerals.toArabicIndic(formatted)
      : formatted;
}

/// أرقام بأرقام النظام الحي.
String _formatDigits(BuildContext context, String digits) {
  return NumeralsScope.of(context) ? Numerals.toArabicIndic(digits) : digits;
}

/// حجم ملف مقروء (ك.ب / م.ب) بأرقام النظام الحي.
String _formatSize(BuildContext context, int bytes) {
  final l10n = AppLocalizations.of(context)!;
  final kb = bytes / 1024;
  if (kb < 1024) {
    final value = _formatDigits(context, kb.round().toString());
    return l10n.backupSizeKb(value);
  }
  final mb = _formatDigits(context, (kb / 1024).toStringAsFixed(1));
  return l10n.backupSizeMb(mb);
}
