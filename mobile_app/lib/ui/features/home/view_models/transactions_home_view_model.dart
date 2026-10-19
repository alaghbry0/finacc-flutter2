/// نموذج عرض مركز المعاملات — V3 (هيكل Simple Invoice Manager):
/// الشاشة الرئيسية صارت محور معاملات بتبويبات أفقية (فواتير بيع/عروض
/// أسعار/مشتريات/قبض/صرف/تقارير) مع مرشح حالة وبحث نصي ونطاق زمني
/// وفرز، وشريط «مبيعات الشهر» الرمادي — كلها من المستودعات الحقيقية
/// عبر `AppController` حصراً (قاعدة §4).
///
/// **أمانة العملات (5.4-7)**: صفوف القائمة تعرض مبالغها بعملة مستندها
/// (لا تجميع عبر العملات). الشريط الشهري وحده يجمع بالعملة الأساسية
/// (`total_base` — نفس أساس `DashboardRepository`).
///
/// **التدهور الرشيق**: فشل استعلام الشهر يُخفض الشريط إلى null (غياب)
/// دون إسقاط القائمة؛ فشل استعلام التبويب يرفع خطأً مع زر إعادة.
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/dashboard_repository.dart';
import '../../../../data/repositories/purchase_repository.dart';
import '../../../../data/repositories/quotation_repository.dart';
import '../../../../data/repositories/sale_repository.dart';
import '../../../../data/repositories/cash_repository.dart';
import '../../../../domain/models/purchase.dart';
import '../../../../domain/models/quotation.dart';
import '../../../../domain/models/sale.dart';

/// ألسنة مركز المعاملات — ترتيب العرض في التبويبات الأفقية.
enum HomeTab {
  /// فواتير البيع المكتملة (سجل INV).
  sales,

  /// عروض الأسعار (QTE) بحالاتها.
  quotations,

  /// فواتير الشراء (PUR).
  purchases,

  /// سندات القبض (RVT) من سجل الصندوق.
  receipts,

  /// سندات الصرف (PMT) من سجل الصندوق.
  payments,

  /// بند التنقل إلى مركز التقارير (قائمة روابط — لا بيانات).
  reports,
}

/// مرشح حالة الدفع — يسري على تبويبات فواتير البيع والشراء (شرائح
/// مدفوع/جزئي/غير مدفوع بنمط Simple Invoice Manager).
enum HomeStatusFilter {
  /// كل المستندات.
  all,

  /// مدفوع بالكامل.
  paid,

  /// مدفوع جزئياً.
  partial,

  /// غير مدفوع (آجل كامل).
  unpaid,
}

/// النطاق الزمني — يقيّد كل التبويبات (نقدي بالاستعلام، والمستندات
/// بالتصفية على تاريخ الإصدار).
enum HomeTimeRange {
  /// بلا حد زمني.
  all,

  /// السنة التقويمية الجارية.
  year,

  /// الربع الحالي.
  quarter,

  /// الشهر التقويمي الجاري.
  month,

  /// آخر ٧ أيام.
  week,
}

/// خيار الفرز.
enum HomeSortOption {
  /// الأحدث أولاً (الافتراضي).
  dateDesc,

  /// الأقدم أولاً.
  dateAsc,

  /// المبلغ الأكبر أولاً.
  totalDesc,

  /// الرصيد المستحق الأكبر أولاً.
  balanceDesc,

  /// اسم الطرف أبجدياً.
  partyAsc,
}

/// شارة صف المعاملة — تُرسم كـ StatusChip بنص واضح (DS-26: علامة
/// غير لونية دائماً — النص نفسه).
enum HomeBadge {
  /// مدفوع بالكامل (أخضر).
  paid,

  /// مدفوع جزئياً (برتقالي).
  partial,

  /// غير مدفوع (أزرق — عائلة البذرة).
  unpaid,

  /// عرض سعر: مسودة.
  draft,

  /// عرض سعر: مرسل.
  sent,

  /// عرض سعر: محوّل إلى فاتورة.
  converted,

  /// عرض سعر: منتهي الصلاحية.
  expired,

  /// عرض سعر: مرفوض.
  rejected,

  /// بلا شارة (سندات النقدية).
  none,
}

/// صف معاملة موحّد عبر التبويبات — التطبيع الوحيد الذي تحتاجه القائمة.
class HomeTransactionRow {
  const HomeTransactionRow({
    required this.id,
    required this.docNo,
    required this.date,
    required this.partyName,
    required this.currencyCode,
    required this.total,
    required this.dueAmount,
    required this.badge,
    required this.detailRoute,
  });

  final int id;

  /// رقم المستند (INV2 / QTE1 / PUR3 / RVT4 / PMT5).
  final String docNo;

  /// تاريخ المستند/الحركة.
  final DateTime date;

  /// اسم الطرف (null = عميل نقدي/بلا طرف).
  final String? partyName;

  /// رمز عملة المستند (YER/USD/…).
  final String? currencyCode;

  /// إجمالي المستند بعملته.
  final double total;

  /// الرصيد المستحق بعملته (0 عند الوفاء).
  final double dueAmount;

  /// شارة الحالة.
  final HomeBadge badge;

  /// مسار التفاصيل عند الضغط (go_router).
  final String detailRoute;
}

/// حالة مركز المعاملات — غير قابلة للتعديل، تُنسخ بـ copyWith.
class TransactionsHomeState {
  const TransactionsHomeState({
    required this.loading,
    required this.tab,
    required this.statusFilter,
    required this.timeRange,
    required this.sort,
    required this.query,
    required this.rows,
    required this.totalCount,
    this.month,
    this.error,
  });

  /// جارٍ التحميل (يُعرض الهيكل العظمي).
  final bool loading;

  final HomeTab tab;
  final HomeStatusFilter statusFilter;
  final HomeTimeRange timeRange;
  final HomeSortOption sort;

  /// نص البحث الحالي (فارغ = بلا بحث).
  final String query;

  /// الصفوف بعد التصفية والفرز.
  final List<HomeTransactionRow> rows;

  /// عدد الصفوف قبل التصفية (لعداد النتائج).
  final int totalCount;

  /// إحصاءات الشهر — null = فشل الاستعلام (غياب الشريط).
  final MonthSalesStats? month;

  final Object? error;

  static const TransactionsHomeState initial = TransactionsHomeState(
    loading: true,
    tab: HomeTab.sales,
    statusFilter: HomeStatusFilter.all,
    timeRange: HomeTimeRange.all,
    sort: HomeSortOption.dateDesc,
    query: '',
    rows: <HomeTransactionRow>[],
    totalCount: 0,
  );

  TransactionsHomeState copyWith({
    bool? loading,
    HomeTab? tab,
    HomeStatusFilter? statusFilter,
    HomeTimeRange? timeRange,
    HomeSortOption? sort,
    String? query,
    List<HomeTransactionRow>? rows,
    int? totalCount,
    MonthSalesStats? month,
    Object? error,
    bool clearError = false,
    bool clearMonth = false,
  }) {
    return TransactionsHomeState(
      loading: loading ?? this.loading,
      tab: tab ?? this.tab,
      statusFilter: statusFilter ?? this.statusFilter,
      timeRange: timeRange ?? this.timeRange,
      sort: sort ?? this.sort,
      query: query ?? this.query,
      rows: rows ?? this.rows,
      totalCount: totalCount ?? this.totalCount,
      month: clearMonth ? null : (month ?? this.month),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// متحكم عرض مركز المعاملات — ChangeNotifier يُنشأ في الشاشة عبر
/// `ChangeNotifierProvider.value` (قاعدة §4).
class TransactionsHomeViewModel extends ChangeNotifier {
  TransactionsHomeViewModel({
    required SaleRepository saleRepository,
    required QuotationRepository quotationRepository,
    required PurchaseRepository purchaseRepository,
    required CashRepository cashRepository,
    required DashboardRepository dashboardRepository,
  }) : _sales = saleRepository,
       _quotations = quotationRepository,
       _purchases = purchaseRepository,
       _cash = cashRepository,
       _dashboard = dashboardRepository;

  final SaleRepository _sales;
  final QuotationRepository _quotations;
  final PurchaseRepository _purchases;
  final CashRepository _cash;
  final DashboardRepository _dashboard;

  TransactionsHomeState _state = TransactionsHomeState.initial;
  bool _isDisposed = false;

  /// الصفوف الخام للتبويب الجاري قبل أي تصفية.
  List<HomeTransactionRow> _rawRows = const <HomeTransactionRow>[];

  TransactionsHomeState get state => _state;

  /// رمز العملة الأساسية (لسطر مبيعات الشهر — يُضبط من الشاشة بعد
  /// `findBaseCurrency`؛ عدم ضبطه = سطر بلا رمز عملة).
  String? currencyCode;

  /// تحميل التبويب النشط + إحصاءات الشهر.
  Future<void> load() async {
    if (_state.tab == HomeTab.reports) {
      // تبويب التقارير قائمة روابط ثابتة — لا استعلامات.
      _state = _state.copyWith(loading: false, clearError: true);
      notifyListeners();
      return;
    }
    _state = _state.copyWith(loading: true, clearError: true);
    notifyListeners();
    try {
      final rows = await _fetchRows();
      final month = await _guardMonth();
      if (_isDisposed) return;
      _state = _state.copyWith(loading: false, month: month);
      _resetRaw(rows);
    } catch (error) {
      if (_isDisposed) return;
      _state = _state.copyWith(loading: false, error: error);
      notifyListeners();
    }
  }

  /// يجلب صفوف التبويب الخام (قبل التصفية) — الأحدث أولاً من المصدر.
  Future<List<HomeTransactionRow>> _fetchRows() async {
    switch (_state.tab) {
      case HomeTab.sales:
        final invoices = await _sales.recentSales(limit: 400);
        return [
          for (final invoice in invoices)
            if (invoice.status == 'completed')
              HomeTransactionRow(
                id: invoice.id,
                docNo: invoice.invoiceNo,
                date: invoice.issuedAt,
                partyName: invoice.customerName,
                currencyCode: invoice.currencyCode,
                total: invoice.total,
                dueAmount: invoice.dueAmount,
                badge: switch (invoice.payStatus) {
                  SalePaymentMethod.cash => HomeBadge.paid,
                  SalePaymentMethod.mixed => HomeBadge.partial,
                  SalePaymentMethod.credit => HomeBadge.unpaid,
                },
                detailRoute: '/sell/invoices/${invoice.id}',
              ),
        ];
      case HomeTab.quotations:
        final quotations = await _quotations.listQuotations(limit: 400);
        return [
          for (final quotation in quotations)
            HomeTransactionRow(
              id: quotation.id,
              docNo: quotation.quotationNo,
              date: quotation.issuedAt,
              partyName: quotation.customerName,
              currencyCode: quotation.currencyCode,
              total: quotation.total,
              dueAmount: 0,
              badge: switch (quotation.status) {
                QuotationStatus.draft => HomeBadge.draft,
                QuotationStatus.sent => HomeBadge.sent,
                QuotationStatus.converted => HomeBadge.converted,
                QuotationStatus.expired => HomeBadge.expired,
                QuotationStatus.rejected => HomeBadge.rejected,
              },
              detailRoute: '/sell/quotations/${quotation.id}',
            ),
        ];
      case HomeTab.purchases:
        final invoices = await _purchases.recentPurchases(limit: 400);
        return [
          for (final invoice in invoices)
            if (invoice.status == 'completed')
              HomeTransactionRow(
                id: invoice.id,
                docNo: invoice.invoiceNo,
                date: invoice.issuedAt,
                partyName: invoice.supplierName,
                currencyCode: invoice.currencyCode,
                total: invoice.total,
                dueAmount: invoice.dueAmount,
                badge: switch (invoice.payStatus) {
                  PurchasePaymentMethod.cash => HomeBadge.paid,
                  PurchasePaymentMethod.mixed => HomeBadge.partial,
                  PurchasePaymentMethod.credit => HomeBadge.unpaid,
                },
                detailRoute: '/purchases/invoices/${invoice.id}',
              ),
        ];
      case HomeTab.receipts:
        return _voucherRows('receipt');
      case HomeTab.payments:
        return _voucherRows('payment');
      case HomeTab.reports:
        return const <HomeTransactionRow>[];
    }
  }

  /// سندات النقدية (receipt قبض / payment صرف) من سجل الصندوق —
  /// الاستعلام نفسه يقيد النطاق الزمني (is_voided وreversal_of
  /// مستبعدان في SQL). [txType] برموز عمود `cash_tx.tx_type`.
  Future<List<HomeTransactionRow>> _voucherRows(String txType) async {
    final range = _timeWindow();
    final movements = await _cash.journal(
      txType: txType,
      from: range.$1,
      to: range.$2,
      limit: 400,
    );
    return [
      for (final movement in movements)
        if (!movement.isVoided)
          HomeTransactionRow(
            id: movement.id,
            docNo: movement.voucherNo ?? txType,
            date: movement.txDate,
            partyName:
                movement.customerName ??
                movement.supplierName ??
                movement.expenseCategoryName,
            currencyCode: movement.currencyCode,
            total: movement.amount.abs(),
            dueAmount: 0,
            badge: HomeBadge.none,
            // لا مسار تفاصيل مستقل للسندات — الرحلة تكمل في سجل النقدية.
            detailRoute: '/cash/movements',
          ),
    ];
  }

  /// نافذة النطاق الزمني (from, to) — null = بلا حد.
  (DateTime?, DateTime?) _timeWindow() {
    final now = DateTime.now();
    switch (_state.timeRange) {
      case HomeTimeRange.all:
        return (null, null);
      case HomeTimeRange.year:
        return (DateTime(now.year), null);
      case HomeTimeRange.quarter:
        return (DateTime(now.year, (now.month - 1) ~/ 3 * 3 + 1), null);
      case HomeTimeRange.month:
        return (DateTime(now.year, now.month), null);
      case HomeTimeRange.week:
        return (now.subtract(const Duration(days: 7)), null);
    }
  }

  /// إحصاءات الشهر بمعزل أخطاء (تدهور رشيق — غياب الشريط فقط).
  Future<MonthSalesStats?> _guardMonth() async {
    try {
      return await _dashboard.monthStats(DateTime.now());
    } catch (_) {
      return null;
    }
  }

  /// يبدّل التبويب النشط ويُعيد التحميل (كل تبويب مصدر بياناته).
  Future<void> setTab(HomeTab tab) async {
    if (tab == _state.tab) return;
    _state = _state.copyWith(tab: tab, clearError: true);
    notifyListeners();
    await load();
  }

  /// يبدّل مرشح الحالة (يسري على فواتير البيع/الشراء — يتجاهله الباقي).
  void setStatusFilter(HomeStatusFilter filter) {
    if (filter == _state.statusFilter) return;
    _state = _state.copyWith(statusFilter: filter);
    _applyFilters();
  }

  /// يبدّل النطاق الزمني ويُعيد التحميل (سندات النقدية تُقيَّد بالاستعلام).
  Future<void> setTimeRange(HomeTimeRange range) async {
    if (range == _state.timeRange) return;
    _state = _state.copyWith(timeRange: range);
    notifyListeners();
    await load();
  }

  /// يبدّل خيار الفرز.
  void setSort(HomeSortOption sort) {
    if (sort == _state.sort) return;
    _state = _state.copyWith(sort: sort);
    _applyFilters();
  }

  /// يضبط نص البحث (تفعيل/إسكات من شريط البحث المضمّن).
  void setQuery(String query) {
    final normalized = query.trim();
    if (normalized == _state.query) return;
    _state = _state.copyWith(query: normalized);
    _applyFilters();
  }

  /// يطبّق مرشحات الحالة/الزمن/البحث والفرز على الصفوف الخام.
  void _applyFilters() {
    Iterable<HomeTransactionRow> visible = _rawRows;

    // النطاق الزمني — المستندات تُصفّى على تاريخ الإصدار (النقدية مقيدة
    // بالاستعلام أصلاً لكن التصفية هنا لا تضر: النافذة نفسها).
    final (from, _) = _timeWindow();
    if (from != null) {
      visible = visible.where((row) => !row.date.isBefore(from));
    }

    // مرشح الحالة — يسري على تبويبات فواتير البيع/الشراء فقط.
    final statusFilter = _state.statusFilter;
    if (statusFilter != HomeStatusFilter.all &&
        (_state.tab == HomeTab.sales || _state.tab == HomeTab.purchases)) {
      visible = visible.where((row) => switch (statusFilter) {
        HomeStatusFilter.paid => row.badge == HomeBadge.paid,
        HomeStatusFilter.partial => row.badge == HomeBadge.partial,
        HomeStatusFilter.unpaid => row.badge == HomeBadge.unpaid,
        HomeStatusFilter.all => true,
      });
    }

    // البحث النصي — رقم المستند أو اسم الطرف (غير حساس للحالة).
    final query = _state.query;
    if (query.isNotEmpty) {
      final lower = query.toLowerCase();
      visible = visible.where((row) {
        return row.docNo.toLowerCase().contains(lower) ||
            (row.partyName?.toLowerCase().contains(lower) ?? false);
      });
    }

    // الفرز.
    final sorted = visible.toList()
      ..sort((a, b) => switch (_state.sort) {
        HomeSortOption.dateDesc => b.date.compareTo(a.date),
        HomeSortOption.dateAsc => a.date.compareTo(b.date),
        HomeSortOption.totalDesc => b.total.compareTo(a.total),
        HomeSortOption.balanceDesc => b.dueAmount.compareTo(a.dueAmount),
        HomeSortOption.partyAsc =>
          (a.partyName ?? '').compareTo(b.partyName ?? ''),
      });

    _state = _state.copyWith(rows: sorted, totalCount: _rawRows.length);
    notifyListeners();
  }

  /// يستبدل الصفوف الخام بعد جلب جديد ثم يعيد التصفية فوقها.
  void _resetRaw(List<HomeTransactionRow> rows) {
    _rawRows = List<HomeTransactionRow>.unmodifiable(rows);
    _applyFilters();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  /// الصفوف الخام قبل التصفية — تكشفها الاختبارات مباشرة.
  List<HomeTransactionRow> get rawRows => _rawRows;
}

