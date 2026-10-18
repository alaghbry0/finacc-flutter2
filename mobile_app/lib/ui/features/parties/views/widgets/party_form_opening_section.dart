/// قسم الرصيد الافتتاحي بنموذج الطرف (مبلغ + عملة + تاريخ مقفل عند وجود
/// حركات) — مستخرج من party_form_screen (R20-D3b: نقل حرفي بلا أي تغيير
/// سلوكي؛ منطق منتقي التاريخ يبقى بمتحكم الشاشة ويصله عبر النداء).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/party_form_view_model.dart';

class PartyFormOpeningSection extends StatelessWidget {
  const PartyFormOpeningSection({
    super.key,
    required this.vm,
    required this.state,
    required this.openingController,
    required this.openingDateController,
    required this.onPickOpeningDate,
  });

  final PartyFormViewModel vm;
  final PartyFormState state;

  final TextEditingController openingController;
  final TextEditingController openingDateController;

  /// يفتح منتقي التاريخ (يظل ملك متحكم الشاشة — يزامن الحقل بعده).
  final VoidCallback onPickOpeningDate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locked = state.openingLocked;
    return FinCard(
      padding: const EdgeInsets.all(14),
      child: IgnorePointer(
        ignoring: locked,
        child: Opacity(
          opacity: locked ? 0.55 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const Key('party_form_opening_field'),
                controller: openingController,
                enabled: !locked,
                onChanged: vm.setOpeningText,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.partyFormOpeningAmountLabel,
                  hintText: l10n.partyFormOpeningAmountHint,
                  prefixIcon: const Icon(Icons.savings_rounded),
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return null;
                  final parsed = double.tryParse(text);
                  if (parsed == null || parsed < 0) {
                    return l10n.partyFormOpeningAmountInvalid;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                key: Key(
                  'party_form_opening_currency_${state.openingCurrencyId}',
                ),
                initialValue: state.openingCurrencyId,
                onChanged: vm.setOpeningCurrency,
                decoration: InputDecoration(
                  labelText: l10n.partyFormOpeningCurrencyLabel,
                  prefixIcon: const Icon(Icons.currency_exchange_rounded),
                ),
                items: [
                  DropdownMenuItem<int>(
                    child: Text(l10n.partyFormOpeningCurrencyNone),
                  ),
                  for (final currency in state.currencies)
                    DropdownMenuItem<int>(
                      value: currency.id,
                      child: Text('${currency.name} (${currency.code})'),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('party_form_opening_date_field'),
                readOnly: true,
                controller: openingDateController,
                onTap: locked ? null : onPickOpeningDate,
                decoration: InputDecoration(
                  labelText: l10n.partyFormOpeningDateLabel,
                  prefixIcon: const Icon(Icons.event_rounded),
                  suffixIcon: locked
                      ? const Icon(Icons.lock_rounded)
                      : const Icon(Icons.edit_calendar_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
