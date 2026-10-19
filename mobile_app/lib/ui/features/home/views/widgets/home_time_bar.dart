/// شريطا النطاق الزمني والشهر — نمط Simple Invoice Manager (V3):
/// رقاقة زرقاء فاتحة (حدّ سماوي/تعبئة سماوية/نص أزرق غامق) لاختيار
/// النطاق الزمني، وشريط رمادي مزرق عريض يجمع اسم الشهر ومبيعاته
/// بالعملة الأساسية وعدد فواتيره.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../../l10n/app_localizations.dart';
import '../../../../../domain/services/numerals.dart';
import '../../../../../data/repositories/dashboard_repository.dart';
import '../../view_models/transactions_home_view_model.dart';
import '../../../../core/widgets/numerals_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';

/// رقاقة النطاق الزمني + رابط التفاصيل.
class HomeTimeBar extends StatelessWidget {
  const HomeTimeBar({super.key, required this.range, required this.onTap});

  /// النطاق الحالي (يُعرض نصه).
  final HomeTimeRange range;

  /// يفتح قائمة النطاقات.
  final VoidCallback onTap;

  String _label(AppLocalizations l10n) => switch (range) {
    HomeTimeRange.all => l10n.homeTimeAll,
    HomeTimeRange.year => l10n.homeTimeYear,
    HomeTimeRange.quarter => l10n.homeTimeQuarter,
    HomeTimeRange.month => l10n.homeTimeMonth,
    HomeTimeRange.week => l10n.homeTimeWeek,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      child: Row(
        children: [
          InkWell(
            key: const Key('home_time_range_button'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Text(
                    _label(l10n),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: scheme.primary,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

/// شريط «مبيعات الشهر» الرمادي — يعكس بيانات `monthStats` بالعملة
/// الأساسية (تدهور رشيق: غيابه عند فشل الاستعلام).
class HomeMonthStrip extends StatelessWidget {
  const HomeMonthStrip({super.key, required this.month, this.currencyCode});

  /// إحصاءات الشهر (null = الشريط البديل).
  final MonthSalesStats? month;

  /// رمز العملة الأساسية (YER/…) — null يُعرض بلا رمز.
  final String? currencyCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final localeName = l10n.localeName;
    final now = DateTime.now();
    final monthName = DateFormat.yMMMM(localeName).format(now);

    return Container(
      key: const Key('home_month_strip'),
      width: double.infinity,
      color: colors.surfaceContainerHigh.withValues(alpha: 0.55),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${l10n.homeMonthSalesLabel} — $monthName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 13,
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (month != null)
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                _monthAmount(context, month!.thisMonthSales),
                style: FinText.withTabularDigits(
                  Theme.of(context).textTheme.labelLarge!,
                ).copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: FinColors.of(context).positive,
                ),
              ),
            )
          else
            Text(
              l10n.homeMonthFallback,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontSize: 12,
                color: colors.onSurfaceVariant,
              ),
            ),
          if (month != null) ...[
            const SizedBox(width: 10),
            Text(
              l10n.homeMonthInvoicesLabel(month!.invoiceCountThisMonth),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 11,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// مبلغ الشهر بعملته الأساسية — أرقام جدولية بأرقام النظام الحي.
  String _monthAmount(BuildContext context, double amount) {
    final decimals = currencyCode == 'YER' ? 0 : 2;
    var text = AmountText.format(amount, decimals);
    if (NumeralsScope.of(context)) {
      text = Numerals.toArabicIndic(text);
    }
    return currencyCode == null ? text : '$text $currencyCode';
  }
}
