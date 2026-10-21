/// بطاقة اليوم بشاشة أسعار الصرف (التاريخ الهجري والميلادي وحالة
/// الإدخال الكاملة) — مستخرجة من exchange_rates_screen (R20-D3c: نقل
/// حرفي بلا أي تغيير سلوكي).
library;

import 'package:flutter/material.dart';

import '../../../../../domain/services/hijri_date.dart';
import '../../../../../domain/services/numerals.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/fin_tokens.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/fin_date_text.dart';
import '../../../../core/widgets/numerals_scope.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../view_models/exchange_rates_view_model.dart';

/// بطاقة اليوم — التاريخ الهجري والميلادي وحالة الإدخال الكاملة.
class ExchangeRatesTodayCard extends StatelessWidget {
  const ExchangeRatesTodayCard({super.key, required this.state});

  final ExchangeRatesState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final arabicIndic = NumeralsScope.of(context);
    String localizeDigits(String plain) =>
        arabicIndic ? Numerals.toArabicIndic(plain) : plain;

    final now = DateTime.now();
    final hijri = HijriCalendar.fromDateTime(now);
    final hijriText = localizeDigits(
      '${hijri.day} ${hijri.monthName} ${hijri.year} هـ',
    );
    final gregorianText = FinDateText.date(context, now);

    return FinCard(
      accent: colors.gold,
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
                  borderRadius: BorderRadius.circular(FinRadius.control),
                ),
                child: Icon(
                  Icons.currency_exchange_rounded,
                  color: scheme.onPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.fxTodayHijriDate(hijriText),
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      gregorianText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // V7-A (تحصين): جملة التحذير الكاملة (76 حرفاً ≈ 737px) كانت
          // تسمية رقاقة واحدة فتفيض داخل بطاقة 296px — الرقاقة الآن
          // بخلاصة قصيرة والجملة نص تفسيري أسفلها (لا فقد معلومة).
          if (state.complete)
            StatusChip(
              label: l10n.fxAllComplete,
              tone: ChipTone.positive,
              icon: Icons.check_circle_rounded,
            )
          else ...[
            StatusChip(
              label: l10n.fxMissingToday,
              tone: ChipTone.warning,
              icon: Icons.warning_amber_rounded,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.fxMissingWarning,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            l10n.fxBaseNote(state.baseCurrency?.code ?? ''),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
