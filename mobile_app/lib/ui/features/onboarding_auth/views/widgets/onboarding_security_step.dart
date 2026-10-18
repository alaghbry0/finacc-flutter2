/// الخطوة 3: الأمان — PIN ثم عبارة المرور (R19-D3c — مستخرجة حرفياً من
/// `onboarding_screen.dart` بلا أي تغيير دلالة).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/pin_pad.dart';
import '../../view_models/onboarding_view_model.dart';
import 'onboarding_step_header.dart';

/// خطوة الأمان — إدخال PIN وتأكيده أو عبارة المرور الملزمة.
class OnboardingSecurityStep extends StatelessWidget {
  const OnboardingSecurityStep({
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
        OnboardingStepHeader(
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
        OnboardingStepHeader(
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
