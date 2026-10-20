/// جسم الداشبورد — تركيب الأقسام (بطاقات/بلاطات/رسوم/تنبيهات) مع
/// حالات التحميل والخطأ. الأقسام المشروطة دوال بحارسات تُرجع null
/// عند غياب القسم (نفس دلالة if/else الأصلية بلا تعشش عميق).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../../domain/services/hijri_date.dart';
import '../../../../../domain/services/numerals.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/fin_tokens.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/mini_sales_chart.dart';
import '../../../../core/widgets/numerals_scope.dart';
import '../../../../core/widgets/stat_tile.dart';
import '../../view_models/home_view_model.dart';
import 'backup_reminder_banner.dart';
import 'last_updated_chip.dart';
import 'month_sales_card.dart';
import 'quick_access_tile.dart';
import 'staggered_entrance.dart';
import 'top_items_card.dart';
import 'welcome_card.dart';

class DashboardBody extends StatelessWidget {
  const DashboardBody({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DashboardViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    // الأقسام المشروطة تُحسب أولاً — الحارسات داخل كل دالة.
    final backupReminder = _backupReminderSection(vm);
    final statTiles = _statTiles(vm, state, l10n);
    final monthSales = _monthSalesSection(state, l10n, vm.currencyCode);
    final topItems = _topItemsSection(state, l10n, vm.currencyCode);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: vm.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            // قاع القوائم الموحد 32 (UX-2b — كان 28 شاذاً بين 28/32/96).
            padding: const EdgeInsets.fromLTRB(
              FinSpacing.xl,
              16,
              FinSpacing.xl,
              FinSpacing.bottom,
            ),
            children: [
              StaggeredEntrance(
                index: 0,
                child: WelcomeCard(
                  companyName: vm.companyName ?? l10n.appTitle,
                  hijriText: _hijriText(NumeralsScope.of(context)),
                  gregorianText: _gregorianText(NumeralsScope.of(context)),
                ),
              ),
              // بانر تذكير النسخ الاحتياطي (FR-11-04) — يظهر عند النتيجة
              // أو الاستحقاق فقط، قابل للإخفاء لبقية الجلسة.
              ...?backupReminder,
              const SizedBox(height: 18),
              statTiles,
              const SizedBox(height: 18),
              // بطاقة «مبيعات الشهر» العريضة (17-c / FR-09-01): الإجمالي
              // + شارة المقارنة بالشهر السابق + عدد فواتير الشهر.
              // التدهور (null) أو الخطأ العام = غياب البطاقة بلا أثر.
              ?monthSales,
              const SizedBox(height: 18),
              _quickAccessCard(context, l10n),
              const SizedBox(height: 18),
              _chartCard(state, l10n, vm.currencyCode),
              const SizedBox(height: 18),
              // أعلى الأصناف مبيعاً هذا الشهر (17-c / FR-09-01) — بعد رسم
              // الـ30 يوماً؛ شارات ترتيب ملوّنة + شريط حصة الكمية.
              ?topItems,
              const SizedBox(height: 18),
              _stockAlertsCard(context, state, l10n),
            ],
          ),
        ),
      ),
    );
  }

  /// بانر النسخ الاحتياطي + فاصلته — غائب تماماً بلا تذكير.
  List<Widget>? _backupReminderSection(DashboardViewModel vm) {
    final reminder = vm.backupReminder;
    if (reminder == null) return null;
    return [
      const SizedBox(height: 12),
      StaggeredEntrance(
        index: 1,
        child: BackupReminderBanner(
          reminder: reminder,
          onDismiss: vm.dismissBackupReminder,
        ),
      ),
    ];
  }

  /// بلاطات الإحصاءات الأربع — هيكل عند التحميل، خطأ، أو الشبكة.
  Widget _statTiles(
    DashboardViewModel vm,
    DashboardState state,
    AppLocalizations l10n,
  ) {
    if (state.loading) return const StatTilesSkeleton();
    if (state.error != null) {
      return ErrorState(
        title: l10n.genericErrorTitle,
        message: l10n.dbOpenErrorMessage,
        technicalDetails: state.error.toString(),
        retryLabel: l10n.commonRetry,
        onRetry: () => vm.load(),
        compact: true,
      );
    }
    return StaggeredEntrance(
      index: 1,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
        children: [
          StatTile(
            label: l10n.todaySales,
            value: state.stats.sales,
            icon: Icons.trending_up_rounded,
            sign: FinSign.incoming,
          ),
          StatTile(
            label: l10n.todayProfit,
            value: state.stats.profit,
            icon: Icons.savings_rounded,
            sign: FinSign.incoming,
          ),
          StatTile(
            label: l10n.todayInvoices,
            value: state.stats.invoiceCount.toDouble(),
            icon: Icons.receipt_long_rounded,
            isCount: true,
          ),
          StatTile(
            label: l10n.netCash,
            value: state.stats.netCash,
            icon: Icons.account_balance_wallet_rounded,
            sign: state.stats.netCash >= 0
                ? FinSign.incoming
                : FinSign.outgoing,
          ),
        ],
      ),
    );
  }

  /// بطاقة «مبيعات الشهر» — هيكل عند التحميل، وغياب عند الخطأ/التدهور.
  Widget? _monthSalesSection(
    DashboardState state,
    AppLocalizations l10n,
    String? currencyCode,
  ) {
    if (state.loading) {
      return StaggeredEntrance(
        index: 2,
        child: FinCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: l10n.monthSalesTitle),
              const ListSkeleton(rows: 2),
            ],
          ),
        ),
      );
    }
    if (state.error != null || state.month == null) return null;
    return StaggeredEntrance(
      index: 2,
      child: MonthSalesCard(stats: state.month!, currencyCode: currencyCode),
    );
  }

  /// بطاقة الوصول السريع — ثلاث بلاطات بصف واحد (A5/R17-b — تدقيق R16):
  /// بلاطات العملاء/الموردين/الصرف الثلاث دُمجت في بلاطة «الأطراف»
  /// واحدة → جذر وحدة /parties (بلا بلاطة رابعة — قرار المنسق:
  /// الداشبورد أصغر وأنظف، والتقارير تبقى من «المزيد»).
  Widget _quickAccessCard(BuildContext context, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return StaggeredEntrance(
      index: 3,
      child: FinCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: l10n.dashboardQuickAccess),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: QuickAccessTile(
                    icon: Icons.inventory_2_rounded,
                    label: l10n.tabInventory,
                    color: scheme.primary,
                    onTap: () => context.go('/inventory'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: QuickAccessTile(
                    icon: Icons.diversity_3_rounded,
                    label: l10n.partiesTabTitle,
                    color: scheme.primary,
                    onTap: () => context.go('/parties/hub'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: QuickAccessTile(
                    key: const Key('home_purchases_tile'),
                    icon: Icons.shopping_cart_rounded,
                    label: l10n.purHomeTitle,
                    color: colors.gold,
                    onTap: () => context.go('/purchases'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// بطاقة رسم الـ30 يوماً + شارة «آخر تحديث».
  Widget _chartCard(
    DashboardState state,
    AppLocalizations l10n,
    String? currencyCode,
  ) {
    return StaggeredEntrance(
      index: 4,
      child: FinCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: SectionHeader(title: l10n.last30DaysTitle)),
                if (state.lastUpdated != null)
                  LastUpdatedChip(at: state.lastUpdated!),
              ],
            ),
            if (state.loading)
              const ChartSkeleton()
            else
              MiniSalesChart(points: state.series, currency: currencyCode),
          ],
        ),
      ),
    );
  }

  /// بطاقة «أعلى الأصناف مبيعاً» — هيكل عند التحميل، وغياب عند الخطأ.
  Widget? _topItemsSection(
    DashboardState state,
    AppLocalizations l10n,
    String? currencyCode,
  ) {
    if (state.loading) {
      return StaggeredEntrance(
        index: 5,
        child: FinCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: l10n.topItemsTitle),
              const ListSkeleton(rows: 3),
            ],
          ),
        ),
      );
    }
    if (state.error != null || state.topItems == null) return null;
    return StaggeredEntrance(
      index: 5,
      child: TopItemsCard(items: state.topItems!, currencyCode: currencyCode),
    );
  }

  /// بطاقة تنبيهات المخزون — فراغ عند الصفر، وصف ملخص عند وجودها.
  Widget _stockAlertsCard(
    BuildContext context,
    DashboardState state,
    AppLocalizations l10n,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return StaggeredEntrance(
      index: 6,
      child: FinCard(
        child: Column(
          children: [
            SectionHeader(title: l10n.stockAlertsTitle),
            if (state.loading)
              const ListSkeleton(rows: 2)
            else if (state.lowStock == 0)
              EmptyState(
                icon: Icons.inventory_2_rounded,
                title: l10n.stockAlertsEmpty,
                message: l10n.stockAlertsCount(0),
                compact: true,
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: scheme.onErrorContainer,
                    size: 22,
                  ),
                ),
                title: Text(l10n.stockAlertsCount(state.lowStock)),
                trailing: const Icon(Icons.chevron_left_rounded),
              ),
          ],
        ),
      ),
    );
  }

  static String _hijriText(bool arabicIndic) {
    final hijri = HijriCalendar.today().toString();
    // الهجري يُخرَج بأرقام غربية — يُحوَّل للشرقية عند تفعيل النظام العربي.
    return arabicIndic ? Numerals.toArabicIndic(hijri) : hijri;
  }

  static String _gregorianText(bool arabicIndic) {
    // الميلادي بـ intl العربي يخرج بأرقام شرقية — يُوحَّد مع النظام المختار.
    final text = DateFormat('EEEE، d MMMM y', 'ar').format(DateTime.now());
    return arabicIndic ? text : Numerals.toWestern(text);
  }
}
