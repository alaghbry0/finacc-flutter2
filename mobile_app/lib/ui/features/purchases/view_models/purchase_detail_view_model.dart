/// نموذج تفاصيل فاتورة الشراء — رأس الفاتورة وبنودها بتكلفة الوحدة
/// الفعلية بعد توزيع خصم الرأس (قراءة `PurchaseRepository.purchaseDetail`).
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/purchase_repository.dart';
import '../../../../domain/models/purchase.dart';

class PurchaseDetailState {
  const PurchaseDetailState({required this.loading, this.detail, this.error});

  final bool loading;
  final PurchaseInvoiceDetail? detail;
  final Object? error;

  static const PurchaseDetailState initial = PurchaseDetailState(loading: true);
}

class PurchaseDetailViewModel extends ChangeNotifier {
  PurchaseDetailViewModel({
    required PurchaseRepository purchaseRepo,
    required this.invoiceId,
  }) : _purchases = purchaseRepo;

  final PurchaseRepository _purchases;
  final int invoiceId;

  PurchaseDetailState _state = PurchaseDetailState.initial;
  PurchaseDetailState get state => _state;

  Future<void> load() async {
    _state = PurchaseDetailState.initial;
    notifyListeners();
    try {
      final detail = await _purchases.purchaseDetail(invoiceId);
      _state = PurchaseDetailState(loading: false, detail: detail);
    } catch (error) {
      _state = PurchaseDetailState(loading: false, error: error);
    }
    notifyListeners();
  }
}
