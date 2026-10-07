/// محور المشتريات (مسار /purchases — المرحلة 5): بطاقة بطلة + إحصاءات
/// مشتريات اليوم + بطاقة «فاتورة شراء جديدة» الكبيرة + بطاقات وصول
/// (قائمة المشتريات / مرتجع بيع / مرتجع شراء / قائمة المشتريات) + آخر
/// المشتريات للوصول السريع. مرآة محور البيع بالنمط والبنية.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/purchase.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/refresh_on_active.dart';
import '../../../core/widgets/stat_tile.dart';
import '../view_models/purchases_home_view_model.dart';
import 'widgets/purchase_widgets.dart';

/// محور المشتريات — مسار علوي خارج هيكل التبويبات (نمط الأطراف).
class PurchasesHomeScreen extends StatelessWidget {
  const PurchasesHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final PurchasesHomeViewModel vm;
    vm = PurchasesHomeViewModel(
      purchaseRepo: app.purchases!,
      companyRepo: app.companies!,
    );
    unawaited(vm.load());
    return ChangeNotifierProvider<PurchasesHomeViewModel>.value(
      value: vm,
      // تحديث حي عند العودة من الشراء/المرتجعات: إحصاءات اليوم وآخر
      // المشتريات تتغير بترحيل PUR من أي شاشة (قاعدة §10).
      child: RefreshOnActive(
        routePattern: RegExp(r'^/purchases$'),
        onActivate: vm.load,
        child: const _PurchasesHomeBody(),
      ),
    );
  }
}

class _PurchasesHomeBody extends StatelessWidget {
  const _PurchasesHomeBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PurchasesHomeViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/sell')),
        title: Text(l10n.purHomeTitle),
        actions: [
          IconButton(
            tooltip: l10n.purInvoicesTitle,
            icon: const Icon(Icons.receipt_long_rounded),
            onPressed: () => context.go('/purchases/invoices'),
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
            const _NewPurchaseCard(),
            const SizedBox(height: 12),
            const _AccessRowOne(),
            const SizedBox(height: 12),
            const _AccessRowTwo(),
            if (state.recent.isNotEmpty) ...[
              const SizedBox(height: 20),
              _RecentPurchasesCard(purchases: state.recent),
            ],
          ],
        ],
      ),
    );
  }
}

/// البطاقة البطلة — دعوة يومية لفواتير الشراء بلون الهوية.
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
              Icons.local_shipping_rounded,
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
                  l10n.purHomeHeroTitle,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${purFormatDate(now)} · ${purFormatTime(now)}',
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

/// بلاطات اليوم — عدد فواتير الشراء + قيمتها بعملة الأساس (فواتير
/// العملة الأساسية حصراً — فصل العملات 5.4-7).
class _TodayStatsRow extends StatelessWidget {
  const _TodayStatsRow();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PurchasesHomeViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final stats = vm.state;
    return Row(
      children: [
        Expanded(
          child: StatTile(
            label: l10n.purHomeTodayCount,
            value: stats.todayCount.toDouble(),
            icon: Icons.receipt_long_rounded,
            isCount: true,
            onTap: () => context.go('/purchases/invoices'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatTile(
            label: l10n.purHomeTodayTotal,
            value: stats.todayTotalBase,
            icon: Icons.local_shipping_rounded,
            sign: FinSign.outgoing,
            decimals: 2,
            onTap: () => context.go('/purchases/invoices'),
          ),
        ),
      ],
    );
  }
}

/// بطاقة «فاتورة شراء جديدة» — أهم فعل في الوحدة، بحركة دخول.
class _NewPurchaseCard extends StatelessWidget {
  const _NewPurchaseCard();

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
          key: const Key('pur_new_purchase_card'),
          onTap: () => context.go('/purchases/new'),
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
                        l10n.purHomeNewInvoice,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.purHomeNewInvoiceHint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onPrimary.withValues(alpha: 0.85),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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

/// صف الوصول الأول — قائمة المشتريات + مرتجع البيع (SRN).
class _AccessRowOne extends StatelessWidget {
  const _AccessRowOne();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return Row(
      children: [
        Expanded(
          child: _AccessCard(
            icon: Icons.receipt_long_rounded,
            title: l10n.purInvoicesTitle,
            subtitle: l10n.purInvoicesSubtitle,
            color: scheme.tertiary,
            onTap: () => context.go('/purchases/invoices'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _AccessCard(
            icon: Icons.undo_rounded,
            title: l10n.retSaleTitle,
            subtitle: l10n.retSaleSubtitle,
            color: colors.gold,
            onTap: () => context.go('/purchases/returns/sale'),
          ),
        ),
      ],
    );
  }
}

/// صف الوصول الثاني — مرتجع الشراء (PRN).
class _AccessRowTwo extends StatelessWidget {
  const _AccessRowTwo();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _AccessCard(
            icon: Icons.assignment_return_rounded,
            title: l10n.retPurchaseTitle,
            subtitle: l10n.retPurchaseSubtitle,
            color: scheme.primary,
            onTap: () => context.go('/purchases/returns/purchase'),
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
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
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

/// آخر المشتريات — وصول سريع لقائمة فواتير الشراء.
class _RecentPurchasesCard extends StatelessWidget {
  const _RecentPurchasesCard({required this.purchases});

  final List<PurchaseInvoiceSummary> purchases;

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
                  l10n.purHomeRecent,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/purchases/invoices'),
                child: Text(l10n.commonViewAll),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final purchase in purchases.take(3))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          purchase.invoiceNo,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontFeatures: FinText.tabularNums,
                              ),
                        ),
                        Text(
                          purchase.supplierName ?? l10n.purSupplierRequired,
                          style: Theme.of(context).textTheme.labelSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  PurchasePayStatusChip(method: purchase.payStatus),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
