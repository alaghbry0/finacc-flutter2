/// شريط فترات التقارير المسبقة (الشريحة 10 — FR-09-02): شريط رقائق
/// أفقي (اليوم / آخر ٧ أيام / الشهر / الربع / السنة / فترة مخصصة)
/// **عنصر مشترك** تعاد استخدامه في تقارير لاحقة.
///
/// «الفترة المخصصة» تفتح منتقي مدى تاريخ (showDateRangePicker) وتسلّم
/// النطاق للمستدعي — منطق حساب النطاقات نفسه هنا (`computePeriodRange`)
/// حتى يبقى النموذج والشريط على قراءة واحدة (قرار موثق: كل النطاقات
/// **تنتهي اليوم** — لا مستقبل في التقارير).
library;

import 'package:flutter/material.dart';

import '../../../../../domain/services/numerals.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/numerals_scope.dart';

/// فترة التقرير المسبقة.
enum ReportPeriod {
  /// [اليوم، اليوم].
  today,

  /// آخر ٧ أيام شاملة اليوم.
  week,

  /// من أول الشهر الجاري إلى اليوم.
  month,

  /// من أول الربع التقويمي الجاري إلى اليوم.
  quarter,

  /// من أول السنة إلى اليوم.
  year,

  /// مدى يختاره المستخدم (منتقي التاريخ).
  custom,
}

/// يحسب نطاق الفترة [من، إلى] (شاملة الطرفين) — الطرف الأعلى دائماً
/// **اليوم** (لا مستقبل)، والأدنى حد الفترة التقويمي.
DateTimeRange computePeriodRange(ReportPeriod period, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  switch (period) {
    case ReportPeriod.today:
      return DateTimeRange(start: today, end: today);
    case ReportPeriod.week:
      return DateTimeRange(
        start: today.subtract(const Duration(days: 6)),
        end: today,
      );
    case ReportPeriod.month:
      return DateTimeRange(
        start: DateTime(today.year, today.month),
        end: today,
      );
    case ReportPeriod.quarter:
      final quarterStart = DateTime(
        today.year,
        ((today.month - 1) ~/ 3) * 3 + 1,
      );
      return DateTimeRange(start: quarterStart, end: today);
    case ReportPeriod.year:
      return DateTimeRange(start: DateTime(today.year), end: today);
    case ReportPeriod.custom:
      // لا نطاق محسوب — يحدده المستدعي عبر onCustomRange.
      return DateTimeRange(start: today, end: today);
  }
}

/// شريط رقائق الفترات المسبقة — بلا حالة داخلية (المصدر الحقيقة عند
/// المستدعي عبر [selected]/[currentFrom]/[currentTo]).
class PeriodPresetBar extends StatelessWidget {
  const PeriodPresetBar({
    super.key,
    required this.selected,
    required this.onPeriodSelected,
    required this.onCustomRange,
    this.currentFrom,
    this.currentTo,
  });

  /// الفترة المحددة حالياً.
  final ReportPeriod selected;

  /// اختيار فترة مسبقة (غير المخصصة).
  final ValueChanged<ReportPeriod> onPeriodSelected;

  /// اختيار المدى المخصص (بعد تأكيد منتقي التاريخ).
  final void Function(DateTime from, DateTime to) onCustomRange;

  /// بداية المدى الحالي (لعرضه ولبذر منتقي التاريخ).
  final DateTime? currentFrom;

  /// نهاية المدى الحالي.
  final DateTime? currentTo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return FinCard(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              // RTL: الرقائق تتدفق من اليمين — «اليوم» أقصى اليمين.
              children: [
                for (final period in ReportPeriod.values)
                  _PeriodChip(
                    key: Key(_periodKey(period)),
                    period: period,
                    selected: period == selected,
                    onTap: () => _handleTap(context, period),
                  ),
              ],
            ),
          ),
          if (selected == ReportPeriod.custom) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.date_range_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: currentFrom == null || currentTo == null
                      ? Text(
                          key: const Key('periodCustomHint'),
                          l10n.periodCustomHint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Text(
                                key: const Key('periodFrom'),
                                '${l10n.periodFrom} '
                                '${_fmtDate(context, currentFrom!)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Text(
                                '·',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                key: const Key('periodTo'),
                                '${l10n.periodTo} '
                                '${_fmtDate(context, currentTo!)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// نقرة رقاقة: المخصصة تفتح منتقي المدى، وغيرها تُسلَّم مباشرة.
  Future<void> _handleTap(BuildContext context, ReportPeriod period) async {
    if (period != ReportPeriod.custom) {
      onPeriodSelected(period);
      return;
    }
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      helpText: AppLocalizations.of(context)!.periodCustomHint,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: currentFrom == null || currentTo == null
          ? null
          : DateTimeRange(start: currentFrom!, end: currentTo!),
    );
    if (range == null) return; // إلغاء — لا تغيير.
    onCustomRange(range.start, range.end);
  }
}

/// مفتاح رقاقة الفترة الثابت — periodToday/periodWeek/periodMonth/
/// periodQuarter/periodYear/periodCustom (لاختبارات التقارير المشتركة).
String _periodKey(ReportPeriod period) {
  final name = period.name; // today/week/month/quarter/year/custom.
  return 'period${name[0].toUpperCase()}${name.substring(1)}';
}

/// رقاقة فترة واحدة — هدف لمس ≥ 48dp (قاعدة الملموسية) ومفتاح ثابت
/// `periodXxx` (periodToday/periodWeek/… — لاختبارات التقارير المشتركة).
class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    super.key,
    required this.period,
    required this.selected,
    required this.onTap,
  });

  final ReportPeriod period;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6),
      child: Center(
        child: ChoiceChip(
          label: Text(_label(l10n, period)),
          selected: selected,
          onSelected: (_) => onTap(),
          // حشوة رأسية أكبر ترفع هدف اللمس نحو 48dp.
          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          avatar: period == ReportPeriod.custom
              ? Icon(
                  Icons.tune_rounded,
                  size: 16,
                  color: selected ? null : colors.neutral,
                )
              : null,
        ),
      ),
    );
  }

  static String _label(AppLocalizations l10n, ReportPeriod period) {
    return switch (period) {
      ReportPeriod.today => l10n.periodToday,
      ReportPeriod.week => l10n.periodWeek,
      ReportPeriod.month => l10n.periodMonth,
      ReportPeriod.quarter => l10n.periodQuarter,
      ReportPeriod.year => l10n.periodYear,
      ReportPeriod.custom => l10n.periodCustom,
    };
  }
}

/// تاريخ للعرض `يوم/شهر/سنة` بنظام أرقام السياق (نمط شاشة الأعمار).
String _fmtDate(BuildContext context, DateTime date) {
  final plain = '${date.day}/${date.month}/${date.year}';
  return NumeralsScope.of(context) ? Numerals.toArabicIndic(plain) : plain;
}
