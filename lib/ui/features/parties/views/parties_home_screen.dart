/// شاشة محور الأطراف — جذر وحدة العملاء والموردين (دليل 06/01 و05/02):
/// بطاقة بطلة + صفوف وصول بأعدّادات حية (العملاء/الموردون)، وإجماليات
/// المستحق لنا وعلينا **لكل عملة على حدة**، وحالة أسعار اليوم
/// (كاملة/ناقصة — FR-08-09) بتاريخ هجري.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../domain/services/hijri_date.dart';
import '../../../../domain/services/numerals.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/numerals_scope.dart';
import '../../../core/widgets/refresh_on_return.dart';
import '../../../core/widgets/status_chip.dart';
import '../view_models/parties_home_view_model.dart';
import 'widgets/parties_widgets.dart';

class PartiesHomeScreen extends StatelessWidget {
  const PartiesHomeScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً — عند غيابه تُنشئ الشاشة نموذجها.
  final PartiesHomeViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final PartiesHomeViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = PartiesHomeViewModel(
        customerRepo: app.customers!,
        supplierRepo: app.suppliers!,
        companyRepo: app.companies!,
        fxRepo: app.fxRates!,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<PartiesHomeViewModel>.value(
      value: vm,
      // تحديث العدّادات والإجماليات عند العودة من مسارات الوحدة الفرعية.
      child: RefreshOnReturn(
        onReappear: vm.load,
        child: const _PartiesHomeBody(),
      ),
    );
  }
}

class _PartiesHomeBody extends StatelessWidget {
  const _PartiesHomeBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PartiesHomeViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // محور الأطراف مسار علوي خارج هيكل التبويبات — زر رجوع صريح
      // يعيد إلى الرئيسية (go_router لا يوفر رجوعاً تلقائياً هنا).
      appBar: AppBar(
        title: Text(l10n.partiesTabTitle),
        leading: BackButton(onPressed: () => context.go('/home')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const _HeroCard(),
          const SizedBox(height: 16),
          if (state.loading)
            const ListSkeleton(rows: 5)
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
            const _HubCard(),
            if (state.isEmpty) ...[
              const SizedBox(height: 16),
              EmptyState(
                icon: Icons.groups_rounded,
                title: l10n.partiesHomeEmptyTitle,
                message: l10n.partiesHomeEmptyBody,
                actionLabel: l10n.partiesHomeEmptyAction,
                onAction: () => context.go('/parties/customers/form'),
                compact: true,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// البطاقة البطلة — هوية الوحدة مع أيقونة داخل تدرج ولمسة ذهبية.
class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return FinCard(
      accent: colors.gold,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary,
                  Color.lerp(scheme.primary, Colors.black, 0.25)!,
                ],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.diversity_3_rounded,
              color: scheme.onPrimary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.partiesHomeHeroTitle,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.partiesHomeHeroSubtitle,
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

/// بطاقة صفوف الوصول — عدّادات وإجماليات لكل عملة وحالة أسعار اليوم.
class _HubCard extends StatelessWidget {
  const _HubCard();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PartiesHomeViewModel>();
    final state = vm.state;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return FinCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        children: [
          _PartyHubRow(
            index: 0,
            icon: Icons.person_rounded,
            title: l10n.partiesHubCustomers,
            subtitle: Text(
              l10n.partiesCountCustomers(state.customersCount),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            color: scheme.primary,
            trailing: PartiesCountBadge(
              count: state.customersCount,
              color: scheme.primary,
            ),
            onTap: () => context.go('/parties/customers'),
          ),
          _PartyHubDivider(),
          _PartyHubRow(
            index: 1,
            icon: Icons.local_shipping_rounded,
            title: l10n.partiesHubSuppliers,
            subtitle: Text(
              l10n.partiesCountSuppliers(state.suppliersCount),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            color: scheme.tertiary,
            trailing: PartiesCountBadge(
              count: state.suppliersCount,
              color: scheme.tertiary,
            ),
            onTap: () => context.go('/parties/suppliers'),
          ),
          _PartyHubDivider(),
          _PartyHubRow(
            index: 2,
            icon: Icons.trending_up_rounded,
            title: l10n.partiesHubReceivables,
            subtitle: _TotalsSubtitle(
              totals: state.receivableTotals,
              emptyText: l10n.partiesDuesCount(state.receivableParties),
            ),
            color: colors.warning,
            trailing: state.receivableParties > 0
                ? PartiesCountBadge(
                    count: state.receivableParties,
                    color: colors.warning,
                  )
                : null,
            onTap: () => context.go('/parties/receivables'),
          ),
          _PartyHubDivider(),
          _PartyHubRow(
            index: 3,
            icon: Icons.trending_down_rounded,
            title: l10n.partiesHubPayables,
            subtitle: _TotalsSubtitle(
              totals: state.payableTotals,
              emptyText: l10n.partiesDuesCount(state.payableParties),
            ),
            color: colors.negative,
            trailing: state.payableParties > 0
                ? PartiesCountBadge(
                    count: state.payableParties,
                    color: colors.negative,
                  )
                : null,
            onTap: () => context.go('/parties/payables'),
          ),
          _PartyHubDivider(),
          _PartyHubRow(
            index: 4,
            icon: Icons.currency_exchange_rounded,
            title: l10n.partiesHubRates,
            subtitle: _RatesSubtitle(
              hijriText: _hijriTodayText(context),
              gregorianText: partyFormatDate(context, DateTime.now()),
            ),
            color: colors.gold,
            trailing: _FxStatusChip(
              complete: state.ratesComplete,
              hasNonBase: state.hasNonBaseCurrencies,
              missingCount: state.ratesMissingCount,
            ),
            onTap: () => context.go('/parties/rates'),
          ),
        ],
      ),
    );
  }

  /// التاريخ الهجري اليوم بأرقام نظام العرض الحي.
  static String _hijriTodayText(BuildContext context) {
    final hijri = HijriCalendar.today();
    final plain = '${hijri.day} ${hijri.monthName} ${hijri.year} هـ';
    return NumeralsScope.of(context) ? Numerals.toArabicIndic(plain) : plain;
  }
}

/// شريط الإجماليات لكل عملة — أو نص بديل عند لا مستحقات.
class _TotalsSubtitle extends StatelessWidget {
  const _TotalsSubtitle({required this.totals, required this.emptyText});

  /// الإجماليات — سطر لكل عملة بلا خلط.
  final List<CurrencyTotal> totals;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (totals.isEmpty) {
      return Text(
        emptyText,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: scheme.onSurfaceVariant),
      );
    }
    return CurrencyTotalsRow(
      totals: [for (final total in totals) (total.currency.code, total.total)],
      decimalsOf: (code) {
        for (final total in totals) {
          if (total.currency.code == code) return total.currency.decimals;
        }
        return 2;
      },
    );
  }
}

/// سطر التاريخ (هجري بارز + ميلادي خافت) لصف الأسعار.
class _RatesSubtitle extends StatelessWidget {
  const _RatesSubtitle({required this.hijriText, required this.gregorianText});

  final String hijriText;
  final String gregorianText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: [
          TextSpan(
            text: hijriText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          TextSpan(
            text: ' · $gregorianText',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// شارة حالة أسعار اليوم — كاملة (إيجابية) أو ناقصة بعددها (تحذيرية).
class _FxStatusChip extends StatelessWidget {
  const _FxStatusChip({
    required this.complete,
    required this.hasNonBase,
    required this.missingCount,
  });

  final bool complete;

  /// هل توجد عملات غير الأساس أصلاً؟
  final bool hasNonBase;

  final int missingCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!hasNonBase || complete) {
      return StatusChip(
        label: l10n.partiesFxChipComplete,
        tone: ChipTone.positive,
        icon: Icons.check_circle_rounded,
        dense: true,
      );
    }
    return StatusChip(
      label: l10n.partiesFxChipMissing(missingCount),
      tone: ChipTone.warning,
      icon: Icons.warning_amber_rounded,
      dense: true,
    );
  }
}

class _PartyHubDivider extends StatelessWidget {
  const _PartyHubDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: Theme.of(context).colorScheme.outlineVariant
          .withValues(alpha: 0.4),
    );
  }
}

/// صف وصول واحد — أيقونة مصبوغة + عنوان + عنوان فرعي (Widget) + شارة،
/// مع حركة دخول متدرجة (fade+slide بتأخير بحسب الترتيب).
class _PartyHubRow extends StatelessWidget {
  const _PartyHubRow({
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.trailing,
  });

  final int index;
  final IconData icon;
  final String title;
  final Widget subtitle;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final start = (index * 0.07).clamp(0.0, 0.6);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 12),
            child: child,
          ),
        );
      },
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 21, color: color),
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
                    subtitle,
                  ],
                ),
              ),
              if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
              Icon(Icons.chevron_left_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
