/// قراءة سجل طرف واحد (عميل/مورد) بمعرّفه — جسر مؤقت فوق مقبض القاعدة.
///
/// **لماذا هذا الجسر؟** مستودعا العملاء والموردين (ملك موجة البيانات)
/// لا يعرّضان `findById` بعد، وشاشتا النموذج والتفاصيل تحتاجان السجل
/// الكامل (العنوان، حد الائتمان، الملاحظات…) لا الأرصدة وحدها. القراءة
/// هنا SELECT صريح بأعمدة الجدول نفسها ثم `fromRow` الرسمي — بلا أي
/// كتابة. **طلب للمنسّق**: إضافة `findById` للمستودعين يُلغي هذا الملف.
library;

import 'package:sqflite/sqflite.dart';

import '../../../../domain/models/party.dart';

/// قراءة سجلات الأطراف بالمعرّف.
class PartyLookup {
  PartyLookup(this._db);

  final Database _db;

  /// سجل العميل بالمعرّف — أو `null` إن لم يوجد.
  Future<Customer?> customer(int id) async {
    final rows = await _db.query(
      'customer',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Customer.fromRow(rows.first);
  }

  /// سجل المورد بالمعرّف — أو `null` إن لم يوجد.
  Future<Supplier?> supplier(int id) async {
    final rows = await _db.query(
      'supplier',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Supplier.fromRow(rows.first);
  }
}
