/// الشاشة الرئيسية — مركز المعاملات بنمط Simple Invoice Manager (V3):
/// ترويسة (قائمة/عنوان/تنبيه/مزامنة/إعدادات) + تبويبات أفقية قابلة
/// للتمرير (فواتير بيع/عروض أسعار/مشتريات/قبض/صرف/تقارير) + شريط
/// تصفية حالة وبحث مضمّن وفرز + رقاقة النطاق الزمني + شريط مبيعات
/// الشهر + قائمة صفوف المعاملات + كبسولة «إنشاء فاتورة» العائمة
/// + درج جانبي (شبكة وصول سريع + وحدات).
///
/// لوحة التحكم السابقة (FR-09-01) انتقلت إلى `/home/dashboard` وتُفتح
/// من الدرج — بياناتها ومكوناتها كما هي بلا تعديل.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/session/app_controller.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/refresh_on_active.dart';
import '../../../../l10n/app_localizations.dart';
import '../view_models/transactions_home_view_model.dart';
import 'widgets/home_drawer.dart';
import 'widgets/home_fab_pill.dart';
import 'widgets/home_filter_bar.dart';
import 'widgets/home_header.dart';
import 'widgets/home_tabs_bar.dart';
import 'widgets/home_time_bar.dart';
import 'widgets/home_transaction_row.dart';

/// الشاشة الرئيسية — مركز المعاملات.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TransactionsHomeViewModel? _vm;
  final TextEditingController _searchController = TextEditingController();
  bool _searchVisible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_vm != null) return;
    final app = context.read<AppController>();
    final vm = TransactionsHomeViewModel(
      saleRepository: app.sales!,
      quotationRepository: app.quotations!,
      purchaseRepository: app.purchases!,
      cashRepository: app.cash!,
      dashboardRepository: app.dashboard!,
    );
    _vm = vm;
    unawaited(_bootstrap(vm, app));
  }

  /// العملة الأساسية (لسطر الشهر) ثم أول تحميل.
  ///
  /// الاختبارات السريعة قد تُخلّي الشاشة وتغلق قاعدة البيانات قبل اكتمال
  /// هذه السلسلة غير المتزامنة — لذلك نتحقق من `mounted` قبل كل خطوة
  /// ونلتقط استثناء القاعدة المغلقة بهدوء (الرمز يبقى فارغاً فحسب).
  Future<void> _bootstrap(
    TransactionsHomeViewModel vm,
    AppController app,
  ) async {
    try {
      vm.currencyCode = (await app.companies?.findBaseCurrency())?.code;
    } catch (_) {
      // القاعدة أُغلقت قبل الرد (بيئة اختبار) — نتجاهل بهدوء.
    }
    if (!mounted) return;
    await vm.load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _vm?.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) {
        _searchController.clear();
        _vm?.setQuery('');
      }
    });
  }

  Future<void> _refresh() async {
    final l10n = AppLocalizations.of(context)!;
    await _vm?.load();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.homeRefreshDone),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    if (vm == null) {
      // إطار بناء أولي قبل didChangeDependencies؟ لا يحدث — الأمان فقط.
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ChangeNotifierProvider<TransactionsHomeViewModel>.value(
      value: vm,
      child: RefreshOnActive(
        routePattern: RegExp(r'^/home$'),
        onActivate: vm.load,
        child: _HomeHubBody(
          searchController: _searchController,
          searchVisible: _searchVisible,
          onToggleSearch: _toggleSearch,
          onRefresh: _refresh,
        ),
      ),
    );
  }
}

/// جسم المركز — يستهلك VM جاهزاً (Consumer).
class _HomeHubBody extends StatelessWidget {
  const _HomeHubBody({
    required this.searchController,
    required this.searchVisible,
    required this.onToggleSearch,
    required this.onRefresh,
  });

  final TextEditingController searchController;
  final bool searchVisible;
  final VoidCallback onToggleSearch;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    final vm = context.watch<TransactionsHomeViewModel>();
    final state = vm.state;
    final l10n = AppLocalizations.of(context)!;

    final tabs = <HomeTabChip>[
      HomeTabChip(
        key: const Key('home_tab_sales'),
        label: l10n.homeTabSales,
      ),
      HomeTabChip(
        key: const Key('home_tab_quotations'),
        label: l10n.homeTabQuotations,
      ),
      HomeTabChip(
        key: const Key('home_tab_purchases'),
        label: l10n.homeTabPurchases,
      ),
      HomeTabChip(
        key: const Key('home_tab_receipts'),
        label: l10n.homeTabReceipts,
      ),
      HomeTabChip(
        key: const Key('home_tab_payments'),
        label: l10n.homeTabPayments,
      ),
      HomeTabChip(
        key: const Key('home_tab_reports'),
        label: l10n.homeTabReports,
      ),
    ];

    final showStatusChip =
        state.tab == HomeTab.sales || state.tab == HomeTab.purchases;

    return Scaffold(
      drawer: const HomeDrawer(),
      floatingActionButton: HomeFabPill(
        onTap: () => context.go('/sell/new'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Column(
        children: [
          HomeHeader(
            title: app.company?.name ?? 'FinAcc',
            onRefresh: onRefresh,
          ),
          HomeTabsBar(
            tabs: tabs,
            selectedIndex: state.tab.index,
            onSelect: (index) => vm.setTab(HomeTab.values[index]),
          ),
          if (state.tab != HomeTab.reports) ...[
            HomeFilterBar(
              statusFilter: state.statusFilter,
              onStatusTap: () => _openStatusSheet(context, vm),
              sort: state.sort,
              onSortTap: () => _openSortSheet(context, vm),
              searchVisible: searchVisible,
              searchController: searchController,
              onQueryChanged: vm.setQuery,
              onToggleSearch: onToggleSearch,
              showStatusChip: showStatusChip,
            ),
            HomeTimeBar(
              range: state.timeRange,
              onTap: () => _openTimeSheet(context, vm),
            ),
            HomeMonthStrip(month: state.month, currencyCode: vm.currencyCode),
          ],
          Expanded(
            child: state.tab == HomeTab.reports
                ? const _ReportsTabBody()
                : _TransactionsBody(state: state),
          ),
        ],
      ),
    );
  }

  void _openStatusSheet(BuildContext context, TransactionsHomeViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    final options = <(HomeStatusFilter, String)>[
      (HomeStatusFilter.all, l10n.homeFilterAll),
      (HomeStatusFilter.paid, l10n.homeFilterPaid),
      (HomeStatusFilter.partial, l10n.homeFilterPartial),
      (HomeStatusFilter.unpaid, l10n.homeFilterUnpaid),
    ];
    _openChoiceSheet<HomeStatusFilter>(
      context,
      title: l10n.homeFilterAll,
      options: options,
      selected: vm.state.statusFilter,
      onSelect: vm.setStatusFilter,
    );
  }

  void _openSortSheet(BuildContext context, TransactionsHomeViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    final options = <(HomeSortOption, String)>[
      (HomeSortOption.dateDesc, l10n.homeSortDateDesc),
      (HomeSortOption.dateAsc, l10n.homeSortDateAsc),
      (HomeSortOption.totalDesc, l10n.homeSortTotalDesc),
      (HomeSortOption.balanceDesc, l10n.homeSortBalanceDesc),
      (HomeSortOption.partyAsc, l10n.homeSortPartyAsc),
    ];
    _openChoiceSheet<HomeSortOption>(
      context,
      title: l10n.homeSortTitle,
      options: options,
      selected: vm.state.sort,
      onSelect: vm.setSort,
    );
  }

  void _openTimeSheet(BuildContext context, TransactionsHomeViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    final options = <(HomeTimeRange, String)>[
      (HomeTimeRange.all, l10n.homeTimeAll),
      (HomeTimeRange.year, l10n.homeTimeYear),
      (HomeTimeRange.quarter, l10n.homeTimeQuarter),
      (HomeTimeRange.month, l10n.homeTimeMonth),
      (HomeTimeRange.week, l10n.homeTimeWeek),
    ];
    _openChoiceSheet<HomeTimeRange>(
      context,
      title: l10n.homeTimeAll,
      options: options,
      selected: vm.state.timeRange,
      onSelect: (range) => unawaited(vm.setTimeRange(range)),
    );
  }

  /// ورقة خيارات سفلية موحّدة (حالة/فرز/زمن) — خيار لكل سطر بعلامة
  /// الصح للمختار (علامة غير لونية — DS-26).
  void _openChoiceSheet<T>(
    BuildContext context, {
    required String title,
    required List<(T, String)> options,
    required T selected,
    required ValueChanged<T> onSelect,
  }) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                child: Text(
                  title,
                  style: Theme.of(sheetContext).textTheme.titleSmall,
                ),
              ),
              for (final (value, label) in options)
                ListTile(
                  key: ValueKey('choice_${value.runtimeType}_$value'),
                  dense: true,
                  title: Text(label),
                  trailing: value == selected
                      ? Icon(Icons.check_rounded, color: scheme.primary)
                      : null,
                  onTap: () {
                    onSelect(value);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
      ),
    );
  }
}

/// قائمة المعاملات بحالاتها (تحميل/خطأ/فراغ/نتائج).
class _TransactionsBody extends StatelessWidget {
  const _TransactionsBody({required this.state});

  final TransactionsHomeState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (state.loading) {
      return const ListSkeleton(rows: 9);
    }
    if (state.error != null) {
      return ErrorState(
        title: l10n.genericErrorTitle,
        message: l10n.dbOpenErrorMessage,
        technicalDetails: state.error.toString(),
      );
    }
    if (state.rows.isEmpty) {
      final filtered = state.totalCount > 0;
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: filtered ? l10n.homeNoResultsTitle : l10n.homeEmptyTitle,
        message: filtered
            ? l10n.homeNoResultsBody
            : l10n.homeEmptyBody,
      );
    }
    return ListView.builder(
      key: const Key('home_transactions_list'),
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: state.rows.length,
      itemBuilder: (context, index) {
        final row = state.rows[index];
        return HomeTransactionTile(
          row: row,
          fallbackParty: l10n.sellCashCustomer,
        );
      },
    );
  }
}

/// تبويب التقارير — روابط التقارير الخمسة الجاهزة + مركز التقارير.
class _ReportsTabBody extends StatelessWidget {
  const _ReportsTabBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final entries = <(IconData, String, String)>[
      (Icons.trending_up_rounded, l10n.profitTitle, '/reports/profit'),
      (Icons.schedule_rounded, l10n.homeDrawerReportsSubAging, '/reports/aging'),
      (
        Icons.swap_vert_rounded,
        l10n.itemMovementTitle,
        '/reports/item-movement',
      ),
      (Icons.summarize_rounded, l10n.stockSummaryTitle, '/reports/stock-summary'),
      (Icons.bar_chart_rounded, l10n.salesByTitle, '/reports/sales-by'),
    ];
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        for (final (icon, label, route) in entries)
          ListTile(
            key: ValueKey('home_report_link_$route'),
            leading: Icon(icon, color: scheme.primary),
            title: Text(label),
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: () => context.go(route),
          ),
      ],
    );
  }
}
