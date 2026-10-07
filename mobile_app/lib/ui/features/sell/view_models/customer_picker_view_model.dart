/// نموذج منتقي العميل السريع لشاشة البيع — بحث بالاسم/الهاتف عبر
/// `listWithBalances` (الرصيد يُعرض معلوماتياً بعملته ولا يدخل أي حساب).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/customer_repository.dart';

/// مطابقة عميل واحدة (مزاولة التكرار — أول سطر رصيد للعميل).
class CustomerPick {
  const CustomerPick({
    required this.partyId,
    required this.name,
    required this.phone,
    required this.currencyCode,
    required this.balance,
    required this.hasMoreCurrencies,
  });

  final int partyId;
  final String name;
  final String? phone;

  /// رمز عملة أول رصيد (للعرض المعلوماتي).
  final String currencyCode;

  /// الرصيد بعملته (موجب = دَين عليه لنا).
  final double balance;

  /// هل له أرصدة بعملات أخرى؟ (يظهر ببساطة ولا يُجمع أبداً — FR-08-11).
  final bool hasMoreCurrencies;
}

class CustomerPickerState {
  const CustomerPickerState({
    required this.loading,
    required this.matches,
    required this.query,
    this.error,
  });

  final bool loading;
  final List<CustomerPick> matches;
  final String query;
  final Object? error;

  static const CustomerPickerState initial = CustomerPickerState(
    loading: true,
    matches: <CustomerPick>[],
    query: '',
  );
}

class CustomerPickerViewModel extends ChangeNotifier {
  CustomerPickerViewModel({required CustomerRepository customerRepo})
    : _customers = customerRepo;

  final CustomerRepository _customers;

  CustomerPickerState _state = CustomerPickerState.initial;
  CustomerPickerState get state => _state;

  Timer? _debounce;

  void onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      unawaited(search(query));
    });
  }

  Future<void> search(String query) async {
    _debounce?.cancel();
    final trimmed = query.trim();
    if (trimmed == _state.query && !_state.loading) return;
    _state = CustomerPickerState(
      loading: true,
      matches: const <CustomerPick>[],
      query: trimmed,
    );
    notifyListeners();
    try {
      final balances = await _customers.listWithBalances(
        search: trimmed.isEmpty ? null : trimmed,
      );
      // طرف له أرصدة بعملتين يظهر في سطرين — نوحّد العرض باختيار الأول.
      final seen = <int>{};
      final matches = <CustomerPick>[];
      for (final balance in balances) {
        if (!seen.add(balance.partyId)) {
          continue;
        }
        matches.add(
          CustomerPick(
            partyId: balance.partyId,
            name: balance.name,
            phone: balance.phone,
            currencyCode: balance.currencyCode,
            balance: balance.balance,
            hasMoreCurrencies: false,
          ),
        );
      }
      _state = CustomerPickerState(
        loading: false,
        matches: matches,
        query: trimmed,
      );
    } catch (error) {
      _state = CustomerPickerState(
        loading: false,
        matches: const <CustomerPick>[],
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
