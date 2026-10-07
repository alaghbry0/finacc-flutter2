/// نموذج عرض محور الأطراف — العدّادات والإجماليات وحالة أسعار اليوم:
/// العملاء والموردون (عدد)، المستحق لنا وعلينا (إجمالي لكل عملة على
/// حدة — FR-03-02/FR-08-11)، وأسعار الصرف (مكتملة/ناقصة — FR-08-09).
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/customer_repository.dart';
import '../../../../data/repositories/exchange_rate_repository.dart';
import '../../../../data/repositories/supplier_repository.dart';
import '../../../../domain/models/company.dart';
import '../../../../domain/models/party.dart';

/// إجمالي بعملة واحدة — سطر مستقل لا يُخلط أبداً (FR-08-11).
final class CurrencyTotal {
  const CurrencyTotal({required this.currency, required this.total});

  /// العملة المقيد بها الإجمالي.
  final Currency currency;

  /// مجموع الأرصدة الموجبة بهذه العملة.
  final double total;
}

/// حالة محور الأطراف.
class PartiesHomeState {
  const PartiesHomeState({
    required this.loading,
    this.error,
    this.customersCount = 0,
    this.suppliersCount = 0,
    this.receivableTotals = const <CurrencyTotal>[],
    this.payableTotals = const <CurrencyTotal>[],
    this.receivableParties = 0,
    this.payableParties = 0,
    this.baseCurrency,
    this.nonBaseCurrencyCount = 0,
    this.ratesEnteredToday = 0,
  });

  final bool loading;
  final Object? error;

  /// عدد العملاء غير المؤرشفين.
  final int customersCount;

  /// عدد الموردين غير المؤرشفين.
  final int suppliersCount;

  /// إجماليات المستحق لنا (عملاء) — سطر لكل عملة.
  final List<CurrencyTotal> receivableTotals;

  /// إجماليات المستحق علينا (موردون) — سطر لكل عملة.
  final List<CurrencyTotal> payableTotals;

  /// عدد العملاء ذوي مديونية قائمة.
  final int receivableParties;

  /// عدد الموردين ذوي ذمم قائمة.
  final int payableParties;

  /// العملة الأساسية.
  final Currency? baseCurrency;

  /// عدد العملات النشطة غير الأساسية.
  final int nonBaseCurrencyCount;

  /// كم عملة أُدخل لها سعر اليوم.
  final int ratesEnteredToday;

  /// هل توجد عملات غير الأساس أصلاً؟ (بلا عملات أخرى تُعد الأسعار
  /// «مكتملة» بالمفهوم العملي — لا شيء ينقص).
  bool get hasNonBaseCurrencies => nonBaseCurrencyCount > 0;

  /// هل أسعار اليوم مكتملة لكل العملات غير الأساسية؟
  bool get ratesComplete => ratesEnteredToday >= nonBaseCurrencyCount;

  /// عدد العملات الناقصة اليوم.
  int get ratesMissingCount =>
      (nonBaseCurrencyCount - ratesEnteredToday).clamp(0, nonBaseCurrencyCount);

  /// لا أطراف إطلاقاً — حالة الفراغ.
  bool get isEmpty => customersCount == 0 && suppliersCount == 0;

  static const PartiesHomeState initial = PartiesHomeState(loading: true);
}

class PartiesHomeViewModel extends ChangeNotifier {
  PartiesHomeViewModel({
    required CustomerRepository customerRepo,
    required SupplierRepository supplierRepo,
    required CompanyRepository companyRepo,
    required ExchangeRateRepository fxRepo,
    DateTime? reference,
  }) : _customers = customerRepo,
       _suppliers = supplierRepo,
       _companies = companyRepo,
       _fx = fxRepo,
       _now = reference;

  final CustomerRepository _customers;
  final SupplierRepository _suppliers;
  final CompanyRepository _companies;
  final ExchangeRateRepository _fx;

  /// لحظة «اليوم» (قابلة للحقن — الاختبارات).
  final DateTime? _now;

  PartiesHomeState _state = PartiesHomeState.initial;
  PartiesHomeState get state => _state;

  /// تحميل كل مؤشرات المحور دفعة واحدة.
  Future<void> load() async {
    _state = PartiesHomeState(loading: true);
    notifyListeners();
    try {
      final today = _dayOf(_now ?? DateTime.now());
      final results = await Future.wait<Object?>([
        _customers.listWithBalances(),
        _suppliers.listWithBalances(),
        _customers.receivablesList(now: _now),
        _suppliers.payablesList(now: _now),
        _companies.listActiveCurrencies(),
        _fx.todayRates(today),
      ]);
      final customerRows = results[0] as List<PartyBalance>;
      final supplierRows = results[1] as List<PartyBalance>;
      final receivables = results[2] as List<PartyBalance>;
      final payables = results[3] as List<PartyBalance>;
      final currencies = results[4] as List<Currency>;
      final todayRates = results[5] as Map<int, double>;

      final byCode = <String, Currency>{
        for (final currency in currencies) currency.code: currency,
      };
      _state = PartiesHomeState(
        loading: false,
        customersCount: _distinctParties(customerRows),
        suppliersCount: _distinctParties(supplierRows),
        receivableTotals: _totalsByCurrency(receivables, byCode),
        payableTotals: _totalsByCurrency(payables, byCode),
        receivableParties: _distinctParties(receivables),
        payableParties: _distinctParties(payables),
        baseCurrency: _baseOf(currencies),
        nonBaseCurrencyCount: currencies.where((c) => !c.isBase).length,
        ratesEnteredToday: todayRates.length,
      );
    } catch (error) {
      _state = PartiesHomeState(loading: false, error: error);
    }
    notifyListeners();
  }

  /// عدد الأطراف الفريدين (الطرف بعملتين يظهر في سطرين لا في اثنين).
  static int _distinctParties(List<PartyBalance> rows) =>
      rows.map((row) => row.partyId).toSet().length;

  /// تجميع المستحقات لكل عملة على حدة — سطر لكل عملة، بلا أي خلط
  /// (القاعدة المركزية FR-03-02 / FR-08-11).
  static List<CurrencyTotal> _totalsByCurrency(
    List<PartyBalance> rows,
    Map<String, Currency> byCode,
  ) {
    final totals = <String, double>{};
    final order = <String>[];
    for (final row in rows) {
      final existing = totals[row.currencyCode];
      if (existing == null) order.add(row.currencyCode);
      totals[row.currencyCode] = (existing ?? 0) + row.balance;
    }
    return [
      for (final code in order)
        CurrencyTotal(
          currency:
              byCode[code] ??
              Currency(
                id: -1,
                code: code,
                name: code,
                isBase: false,
                decimals: 2,
              ),
          total: totals[code]!,
        ),
    ];
  }

  /// يوم عمل كامل بلا وقت.
  static DateTime _dayOf(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static Currency? _baseOf(List<Currency> currencies) {
    for (final currency in currencies) {
      if (currency.isBase) return currency;
    }
    return null;
  }
}
