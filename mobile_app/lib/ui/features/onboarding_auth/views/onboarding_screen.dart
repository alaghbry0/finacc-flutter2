/// شاشة Onboarding — FR-13-01: بيانات المنشأة ثم PIN وعبارة المرور ثم
/// التأسيس الذرّي (المخزن الرئيسي + الصندوق الرئيسي + السنة المالية).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/company.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/pin_pad.dart';
import '../view_models/onboarding_view_model.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OnboardingViewModel(),
      child: const _OnboardingBody(),
    );
  }
}

class _OnboardingBody extends StatefulWidget {
  const _OnboardingBody();

  @override
  State<_OnboardingBody> createState() => _OnboardingBodyState();
}

class _OnboardingBodyState extends State<_OnboardingBody> {
  List<Currency>? _currencies;
  final _passphraseController = TextEditingController();
  final _passphraseConfirmController = TextEditingController();
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    final repo = context.read<AppController>().companies;
    if (repo != null) {
      unawaited(
        repo.listActiveCurrencies().then((currencies) {
          if (mounted) setState(() => _currencies = currencies);
        }),
      );
    }
  }

  @override
  void dispose() {
    _passphraseController.dispose();
    _passphraseConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OnboardingViewModel>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: switch (vm.step) {
            OnboardingStep.welcome => _WelcomeStep(
              key: const ValueKey('welcome'),
              onStart: vm.startCompanyForm,
            ),
            OnboardingStep.company => _CompanyStep(
              key: const ValueKey('company'),
              currencies: _currencies,
              vm: vm,
              onContinue: vm.submitCompanyForm,
            ),
            OnboardingStep.security => _SecurityStep(
              key: const ValueKey('security'),
              vm: vm,
              passphraseController: _passphraseController,
              passphraseConfirmController: _passphraseConfirmController,
              obscured: _obscured,
              toggleObscured: () => setState(() => _obscured = !_obscured),
              onSubmit: () => vm.submit(context.read<AppController>()),
            ),
            OnboardingStep.creating => _CreatingStep(
              key: const ValueKey('creating'),
            ),
            OnboardingStep.done => _DoneStep(
              key: const ValueKey('done'),
              vm: vm,
              onDone: () async {
                // تفعيل الجلسة يقلب الطور — والموجّه ينتقل بـ/home تلقائياً.
                await context.read<AppController>().completeOnboarding();
                if (context.mounted) context.go('/home');
              },
            ),
          },
        ),
      ),
    );
  }
}

// ── الخطوة 1: الترحيب ──

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final features = <(IconData, String, String)>[
      (
        Icons.wifi_off_rounded,
        l10n.onboardFeature1Title,
        l10n.onboardFeature1Desc,
      ),
      (
        Icons.verified_rounded,
        l10n.onboardFeature2Title,
        l10n.onboardFeature2Desc,
      ),
      (Icons.lock_rounded, l10n.onboardFeature3Title, l10n.onboardFeature3Desc),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
      children: [
        const BrandMark(size: 96, showWordmark: true),
        const SizedBox(height: 26),
        Text(
          l10n.onboardWelcomeTitle,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          l10n.onboardWelcomeMessage,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),
        for (final (icon, title, desc) in features) ...[
          _FeatureRow(icon: icon, title: title, desc: desc),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 26),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onStart,
            child: Text(l10n.commonContinue),
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.desc,
  });

  final IconData icon;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: scheme.onPrimaryContainer, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── الخطوة 2: بيانات المنشأة ──

class _CompanyStep extends StatelessWidget {
  const _CompanyStep({
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
          _StepHeader(
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

// ── الخطوة 3: الأمان (PIN ثم عبارة المرور) ──

class _SecurityStep extends StatelessWidget {
  const _SecurityStep({
    super.key,
    required this.vm,
    required this.passphraseController,
    required this.passphraseConfirmController,
    required this.obscured,
    required this.toggleObscured,
    required this.onSubmit,
  });

  final OnboardingViewModel vm;
  final TextEditingController passphraseController;
  final TextEditingController passphraseConfirmController;
  final bool obscured;
  final VoidCallback toggleObscured;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return vm.passphraseMode
        ? _passphraseSection(context, l10n)
        : _pinSection(context, l10n);
  }

  Widget _pinSection(BuildContext context, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final errorText = _errorText(context, vm.error);
    final pinReady = vm.pinForDots.length >= 4;
    return ListView(
      key: const ValueKey('pin-section'),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      children: [
        _StepHeader(
          index: 2,
          title: vm.confirmingPin ? l10n.pinConfirmTitle : l10n.pinSetupTitle,
          subtitle: vm.confirmingPin
              ? l10n.pinConfirmSubtitle
              : l10n.pinSetupSubtitle,
        ),
        const SizedBox(height: 28),
        PinDots(
          length: vm.pinDotsLength,
          filled: vm.pinForDots.length,
          error: errorText != null,
          shakeKey: vm.error,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 20,
          child: errorText == null
              ? null
              : Text(
                  errorText,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.error),
                  textAlign: TextAlign.center,
                ),
        ),
        const SizedBox(height: 18),
        PinPad(
          onDigit: (digit) {
            vm.addPinDigit(digit);
            // إرسال تلقائي عند بلوغ الحد الأقصى (6 خانات) — توحيداً مع
            // لوحة شاشة القفل (P2-9): نفس سلوك الكاشير في المكانين.
            if (vm.pinForDots.length == 6) {
              vm.pinContinuePressed();
            }
          },
          onBackspace: vm.backspacePin,
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: pinReady ? vm.pinContinuePressed : null,
            icon: const Icon(Icons.check_rounded, size: 20),
            label: Text(
              vm.confirmingPin ? l10n.commonConfirm : l10n.commonContinue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _passphraseSection(BuildContext context, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final errorText = _errorText(context, vm.error);
    final valid = vm.passphraseFormValid;
    // توكنز التحذير الموحدة من FinColors (UX-2b) بدل تكرار قيم
    // warningContainer/onWarningContainer بفحص سطوح يدوي.
    final colors = FinColors.of(context);
    final warningColor = colors.warningContainer;
    final warningFg = colors.onWarningContainer;
    return ListView(
      key: const ValueKey('passphrase-section'),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      children: [
        _StepHeader(
          index: 2,
          title: l10n.passphraseTitle,
          subtitle: l10n.passphraseSubtitle,
        ),
        const SizedBox(height: 22),
        // بطاقة التحذير الملزمة (FR-12-06).
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: warningColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: warningFg, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.passphraseWarningTitle,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(color: warningFg),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.passphraseWarningBody,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: warningFg.withValues(alpha: 0.9)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: passphraseController,
          onChanged: vm.setPassphrase,
          obscureText: obscured,
          decoration: InputDecoration(
            labelText: l10n.passphraseLabel,
            prefixIcon: const Icon(Icons.key_rounded),
            suffixIcon: IconButton(
              onPressed: toggleObscured,
              icon: Icon(
                obscured
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: passphraseConfirmController,
          onChanged: vm.setConfirmedPassphrase,
          obscureText: obscured,
          onSubmitted: (_) => valid ? onSubmit() : null,
          decoration: InputDecoration(
            labelText: l10n.passphraseConfirmLabel,
            prefixIcon: const Icon(Icons.password_rounded),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 20,
          child: errorText == null
              ? null
              : Text(
                  errorText,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.error),
                ),
        ),
        const SizedBox(height: 14),
        if (vm.submitting)
          const Center(child: CircularProgressIndicator())
        else
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: valid ? onSubmit : null,
              icon: const Icon(Icons.shield_rounded, size: 20),
              label: Text(l10n.commonContinue),
            ),
          ),
        TextButton(onPressed: vm.backToPin, child: Text(l10n.commonBack)),
      ],
    );
  }

  String? _errorText(BuildContext context, OnboardingError? error) {
    if (error == null) return null;
    final l10n = AppLocalizations.of(context)!;
    return switch (error) {
      OnboardingError.pinMismatch => l10n.pinMismatch,
      OnboardingError.pinInvalidLength => l10n.pinInvalidLength,
      OnboardingError.passphraseMismatch => l10n.passphraseMismatch,
      OnboardingError.passphraseShort => l10n.passphraseShort,
      OnboardingError.passphraseRequired => l10n.passphraseShort,
      OnboardingError.setupFailed => l10n.setupFailedBody,
    };
  }
}

// ── الخطوة 4: التنفيذ ──

class _CreatingStep extends StatelessWidget {
  const _CreatingStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 54,
              height: 54,
              child: CircularProgressIndicator(strokeWidth: 3.4),
            ),
            const SizedBox(height: 26),
            Text(
              l10n.creatingTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              l10n.creatingMessage,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── الخطوة 5: تم ──

class _DoneStep extends StatelessWidget {
  const _DoneStep({super.key, required this.vm, required this.onDone});

  final OnboardingViewModel vm;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final result = vm.result;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.task_alt_rounded,
                size: 46,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.createdTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            if (result != null) ...[
              Text(
                l10n.createdMessage(result.warehouseName, result.cashboxName),
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusChip(
                    label: result.warehouseName,
                    tone: ChipTone.brand,
                    icon: Icons.warehouse_rounded,
                  ),
                  StatusChip(
                    label: result.cashboxName,
                    tone: ChipTone.positive,
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                  StatusChip(
                    label: result.currencyName,
                    tone: ChipTone.neutral,
                    icon: Icons.payments_rounded,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onDone,
                icon: const Icon(Icons.rocket_launch_rounded, size: 20),
                label: Text(l10n.startUsing),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── ترويسة خطوة موحدة ──

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.index,
    required this.title,
    required this.subtitle,
  });

  final int index;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$index',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: scheme.onPrimary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
