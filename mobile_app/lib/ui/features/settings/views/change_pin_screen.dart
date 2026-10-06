/// شاشة تغيير رمز PIN — ثلاث خطوات (الحالي ← الجديد ← التأكيد) بلوحة
/// PIN نفسها مع رأس خطوات بصري (شارات مرقمة متصلة بخط تقدم).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/pin_pad.dart';
import '../view_models/settings_view_model.dart';

class ChangePinScreen extends StatelessWidget {
  const ChangePinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    return ChangeNotifierProvider(
      create: (_) => ChangePinViewModel(userRepo: app.users!),
      child: const _ChangePinBody(),
    );
  }
}

class _ChangePinBody extends StatefulWidget {
  const _ChangePinBody();

  @override
  State<_ChangePinBody> createState() => _ChangePinBodyState();
}

class _ChangePinBodyState extends State<_ChangePinBody> {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ChangePinViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    if (vm.step == 3) {
      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(leading: const CloseButton()),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.6, end: 1),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutBack,
                  builder: (context, t, child) =>
                      Transform.scale(scale: t, child: child),
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primaryContainer,
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 52,
                      color: scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.changePinDoneTitle,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.changePinDoneBody,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.task_alt_rounded, size: 20),
                    label: Text(l10n.commonDone),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: Text(l10n.settingsChangePin),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          children: [
            _StepHeader(step: vm.step),
            const SizedBox(height: 26),
            Text(
              _subtitleFor(l10n, vm.step),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            PinDots(
              length: vm.dotLength,
              filled: vm.entered.length,
              error:
                  vm.errorKey == 'pinMismatch' ||
                  vm.errorKey == 'wrongCurrent' ||
                  vm.errorKey == 'sameAsCurrent',
              shakeKey: vm.errorKey,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 22,
              child: vm.submitting
                  ? Text(
                      l10n.lockVerifying,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    )
                  : _errorText(l10n, vm.errorKey) == null
                  ? null
                  : Text(
                      _errorText(l10n, vm.errorKey)!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.error),
                    ),
            ),
            const SizedBox(height: 6),
            PinPad(onDigit: vm.addDigit, onBackspace: vm.backspace),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: vm.entered.length >= 4 && !vm.submitting
                    ? () => vm.submit()
                    : null,
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                label: Text(l10n.commonContinue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _subtitleFor(AppLocalizations l10n, int step) {
    return switch (step) {
      0 => l10n.changePinStepCurrent,
      1 => l10n.changePinStepNew,
      _ => l10n.changePinStepConfirm,
    };
  }

  static String? _errorText(AppLocalizations l10n, String? key) {
    if (key == null) return null;
    return switch (key) {
      'pinShort' => l10n.pinInvalidLength,
      'pinMismatch' => l10n.pinMismatch,
      'wrongCurrent' => l10n.changePinWrongCurrent,
      'sameAsCurrent' => l10n.changePinSameAsCurrent,
      'noPin' => l10n.changePinNoPin,
      _ => null,
    };
  }
}

/// رأس الخطوات: ثلاث شارات مرقمة يتصلها خط تقدم يُملأ حسب الخطوة.
class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final labels = [
      l10n.changePinStep1Label,
      l10n.changePinStep2Label,
      l10n.changePinStep3Label,
    ];
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 3.5,
                        decoration: BoxDecoration(
                          color: i <= step
                              ? scheme.primary
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < step
                            ? scheme.primary
                            : i == step
                            ? scheme.primaryContainer
                            : scheme.surfaceContainerHighest,
                      ),
                      child: Center(
                        child: i < step
                            ? Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: scheme.onPrimary,
                              )
                            : Text(
                                '${i + 1}',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: i == step
                                          ? scheme.onPrimaryContainer
                                          : scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w800,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 3.5,
                        decoration: BoxDecoration(
                          color: i < step
                              ? scheme.primary
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  labels[i],
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: i <= step
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                    fontWeight: i == step ? FontWeight.w800 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (i < 2) const SizedBox(width: 12),
        ],
      ],
    );
  }
}
