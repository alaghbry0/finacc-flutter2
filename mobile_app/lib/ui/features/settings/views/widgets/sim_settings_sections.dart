/// أقسام شاشة الإعدادات بهوية Simple Invoice Manager (V7) — إعادة صياغة
/// أقسام `settings_sections` القائمة بصفوف SIM ([SimSettingRow] بنمط
/// `.setting-row` من النموذج الأولي): بطاقات بيضاء بفواصل 1px وشيفرون
/// RTL يسار للبوابات، وصفوف فعل بلا شيفرون للأفعال المباشرة (القفل
/// الفوري والمسح المحروس) كما عالجتها الأقسام القائمة:
///
/// - [SimSettingsGroupCard]: البطاقة البيضاء بفواصل الصفوف.
/// - [SimSettingsSectionLabel]: عنوان قسم صغير (باسم بارز أو رمادي).
/// - [SimSettingsCoreRows]: الصفوف الستة المقفلة (مفاتيح l10n محمية).
/// - [SimSettingsCustomizationRows]/[SimSettingsSecurityRows]/
///   [SimSettingsDataRows]/[SimSettingsReportsRows]: الأقسام الباقية.
///
/// كل وجهة/فعل من الشاشة القائمة محفوظ بنفس المسار/التدفق (التخصيص
/// والأمان والبيانات ومركز التقارير) — بطاقة المنشأة (FR-12-05) وبطاقة
/// «حول» تبقيان بمكوّناتهما الأصلية في الشاشة.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/session/app_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/fin_tokens.dart';
import '../../../../core/widgets/confirm_word_dialog.dart';
import '../../../../core/widgets/sim_list_widgets.dart';

/// بطاقة مجموعة إعدادات SIM — سطح أبيض بحد رقيق وزوايا 8px والصفوف
/// بينها فواصل 1px (`#F0F0F0` فاتح) بنمط `.list-content` بالنموذج.
class SimSettingsGroupCard extends StatelessWidget {
  const SimSettingsGroupCard({super.key, required this.children});

  /// صفوف المجموعة (SimSettingRow/صفوف الفعل) — الفواصل تلقائية.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(FinRadius.chip),
        border: Border.all(color: FinColors.of(context).cardBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(FinRadius.chip - 1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark
                      ? scheme.outlineVariant.withValues(alpha: 0.4)
                      : const Color(0xFFF0F0F0),
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// عنوان قسم صغير — البارز (فاصل «المزيد من إعدادات FinAcc») بعنوان
/// عريض داكن، والعادي (التخصيص/الأمان/…) بتسمية رمادية خفيفة.
class SimSettingsSectionLabel extends StatelessWidget {
  const SimSettingsSectionLabel({
    super.key,
    required this.title,
    this.prominent = false,
    this.labelKey,
  });

  final String title;

  /// التسمية البارزة (فاصل القسم الرئيسي بعد الصفوف الستة).
  final bool prominent;

  /// مفتاح اختبار (اختياري).
  final Key? labelKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      key: labelKey,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: prominent
            ? Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              )
            : Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
      ),
    );
  }
}

/// حاوية أيقونة صف الإعدادات — مربع 34×34 مصبوغ بشفافية اللون.
Widget _simRowIcon(IconData icon, Color color) => Container(
  width: 34,
  height: 34,
  decoration: BoxDecoration(
    color: color.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(FinRadius.chip),
  ),
  child: Icon(icon, size: 18, color: color),
);

/// صف فعل مباشر بلا شيفرون — نفس لغة [SimSettingRow] (عنوان عريق +
/// وصف رمادي) بأيقونة بادئة ولا وجهة: القفل الفوري والمسح المحروس
/// (كما عالجتهما الأقسام القائمة — الفعل ينفَّذ فور النقر).
class _SimSettingActionRow extends StatelessWidget {
  const _SimSettingActionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleKey,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// مفتاح اختبار للعنوان.
  final Key? titleKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _simRowIcon(icon, iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      key: titleKey,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// الصفوف الستة المقفلة (شاشة `screen-settings` بالنموذج حرفياً) —
/// العناوين والأوصاف من مفاتيح l10n المحمية لا تُعدَّل:
/// بيانات أساسية → `/more/company` · قالب الفاتورة → `/more/print-templates` ·
/// رأس الفاتورة → `/more/print-templates` · المخزون → `/inventory` ·
/// العملات → `/parties/rates` · الفئات → `/inventory/categories-units`.
class SimSettingsCoreRows extends StatelessWidget {
  const SimSettingsCoreRows({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SimSettingsGroupCard(
      children: [
        SimSettingRow(
          titleKey: const Key('sim_settings_row_basic'),
          title: l10n.settingsSimRowBasicTitle,
          subtitle: l10n.settingsSimRowBasicDesc,
          onTap: () => context.go('/more/company'),
        ),
        SimSettingRow(
          titleKey: const Key('sim_settings_row_template'),
          title: l10n.settingsSimRowTemplateTitle,
          subtitle: l10n.settingsSimRowTemplateDesc,
          onTap: () => context.go('/more/print-templates'),
        ),
        SimSettingRow(
          titleKey: const Key('sim_settings_row_header'),
          title: l10n.settingsSimRowHeaderTitle,
          subtitle: l10n.settingsSimRowHeaderDesc,
          onTap: () => context.go('/more/print-templates'),
        ),
        SimSettingRow(
          titleKey: const Key('sim_settings_row_stock'),
          title: l10n.settingsSimRowStockTitle,
          subtitle: l10n.settingsSimRowStockDesc,
          onTap: () => context.go('/inventory'),
        ),
        SimSettingRow(
          titleKey: const Key('sim_settings_row_currency'),
          title: l10n.settingsSimRowCurrencyTitle,
          subtitle: l10n.settingsSimRowCurrencyDesc,
          onTap: () => context.go('/parties/rates'),
        ),
        SimSettingRow(
          titleKey: const Key('sim_settings_row_category'),
          title: l10n.settingsSimRowCategoryTitle,
          subtitle: l10n.settingsSimRowCategoryDesc,
          onTap: () => context.go('/inventory/categories-units'),
        ),
      ],
    );
  }
}

/// قسم التخصيص الباقي — المظهر (`/more/appearance`) بملخص حي (ثيم ·
/// أرقام · خط · تباين) وتفضيلات البيع (`/more/sale-prefs`)؛ بيانات
/// المنشأة والطباعة ارتفعت للصفوف الستة المقفلة أعلاه.
class SimSettingsCustomizationRows extends StatelessWidget {
  const SimSettingsCustomizationRows({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    return SimSettingsGroupCard(
      children: [
        SimSettingRow(
          titleKey: const Key('sim_settings_row_appearance'),
          title: l10n.settings2AppearanceTitle,
          subtitle: _appearanceSummary(context),
          leading: _simRowIcon(Icons.palette_rounded, colors.gold),
          onTap: () => context.go('/more/appearance'),
        ),
        SimSettingRow(
          titleKey: const Key('sim_settings_row_sale_prefs'),
          title: l10n.settings2SalePrefsTitle,
          subtitle: l10n.settings2SalePrefsSubtitle,
          leading: _simRowIcon(
            Icons.shopping_cart_checkout_rounded,
            colors.warning,
          ),
          onTap: () => context.go('/more/sale-prefs'),
        ),
      ],
    );
  }

  /// ملخص حي لخيارات المظهر بصف البوابة (ثيم · أرقام · خط · تباين) —
  /// نقل حرفي من قسم التخصيص القائم (مراقبة AppController).
  String _appearanceSummary(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final app = context.watch<AppController>();
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

/// قسم الأمان — تغيير PIN (`/more/change-pin`) وسجل التدقيق
/// (`/more/audit-log`) بصفوف بوابات، والقفل الفوري صف فعل مباشر بلا
/// شيفرون (go للبوابات كما بالأقسام القائمة يحدّث عنوان URL للفرع).
class SimSettingsSecurityRows extends StatelessWidget {
  const SimSettingsSecurityRows({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return SimSettingsGroupCard(
      children: [
        SimSettingRow(
          titleKey: const Key('sim_settings_row_change_pin'),
          title: l10n.settingsChangePin,
          subtitle: l10n.settingsChangePinDesc,
          leading: _simRowIcon(Icons.password_rounded, scheme.primary),
          onTap: () => context.go('/more/change-pin'),
        ),
        SimSettingRow(
          titleKey: const Key('sim_settings_row_audit_log'),
          title: l10n.settingsAuditLog,
          subtitle: l10n.settingsAuditLogDesc,
          leading: _simRowIcon(Icons.receipt_long_rounded, scheme.tertiary),
          onTap: () => context.go('/more/audit-log'),
        ),
        _SimSettingActionRow(
          titleKey: const Key('sim_settings_row_lock_now'),
          icon: Icons.lock_rounded,
          iconColor: scheme.onSurfaceVariant,
          title: l10n.settingsLockNow,
          subtitle: l10n.settingsLockNowDesc,
          onTap: () => context.read<AppController>().lock(),
        ),
      ],
    );
  }
}

/// قسم البيانات — النسخ الاحتياطي والاستعادة (`/more/backup`) بوابة،
/// والمسح الكامل صف فعل مباشر بلا شيفرون يفتح المسار المحروس الموحد
/// (AC-15: تأكيد ← كتابة الكلمة ← نسخة أمان إجبارية ← حوار نجاح).
class SimSettingsDataRows extends StatelessWidget {
  const SimSettingsDataRows({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SimSettingsGroupCard(
      children: [
        SimSettingRow(
          titleKey: const Key('sim_settings_row_backup'),
          title: l10n.settingsBackupTitle,
          subtitle: l10n.settingsBackupDesc,
          leading: _simRowIcon(Icons.backup_rounded, scheme.primary),
          onTap: () => context.go('/more/backup'),
        ),
        _SimSettingActionRow(
          titleKey: const Key('sim_settings_row_wipe'),
          icon: Icons.delete_forever_rounded,
          iconColor: colors.negative,
          title: l10n.settingsWipe,
          subtitle: l10n.settingsWipeDesc,
          onTap: () => unawaited(
            runGuardedWipeFlow(context, context.read<AppController>()),
          ),
        ),
      ],
    );
  }
}

/// قسم مركز التقارير — بوابة `/reports` (أهم أداة رقابية يومية) مع
/// السطر التوضيحي الذهبي كما بالقسم القائم تحتها.
class SimSettingsReportsRows extends StatelessWidget {
  const SimSettingsReportsRows({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SimSettingsGroupCard(
          children: [
            SimSettingRow(
              titleKey: const Key('sim_settings_row_reports'),
              title: l10n.reportsHeroTitle,
              subtitle: l10n.reportsPnlDesc,
              leading: _simRowIcon(Icons.trending_up_rounded, colors.positive),
              onTap: () => context.go('/reports'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            l10n.reportsHeroSubtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
