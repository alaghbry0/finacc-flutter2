/// شاشة «المزيد» — **مركز أقسام الإعدادات** (UX-2a): بطاقات أقسام بنمط
/// التطبيق (FinCard) تفتح شاشات فرعية متخصصة:
/// بطاقة المنشأة (شعار + مدة القفل التلقائي القابلة للضبط — FR-12-05)
/// → بيانات المنشأة `/more/company` · تفضيلات البيع `/more/sale-prefs` ·
/// العرض والمظهر `/more/appearance` · قوالب طباعة الفواتير
/// `/more/print-templates` (UX-3) · الأمان (تغيير PIN/سجل التدقيق/
/// القفل الفوري) · البيانات (النسخ/المسح المحروس) · مركز التقارير · حول.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../core/app_version.dart';
import '../../../../domain/services/numerals.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/fin_tokens.dart';
import '../../../core/widgets/confirm_word_dialog.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/fin_section_title.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/numerals_scope.dart';
import '../view_models/settings_view_model.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً (في `runAsync`) — عند غيابه
  /// تُنشئ الشاشة نموذجها وتحمّله بنفسها.
  final SettingsViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final SettingsViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = SettingsViewModel(
        companyRepo: app.companies!,
        userRepo: app.users!,
        settingsRepo: app.settings!,
        backupEngine: app.backupEngine,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<SettingsViewModel>.value(
      value: vm,
      child: const _SettingsBody(),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.tabMore)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (state.loading)
            const ListSkeleton(rows: 6)
          else if (state.error != null)
            ErrorState(
              title: l10n.genericErrorTitle,
              message: l10n.dbOpenErrorMessage,
              technicalDetails: state.error.toString(),
              retryLabel: l10n.commonRetry,
              onRetry: vm.load,
              compact: true,
            )
          else ...[
            _CompanyCard(state: state),
            const SizedBox(height: 16),
            // مركز التقارير (الشريحة 10) — بوابة الأرباح والرقابة اليومية.
            const _ReportsSection(),
            const SizedBox(height: 16),
            _CustomizationSection(state: state),
            const SizedBox(height: 16),
            _SecuritySection(),
            const SizedBox(height: 16),
            _DataSection(),
            const SizedBox(height: 16),
            _AboutCard(state: state),
          ],
        ],
      ),
    );
  }
}

/// قسم مركز التقارير — بطاقة ذهبية Accent بنمط أقسام الإعدادات، أول
/// ما يقع عليه البصر بعد بطاقة المنشأة (أهم أداة رقابية يومية).
class _ReportsSection extends StatelessWidget {
  const _ReportsSection();

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
          child: _ActionRow(
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
class _CustomizationSection extends StatelessWidget {
  const _CustomizationSection({required this.state});

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
              _ActionRow(
                icon: Icons.storefront_rounded,
                iconColor: scheme.primary,
                title: l10n.settings2CompanyTitle,
                subtitle: l10n.settings2CompanySubtitle,
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => context.go('/more/company'),
              ),
              Divider(color: scheme.outlineVariant.withValues(alpha: 0.4)),
              _ActionRow(
                icon: Icons.shopping_cart_checkout_rounded,
                iconColor: colors.warning,
                title: l10n.settings2SalePrefsTitle,
                subtitle: l10n.settings2SalePrefsSubtitle,
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => context.go('/more/sale-prefs'),
              ),
              Divider(color: scheme.outlineVariant.withValues(alpha: 0.4)),
              _ActionRow(
                icon: Icons.palette_rounded,
                iconColor: colors.gold,
                title: l10n.settings2AppearanceTitle,
                subtitle: _appearanceSummary(context, app),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => context.go('/more/appearance'),
              ),
              Divider(color: scheme.outlineVariant.withValues(alpha: 0.4)),
              // قوالب طباعة الفواتير (UX-3) — بطاقة رابعة بقسم التخصيص.
              _ActionRow(
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

/// بطاقة المنشأة: الشعار (BLOB إن وُجد — UX-2a) + الاسم + العملة
/// الأساسية + المدير + مدة القفل التلقائي + بوابة التحرير الكامل.
class _CompanyCard extends StatelessWidget {
  const _CompanyCard({required this.state});

  final SettingsData state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final company = state.company;
    final logo = company?.logoPng;
    return FinCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (logo != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(FinRadius.control),
                  child: Image.memory(
                    logo,
                    width: 44,
                    height: 44,
                    fit: BoxFit.contain,
                  ),
                )
              else
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.primary,
                        Color.lerp(scheme.primary, Colors.black, 0.25)!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(FinRadius.control),
                  ),
                  child: Icon(
                    Icons.storefront_rounded,
                    color: scheme.onPrimary,
                    size: 22,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  company?.name ?? l10n.appTitle,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.attach_money_rounded,
            label: l10n.settingsBaseCurrency,
            value: state.baseCurrency == null
                ? '—'
                : '${state.baseCurrency!.code} • ${state.baseCurrency!.name}',
          ),
          _InfoRow(
            icon: Icons.badge_rounded,
            label: l10n.settingsAdmin,
            value: state.adminName ?? '—',
          ),
          // مدة القفل التلقائي — قابلة للضبط (FR-12-05: 1–60 دقيقة).
          const _AutolockRow(),
        ],
      ),
    );
  }
}

/// صف مدة القفل التلقائي — قابل للنقر يفتح لوحة الخيارات.
///
/// يقرأ القيمة من AppController مباشرة (مراقبة حية) — التغيير من
/// اللوحة ينعكس فوراً دون إعادة تحميل الشاشة كاملة.
class _AutolockRow extends StatelessWidget {
  const _AutolockRow();

  @override
  Widget build(BuildContext context) {
    final minutes = context.watch<AppController>().autolockMinutes;
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => _openAutolockSheet(context),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 18,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.settingsAutolock,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onPrimaryContainer),
                  ),
                ),
                Text(
                  l10n.settingsAutolackValue(minutes),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: scheme.onPrimaryContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAutolockSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      // فوق شريط التبويبات (متصفح الفرع) — لا من أسفل الشاشة خلفه.
      useRootNavigator: false,
      // لوحة كاملة العرض بحواف علوية مستديرة ومقبض.
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _AutolockSheet(
        current: context.read<AppController>().autolockMinutes,
      ),
    );
  }
}

/// لوحة اختيار مدة القفل التلقائي (FR-12-05 — 1–60 دقيقة).
class _AutolockSheet extends StatelessWidget {
  const _AutolockSheet({required this.current});

  final int current;

  /// الخيارات المعروضة (خيارات مشتركة ضمن النطاق الملزم 1–60).
  static const options = [1, 5, 10, 15, 30, 60];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        // تمرير آمن للشاشات القصيرة (لا تجاوز أبداً).
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // مقبض اللوحة.
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primary,
                          Color.lerp(scheme.primary, Colors.black, 0.25)!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.timer_outlined,
                      color: scheme.onPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.settingsAutolockSheetTitle,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          l10n.settingsAutolockSheetSubtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              for (final option in options)
                _AutolockOption(
                  minutes: option,
                  selected: option == current,
                  onTap: () {
                    unawaited(
                      context.read<AppController>().setAutolockMinutes(option),
                    );
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// خيار مدة واحد داخل اللوحة — علامة تحديد متحركة عند الاختيار.
class _AutolockOption extends StatelessWidget {
  const _AutolockOption({
    required this.minutes,
    required this.selected,
    required this.onTap,
  });

  final int minutes;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.settingsAutolackValue(minutes),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: selected ? scheme.onPrimaryContainer : null,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            AnimatedScale(
              duration: const Duration(milliseconds: 220),
              scale: selected ? 1 : 0,
              child: Icon(
                Icons.check_circle_rounded,
                color: scheme.primary,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.start,
            ),
          ),
        ],
      ),
    );
  }
}

/// قسم الأمان: تغيير PIN + سجل التدقيق + القفل الفوري.
class _SecuritySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinSectionTitle(icon: Icons.shield_rounded, title: l10n.settingsSecurity),
        const SizedBox(height: 8),
        FinCard(
          child: Column(
            children: [
              _ActionRow(
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
              _ActionRow(
                icon: Icons.receipt_long_rounded,
                iconColor: scheme.tertiary,
                title: l10n.settingsAuditLog,
                subtitle: l10n.settingsAuditLogDesc,
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => context.go('/more/audit-log'),
              ),
              Divider(color: scheme.outlineVariant.withValues(alpha: 0.4)),
              _ActionRow(
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
class _DataSection extends StatelessWidget {
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
              _ActionRow(
                icon: Icons.backup_rounded,
                iconColor: scheme.primary,
                title: l10n.settingsBackupTitle,
                subtitle: l10n.settingsBackupDesc,
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => context.go('/more/backup'),
              ),
              Divider(color: scheme.outlineVariant.withValues(alpha: 0.4)),
              _ActionRow(
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

/// بطاقة «حول»: الاسم والإصدار (من المصدر الوحيد `appVersion` — UX-2a
/// توحيد الإصدار: بلا تضارب بين نص القالب والإصدار الفعلي) ووثيقة
/// المتطلبات وحجم القاعدة.
class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.state});

  /// بيانات الإعدادات (لحجم القاعدة — FR-13-07).
  final SettingsData state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    return FinCard(
      child: Column(
        children: [
          // شارة الطور: وسط البطاقة — النص مرن (RTL عربي + لاتيني «v1.0.0»
          // يفيض 1.5px على 390dp بالسطر الصلب — ellipsis عند الضيق).
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_rounded, color: colors.gold, size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  l10n.settings2AboutPhase,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${l10n.appBrand} — ${l10n.appTitle}',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.settings2AboutVersion(appVersion),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.settingsAboutSrs,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          // حجم القاعدة (FR-13-07) — من ملف finacc.db على المنصات الأصلية.
          if (state.dbSizeBytes != null) ...[
            const SizedBox(height: 4),
            Text(
              l10n.settingsAboutDbSize(
                _formatDbSize(context, state.dbSizeBytes!),
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 14),
          Divider(
            color: Theme.of(context).colorScheme.outlineVariant
                .withValues(alpha: 0.4),
          ),
          const SizedBox(height: 10),
          // صف التراخيص المفتوحة — صفحة تراخيص Flutter الرسمية.
          _ActionRow(
            icon: Icons.description_rounded,
            iconColor: colors.gold,
            title: l10n.settingsLicenses,
            subtitle: l10n.settingsLicensesDesc,
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: () => showLicensePage(
              context: context,
              applicationName: '${l10n.appBrand} — ${l10n.appTitle}',
              applicationVersion: appVersion,
              applicationIcon: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: colors.gold,
                  size: 40,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(FinRadius.control),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// حجم القاعدة مقروءاً (ك.ب/م.ب) بأرقام النظام الحي — لبند «حول».
String _formatDbSize(BuildContext context, int bytes) {
  final l10n = AppLocalizations.of(context)!;
  final arabicIndic = NumeralsScope.of(context);
  String digits(String text) =>
      arabicIndic ? Numerals.toArabicIndic(text) : text;
  final kb = bytes / 1024;
  if (kb < 1024) {
    return l10n.backupSizeKb(digits(kb.round().toString()));
  }
  return l10n.backupSizeMb(digits((kb / 1024).toStringAsFixed(1)));
}
