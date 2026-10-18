/// شريط رقائق تصفية قائمة الأطراف الأربع (الكل/بأرصدة/بدون/مؤرشفون) —
/// مستخرج من parties_list_screen (R20-D3b: نقل حرفي بلا أي تغيير سلوكي).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../view_models/party_list_view_model.dart';

/// شريط رقائق التصفية الأربع.
class PartiesFilterBar extends StatelessWidget {
  const PartiesFilterBar({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final PartyListFilter selected;
  final ValueChanged<PartyListFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          _FilterChip(
            key: const Key('parties_filter_all'),
            label: l10n.partiesFilterAll,
            selected: selected == PartyListFilter.all,
            onTap: () => onSelect(PartyListFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            key: const Key('parties_filter_with_balance'),
            label: l10n.partiesFilterWithBalance,
            selected: selected == PartyListFilter.withBalance,
            onTap: () => onSelect(PartyListFilter.withBalance),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            key: const Key('parties_filter_zero_balance'),
            label: l10n.partiesFilterZeroBalance,
            selected: selected == PartyListFilter.zeroBalance,
            onTap: () => onSelect(PartyListFilter.zeroBalance),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            key: const Key('parties_filter_archived'),
            label: l10n.partiesFilterArchived,
            selected: selected == PartyListFilter.archived,
            onTap: () => onSelect(PartyListFilter.archived),
          ),
        ],
      ),
    );
  }
}

/// رقاقة تصفية واحدة — حركة اختيار متحركة.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effective = scheme.primary;
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? effective : scheme.onSurface,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
