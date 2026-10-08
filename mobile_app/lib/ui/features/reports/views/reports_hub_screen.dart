/// مركز التقارير — جذر مسار /reports (الشريحة 10): بطاقة بطل + أقسام
/// تعرض كل تقارير الرقابة المتاحة (الأرباح عبر خريطة الترحيل، أعمار
/// الديون، الجرد الفعلي، الحد الأدنى، الصلاحية) مع روابط عميقة لوحدات
/// المخزون. تُلحق بها تقارير الشريحة 10 الباقية (حركة صنف/ملخص حركة/
/// المبيعات حسب) فور تسليم وكلاءها.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fin_card.dart';

/// شاشة مركز التقارير — قائمة ثابتة من بطاقات الأقسام (لا حالة تحميل؛
/// كل تقرير يحمّل بياناته عند فتحه).
class ReportsHubScreen extends StatelessWidget {
  const ReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.reportsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: const [
          _HeroCard(),
          SizedBox(height: 16),
          _FinanceSection(),
          SizedBox(height: 16),
          _FlowsSection(),
          SizedBox(height: 16),
          _DebtsSection(),
          SizedBox(height: 16),
          _InventoryControlSection(),
        ],
      ),
    );
  }
}

/// البطاقة البطلة — هوية المركز بلمسة ذهبية.
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
              Icons.insights_rounded,
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
                  l10n.reportsHeroTitle,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.reportsHeroSubtitle,
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

/// عنوان قسم صغير بأيقونة.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// صف تقرير واحد — أيقونة داخل حاوية مصبوغة + عنوان/وصف + سهم،
/// بحركة دخول متدرجة (نمط صفوف لوحة المخزن).
class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.route,
    this.accentColor,
  });

  final int index;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String route;

  /// لون شارة جانبية مميزة (اختياري — بطاقة الأرباح الذهبية).
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final start = (index * 0.08).clamp(0.0, 0.6);
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
        onTap: () => context.go(route),
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (accentColor != null) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 14,
                            color: accentColor,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// فاصل رفيع بين الصفوف.
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: Theme.of(context).colorScheme.outlineVariant
          .withValues(alpha: 0.4),
    );
  }
}

/// قسم المالية والأرباح — التقرير الذهبي للشريحة 10.
class _FinanceSection extends StatelessWidget {
  const _FinanceSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.account_balance_wallet_rounded,
          title: l10n.reportsSectionFinance,
        ),
        FinCard(
          accent: colors.gold,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: _ReportRow(
            index: 0,
            icon: Icons.trending_up_rounded,
            title: l10n.profitTitle,
            subtitle: l10n.reportsPnlDesc,
            color: colors.positive,
            route: '/reports/profit',
            accentColor: colors.gold,
          ),
        ),
      ],
    );
  }
}

/// قسم حركة المخزون والمبيعات — تقارير الشريحة 10 الثلاثة
/// (FR-09-03/04/06).
class _FlowsSection extends StatelessWidget {
  const _FlowsSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.swap_vert_rounded,
          title: l10n.reportsSectionFlows,
        ),
        FinCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            children: [
              _ReportRow(
                index: 1,
                icon: Icons.receipt_long_rounded,
                title: l10n.itemMovementTitle,
                subtitle: l10n.reportsItemMovementDesc,
                color: scheme.primary,
                route: '/reports/item-movement',
              ),
              const _RowDivider(),
              _ReportRow(
                index: 2,
                icon: Icons.inventory_2_rounded,
                title: l10n.stockSummaryTitle,
                subtitle: l10n.reportsStockSummaryDesc,
                color: scheme.tertiary,
                route: '/reports/stock-summary',
              ),
              const _RowDivider(),
              _ReportRow(
                index: 3,
                icon: Icons.bar_chart_rounded,
                title: l10n.salesByTitle,
                subtitle: l10n.reportsSalesByDesc,
                color: colors.positive,
                route: '/reports/sales-by',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// قسم الديون والتحصيل — أعمار الديون (الشريحة 9).
class _DebtsSection extends StatelessWidget {
  const _DebtsSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.schedule_send_rounded,
          title: l10n.reportsSectionDebts,
        ),
        FinCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: _ReportRow(
            index: 1,
            icon: Icons.event_busy_rounded,
            title: l10n.agingTitle,
            subtitle: l10n.agingHubSubtitle,
            color: scheme.primary,
            route: '/reports/aging',
          ),
        ),
      ],
    );
  }
}

/// قسم المخزون والرقابة — الجرد + الحد الأدنى + الصلاحية (روابط عميقة
/// إلى وحدات المخزون حيث تعيش شاشاتها).
class _InventoryControlSection extends StatelessWidget {
  const _InventoryControlSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.fact_check_rounded,
          title: l10n.reportsSectionInventory,
        ),
        FinCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            children: [
              _ReportRow(
                index: 2,
                icon: Icons.checklist_rounded,
                title: l10n.stocktakeTitle,
                subtitle: l10n.reportsStocktakeDesc,
                color: colors.gold,
                route: '/inventory/stocktake',
                accentColor: colors.gold,
              ),
              const _RowDivider(),
              _ReportRow(
                index: 3,
                icon: Icons.trending_down_rounded,
                title: l10n.inventoryHubLowStock,
                subtitle: l10n.inventoryHubLowStockDesc,
                color: colors.warning,
                route: '/inventory/low-stock',
              ),
              const _RowDivider(),
              _ReportRow(
                index: 4,
                icon: Icons.schedule_rounded,
                title: l10n.inventoryHubBatches,
                subtitle: l10n.inventoryHubBatchesDesc,
                color: colors.negative,
                route: '/inventory/batches',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
