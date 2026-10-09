/// شاشة الافتتاح — الهوية أثناء فتح القاعدة + معالجة فشل الفتح (DS-33).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/brand_mark.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = context.watch<AppController>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: switch (controller.phase) {
            AppPhase.error => ErrorState(
              title: l10n.dbOpenErrorTitle,
              message: l10n.dbOpenErrorMessage,
              technicalDetails: controller.errorDetails,
              retryLabel: l10n.commonRetry,
              onRetry: controller.bootstrap,
            ),
            _ => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(size: 108),
                const SizedBox(height: 22),
                Text(
                  l10n.appBrand,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.appTitle,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 34),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.splashLoading,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          },
        ),
      ),
    );
  }
}
