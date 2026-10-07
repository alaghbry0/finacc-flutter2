/// نموذج نافذة اختيار المورد — بحث فوري مؤجَّل بالاسم/الهاتف مع رصيد
/// المورد بعملته (معلوماتي — «ما ندين له به»).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/supplier_repository.dart';
import '../../../../domain/models/party.dart';

class SupplierPickerState {
  const SupplierPickerState({
    required this.loading,
    required this.matches,
    required this.query,
    this.error,
  });

  final bool loading;
  final List<PartyBalance> matches;
  final String query;
  final Object? error;

  static const SupplierPickerState initial = SupplierPickerState(
    loading: true,
    matches: <PartyBalance>[],
    query: '',
  );
}

class SupplierPickerViewModel extends ChangeNotifier {
  SupplierPickerViewModel({required SupplierRepository supplierRepo})
    : _suppliers = supplierRepo;

  final SupplierRepository _suppliers;

  SupplierPickerState _state = SupplierPickerState.initial;
  SupplierPickerState get state => _state;

  Timer? _debounce;

  /// بحث الكتابة — تأجيل 200ms مثل منتقي عميل الكاشير.
  void onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      unawaited(search(query));
    });
  }

  /// بحث فوري (Enter أو مسح) — سطر لكل (مورد × عملة).
  Future<void> search(String query) async {
    _debounce?.cancel();
    final trimmed = query.trim();
    if (trimmed == _state.query && !_state.loading) return;
    _state = SupplierPickerState(
      loading: true,
      matches: const <PartyBalance>[],
      query: trimmed,
    );
    notifyListeners();
    try {
      // بحث المستودع بالاسم/الهاتف (LIKE) — كل الأرصدة بعملاتها.
      final rows = await _suppliers.listWithBalances(search: trimmed);
      // دمج أسطر المورد الواحد في بطاقة واحدة (اسم + أول عملة برصيد):
      // الرصيد الكامل بعملته الرئيسة (أعلى قيمة مطلقة) لعرض بسيط صادق.
      final byId = <int, PartyBalance>{};
      for (final row in rows) {
        final existing = byId[row.partyId];
        if (existing == null || row.balance.abs() > existing.balance.abs()) {
          byId[row.partyId] = row;
        }
      }
      _state = SupplierPickerState(
        loading: false,
        matches: byId.values.toList(),
        query: trimmed,
      );
    } catch (error) {
      _state = SupplierPickerState(
        loading: false,
        matches: const <PartyBalance>[],
        query: trimmed,
        error: error,
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
