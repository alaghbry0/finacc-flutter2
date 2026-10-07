/// نموذج محور النقدية (تبويب /cash) — بطاقة «صافي النقدية» لكل عملة
/// (لا خلط عملات — 5.4-7) + بطاقات الصناديق بأرصدتها الحية (سالب =
/// تحذير للواجهة — FR-04-06/09) + آخر الحركات للوصول السريع.
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/cash_repository.dart';
import '../../../../domain/models/cash.dart';

class CashHomeState {
  const CashHomeState({
    required this.loading,
    required this.boxes,
    required this.netLines,
    required this.recent,
    this.error,
  });

  final bool loading;
  final List<CashboxWithBalance> boxes;
  final List<CashNetLine> netLines;
  final List<CashMovementRow> recent;
  final Object? error;

  static const CashHomeState initial = CashHomeState(
    loading: true,
    boxes: <CashboxWithBalance>[],
    netLines: <CashNetLine>[],
    recent: <CashMovementRow>[],
  );

  /// خط صافي العملة الأساسية (العنوان الرئيسي للبطاقة البطلة) —
  /// `null` إن لم توجد حركات بعد.
  CashNetLine? get baseNetLine {
    for (final line in netLines) {
      if (line.isBase) return line;
    }
    return netLines.isEmpty ? null : netLines.first;
  }
}

class CashHomeViewModel extends ChangeNotifier {
  CashHomeViewModel({required CashRepository cashRepo}) : _cash = cashRepo;

  final CashRepository _cash;

  CashHomeState _state = CashHomeState.initial;
  CashHomeState get state => _state;

  Future<void> load() async {
    _state = CashHomeState.initial;
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        _cash.listBoxes(),
        _cash.netCashByCurrency(),
        _cash.journal(limit: 6),
      ]);
      _state = CashHomeState(
        loading: false,
        boxes: results[0]! as List<CashboxWithBalance>,
        netLines: results[1]! as List<CashNetLine>,
        recent: results[2]! as List<CashMovementRow>,
      );
    } catch (error) {
      _state = CashHomeState(
        loading: false,
        boxes: const <CashboxWithBalance>[],
        netLines: const <CashNetLine>[],
        recent: const <CashMovementRow>[],
        error: error,
      );
    }
    notifyListeners();
  }
}
