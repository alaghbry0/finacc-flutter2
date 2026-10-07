/// نموذج عرض قائمة الأطراف (العملاء أو الموردين) — بحث فوري مؤجَّل
/// (300ms)، رقائق تصفية (الكل / بأرصدة / بدون أرصدة / مؤرشفون)، وأرشفة
/// بالسحب للطرف بلا حركات (FR-03-09).
///
/// كل سطر = (طرف × عملة) — القاعدة المركزية: لا خلط للعملات في رقم
/// واحد مهما تكرر الطرف (FR-03-02 / FR-08-11).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/company_repository.dart';
import '../../../../domain/models/company.dart';
import '../../../../domain/models/party.dart';
import 'party_kind.dart';
import 'party_repo_gate.dart';

/// رقائق تصفية القائمة.
enum PartyListFilter {
  /// كل الأطراف غير المؤرشفين (بكل عملاتهم).
  all,

  /// سطور الأرصدة غير الصفرية فقط.
  withBalance,

  /// سطور الأرصدة الصفرية فقط (طرف بلا حركة يظهر برصيد صفري).
  zeroBalance,

  /// المؤرشفون فقط.
  archived,
}

/// نتيجة طلب الأرشفة — تُترجم في الواجهة إلى رسالة.
enum PartyArchiveOutcome {
  /// نجحت الأرشفة وتحديثت القائمة.
  done,

  /// الطرف له حركات مالية — الأرشفة من القائمة مرفوضة.
  blocked,
}

/// حالة قائمة الأطراف.
class PartyListState {
  const PartyListState({
    required this.loading,
    required this.kind,
    this.error,
    required this.query,
    required this.filter,
    required this.rows,
    required this.currencies,
    this.baseCurrency,
    this.refreshing = false,
  });

  final bool loading;

  /// نوع الطرف (عميل/مورد) — للتسميات والاتجاه.
  final PartyKind kind;

  final Object? error;

  /// نص البحث الحالي (اسم أو هاتف).
  final String query;

  /// الرقاقة المحددة.
  final PartyListFilter filter;

  /// السطور المعروضة — سطر لكل (طرف × عملة).
  final List<PartyBalance> rows;

  /// العملات النشطة (لمنازل العرض بالرمز).
  final List<Currency> currencies;

  final Currency? baseCurrency;

  /// تحديث خلفي جارٍ (بعد أرشفة) — القائمة تبقى ظاهرة.
  final bool refreshing;

  /// عدد الأطراف الفريدين في السطور المعروضة.
  int get distinctParties => rows.map((row) => row.partyId).toSet().length;

  /// منازل العملة ب رمزها (2 افتراضياً).
  int decimalsFor(String code) {
    for (final currency in currencies) {
      if (currency.code == code) return currency.decimals;
    }
    return 2;
  }

  static PartyListState initial(PartyKind kind) => PartyListState(
    loading: true,
    kind: kind,
    query: '',
    filter: PartyListFilter.all,
    rows: const <PartyBalance>[],
    currencies: const <Currency>[],
  );
}

class PartyListViewModel extends ChangeNotifier {
  PartyListViewModel({
    required PartyRepoGate gate,
    required CompanyRepository companyRepo,
    required PartyKind partyKind,
  }) : _repo = gate,
       _companies = companyRepo,
       _kind = partyKind,
       _state = PartyListState.initial(partyKind);

  final PartyRepoGate _repo;
  final CompanyRepository _companies;
  final PartyKind _kind;

  PartyListState _state;
  PartyListState get state => _state;

  Timer? _searchDebounce;

  /// البحث بالكتابة — تأجيل 300ms ثم تثبيت الاستعلام.
  void onQueryChanged(String query) {
    if (query == _state.query) return;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(setQuery(query));
    });
  }

  /// تثبيت البحث فوراً (الاختبارات ومسح الحقل).
  Future<void> setQuery(String query) async {
    _searchDebounce?.cancel();
    if (query == _state.query && !_state.loading) return;
    await _reload(query: query);
  }

  /// اختيار رقاقة التصفية.
  Future<void> setFilter(PartyListFilter filter) async {
    if (filter == _state.filter && !_state.loading) return;
    await _reload(filter: filter);
  }

  /// إعادة التحميل الكاملة (العملات + السطور).
  Future<void> load() => _reload(reset: true);

  /// تحديث سطري القائمة **مع إبقاء** البحث والتصفية الحاليين —
  /// يُستدعى عند عودة الشاشة للظهور بعد حفظ النموذج (RefreshOnReturn).
  Future<void> refresh() => _reload();

  /// أرشفة طرف — تنجح فقط للطرف بلا حركات (له فواتير أو سندات أو رصيد
  /// افتتاحي غير صفري يُمنع من القائمة)، ثم تحدَّث السطور (FR-03-09).
  Future<PartyArchiveOutcome> archive(int partyId) async {
    final hasMovements = await _repo.hasMovements(partyId);
    if (hasMovements) {
      return PartyArchiveOutcome.blocked;
    }
    final userId = await _companies.findAdminUserId();
    if (userId == null) {
      return PartyArchiveOutcome.blocked;
    }
    final result = await _repo.archive(partyId, userId: userId);
    if (result.isErr) {
      return PartyArchiveOutcome.blocked;
    }
    await _reload();
    return PartyArchiveOutcome.done;
  }

  Future<void> _reload({
    bool reset = false,
    String? query,
    PartyListFilter? filter,
  }) async {
    final effectiveQuery = query ?? _state.query;
    final effectiveFilter = filter ?? _state.filter;
    final firstLoad = _state.currencies.isEmpty;
    _state = PartyListState(
      loading: true,
      kind: _kind,
      query: effectiveQuery,
      filter: effectiveFilter,
      rows: const <PartyBalance>[],
      currencies: _state.currencies,
      baseCurrency: _state.baseCurrency,
    );
    notifyListeners();
    try {
      final search = effectiveQuery.trim().isEmpty
          ? null
          : effectiveQuery.trim();
      // قائمتان: النشطة (افتراض العرض) والكلية — الفرق = المؤرشفون.
      final results = await Future.wait<Object?>([
        _repo.listWithBalances(search: search, includeArchived: false),
        _repo.listWithBalances(search: search, includeArchived: true),
        if (firstLoad || reset) _companies.listActiveCurrencies(),
      ]);
      final activeRows = results[0] as List<PartyBalance>;
      final allRows = results[1] as List<PartyBalance>;
      final currencies = results.length > 2
          ? results[2] as List<Currency>
          : _state.currencies;
      final activeIds = activeRows.map((row) => row.partyId).toSet();
      final rows = switch (effectiveFilter) {
        PartyListFilter.all => activeRows,
        PartyListFilter.withBalance =>
          activeRows.where((row) => row.balance != 0).toList(growable: false),
        PartyListFilter.zeroBalance =>
          activeRows.where((row) => row.balance == 0).toList(growable: false),
        PartyListFilter.archived =>
          allRows
              .where((row) => !activeIds.contains(row.partyId))
              .toList(growable: false),
      };
      _state = PartyListState(
        loading: false,
        kind: _kind,
        query: effectiveQuery,
        filter: effectiveFilter,
        rows: rows,
        currencies: currencies,
        baseCurrency: _baseOf(currencies),
      );
    } catch (error) {
      _state = PartyListState(
        loading: false,
        kind: _kind,
        error: error,
        query: effectiveQuery,
        filter: effectiveFilter,
        rows: const <PartyBalance>[],
        currencies: _state.currencies,
        baseCurrency: _state.baseCurrency,
      );
    }
    notifyListeners();
  }

  static Currency? _baseOf(List<Currency> currencies) {
    for (final currency in currencies) {
      if (currency.isBase) return currency;
    }
    return null;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
