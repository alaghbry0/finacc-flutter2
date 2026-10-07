/// محور البيع (تبويب /sell) — البوابة اليومية للكاشير: بطاقة بطلة بمبيعات
/// اليوم وصافي الصندوق (DashboardRepository بعملة الأساس) + بطاقتا وصول
/// كبيرتان («فاتورة بيع جديدة» و«عروض الأسعار») + آخر الفواتير للوصول
/// السريع لقائمة فواتير المبيعات.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/sale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/stat_tile.dart';
import '../view_models/sell_home_view_model.dart';
import 'widgets/sell_widgets.dart';

/// محور البيع داخل هيكل التبويبات (مسار `/sell`).
class SellHomeScreen extends StatelessWidget {
  const SellHomeScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً — عند غيابه تُنشئ الشاشة نموذجها.
  final SellHomeViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final SellHomeViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = SellHomeViewModel(
        dashboardRepo: app.dashboard!,
        saleRepo: app.sales!,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<SellHomeViewModel>.value(
      value: vm,
      child: const _SellHomeBody(),
    );
  }
}

class _SellHomeBody extends StatelessWidget {
  const _SellHomeBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SellHomeViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.sellHomeTitle),
        actions: [
          IconButton(
            tooltip: l10n.sellInvoicesTitle,
            icon: const Icon(Icons.receipt_long_rounded),
            onPressed: () => context.go('/sell/invoices'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const _HeroCard(),
          const SizedBox(height: 16),
          if (state.loading)
            const StatTilesSkeleton()
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
            const _TodayStatsRow(),
            const SizedBox(height: 16),
            const _NewSaleCard(),
            const SizedBox(height: 12),
            const _SecondaryAccessRow(),
            if (state.recentInvoices.isNotEmpty) ...[
              const SizedBox(height: 20),
              _RecentInvoicesCard(invoices: state.recentInvoices),
            ],
          ],
        ],
      ),
    );
  }
}

/// البطاقة البطلة — دعوة يومية سريعة للكاشير بلمسة ذهبية.
class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final now = DateTime.now();
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
              Icons.point_of_sale_rounded,
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
                  l10n.sellHomeHeroTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${sellFormatDate(now)} · ${sellFormatTime(now)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: FinText.tabularNums,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// بلاطات اليوم — المبيعات والصافي (بعملة الأساس — total_base).
class _TodayStatsRow extends StatelessWidget {
  const _TodayStatsRow();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SellHomeViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final stats = vm.state.stats;
    return Row(
      children: [
        Expanded(
          child: StatTile(
            label: l10n.sellHomeTodaySales,
            value: stats?.sales ?? 0,
            icon: Icons.trending_up_rounded,
            sign: FinSign.incoming,
            decimals: 2,
            onTap: () => context.go('/sell/invoices'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatTile(
            label: l10n.sellHomeTodayCash,
            value: stats?.netCash ?? 0,
            icon: Icons.account_balance_wallet_rounded,
            sign: stats != null && stats.netCash < 0
                ? FinSign.outgoing
                : FinSign.neutral,
            decimals: 2,
            onTap: () => context.go('/sell/invoices'),
          ),
        ),
      ],
    );
  }
}

/// بطاقة «فاتورة بيع جديدة» — أهم فعل يومي، بحركة دخول.
class _NewSaleCard extends StatelessWidget {
  const _NewSaleCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 14),
            child: child,
          ),
        );
      },
      child: FinCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: () => context.go('/sell/new'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  scheme.primary,
                  Color.lerp(scheme.primary, Colors.black, 0.28)!,
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: scheme.onPrimary.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_shopping_cart_rounded,
                    color: scheme.onPrimary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.sellHomeNewInvoice,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.sellHomeNewInvoiceHint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onPrimary.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_left_rounded,
                  color: scheme.onPrimary,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// بطاقتا الوصول الثانوية — عروض الأسعار + فواتير المبيعات.
class _SecondaryAccessRow extends StatelessWidget {
  const _SecondaryAccessRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return Row(
      children: [
        Expanded(
          child: _AccessCard(
            icon: Icons.request_quote_rounded,
            title: l10n.sellQuotationsTitle,
            subtitle: l10n.sellQuotationsSubtitle,
            color: colors.gold,
            onTap: () => context.go('/sell/quotations'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _AccessCard(
            icon: Icons.receipt_long_rounded,
            title: l10n.sellInvoicesTitle,
            subtitle: l10n.sellInvoicesSubtitle,
            color: scheme.tertiary,
            onTap: () => context.go('/sell/invoices'),
          ),
        ),
      ],
    );
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FinCard(
      padding: const EdgeInsets.all(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 21, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// آخر الفواتير — وصول سريع لقائمة فواتير المبيعات.
class _RecentInvoicesCard extends StatelessWidget {
  const _RecentInvoicesCard({required this.invoices});

  final List<SaleInvoiceSummary> invoices;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FinCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.sellHomeRecentInvoices,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/sell/invoices'),
                child: Text(l10n.commonViewAll),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final invoice in invoices.take(3))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.invoiceNo,
                          style: Theme.of(
                            context,
                          ).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontFeatures: FinText.tabularNums,
                          ),
                        ),
                        Text(
                          invoice.customerName ?? l10n.sellCashCustomer,
                          style: Theme.of(context).textTheme.labelSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  PayStatusChip(method: invoice.payStatus),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
