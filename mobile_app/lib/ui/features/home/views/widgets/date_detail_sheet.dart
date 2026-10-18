/// لوحة تفاصيل التاريخ للداشبورد (§6.5) — تُفتح من بطاقة الترحيب.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../domain/services/hijri_date.dart';
import '../../../../../domain/services/numerals.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/numerals_scope.dart';

/// يفتح لوحة تفاصيل التاريخ — التقويمان هجري/ميلادي بيوم الأسبوع.
Future<void> showHomeDateDetails(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (context) => const DateDetailSheet(),
  );
}

/// لوحة تفاصيل التاريخ: هجري كبير + ميلادي + يوم الأسبوع بنظام الأرقام الحي.
class DateDetailSheet extends StatelessWidget {
  const DateDetailSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final arabicIndic = NumeralsScope.of(context);
    final now = DateTime.now();
    final hijri = HijriCalendar.today();
    final hijriText = hijri.toString();
    final weekday = DateFormat('EEEE', 'ar').format(now);
    final gregorian = DateFormat('d MMMM y', 'ar').format(now);
    String num(String t) => arabicIndic ? Numerals.toArabicIndic(t) : t;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  color: scheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.dateSheetTitle,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.gold.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.gold.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    l10n.dateSheetTodayBadge,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // البطاقة الهجرية — البطاقة البطلة بلون دلالي إيجابي.
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    scheme.primary,
                    Color.lerp(scheme.primary, Colors.black, 0.3)!,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.nightlight_round,
                        color: colors.gold,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.dateSheetHijriLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimary.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    num(hijriText),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // البطاقة الميلادية + يوم الأسبوع.
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.wb_sunny_rounded,
                              color: colors.warning,
                              size: 15,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              l10n.dateSheetGregorianLabel,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          num(gregorian),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.today_rounded,
                          size: 14,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          weekday,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
