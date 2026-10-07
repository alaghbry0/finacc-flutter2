/// نموذج عرض تفاصيل الطرف — البيانات + الأرصدة مفصولة بكل عملة
/// (FR-03-02/FR-08-11) + كشف الحساب بعملة وفترة (FR-03-04) برصيد رأسي
/// متحرك، مع توزيع الرصيد حسب العملة إن تعددت.
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/company_repository.dart';
import '../../../../domain/models/company.dart';
import '../../../../domain/models/party.dart';
import 'party_kind.dart';
import 'party_lookup.dart';
import 'party_repo_gate.dart';

/// سجل طرف موحّد للعرض (عميل أو مورد) — الحقول المشتركة بين النوعين.
final class PartyRecordView {
  const PartyRecordView({
    required this.name,
    this.phone,
    this.whatsapp,
    this.address,
    this.area,
    this.creditLimit,
    this.notes,
    this.archived = false,
    this.openingBalance = 0,
    this.openingCurrencyId,
    this.openingDate,
  });

  final String name;
  final String? phone;
  final String? whatsapp;
  final String? address;
  final String? area;

  /// حد الائتمان — `null` بلا حد / `0` منع الآجل / قيمة = الحد.
  final double? creditLimit;

  final String? notes;
  final bool archived;
  final double openingBalance;
  final int? openingCurrencyId;
  final DateTime? openingDate;
}

/// حالة تفاصيل الطرف.
class PartyDetailState {
  const PartyDetailState({
    required this.loading,
    required this.kind,
    required this.partyId,
    this.error,
    this.notFound = false,
    this.record,
    required this.currencies,
    this.baseCurrency,
    required this.balances,
    this.statement,
    this.statementCurrencyId,
    this.from,
    this.to,
    this.loadingStatement = false,
  });

  final bool loading;
  final PartyKind kind;
  final int partyId;
  final Object? error;

  /// الطرف غير موجود (معرّف خاطئ).
  final bool notFound;

  /// السجل الموحّد.
  final PartyRecordView? record;

  /// العملات النشطة.
  final List<Currency> currencies;

  final Currency? baseCurrency;

  /// أرصدة الطرف — سطر لكل عملة (قد يكون سطراً صفرياً وحيداً).
  final List<PartyBalance> balances;

  /// كشف الحساب الحالي (بعملته وفترته).
  final StatementResult? statement;

  /// عملة الكشف المحددة.
  final int? statementCurrencyId;

  /// بداية الفترة (null = من أول حركة — يظهر الافتتاحي نفسه أول الكشف).
  final DateTime? from;

  /// نهاية الفترة (null = حتى اليوم).
  final DateTime? to;

  final bool loadingStatement;

  /// هل للطرف أكثر من عملة ذات رصيد؟ (توزيع الرصيد حسب العملة)
  bool get hasMultiCurrencyBalances {
    var count = 0;
    for (final row in balances) {
      if (row.balance != 0) count++;
    }
    return count > 1;
  }

  /// منازل عملة الكشف.
  int get statementDecimals {
    final id = statementCurrencyId;
    for (final currency in currencies) {
      if (currency.id == id) return currency.decimals;
    }
    return 2;
  }

  /// منازل العملة برمزها.
  int decimalsFor(String code) {
    for (final currency in currencies) {
      if (currency.code == code) return currency.decimals;
    }
    return 2;
  }

  static PartyDetailState initial(PartyKind kind, int partyId) =>
      PartyDetailState(
        loading: true,
        kind: kind,
        partyId: partyId,
        currencies: const <Currency>[],
        balances: const <PartyBalance>[],
      );
}

class PartyDetailViewModel extends ChangeNotifier {
  PartyDetailViewModel({
    required PartyRepoGate gate,
    required CompanyRepository companyRepo,
    required PartyLookup partyLookup,
    required PartyKind partyKind,
    required int id,
  }) : _repo = gate,
       _companies = companyRepo,
       _lookup = partyLookup,
       _kind = partyKind,
       _partyId = id,
       _state = PartyDetailState.initial(partyKind, id);

  final PartyRepoGate _repo;
  final CompanyRepository _companies;
  final PartyLookup _lookup;
  final PartyKind _kind;
  final int _partyId;

  PartyDetailState _state;
  PartyDetailState get state => _state;

  /// تحميل كامل: السجل + العملات + الأرصدة + الكشف الافتراضي
  /// (عملة الرصيد الافتتاحي أو الأساس).
  Future<void> load() async {
    _state = PartyDetailState.initial(_kind, _partyId);
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        _companies.listActiveCurrencies(),
        _repo.listWithBalances(includeArchived: true),
        _lookupRecord(),
      ]);
      final currencies = results[0] as List<Currency>;
      final allRows = results[1] as List<PartyBalance>;
      final record = results[2] as PartyRecordView?;
      if (record == null) {
        _state = PartyDetailState(
          loading: false,
          kind: _kind,
          partyId: _partyId,
          notFound: true,
          currencies: currencies,
          balances: const <PartyBalance>[],
        );
        notifyListeners();
        return;
      }
      final baseCurrency = _baseOf(currencies);
      final balances = allRows
          .where((row) => row.partyId == _partyId)
          .toList(growable: false);
      final statementCurrency =
          record.openingBalance != 0 && record.openingCurrencyId != null
          ? record.openingCurrencyId!
          : baseCurrency?.id;
      _state = PartyDetailState(
        loading: false,
        kind: _kind,
        partyId: _partyId,
        record: record,
        currencies: currencies,
        baseCurrency: baseCurrency,
        balances: balances,
        statementCurrencyId: statementCurrency,
      );
      notifyListeners();
      await _refreshStatement();
    } catch (error) {
      _state = PartyDetailState(
        loading: false,
        kind: _kind,
        partyId: _partyId,
        error: error,
        currencies: _state.currencies,
        balances: const <PartyBalance>[],
      );
      notifyListeners();
    }
  }

  /// اختيار عملة الكشف — يعيد بناء الكشف بها.
  Future<void> setStatementCurrency(int currencyId) async {
    if (currencyId == _state.statementCurrencyId) return;
    _state = _copyWith(statementCurrencyId: currencyId);
    notifyListeners();
    await _refreshStatement();
  }

  /// تحديد بداية الفترة — null يمسحها (كل الفترات).
  Future<void> setFrom(DateTime? from) async {
    _state = _copyWithPeriod(from: from, to: _state.to);
    notifyListeners();
    await _refreshStatement();
  }

  /// تحديد نهاية الفترة — null تمسحها (حتى اليوم).
  Future<void> setTo(DateTime? to) async {
    _state = _copyWithPeriod(from: _state.from, to: to);
    notifyListeners();
    await _refreshStatement();
  }

  /// مسح الفترة — الكشف من أول حركة (يظهر الافتتاحي نفسه أول قيد).
  Future<void> clearPeriod() async {
    _state = _copyWithPeriod(from: null, to: null);
    notifyListeners();
    await _refreshStatement();
  }

  Future<void> _refreshStatement() async {
    final currencyId = _state.statementCurrencyId;
    if (currencyId == null) return;
    _state = _copyWith(loadingStatement: true);
    notifyListeners();
    try {
      final statement = await _repo.statement(
        _partyId,
        currencyId: currencyId,
        from: _state.from,
        to: _state.to,
      );
      _state = _copyWith(statement: statement, loadingStatement: false);
    } catch (_) {
      _state = _copyWith(loadingStatement: false);
    }
    notifyListeners();
  }

  /// يقرأ السجل الموحّد من جدول النوع المناسب.
  Future<PartyRecordView?> _lookupRecord() async {
    if (_kind == PartyKind.customer) {
      final customer = await _lookup.customer(_partyId);
      if (customer == null) return null;
      return PartyRecordView(
        name: customer.name,
        phone: customer.phone,
        whatsapp: customer.whatsapp,
        address: customer.address,
        area: customer.area,
        creditLimit: customer.creditLimit,
        notes: customer.notes,
        archived: customer.isArchived,
        openingBalance: customer.openingBalance,
        openingCurrencyId: customer.openingBalanceCurrencyId,
        openingDate: _parseYmd(customer.openingBalanceDate),
      );
    }
    final supplier = await _lookup.supplier(_partyId);
    if (supplier == null) return null;
    return PartyRecordView(
      name: supplier.name,
      phone: supplier.phone,
      address: supplier.address,
      notes: supplier.notes,
      archived: supplier.isArchived,
      openingBalance: supplier.openingBalance,
      openingCurrencyId: supplier.openingBalanceCurrencyId,
      openingDate: _parseYmd(supplier.openingBalanceDate),
    );
  }

  PartyDetailState _copyWith({
    int? statementCurrencyId,
    StatementResult? statement,
    bool? loadingStatement,
  }) => PartyDetailState(
    loading: _state.loading,
    kind: _state.kind,
    partyId: _state.partyId,
    error: _state.error,
    notFound: _state.notFound,
    record: _state.record,
    currencies: _state.currencies,
    baseCurrency: _state.baseCurrency,
    balances: _state.balances,
    statement: statement ?? _state.statement,
    statementCurrencyId: statementCurrencyId ?? _state.statementCurrencyId,
    from: _state.from,
    to: _state.to,
    loadingStatement: loadingStatement ?? _state.loadingStatement,
  );

  /// نسخة بفترة صريحة — قيم null تمسح الفترة فعلاً.
  PartyDetailState _copyWithPeriod({DateTime? from, DateTime? to}) =>
      PartyDetailState(
        loading: _state.loading,
        kind: _state.kind,
        partyId: _state.partyId,
        error: _state.error,
        notFound: _state.notFound,
        record: _state.record,
        currencies: _state.currencies,
        baseCurrency: _state.baseCurrency,
        balances: _state.balances,
        statement: _state.statement,
        statementCurrencyId: _state.statementCurrencyId,
        from: from,
        to: to,
        loadingStatement: _state.loadingStatement,
      );

  static Currency? _baseOf(List<Currency> currencies) {
    for (final currency in currencies) {
      if (currency.isBase) return currency;
    }
    return null;
  }

  static DateTime? _parseYmd(String? ymd) {
    if (ymd == null || ymd.isEmpty) return null;
    final parsed = DateTime.tryParse(ymd);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }
}
