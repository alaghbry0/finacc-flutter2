/// شاشة تفضيلات البيع (UX-2a) — مسار `/more/sale-prefs`: خمس سياسات في
/// بطاقات FinCard: طريقة الدفع الافتراضية (`sale.default_payment` — شرائح
/// ثلاثية) + إظهار الخصومات (`sale.show_discounts` — مفتاح تبديل) +
/// سياسة حد الائتمان (`parties.credit_limit_action` — كانت مستهلكة بلا
/// واجهة) + البيع فوق المتاح (`sale.over_avail_policy` — block يمنع
/// الترحيل فعلياً) + تحذير البيع تحت التكلفة (`invoicing.discount_below_margin`).
///
/// كل تبديل يُكتب فوراً في المستودع (إعداد لحظي بلا زر حفظ).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/fin_tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../view_models/sale_preferences_view_model.dart';

/// شاشة تفضيلات البيع — مسار `/more/sale-prefs`.
class SalePreferencesScreen extends StatelessWidget {
  const SalePreferencesScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً — عند غيابه تُنشئ الشاشة نموذجها.
  final SalePreferencesViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    late final SalePreferencesViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      final app = context.read<AppController>();
      vm = SalePreferencesScreenModelFactory.create(app);
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<SalePreferencesViewModel>.value(
      value: vm,
      child: const _SalePreferencesBody(),
    );
  }
}

/// نقطة إنشاء النموذج (وحدة قابلة للاختبار/الحقن).
class SalePreferencesScreenModelFactory {
  static SalePreferencesViewModel create(AppController app) =>
      SalePreferencesViewModel(settingsRepo: app.settings!);
}

class _SalePreferencesBody extends StatelessWidget {
  const _SalePreferencesBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SalePreferencesViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.settings2SalePrefsTitle)),
      body: state.loading
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: const [ListSkeleton(rows: 5)],
            )
          : state.error != null
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                ErrorState(
                  title: l10n.genericErrorTitle,
                  message: l10n.dbOpenErrorMessage,
                  technicalDetails: state.error.toString(),
                  retryLabel: l10n.commonRetry,
                  onRetry: vm.load,
                  compact: true,
                ),
              ],
            )
          : _SalePrefsList(),
    );
  }
}

class _SalePrefsList extends StatelessWidget {
  const _SalePrefsList();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SalePreferencesViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // ── طريقة الدفع الافتراضية ──
        FinCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PrefHeader(
                icon: Icons.payments_rounded,
                title: l10n.settings2SaleDefaultPayment,
                subtitle: l10n.settings2SaleDefaultPaymentDesc,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final (mode, label) in [
                    ('cash', l10n.settings2SalePayCash),
                    ('credit', l10n.settings2SalePayCredit),
                    ('mixed', l10n.settings2SalePayMixed),
                  ])
                    Expanded(
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(
                          end: mode == 'cash' || mode == 'credit' ? 8 : 0,
                        ),
                        child: _ModeOption(
                          label: label,
                          selected: state.defaultPayment == mode,
                          onTap: () => vm.setDefaultPayment(mode),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── إظهار الخصومات ──
        FinCard(
          child: _SwitchRow(
            icon: Icons.discount_rounded,
            iconColor: colors.negative,
            title: l10n.settings2SaleShowDiscounts,
            subtitle: l10n.settings2SaleShowDiscountsDesc,
            value: state.showDiscounts,
            onChanged: vm.setShowDiscounts,
          ),
        ),
        const SizedBox(height: 16),

        // ── سياسة حد الائتمان ──
        FinCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PrefHeader(
                icon: Icons.account_balance_wallet_rounded,
                title: l10n.settings2SaleCreditLimitPolicy,
                subtitle: l10n.settings2SaleCreditLimitPolicyDesc,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _PolicyOption(
                      label: l10n.settings2SalePolicyWarn,
                      icon: Icons.warning_amber_rounded,
                      iconColor: colors.warning,
                      selected: state.creditLimitAction == 'warn',
                      onTap: () => vm.setCreditLimitAction('warn'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PolicyOption(
                      label: l10n.settings2SalePolicyBlock,
                      icon: Icons.block_rounded,
                      iconColor: colors.negative,
                      selected: state.creditLimitAction == 'block',
                      onTap: () => vm.setCreditLimitAction('block'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── البيع فوق المتاح ──
        FinCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PrefHeader(
                icon: Icons.inventory_2_rounded,
                title: l10n.settings2SaleOverAvailPolicy,
                subtitle: l10n.settings2SaleOverAvailPolicyDesc,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _PolicyOption(
                      label: l10n.settings2SalePolicyWarn,
                      icon: Icons.warning_amber_rounded,
                      iconColor: colors.warning,
                      selected: state.overAvailPolicy == 'warn',
                      onTap: () => vm.setOverAvailPolicy('warn'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PolicyOption(
                      label: l10n.settings2SalePolicyBlock,
                      icon: Icons.block_rounded,
                      iconColor: colors.negative,
                      selected: state.overAvailPolicy == 'block',
                      onTap: () => vm.setOverAvailPolicy('block'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── تحذير البيع تحت التكلفة ──
        FinCard(
          child: _SwitchRow(
            icon: Icons.trending_down_rounded,
            iconColor: colors.warning,
            title: l10n.settings2SaleBelowMarginPolicy,
            subtitle: l10n.settings2SaleBelowMarginPolicyDesc,
            value: state.warnBelowMargin,
            onChanged: vm.setWarnBelowMargin,
          ),
        ),

        // فشل كتابة آخر تبديل — ظاهر بلا كسر القيم الحية.
        if (state.writeError != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              l10n.settings2SaleWriteFailed,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.negative,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            l10n.settings2SalePrefsNote,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// رأس بطاقة تفضيل (أيقونة + عنوان + وصف).
class _PrefHeader extends StatelessWidget {
  const _PrefHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(FinRadius.control),
          ),
          child: Icon(icon, size: 20, color: scheme.primary),
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
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// صف مفتاح تبديل (إعداد on/off).
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

/// بطاقة خيار وضع (نقدي/آجل/مختلط) — نمط بطاقتي الأرقام بالمظهر.
class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected ? scheme.onPrimaryContainer : null,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// بطاقة خيار سياسة (تحذير/منع) بأيقونة دلالية.
class _PolicyOption extends StatelessWidget {
  const _PolicyOption({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? scheme.onPrimaryContainer : iconColor,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? scheme.onPrimaryContainer : null,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
