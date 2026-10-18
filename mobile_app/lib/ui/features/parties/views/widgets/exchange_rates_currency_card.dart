/// بطاقة عملة واحدة بشاشة أسعار الصرف (آخر سعر معروف + حقل سعر اليوم +
/// الحفظ + السجل) — مستخرجة من exchange_rates_screen (R20-D3c: نقل حرفي
/// بلا أي تغيير سلوكي؛ مفاتيح الاختبار fx_field_/fx_save_ كما هي).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../view_models/exchange_rates_view_model.dart';
import 'exchange_rate_format.dart';
import 'exchange_rates_history_list.dart';
import 'parties_widgets.dart';

/// بطاقة عملة واحدة — آخر سعر معروف + حقل سعر اليوم + الحفظ + السجل.
class ExchangeRatesCurrencyCard extends StatelessWidget {
  const ExchangeRatesCurrencyCard({
    super.key,
    required this.entry,
    required this.controller,
    required this.expanded,
    required this.onToggleHistory,
    required this.onSave,
  });

  final FxCurrencyEntry entry;
  final TextEditingController? controller;
  final bool expanded;
  final VoidCallback onToggleHistory;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final currency = entry.currency;
    final latest = entry.latest;

    return FinCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CurrencyCodePill(code: currency.code),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  currency.name,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              StatusChip(
                label: entry.enteredToday
                    ? l10n.fxEnteredToday
                    : l10n.fxMissingToday,
                tone: entry.enteredToday ? ChipTone.positive : ChipTone.warning,
                icon: entry.enteredToday
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            latest == null
                ? l10n.fxNoRateYet
                : l10n.fxLastKnownRate(
                    exchangeRateFormatRate(context, latest.rate),
                    partyFormatDate(context, latest.rateDateUtc),
                  ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  key: Key('fx_field_${currency.code}'),
                  controller: controller,
                  enabled: !entry.saving,
                  onChanged: (_) => context
                      .read<ExchangeRatesViewModel>()
                      .clearFieldError(currency.id),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.fxRateFieldLabel,
                    helperText: l10n.fxAgainstBase(_baseCode(context)),
                    errorText: entry.fieldError ? l10n.fxRateInvalid : null,
                    prefixIcon: const Icon(Icons.price_change_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                key: Key('fx_save_${currency.code}'),
                onPressed: entry.saving ? null : onSave,
                icon: entry.saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(
                  entry.saving ? l10n.fxSavingLabel : l10n.fxSaveLabel,
                ),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              ),
            ],
          ),
          if (entry.fieldError) ...[
            const SizedBox(height: 6),
            Text(
              l10n.fxRateInvalid,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.negative,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: onToggleHistory,
              icon: Icon(
                expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 18,
              ),
              label: Text(expanded ? l10n.fxHideHistory : l10n.fxShowHistory),
            ),
          ),
          if (expanded) ExchangeRatesHistoryList(entry: entry),
        ],
      ),
    );
  }

  static String _baseCode(BuildContext context) {
    final state = context.read<ExchangeRatesViewModel>().state;
    return state.baseCurrency?.code ?? '';
  }
}
