/// جسر موحّد فوق مستودعي العملاء والموردين — النماذج والشاشات واحدة
/// لكل نوع الطرف لأن بنية FR-03-03 مرآة حرفية لـ FR-03-01.
///
/// (المستودعان متطابقان تواقيعياً في القراءات؛ هذا الجسر يخفي اختلاف
/// أسماء الإنشاء/الأرشفة فقط ويُزال فور توحيد التوقيعات مستقبلاً.)
library;

import '../../../../data/repositories/customer_repository.dart';
import '../../../../data/repositories/supplier_repository.dart';
import '../../../../domain/core/result.dart';
import '../../../../domain/models/party.dart';

/// عمليات القراءة المشتركة بين العملاء والموردين بواجهة واحدة.
abstract interface class PartyRepoGate {
  /// قائمة الأطراف مع أرصدة كل (طرف × عملة).
  Future<List<PartyBalance>> listWithBalances({
    String? search,
    bool includeArchived = false,
  });

  /// هل للطرف حركات (فواتير/سندات/رصيد افتتاحي غير صفري)؟
  Future<bool> hasMovements(int id);

  /// أرشفة الطرف (تدقيق `customer_archive` / `supplier_archive`).
  Future<Result<void, String>> archive(int id, {required int userId});

  /// رصيد الطرف في عملة واحدة (صيغة FR-03-02 حصراً).
  Future<double> balanceInCurrency(int id, int currencyId);

  /// كشف حساب الطرف بعملة واحدة وفترة اختيارية (FR-03-04).
  Future<StatementResult> statement(
    int id, {
    required int currencyId,
    DateTime? from,
    DateTime? to,
  });

  /// قائمة المستحقات: `receivablesList` للعملاء و`payablesList`
  /// للموردين — مرتّبة بأقدم فاتورة مفتوحة مع أيام التأخير.
  Future<List<PartyBalance>> duesList({DateTime? now});
}

/// بوابة العملاء.
final class CustomerRepoGate implements PartyRepoGate {
  const CustomerRepoGate(this._repo);

  final CustomerRepository _repo;

  @override
  Future<List<PartyBalance>> listWithBalances({
    String? search,
    bool includeArchived = false,
  }) =>
      _repo.listWithBalances(search: search, includeArchived: includeArchived);

  @override
  Future<bool> hasMovements(int id) => _repo.hasMovements(id);

  @override
  Future<Result<void, String>> archive(int id, {required int userId}) =>
      _repo.archiveCustomer(id, userId: userId);

  @override
  Future<double> balanceInCurrency(int id, int currencyId) =>
      _repo.balanceInCurrency(id, currencyId);

  @override
  Future<StatementResult> statement(
    int id, {
    required int currencyId,
    DateTime? from,
    DateTime? to,
  }) => _repo.statement(id, currencyId: currencyId, from: from, to: to);

  @override
  Future<List<PartyBalance>> duesList({DateTime? now}) =>
      _repo.receivablesList(now: now);
}

/// بوابة الموردين.
final class SupplierRepoGate implements PartyRepoGate {
  const SupplierRepoGate(this._repo);

  final SupplierRepository _repo;

  @override
  Future<List<PartyBalance>> listWithBalances({
    String? search,
    bool includeArchived = false,
  }) =>
      _repo.listWithBalances(search: search, includeArchived: includeArchived);

  @override
  Future<bool> hasMovements(int id) => _repo.hasMovements(id);

  @override
  Future<Result<void, String>> archive(int id, {required int userId}) =>
      _repo.archiveSupplier(id, userId: userId);

  @override
  Future<double> balanceInCurrency(int id, int currencyId) =>
      _repo.balanceInCurrency(id, currencyId);

  @override
  Future<StatementResult> statement(
    int id, {
    required int currencyId,
    DateTime? from,
    DateTime? to,
  }) => _repo.statement(id, currencyId: currencyId, from: from, to: to);

  @override
  Future<List<PartyBalance>> duesList({DateTime? now}) =>
      _repo.payablesList(now: now);
}
