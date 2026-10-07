/// نموذج عرض شاشة الأرصدة المستحقة (المتبقية عند العملاء أو للموردين) —
/// قائمة مجمّعة **مفصولة بكل عملة**: سطر لكل (طرف × عملة)، وإجمالي
/// مستقل لكل عملة في رأس مجموعة خاصة بها — لا يُخلط عملتان في رقم
/// واحد أبداً (القاعدة المركزية FR-03-02 / FR-08-11).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/company_repository.dart';
import '../../../../domain/models/company.dart';
import '../../../../domain/models/party.dart';
import 'party_kind.dart';
import 'party_repo_gate.dart';

/// مجموعة أرصدة بعملة واحدة — رأس مستقل بإجماليه.
final class PartyCurrencyGroup {
  PartyCurrencyGroup({
    required this.currencyCode,
    required this.decimals,
    required this.rows,
  }) : total = _sum(rows);

  /// رمز العملة المقيد بها كل سطر.
  final String currencyCode;

  /// منازل العملة للعرض.
  final int decimals;

  /// السطور (طرف × هذه العملة).
  final List<PartyBalance> rows;

  /// إجمالي المجموعة **بهذه العملة فقط**.
  final double total;

  static double _sum(List<PartyBalance> rows) {
    var sum = 0.0;
    for (final row in rows) {
      sum += row.balance;
    }
    return sum;
  }
}

/// حالة شاشة الأرصدة المستحقة.
class PartyBalancesState {
  const PartyBalancesState({
    required this.loading,
    required this.kind,
    this.error,
    required this.query,
    required this.groups,
    this.hasAnyDues = false,
  });

  final bool loading;
  final PartyKind kind;
  final Object? error;

  /// نص البحث المحلي (اسم أو هاتف).
  final String query;

  /// المجموعات المعروضة — مجموعة لكل عملة لها أرصدة.
  final List<PartyCurrencyGroup> groups;

  /// هل توجد مستحقات إطلاقاً (قبل البحث)؟
  final bool hasAnyDues;

  /// عدد الأطراف الفريدين في المجموعات المعروضة.
  int get distinctParties {
    final ids = <int>{};
    for (final group in groups) {
      for (final row in group.rows) {
        ids.add(row.partyId);
      }
    }
    return ids.length;
  }

  static PartyBalancesState initial(PartyKind kind) => PartyBalancesState(
    loading: true,
    kind: kind,
    query: '',
    groups: const <PartyCurrencyGroup>[],
  );
}

class PartyBalancesViewModel extends ChangeNotifier {
  PartyBalancesViewModel({
    required PartyRepoGate gate,
    required CompanyRepository companyRepo,
    required PartyKind partyKind,
    DateTime? reference,
  }) : _repo = gate,
       _companies = companyRepo,
       _kind = partyKind,
       _now = reference,
       _state = PartyBalancesState.initial(partyKind);

  final PartyRepoGate _repo;
  final CompanyRepository _companies;
  final PartyKind _kind;

  /// لحظة احتساب أيام التأخير (قابلة للحقن).
  final DateTime? _now;

  PartyBalancesState _state;
  PartyBalancesState get state => _state;

  /// كل السطور قبل البحث (لبحث محلي فوري دون العودة للقاعدة).
  List<PartyBalance> _allRows = const <PartyBalance>[];

  /// منازل كل عملة برمزها (من العملات النشطة).
  Map<String, int> _decimalsByCode = const <String, int>{};

  Timer? _searchDebounce;

  /// البحث بالكتابة — تأجيل 300ms (بحث محلي فوق المُحمَّل).
  void onQueryChanged(String query) {
    if (query == _state.query) return;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _applyQuery(query);
    });
  }

  /// تثبيت البحث فوراً.
  void setQuery(String query) {
    _searchDebounce?.cancel();
    _applyQuery(query);
  }

  /// تحميل قائمة المستحقات كاملة ثم تجميعها لكل عملة.
  Future<void> load() async {
    _state = PartyBalancesState(
      loading: true,
      kind: _kind,
      query: _state.query,
      groups: const <PartyCurrencyGroup>[],
    );
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        _repo.duesList(now: _now),
        _companies.listActiveCurrencies(),
      ]);
      final rows = results[0] as List<PartyBalance>;
      _allRows = rows;
      _decimalsByCode = {
        for (final currency in results[1] as List<Currency>)
          currency.code: currency.decimals,
      };
      _rebuild(rows, hasAnyDues: rows.isNotEmpty);
    } catch (error) {
      _allRows = const <PartyBalance>[];
      _decimalsByCode = const <String, int>{};
      _state = PartyBalancesState(
        loading: false,
        kind: _kind,
        error: error,
        query: _state.query,
        groups: const <PartyCurrencyGroup>[],
      );
      notifyListeners();
    }
  }

  /// يطبّق البحث محلياً ويجمّع النتائج لكل عملة.
  void _applyQuery(String query) {
    final trimmed = query.trim();
    final filtered = trimmed.isEmpty
        ? _allRows
        : _allRows
              .where(
                (row) =>
                    row.name.contains(trimmed) ||
                    (row.phone ?? '').contains(trimmed),
              )
              .toList(growable: false);
    _rebuild(filtered, hasAnyDues: _allRows.isNotEmpty, query: query);
  }

  void _rebuild(
    List<PartyBalance> rows, {
    required bool hasAnyDues,
    String? query,
  }) {
    // تجميع لكل عملة على حدة مع الحفاظ على ترتيب أول ظهور.
    final byCode = <String, List<PartyBalance>>{};
    final order = <String>[];
    for (final row in rows) {
      final bucket = byCode[row.currencyCode];
      if (bucket == null) {
        order.add(row.currencyCode);
        byCode[row.currencyCode] = [row];
      } else {
        bucket.add(row);
      }
    }
    _state = PartyBalancesState(
      loading: false,
      kind: _kind,
      query: query ?? _state.query,
      groups: [
        for (final code in order)
          PartyCurrencyGroup(
            currencyCode: code,
            decimals: _decimalsByCode[code] ?? 2,
            rows: byCode[code]!,
          ),
      ],
      hasAnyDues: hasAnyDues,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
