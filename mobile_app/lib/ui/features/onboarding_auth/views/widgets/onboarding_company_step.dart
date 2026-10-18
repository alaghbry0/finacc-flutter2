/// الخطوة 2: بيانات المنشأة (R19-D3c — مستخرجة حرفياً من
/// `onboarding_screen.dart` بلا أي تغيير دلالة).
library;

import 'package:flutter/material.dart';

import '../../../../../domain/models/company.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../view_models/onboarding_view_model.dart';
import 'onboarding_step_header.dart';

/// خطوة بيانات المنشأة — الاسم والهاتف + اختيار العملة الأساسية.
class OnboardingCompanyStep extends StatelessWidget {
  const OnboardingCompanyStep({
    super.key,
    required this.currencies,
    required this.vm,
    required this.onContinue,
  });

  final List<Currency>? currencies;
  final OnboardingViewModel vm;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final nameValid = vm.isCompanyNameValid;
    return Form(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        children: [
          OnboardingStepHeader(
            index: 1,
            title: l10n.onboardStepCompany,
            subtitle: l10n.companyNameHint,
          ),
          const SizedBox(height: 24),
          TextField(
            onChanged: vm.setCompanyName,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.companyNameLabel,
              hintText: l10n.companyNameHint,
              prefixIcon: const Icon(Icons.storefront_rounded),
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: vm.setCompanyPhone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.companyPhoneLabel,
              hintText: l10n.companyPhoneHint,
              prefixIcon: const Icon(Icons.phone_rounded),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.baseCurrencyLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.baseCurrencyHint,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          if (currencies == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else
            ...currencies!.map(
              (currency) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CurrencyOption(
                  currency: currency,
                  selected: vm.baseCurrencyCode == currency.code,
                  decimalsNote: l10n.baseCurrencyDecimalsNote(
                    currency.decimals,
                  ),
                  onTap: () =>
                      vm.selectCurrency(currency.code, currency.decimals),
                ),
              ),
            ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: nameValid ? onContinue : null,
              child: Text(l10n.commonContinue),
            ),
          ),
          if (!nameValid)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                l10n.companyFormInvalid,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.error),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _CurrencyOption extends StatelessWidget {
  const _CurrencyOption({
    required this.currency,
    required this.selected,
    required this.decimalsNote,
    required this.onTap,
  });

  final Currency currency;
  final bool selected;
  final String decimalsNote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.primary
                      : scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  currency.code,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currency.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: selected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                      ),
                    ),
                    Text(
                      decimalsNote,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: selected
                            ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? scheme.primary : scheme.outlineVariant,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
