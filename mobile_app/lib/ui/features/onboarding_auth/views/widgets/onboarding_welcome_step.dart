/// الخطوة 1: الترحيب (R19-D3c — مستخرجة حرفياً من `onboarding_screen.dart`
/// بلا أي تغيير دلالة).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/brand_mark.dart';

/// خطوة الترحيب — الشعار + الميزات الثلاث + زر المتابعة.
class OnboardingWelcomeStep extends StatelessWidget {
  const OnboardingWelcomeStep({super.key, required this.onStart});

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
