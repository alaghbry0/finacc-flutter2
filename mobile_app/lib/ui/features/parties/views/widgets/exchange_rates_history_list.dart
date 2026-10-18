/// سجل آخر الأسعار لعملة واحدة (تاريخ + سعر بأرقام جدولية LTR) —
/// مستخرجة من exchange_rates_screen (R20-D3c: نقل حرفي بلا أي تغيير
/// سلوكي).
library;

import 'package:flutter/material.dart';

import '../../../../../domain/services/numerals.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/numerals_scope.dart';
import '../../view_models/exchange_rates_view_model.dart';
import 'exchange_rate_format.dart';
import 'parties_widgets.dart';

/// سجل آخر الأسعار لعملة — تاريخ + سعر بأرقام جدولية LTR.
class ExchangeRatesHistoryList extends StatelessWidget {
  const ExchangeRatesHistoryList({super.key, required this.entry});

  final FxCurrencyEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    if (entry.history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          l10n.fxHistoryEmpty,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          for (final rate in entry.history.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(
                    Icons.event_rounded,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      partyFormatDate(context, rate.rateDateUtc),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      NumeralsScope.of(context)
                          ? Numerals.toArabicIndic(exchangeRatePlainRate(rate))
                          : exchangeRatePlainRate(rate),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
