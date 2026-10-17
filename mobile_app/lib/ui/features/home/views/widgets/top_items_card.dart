/// قسم «أعلى الأصناف مبيعاً» هذا الشهر (17-c / FR-09-01): بطاقة ترتيب
/// بشارات ذهبية/فضية/برونزية للأعمدة الأولى، وكمية وإيراد لكل صنف،
/// وشريط حصة الكمية النسبي — أو حالة فراغ عند غياب مبيعات الشهر.
library;

import 'package:flutter/material.dart';

import '../../../../../data/repositories/dashboard_repository.dart'
    show TopItemStat;
import '../../../../../domain/services/numerals.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/numerals_scope.dart';

class TopItemsCard extends StatelessWidget {
  const TopItemsCard({
    super.key,
    required this.items,
    required this.currencyCode,
  });

  final List<TopItemStat> items;
  final String? currencyCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: l10n.topItemsTitle),
          EmptyState(
            icon: Icons.military_tech_rounded,
            title: l10n.topItemsEmpty,
            message: l10n.topItemsEmptyBody,
            compact: true,
          ),
        ],
      );
    }
    final maxQty = items.first.qtySold <= 0 ? 1.0 : items.first.qtySold;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: SectionHeader(title: l10n.topItemsTitle)),
            _MonthScopeChip(label: l10n.topItemsScope),
          ],
        ),
        for (var i = 0; i < items.length; i++)
          _TopItemRow(
            rank: i + 1,
            stat: items[i],
            maxQty: maxQty,
            currencyCode: currencyCode,
          ),
      ],
    );
  }
}

/// شارة «هذا الشهر» الصغيرة بجوار ترويسة القسم.
class _MonthScopeChip extends StatelessWidget {
  const _MonthScopeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_repeat_rounded,
            size: 13,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// سطر صنف في قائمة الأعلى: شارة ترتيب (ذهبي/فضي/برونزي) + الاسم
/// والكمية + الإيراد بالعملة الأساس + شريط حصة الكمية النسبي.
class _TopItemRow extends StatelessWidget {
  const _TopItemRow({
    required this.rank,
    required this.stat,
    required this.maxQty,
    required this.currencyCode,
  });

  final int rank;
  final TopItemStat stat;
  final double maxQty;
  final String? currencyCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final arabicIndic = NumeralsScope.of(context);

    // تدرّج الميداليات: ذهبي → فضي (محايد) → برونزي (تحذيري دافئ)
    // → بقية القائمة بلون التطبيق الهادئ.
    final medalColor = switch (rank) {
      1 => colors.gold,
      2 => colors.neutral,
      3 => colors.warning,
      _ => scheme.primary.withValues(alpha: 0.75),
    };
    final rankText = arabicIndic
        ? Numerals.toArabicIndic(rank.toString())
        : rank.toString();
    final qtyText = stat.qtySold == stat.qtySold.truncateToDouble()
        ? stat.qtySold.truncate().toString()
        : stat.qtySold.toStringAsFixed(3);

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: medalColor.withValues(alpha: 0.16),
                  border: Border.all(color: medalColor.withValues(alpha: 0.40)),
                ),
                child: Center(
                  child: Text(
                    rankText,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: medalColor,
                      // w900 غير متوفر في Almarai (300/400/700/800) —
                      // أقرب وزن متاح هو 800 (UX-2b).
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat.name,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.topItemsQtyCount(
                        arabicIndic ? Numerals.toArabicIndic(qtyText) : qtyText,
                      ),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AmountText(
                    amount: stat.revenueBase,
                    size: AmountSize.row,
                    showSignMarker: false,
                  ),
                  if (currencyCode != null && currencyCode!.isNotEmpty)
                    Text(
                      currencyCode!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          // شريط حصة الكمية النسبي (نسبةً لأعلى صنف) بلون الميدالية.
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: (stat.qtySold / maxQty).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: scheme.surfaceContainerLow,
                valueColor: AlwaysStoppedAnimation<Color>(
                  medalColor.withValues(alpha: 0.75),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
