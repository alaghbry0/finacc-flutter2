/// مركز التقارير — جذر مسار /reports (الشريحة 10) بهوية Simple Invoice
/// Manager (V7-C): ترويسة فرعية بعنوان «التقارير» **بلا زر رجوع** (قرار
/// نقد F9-a — نمط جذر /more)، بطاقة البطل القائمة ببياناتها، ثم مجموعات
/// التقارير الأربع (المالية/التدفقات/الديون/المخزون) بصفوف SIM
/// (`.setting-row` — بطاقات بيضاء بحدود cardBorder وفواصل 1px وشيفرون
/// RTL)، مع **صف «كشف حساب طرف»** الجديد (V7-7: الكشف موجود وظيفيًا
/// لكل طرف من محور الأطراف → /parties).
///
/// كل وجهة من الشاشة القائمة محفوظة بنفس مسارها: الأرباح وخريطة
/// الترحيل، أعمار الديون، حركة صنف/ملخص المخزون/المبيعات حسب، والروابط
/// العميقة لوحدات المخزون (الجرد/الحد الأدنى/الصلاحية).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/fin_tokens.dart';
import '../../../core/widgets/fin_section_title.dart';
import '../../../core/widgets/hub_hero_card.dart';
import '../../../core/widgets/sim_list_widgets.dart';

/// شاشة مركز التقارير — قائمة ثابتة من مجموعات الصفوف (لا حالة تحميل؛
/// كل تقرير يحمّل بياناته عند فتحه).
class ReportsHubScreen extends StatelessWidget {
  const ReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // مسار علوي خارج الهيكل (لا شريط سفلي/درج هنا) — زر رجوع
            // إلزامي كي لا يُحاصر المستخدم (رجوع R16-b — مراجعة V7 🔴-1):
            // pop عند توفره (دخلت من شاشة قائمة) وإلا عودة صريحة للرئيسية
            // بنمط محور الأطراف /parties نفسه.
            SimSubHeader(
              titleKey: const Key('reports_hub_title'),
              title: l10n.reportsTitle,
              onBack: () {
                final navigator = Navigator.of(context);
                if (navigator.canPop()) {
                  navigator.maybePop();
                } else {
                  context.go('/home');
                }
              },
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
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
            ),
          ],
        ),
      ),
    );
  }
}

/// البطاقة البطلة — هوية المركز بلمسة ذهبية
/// (HubHeroCard الموحدة — W3/R17-b: كان construct يدوياً مكرراً).
class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HubHeroCard(
      icon: Icons.insights_rounded,
      title: l10n.reportsHeroTitle,
      subtitle: Text(
        l10n.reportsHeroSubtitle,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// بطاقة مجموعة تقارير SIM — سطح أبيض بحد رقيق وزوايا 8px والصفوف
/// بينها فواصل 1px (نمط `.list-content` — مطابقة لبطاقات إعدادات V7-A).
class _ReportsGroupCard extends StatelessWidget {
  const _ReportsGroupCard({required this.children});

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

/// عنوان مجموعة التقارير — FinSectionTitle القائم بنمطه (أيقونة + نص).
class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 8),
      child: FinSectionTitle(icon: icon, title: title),
    );
  }
}

/// حاوية أيقونة صف التقرير — مربع 34×34 مصبوغ بشفافية اللون (نمط صفوف
/// إعدادات V7-A)؛ لون أيقونة كل تقرير محفوظ كما كان.
Widget _rowIcon(IconData icon, Color color) => Container(
  width: 34,
  height: 34,
  decoration: BoxDecoration(
    color: color.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(FinRadius.chip),
  ),
  child: Icon(icon, size: 18, color: color),
);

/// صف تقرير واحد بلغة SimSettingRow — العنوان والوصف والوجهة كما كانا؛
/// [titleKey] مفتاح ثابت للاختبارات (نقر الصف → مساره).
class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.route,
    required this.titleKey,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String route;
  final Key titleKey;

  @override
  Widget build(BuildContext context) {
    return SimSettingRow(
      titleKey: titleKey,
      leading: _rowIcon(icon, color),
      title: title,
      subtitle: subtitle,
      onTap: () => context.go(route),
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
        _GroupLabel(
          icon: Icons.account_balance_wallet_rounded,
          title: l10n.reportsSectionFinance,
        ),
        _ReportsGroupCard(
          children: [
            _ReportRow(
              icon: Icons.trending_up_rounded,
              title: l10n.profitTitle,
              subtitle: l10n.reportsPnlDesc,
              color: colors.positive,
              route: '/reports/profit',
              titleKey: const Key('reports_hub_row_profit'),
            ),
          ],
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
        _GroupLabel(
          icon: Icons.swap_vert_rounded,
          title: l10n.reportsSectionFlows,
        ),
        _ReportsGroupCard(
          children: [
            _ReportRow(
              icon: Icons.receipt_long_rounded,
              title: l10n.itemMovementTitle,
              subtitle: l10n.reportsItemMovementDesc,
              color: scheme.primary,
              route: '/reports/item-movement',
              titleKey: const Key('reports_hub_row_item_movement'),
            ),
            _ReportRow(
              icon: Icons.inventory_2_rounded,
              title: l10n.stockSummaryTitle,
              subtitle: l10n.reportsStockSummaryDesc,
              color: scheme.tertiary,
              route: '/reports/stock-summary',
              titleKey: const Key('reports_hub_row_stock_summary'),
            ),
            _ReportRow(
              icon: Icons.bar_chart_rounded,
              title: l10n.salesByTitle,
              subtitle: l10n.reportsSalesByDesc,
              color: colors.positive,
              route: '/reports/sales-by',
              titleKey: const Key('reports_hub_row_sales_by'),
            ),
          ],
        ),
      ],
    );
  }
}

/// قسم الديون والتحصيل — أعمار الديون (الشريحة 9) + كشف حساب طرف
/// (V7-7: الكشف الرسمي بالرصيد التراكمي متاح لكل طرف من محور الأطراف).
class _DebtsSection extends StatelessWidget {
  const _DebtsSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GroupLabel(
          icon: Icons.schedule_send_rounded,
          title: l10n.reportsSectionDebts,
        ),
        _ReportsGroupCard(
          children: [
            _ReportRow(
              icon: Icons.event_busy_rounded,
              title: l10n.agingTitle,
              subtitle: l10n.agingHubSubtitle,
              color: scheme.primary,
              route: '/reports/aging',
              titleKey: const Key('reports_hub_row_aging'),
            ),
            _ReportRow(
              icon: Icons.receipt_long_rounded,
              title: l10n.reportsHubPartyStatementTitle,
              subtitle: l10n.reportsHubPartyStatementDesc,
              color: colors.gold,
              route: '/parties',
              titleKey: const Key('reports_hub_row_party_statement'),
            ),
          ],
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
        _GroupLabel(
          icon: Icons.fact_check_rounded,
          title: l10n.reportsSectionInventory,
        ),
        _ReportsGroupCard(
          children: [
            _ReportRow(
              icon: Icons.checklist_rounded,
              title: l10n.stocktakeTitle,
              subtitle: l10n.reportsStocktakeDesc,
              color: colors.gold,
              route: '/inventory/stocktake',
              titleKey: const Key('reports_hub_row_stocktake'),
            ),
            _ReportRow(
              icon: Icons.trending_down_rounded,
              title: l10n.inventoryHubLowStock,
              subtitle: l10n.inventoryHubLowStockDesc,
              color: colors.warning,
              route: '/inventory/low-stock',
              titleKey: const Key('reports_hub_row_low_stock'),
            ),
            _ReportRow(
              icon: Icons.schedule_rounded,
              title: l10n.inventoryHubBatches,
              subtitle: l10n.inventoryHubBatchesDesc,
              color: colors.negative,
              route: '/inventory/batches',
              titleKey: const Key('reports_hub_row_batches'),
            ),
          ],
        ),
      ],
    );
  }
}
