/// بطاقة «مبيعات الشهر» (17-c / FR-09-01): إجمالي الشهر بالعملة الأساس
/// + شارة المقارنة بالشهر السابق (أخضر ▲ / أحمر ▼ / محايد / «جديد» عند
/// صفر السابق) + شارة عدد فواتير الشهر بجانب حلقة أيقونة تقويم.
library;

import 'package:flutter/material.dart';

import '../../../../../data/repositories/dashboard_repository.dart'
    show MonthSalesStats;
import '../../../../../domain/services/numerals.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/numerals_scope.dart';

class MonthSalesCard extends StatelessWidget {
  const MonthSalesCard({
    super.key,
    required this.stats,
    required this.currencyCode,
  });

  final MonthSalesStats stats;
  final String? currencyCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final arabicIndic = NumeralsScope.of(context);
    final pct = stats.changePct;

    // شارة المقارنة: أخضر عند الصعود، أحمر عند الهبوط، محايد عند
    // التساوي، و«جديد» عند صفر الشهر السابق (لا نسبة رياضياً).
    Widget? badge;
    Color? badgeColor;
    if (pct == null) {
      if (stats.thisMonthSales > 0) {
        badge = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 13),
            const SizedBox(width: 4),
            Text(l10n.monthNew),
          ],
        );
        badgeColor = colors.gold;
      }
    } else if (pct > 0) {
      badge = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_drop_up_rounded, size: 18),
          const SizedBox(width: 2),
          Text(l10n.monthChangeUp(_pctText(pct, arabicIndic))),
        ],
      );
      badgeColor = colors.positive;
    } else if (pct < 0) {
      badge = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_drop_down_rounded, size: 18),
          const SizedBox(width: 2),
          Text(l10n.monthChangeDown(_pctText(pct, arabicIndic))),
        ],
      );
      badgeColor = colors.negative;
    } else {
      badge = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.trending_flat_rounded, size: 15),
          const SizedBox(width: 4),
          Text(l10n.monthChangeFlat),
        ],
      );
      badgeColor = colors.neutral;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l10n.monthSalesTitle),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: AmountText(
                          amount: stats.thisMonthSales,
                          size: AmountSize.display,
                        ),
                      ),
                      if (currencyCode != null && currencyCode!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          currencyCode!,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: colors.gold,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ],
                  ),
                  if (badge != null) ...[
                    const SizedBox(height: 8),
                    // الشارة: نص ملون بخلفية دلالية شفافة — العلامة
                    // غير اللونية (السهم) مرافقة دائماً (§6.1).
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor!.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: badgeColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: DefaultTextStyle(
                        style: Theme.of(context).textTheme.labelMedium!
                            .copyWith(
                              color: badgeColor,
                              fontWeight: FontWeight.w800,
                            ),
                        child: badge,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // حلقة أيقونة تقويم + شارة عدد فواتير الشهر تحتها.
            Column(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary.withValues(alpha: 0.10),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    color: scheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.monthInvoices(stats.invoiceCountThisMonth),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// نسبة مئوية مضغوطة (بلا كسر زائف: «23» لا «23.0») بأرقام النظام.
  static String _pctText(double pct, bool arabicIndic) {
    final text = pct.abs().toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
    return arabicIndic ? Numerals.toArabicIndic(text) : text;
  }
}
