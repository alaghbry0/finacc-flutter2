/// بطاقتا المبلغ/العملة والصندوق/التاريخ لشاشة السند.
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/voucher_view_model.dart';
import 'cash_widgets.dart';

/// المبلغ وعملة السند — خيارات العملة = عملات الصناديق (+ عملة الطرف
/// إن خالفتها)؛ تغييرها يعيد حساب المديونية المفتوحة والتخصيص.
class VoucherAmountCurrencyCard extends StatelessWidget {
  const VoucherAmountCurrencyCard({
    super.key,
    required this.vm,
    required this.controller,
  });

  final VoucherViewModel vm;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);

    // خيارات فريدة بمعرّف العملة (صناديق + عملة الطرف عند اختلافها).
    final seen = <int>{};
    final options = <({int id, String code})>[
      for (final b in vm.boxes)
        if (seen.add(b.box.currencyId))
          (id: b.box.currencyId, code: b.box.currencyCode),
      if (vm.partyCurrencyId != null &&
          vm.partyCurrencyCode != null &&
          seen.add(vm.partyCurrencyId!))
        (id: vm.partyCurrencyId!, code: vm.partyCurrencyCode!),
    ];

    return FinCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.cashVoucherAmountSection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          CashAmountField(
            controller: controller,
            label: l10n.cashQmAmountLabel,
            suffixCode: vm.voucherCurrencyCode,
            enabled: !vm.saving,
            onChanged: (raw) => vm.setAmount(CashAmountField.parse(raw)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: vm.voucherCurrencyId,
            onChanged: vm.saving ? null : vm.setVoucherCurrency,
            decoration: InputDecoration(
              labelText: l10n.cashVoucherCurrencyLabel,
              prefixIcon: Icon(
                Icons.currency_exchange_rounded,
                color: colors.gold,
              ),
            ),
            items: [
              for (final option in options)
                DropdownMenuItem<int>(
                  value: option.id,
                  child: Text(
                    option.code,
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(fontFeatures: FinText.tabularNums),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// الصندوق والتاريخ.
class VoucherBoxDateCard extends StatelessWidget {
  const VoucherBoxDateCard({
    super.key,
    required this.vm,
    required this.onPickDate,
  });

  final VoucherViewModel vm;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FinCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.cashVoucherBoxSection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          CashBoxPickerField(
            boxes: vm.boxes,
            selectedId: vm.boxId,
            label: l10n.cashMovementFieldBox,
            onChanged: vm.setBox,
            enabled: !vm.saving,
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: vm.saving ? null : onPickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.cashQmDateLabel,
                prefixIcon: const Icon(Icons.event_rounded),
                border: const OutlineInputBorder(),
              ),
              child: Text(
                cashFormatDate(vm.txDate),
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(fontFeatures: FinText.tabularNums),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
