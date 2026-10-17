/// بطاقتا الجدولة (FR-11-04) والاحتفاظ (FR-11-05) + عنوان القسم ورقاقة
/// الاختيار المشتركان — نمط شاشة الإعدادات.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../domain/services/backup_policy.dart';
import '../../../../../domain/services/numerals.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/fin_tokens.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/numerals_scope.dart';
import '../../view_models/backup_view_model.dart';

/// عنوان قسم بأيقونة مصبوغة — نمط شاشة الإعدادات.
class BackupSectionTitle extends StatelessWidget {
  const BackupSectionTitle({
    super.key,
    required this.icon,
    required this.title,
  });

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
            borderRadius: BorderRadius.circular(FinRadius.chip),
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
class BackupOptionChip extends StatelessWidget {
  const BackupOptionChip({
    super.key,
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

/// بطاقة الجدولة (FR-11-04) — رقائق اختيار يومي/أسبوعي/إيقاف.
class BackupScheduleCard extends StatelessWidget {
  const BackupScheduleCard({super.key, required this.vm});

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
                child: BackupOptionChip(
                  label: l10n.backupScheduleDaily,
                  icon: Icons.today_rounded,
                  selected: state.schedule == BackupSchedule.daily,
                  onTap: () => unawaited(vm.setSchedule(BackupSchedule.daily)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: BackupOptionChip(
                  label: l10n.backupScheduleWeekly,
                  icon: Icons.date_range_rounded,
                  selected: state.schedule == BackupSchedule.weekly,
                  onTap: () => unawaited(vm.setSchedule(BackupSchedule.weekly)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: BackupOptionChip(
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
class BackupRetentionCard extends StatelessWidget {
  const BackupRetentionCard({super.key, required this.vm});

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
          BackupSectionTitle(
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
                  child: BackupOptionChip(
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
