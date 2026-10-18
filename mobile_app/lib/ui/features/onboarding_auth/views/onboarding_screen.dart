/// شاشة Onboarding — FR-13-01: بيانات المنشأة ثم PIN وعبارة المرور ثم
/// التأسيس الذرّي (المخزن الرئيسي + الصندوق الرئيسي + السنة المالية).
///
/// خطوات الشاشة الخمس مستخرجة إلى `widgets/` (R19-D3c): الترحيب وبطاقاته،
/// بيانات المنشأة وخيارات عملتها، الأمان (PIN/عبارة المرور)، والتنفيذ
/// والتمام — هذا الملف هو آلة الأطوار ومالك متحكمات الإدخال.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/company.dart';
import '../../../core/session/app_controller.dart';
import '../view_models/onboarding_view_model.dart';
import 'widgets/onboarding_company_step.dart';
import 'widgets/onboarding_creating_done_steps.dart';
import 'widgets/onboarding_security_step.dart';
import 'widgets/onboarding_welcome_step.dart';

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
            OnboardingStep.welcome => OnboardingWelcomeStep(
              key: const ValueKey('welcome'),
              onStart: vm.startCompanyForm,
            ),
            OnboardingStep.company => OnboardingCompanyStep(
              key: const ValueKey('company'),
              currencies: _currencies,
              vm: vm,
              onContinue: vm.submitCompanyForm,
            ),
            OnboardingStep.security => OnboardingSecurityStep(
              key: const ValueKey('security'),
              vm: vm,
              passphraseController: _passphraseController,
              passphraseConfirmController: _passphraseConfirmController,
              obscured: _obscured,
              toggleObscured: () => setState(() => _obscured = !_obscured),
              onSubmit: () => vm.submit(context.read<AppController>()),
            ),
            OnboardingStep.creating => const OnboardingCreatingStep(
              key: ValueKey('creating'),
            ),
            OnboardingStep.done => OnboardingDoneStep(
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
