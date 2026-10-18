/// موصّل قراءة سجل طرف واحد (عميل/مورد) بمعرّفه — غلاف رقيق فوق
/// مستودعَي العملاء والموردين.
///
/// **التاريخ**: كان هذا الملف جسر SQL صريحاً فوق مقبض القاعدة (دين
/// موثق بطلب صريح من المنسق: «إضافة findById للمستودعين تُلغي هذا
/// الملف») — انتقل الاستعلام إلى `findById` بالمستودعين في R20-D1
/// فصار هذا تفويضاً خالصاً لا SQL فيه إطلاقاً. يبقى الملف لأن نماذج
/// العرض تأخذه معاملاً (ونماذج عرض الاختبارات تبنيه فوق مقبض القاعدة
/// مباشرة بـ[PartyLookup] الافتراضي)؛ أما الشاشات فتبنيه من مستودعات
/// `AppController` حصراً عبر [PartyLookup.fromRepositories].
library;

import 'package:sqflite/sqflite.dart';

import '../../../../data/repositories/customer_repository.dart';
import '../../../../data/repositories/supplier_repository.dart';
import '../../../../domain/models/party.dart';

/// قراءة سجلات الأطراف بالمعرّف.
class PartyLookup {
  /// موصّل فوق مستودعين جاهزين — مسار الشاشات (المستودعات تُؤخذ من
  /// `AppController` حصراً — AGENTS §4-4).
  PartyLookup.fromRepositories(this._customers, this._suppliers);

  /// موصّل يبني المستودعين داخلياً فوق مقبض القاعدة — مسار الاختبارات.
  PartyLookup(Database db)
    : _customers = CustomerRepository(db),
      _suppliers = SupplierRepository(db);

  final CustomerRepository _customers;
  final SupplierRepository _suppliers;

  /// سجل العميل بالمعرّف — أو `null` إن لم يوجد.
  Future<Customer?> customer(int id) => _customers.findById(id);

  /// سجل المورد بالمعرّف — أو `null` إن لم يوجد.
  Future<Supplier?> supplier(int id) => _suppliers.findById(id);
}
