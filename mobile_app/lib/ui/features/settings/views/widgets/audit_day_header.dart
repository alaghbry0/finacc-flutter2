/// رأس اليوم: «اليوم/أمس» أو التاريخ هجري + ميلادي.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../domain/services/hijri_date.dart';
import '../../../../../domain/services/numerals.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

class AuditDayHeader extends StatelessWidget {
  const AuditDayHeader({
    super.key,
    required this.dayKey,
    required this.arabicIndic,
    required this.count,
  });

  final String dayKey;
  final bool arabicIndic;

  /// عدد أحداث اليوم المعروضة — شارة جدولية بجانب التاريخ.
  final int count;

  (String, String) _labels(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final parts = dayKey.split('-');
    final date = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(date).inDays;
    final hijri = HijriCalendar.fromDateTime(date).toString();
    final gregorian = DateFormat('d MMMM y', 'ar').format(date);
    final hijriText = arabicIndic ? Numerals.toArabicIndic(hijri) : hijri;
    final gregorianText = arabicIndic
        ? gregorian
        : Numerals.toWestern(gregorian);
    final prefix = switch (diff) {
      0 => l10n.auditDayToday,
      1 => l10n.auditDayYesterday,
      _ => '',
    };
    return (prefix, '$hijriText  •  $gregorianText');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final (prefix, dateText) = _labels(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Row(
        children: [
          if (prefix.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    scheme.primary,
                    Color.lerp(scheme.primary, Colors.black, 0.2)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                prefix,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              dateText,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: colors.gold, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: colors.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              arabicIndic ? Numerals.toArabicIndic('$count') : '$count',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.gold,
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
