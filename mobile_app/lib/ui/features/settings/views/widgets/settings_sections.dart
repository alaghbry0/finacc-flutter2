/// أقسام شاشة الإعدادات: التقارير/التخصيص/الأمان/البيانات — مستخرجة من
/// settings_screen (R19-D3b: نقل حرفي بلا أي تغيير سلوكي).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/session/app_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/confirm_word_dialog.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/fin_section_title.dart';
import '../../view_models/settings_view_model.dart';
import 'settings_action_row.dart';

/// قسم مركز التقارير — بطاقة ذهبية Accent بنمط أقسام الإعدادات، أول
/// ما يقع عليه البصر بعد بطاقة المنشأة (أهم أداة رقابية يومية).
class SettingsReportsSection extends StatelessWidget {
  const SettingsReportsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinSectionTitle(icon: Icons.insights_rounded, title: l10n.reportsTitle),
        const SizedBox(height: 8),
        FinCard(
          accent: colors.gold,
          child: SettingsActionRow(
            icon: Icons.trending_up_rounded,
            iconColor: colors.positive,
            title: l10n.reportsHeroTitle,
            subtitle: l10n.reportsPnlDesc,
            trailing: Icon(
              Icons.auto_awesome_rounded,
              size: 16,
              color: colors.gold,
            ),
            onTap: () => context.go('/reports'),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            l10n.reportsHeroSubtitle,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// قسم التخصيص (UX-2a + UX-3) — بوابات «بيانات المنشأة» و«تفضيلات
/// البيع» و«العرض والمظهر» و«الطباعة والفواتير» (شاشات فرعية متخصصة
/// بلا ازدحام بالمركز).
class SettingsCustomizationSection extends StatelessWidget {
  const SettingsCustomizationSection({super.key, required this.state});

  final SettingsData state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final app = context.watch<AppController>();
    final colors = FinColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinSectionTitle(
          icon: Icons.tune_rounded,
          title: l10n.settings2CustomizationTitle,
        ),
        const SizedBox(height: 8),
        FinCard(
          child: Column(
            children: [
              SettingsActionRow(
                icon: Icons.storefront_rounded,
                iconColor: scheme.primary,
                title: l10n.settings2CompanyTitle,
                subtitle: l10n.settings2CompanySubtitle,
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => context.go('/more/company'),
              ),
              Divider(color: scheme.outlineVariant.withValues(alpha: 0.4)),
              SettingsActionRow(
                icon: Icons.shopping_cart_checkout_rounded,
                iconColor: colors.warning,
                title: l10n.settings2SalePrefsTitle,
                subtitle: l10n.settings2SalePrefsSubtitle,
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => context.go('/more/sale-prefs'),
              ),
              Divider(color: scheme.outlineVariant.withValues(alpha: 0.4)),
              SettingsActionRow(
                icon: Icons.palette_rounded,
                iconColor: colors.gold,
                title: l10n.settings2AppearanceTitle,
                subtitle: _appearanceSummary(context, app),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => context.go('/more/appearance'),
              ),
              Divider(color: scheme.outlineVariant.withValues(alpha: 0.4)),
              // قوالب طباعة الفواتير (UX-3) — بطاقة رابعة بقسم التخصيص.
              SettingsActionRow(
                icon: Icons.receipt_long_rounded,
                iconColor: colors.positive,
                title: l10n.tmplSectionTitle,
                subtitle: l10n.tmplSectionSubtitle,
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => context.go('/more/print-templates'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// ملخص حي لخيارات المظهر بصف البوابة (ثيم · أرقام · خط · تباين).
  String _appearanceSummary(BuildContext context, AppController app) {
    final l10n = AppLocalizations.of(context)!;
    final theme = switch (app.themeMode) {
      'light' => l10n.themeLight,
      'dark' => l10n.themeDark,
      _ => l10n.themeSystem,
    };
    final scale = switch (app.fontScale) {
      'large' => l10n.settings2FontScaleLarge,
      'xlarge' => l10n.settings2FontScaleXlarge,
      _ => l10n.settings2FontScaleNormal,
    };
    return '$theme · $scale'
        '${app.highContrast ? ' · ${l10n.settings2HighContrast}' : ''}';
  }
}

/// قسم الأمان: تغيير PIN + سجل التدقيق + القفل الفوري.
class SettingsSecuritySection extends StatelessWidget {
  const SettingsSecuritySection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinSectionTitle(
          icon: Icons.shield_rounded,
          title: l10n.settingsSecurity,
        ),
        const SizedBox(height: 8),
        FinCard(
          child: Column(
            children: [
              SettingsActionRow(
                icon: Icons.password_rounded,
                iconColor: scheme.primary,
                title: l10n.settingsChangePin,
                subtitle: l10n.settingsChangePinDesc,
                trailing: const Icon(Icons.chevron_left_rounded),
                // go (لا push): يحدّث عنوان URL للمسارات الفرعية للفرع ويحفظ
                // عمق الرجوع داخل شريط التطبيق (push كان يترك #/more ثابتاً).
                onTap: () => context.go('/more/change-pin'),
              ),
              Divider(color: scheme.outlineVariant.withValues(alpha: 0.4)),
              SettingsActionRow(
                icon: Icons.receipt_long_rounded,
                iconColor: scheme.tertiary,
                title: l10n.settingsAuditLog,
                subtitle: l10n.settingsAuditLogDesc,
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => context.go('/more/audit-log'),
              ),
              Divider(color: scheme.outlineVariant.withValues(alpha: 0.4)),
              SettingsActionRow(
                icon: Icons.lock_rounded,
                iconColor: scheme.onSurfaceVariant,
                title: l10n.settingsLockNow,
                subtitle: l10n.settingsLockNowDesc,
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => context.read<AppController>().lock(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// قسم البيانات: النسخ الاحتياطي والاستعادة (الشريحة 8 — FR-11) +
/// المسح الكامل (AC-15) — بوابة الحذر الأحمر.
class SettingsDataSection extends StatelessWidget {
  const SettingsDataSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinSectionTitle(icon: Icons.storage_rounded, title: l10n.settingsData),
        const SizedBox(height: 8),
        FinCard(
          child: Column(
            children: [
              SettingsActionRow(
                icon: Icons.backup_rounded,
                iconColor: scheme.primary,
                title: l10n.settingsBackupTitle,
                subtitle: l10n.settingsBackupDesc,
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => context.go('/more/backup'),
              ),
              Divider(color: scheme.outlineVariant.withValues(alpha: 0.4)),
              SettingsActionRow(
                icon: Icons.delete_forever_rounded,
                iconColor: colors.negative,
                title: l10n.settingsWipe,
                subtitle: l10n.settingsWipeDesc,
                trailing: Icon(
                  Icons.chevron_left_rounded,
                  color: scheme.onSurfaceVariant,
                ),
                // المسار المحروس الموحد (AC-15): تأكيد ← كتابة الكلمة ←
                // نسخة أمان إجبارية قبل المسح ← حوار نجاح يذكر ملفها.
                onTap: () => unawaited(
                  runGuardedWipeFlow(context, context.read<AppController>()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
