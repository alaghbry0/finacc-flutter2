/// نموذج عرض لوحة المخزن — عدّادات التنبيهات الحية للصفوف الرئيسية
/// (أصناف تحت الحد + دفعات قريبة من الانتهاء) في تحميل واحد.
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/batch_repository.dart';
import '../../../../data/repositories/item_repository.dart';

/// حالة لوحة المخزن.
class InventoryHomeState {
  const InventoryHomeState({
    required this.loading,
    this.lowStockCount,
    this.expiringCount,
    this.error,
  });

  final bool loading;

  /// عدد الأصناف تحت حد إعادة الطلب (null = قيد التحميل).
  final int? lowStockCount;

  /// عدد الدفعات المنتهية أو المنتهية خلال 30 يوماً (null = قيد التحميل).
  final int? expiringCount;

  final Object? error;

  static const InventoryHomeState initial = InventoryHomeState(loading: true);
}

class InventoryHomeViewModel extends ChangeNotifier {
  InventoryHomeViewModel({
    required ItemRepository itemRepo,
    required BatchRepository batchRepo,
  }) : _items = itemRepo,
       _batches = batchRepo;

  final ItemRepository _items;
  final BatchRepository _batches;

  InventoryHomeState _state = InventoryHomeState.initial;
  InventoryHomeState get state => _state;

  /// تحميل العدّادات (استدعاء عند فتح اللوحة أو العودة إليها).
  Future<void> load() async {
    _state = const InventoryHomeState(loading: true);
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        _items.lowStockItems(),
        _batches.expiryAlerts(withinDays: 30),
      ]);
      _state = InventoryHomeState(
        loading: false,
        lowStockCount: (results[0] as List<dynamic>).length,
        expiringCount: (results[1] as List<dynamic>).length,
      );
    } catch (error) {
      _state = InventoryHomeState(loading: false, error: error);
    }
    notifyListeners();
  }
}
