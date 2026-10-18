/// شريط تصفية بالتصنيف — رقائق أفقية بعدّادات لكل تصنيف.
library;

import 'package:flutter/material.dart';

import '../../../../../domain/models/audit_event.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

class AuditFilterBar extends StatelessWidget {
  const AuditFilterBar({
    super.key,
    required this.selected,
    required this.counts,
    required this.onSelect,
  });

  final AuditCategory? selected;
  final Map<AuditCategory, int> counts;
  final ValueChanged<AuditCategory?> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          _FilterChip(
            label: l10n.auditFilterAll,
            count: total,
            selected: selected == null,
            icon: Icons.apps_rounded,
            onTap: () => onSelect(null),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: l10n.auditFilterSetup,
            count: counts[AuditCategory.setup] ?? 0,
            selected: selected == AuditCategory.setup,
            icon: Icons.rocket_launch_rounded,
            accent: _accentFor(context, AuditCategory.setup),
            onTap: () => onSelect(AuditCategory.setup),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: l10n.auditFilterSecurity,
            count: counts[AuditCategory.security] ?? 0,
            selected: selected == AuditCategory.security,
            icon: Icons.gpp_maybe_rounded,
            accent: _accentFor(context, AuditCategory.security),
            onTap: () => onSelect(AuditCategory.security),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: l10n.auditFilterSettings,
            count: counts[AuditCategory.settings] ?? 0,
            selected: selected == AuditCategory.settings,
            icon: Icons.tune_rounded,
            accent: _accentFor(context, AuditCategory.settings),
            onTap: () => onSelect(AuditCategory.settings),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: l10n.auditFilterOther,
            count: counts[AuditCategory.other] ?? 0,
            selected: selected == AuditCategory.other,
            icon: Icons.event_note_rounded,
            accent: _accentFor(context, AuditCategory.other),
            onTap: () => onSelect(AuditCategory.other),
          ),
        ],
      ),
    );
  }

  /// لون التصنيف — مطابق لأيقونات الخط الزمني (اتساق دلالي §6.1).
  Color _accentFor(BuildContext context, AuditCategory category) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return switch (category) {
      AuditCategory.setup => scheme.primary,
      AuditCategory.security => colors.negative,
      AuditCategory.settings => colors.warning,
      AuditCategory.other => scheme.onSurfaceVariant,
    };
  }
}

/// رقاقة تصفية واحدة بحركة اختيار وعدّاد بأرقام جدولية.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.icon,
    required this.onTap,
    this.accent,
  });

  final String label;
  final int count;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effective = accent ?? scheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Material(
        color: selected
            ? effective.withValues(alpha: 0.14)
            : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: selected
              ? BorderSide(color: effective.withValues(alpha: 0.55), width: 1.4)
              : BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: selected ? effective : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? effective : scheme.onSurface,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? effective.withValues(alpha: 0.18)
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected ? effective : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
