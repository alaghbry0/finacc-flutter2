/// الخطوتان 4 و5: التنفيذ ثم التمام (R19-D3c — مستخرجتان حرفياً من
/// `onboarding_screen.dart` بلا أي تغيير دلالة).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../view_models/onboarding_view_model.dart';

/// خطوة التنفيذ — مؤشر ترقّي مع رسالة التأسيس الذرّي.
class OnboardingCreatingStep extends StatelessWidget {
  const OnboardingCreatingStep({super.key});

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

/// خطوة التمام — نتيجة التأسيس (المخزن/الصندوق/العملة) وزر البدء.
class OnboardingDoneStep extends StatelessWidget {
  const OnboardingDoneStep({super.key, required this.vm, required this.onDone});

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
