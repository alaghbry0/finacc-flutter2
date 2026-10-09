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
import '../../../core/widgets/access_card.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/hub_hero_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/refresh_on_active.dart';
import '../../../core/widgets/stat_tile.dart';
import '../view_models/purchases_home_view_model.dart';
import 'widgets/purchase_widgets.dart';

/// محور المشتريات — مسار علوي خارج هيكل التبويبات (نمط الأطراف).
class PurchasesHomeScreen extends StatelessWidget {
  const PurchasesHomeScreen({super.key, this.origin});

  /// مسار الأصل الذي دخل منه المستخدم الوحدة (P2-7) — يموّنه الموجّه من
  /// متتبع المواقع؛ null = مجهول فيرجع الجسم إلى «المزيد».
  final String? origin;

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
        child: _PurchasesHomeBody(origin: origin),
      ),
    );
  }
}

class _PurchasesHomeBody extends StatelessWidget {
  const _PurchasesHomeBody({this.origin});

  /// مسار الأصل الذي دخل منه المستخدم الوحدة (P2-7) — يرجع إليه زر
  /// الرجوع؛ null = مجهول فيرجع إلى «المزيد».
  final String? origin;

  /// وجهة زر الرجوع — الأصل إن عُرف، وإلا «المزيد» (فك ارتباط الوحدة
  /// عن تصلّب مسار واحد مهما كان مدخل المستخدم).
  String get _backDestination => origin ?? '/more';

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PurchasesHomeViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go(_backDestination)),
        title: Text(l10n.purHomeTitle),
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

/// البطاقة البطلة — دعوة يومية لفواتير الشراء بلون الهوية
/// (HubHeroCard الموحدة — W3/R17-b: كان construct يدوياً مكرراً).
class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    return HubHeroCard(
      icon: Icons.local_shipping_rounded,
      title: l10n.purHomeHeroTitle,
      subtitle: Text(
        '${purFormatDate(now)} · ${purFormatTime(now)}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontFeatures: FinText.tabularNums,
        ),
      ),
    );
  }
}

/// بلاطات اليوم — عدد فواتير الشراء + قيمتها بعملة الأساس (فواتير
/// العملة الأساسية حصراً — فصل العملات 5.4-7).
/// معلوماتية بلا تنقل (A2/R17-b): قائمة المشتريات لها بطاقة وصول واحدة.
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
          child: AccessCard(
            icon: Icons.receipt_long_rounded,
            title: l10n.purInvoicesTitle,
            subtitle: l10n.purInvoicesSubtitle,
            color: scheme.tertiary,
            onTap: () => context.go('/purchases/invoices'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AccessCard(
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
          child: AccessCard(
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

/// آخر المشتريات — عرض موجز فقط (A2/R17-b): مدخل القائمة الوحيد هو
/// بطاقة الوصول؛ الصفوف معلوماتية بلا تنقل.
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
          Text(
            l10n.purHomeRecent,
            style: Theme.of(context).textTheme.titleMedium,
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
