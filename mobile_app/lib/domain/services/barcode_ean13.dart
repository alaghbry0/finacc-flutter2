/// مولّد الباركود EAN-13 الداخلي — FR-01-02.
///
/// نطاق المتجر الداخلي (In-Store): البادئة 200–299 (الرقم الأول «2») —
/// محجوزة للاستخدام الداخلي ولا تتعارض مع ترميز GS العالمي، فيولَّد
/// باركود فريد لكل صنف بلا تسجيل لدى جهة إصدار.
///
/// خوارزمية خانة التحقق (mod-10): أوزان 1،3 متناوبة من اليسار على
/// الأرقام الاثني عشر الأولى، ثم `check = (10 − sum % 10) % 10`.
library;

import 'dart:math';

/// مولّد باركودات EAN-13 بنطاق المتجر (200–299) مع خانة تحقق سليمة.
class Ean13Generator {
  const Ean13Generator();

  /// يولّد باركود EAN-13 داخلياً صالحاً:
  /// - خانة أولى «2» + خانتان عشوائيتان (البادئة 200–299).
  /// - 9 أرقام عشوائية (إجمالي 12 خانة بيانات).
  /// - خانة تحقق mod-10.
  ///
  /// [random] قابل للحقن للاختبارات (بذرة ثابتة ← نتائج قابلة للتكرار).
  String generate({Random? random}) {
    final rnd = random ?? Random();
    final digits = List<int>.generate(12, (_) => rnd.nextInt(10));
    digits[0] = 2; // نطاق المتجر الداخلي 200–299 (FR-01-02).
    final body = digits.join();
    return body + checkDigit(body).toString();
  }

  /// خانة التحقق mod-10 لأول 12 رقماً — أوزان 1،3 متناوبة من اليسار.
  ///
  /// يرمي [ArgumentError] إن لم تكن [first12] اثني عشر رقماً.
  int checkDigit(String first12) {
    if (first12.length != 12) {
      throw ArgumentError('المدخل يجب أن يكون 12 رقماً');
    }
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      final d = first12.codeUnitAt(i) - 0x30;
      if (d < 0 || d > 9) {
        throw ArgumentError('المدخل يحتوي محارف غير رقمية');
      }
      sum += d * (i.isEven ? 1 : 3);
    }
    return (10 - sum % 10) % 10;
  }

  /// تحقق شامل لباركود EAN-13: 13 رقماً + خانة تحقق سليمة.
  static bool isValidEan13(String code) {
    if (code.length != 13) return false;
    for (var i = 0; i < 13; i++) {
      final d = code.codeUnitAt(i) - 0x30;
      if (d < 0 || d > 9) return false;
    }
    const generator = Ean13Generator();
    return code.codeUnitAt(12) - 0x30 ==
        generator.checkDigit(code.substring(0, 12));
  }
}
