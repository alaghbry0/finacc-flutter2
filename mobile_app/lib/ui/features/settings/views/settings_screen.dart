/// شاشة «المزيد» — مركز الإعدادات (ضمن نطاق المرحلة الأولى: الهوية
/// والجلسة والأمان — لا وحدات أعمال): بطاقة المنشأة (مع مدة القفل
/// التلقائي القابلة للضبط — FR-12-05)، الأمان (تغيير PIN، سجل التدقيق،
/// القفل الفوري)، المظهر (وضع الثيم + نظام الأرقام — `display.numerals`)،
/// البيانات (المسح الكامل بتأكيد مزدوج)، وحول التطبيق.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
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
            _SecuritySection(),
            const SizedBox(height: 16),
            const _AppearanceSection(),
            const SizedBox(height: 16),
            _DataSection(),
            const SizedBox(height: 16),
            const _AboutCard(),
          ],
        ],
      ),
    );
  }
}

/// بطاقة المنشأة: الاسم + العملة الأساسية + المدير (للقراءة فقط —
/// تعديل بيانات المنشأة وحدة لاحقة).
class _CompanyCard extends StatelessWidget {
  const _CompanyCard({required this.state});

  final SettingsData state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final company = state.company;
    return FinCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
                  borderRadius: BorderRadius.circular(13),
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
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
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
        _SectionTitle(icon: Icons.shield_rounded, title: l10n.settingsSecurity),
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
                onTap: () => context.push('/more/change-pin'),
              ),
              Divider(color: scheme.outlineVariant.withValues(alpha: 0.4)),
              _ActionRow(
                icon: Icons.receipt_long_rounded,
                iconColor: scheme.tertiary,
                title: l10n.settingsAuditLog,
                subtitle: l10n.settingsAuditLogDesc,
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => context.push('/more/audit-log'),
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

/// قسم المظهر: وضع الثيم (نظام/فاتح/داكن) + نظام الأرقام
/// (`display.numerals` — غربي/عربي شرقي بمعاينة حيّة).
class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    // المراقبة الحيّة للمتحكم: التحديد يتحرك فور التبديل (ثيم/أرقام).
    final app = context.watch<AppController>();
    final themeMode = app.themeMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(icon: Icons.palette_rounded, title: l10n.settingsTheme),
        const SizedBox(height: 8),
        FinCard(
          child: Column(
            children: [
              for (final (mode, icon, label) in [
                ('system', Icons.brightness_auto_rounded, l10n.themeSystem),
                ('light', Icons.light_mode_rounded, l10n.themeLight),
                ('dark', Icons.dark_mode_rounded, l10n.themeDark),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: _ThemeOptionRow(
                    mode: mode,
                    icon: icon,
                    label: label,
                    selected: themeMode == mode,
                    onTap: () => app.setThemeMode(mode),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, right: 4),
          child: Text(
            l10n.settingsThemeNote,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 16),
        _SectionTitle(icon: Icons.pin_rounded, title: l10n.settingsNumerals),
        const SizedBox(height: 8),
        // نظام الأرقام: بطاقتان بمعاينة حيّة للأرقام بكل نظام.
        Row(
          children: [
            Expanded(
              child: _NumeralsOption(
                mode: 'western',
                title: l10n.numeralsWestern,
                sample: '1,234.50',
                selected: app.numerals == 'western',
                onTap: () => app.setNumerals('western'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NumeralsOption(
                mode: 'arabic_indic',
                title: l10n.numeralsArabicIndic,
                sample: '١٬٢٣٤٫٥٠',
                selected: app.numerals == 'arabic_indic',
                onTap: () => app.setNumerals('arabic_indic'),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, right: 4),
          child: Text(
            l10n.settingsNumeralsNote,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// بطاقة خيار نظام الأرقام — معاينة المبلغ بخط المبالغ نفسه.
class _NumeralsOption extends StatelessWidget {
  const _NumeralsOption({
    required this.mode,
    required this.title,
    required this.sample,
    required this.selected,
    required this.onTap,
  });

  final String mode;
  final String title;
  final String sample;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected ? scheme.onPrimaryContainer : null,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 5),
                AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  scale: selected ? 1 : 0,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: scheme.primary,
                    size: 17,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                sample,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOptionRow extends StatelessWidget {
  const _ThemeOptionRow({
    required this.mode,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String mode;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: selected ? scheme.onPrimaryContainer : null,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: selected ? 1 : 0,
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

/// قسم البيانات: المسح الكامل (AC-15) — بوابة الحذر الأحمر.
class _DataSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(icon: Icons.storage_rounded, title: l10n.settingsData),
        const SizedBox(height: 8),
        FinCard(
          child: _ActionRow(
            icon: Icons.delete_forever_rounded,
            iconColor: colors.negative,
            title: l10n.settingsWipe,
            subtitle: l10n.settingsWipeDesc,
            trailing: Icon(
              Icons.chevron_left_rounded,
              color: scheme.onSurfaceVariant,
            ),
            onTap: () => _confirmWipe(context, l10n),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmWipe(BuildContext context, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.wipeDialogTitle),
        content: Text(l10n.wipeDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.wipeConfirmWord),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    await context.read<AppController>().wipeAllData();
  }
}

/// بطاقة «حول»: الاسم والإصدار ووثيقة المتطلبات ومرحلة التسليم.
class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    return FinCard(
      child: Column(
        children: [
          Row(
            children: [
              const Spacer(),
              Icon(Icons.verified_rounded, color: colors.gold, size: 20),
              const SizedBox(width: 6),
              Text(
                l10n.settingsAboutPhase1,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
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
            l10n.settingsAboutVersion,
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
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        // حاوية أيقونة مصبوغة خفيفة — عمق بصري لأقسام الإعدادات.
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: scheme.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface),
        ),
      ],
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
                borderRadius: BorderRadius.circular(11),
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
