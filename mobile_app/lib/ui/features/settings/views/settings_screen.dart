/// شاشة «المزيد» — مركز الإعدادات (ضمن نطاق المرحلة الأولى: الهوية
/// والجلسة والأمان — لا وحدات أعمال): بطاقة المنشأة، الأمان (تغيير
/// PIN، القفل الفوري، مدة القفل التلقائي)، التفضيلات (وضع الثيم
/// المحفوظ)، البيانات (المسح الكامل بتأكيد مزدوج)، وحول التطبيق.
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
            _ThemeSection(currentMode: state.themeMode),
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
          _InfoRow(
            icon: Icons.timer_outlined,
            label: l10n.settingsAutolock,
            value: l10n.settingsAutolackValue(state.autolockMinutes),
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
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

/// قسم الأمان: تغيير PIN + القفل الفوري.
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

/// قسم التفضيلات: وضع الثيم (نظام/فاتح/داكن) — ثلاث بطاقات اختيار.
class _ThemeSection extends StatelessWidget {
  const _ThemeSection({required this.currentMode});

  final String currentMode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final app = context.read<AppController>();
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
                    selected: currentMode == mode,
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
      ],
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
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 8),
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
