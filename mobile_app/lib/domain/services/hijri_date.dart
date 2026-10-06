/// التقويم الهجري (جدولي) — للعرض في الداشبورد (§6.5: «التاريخ هجري/ميلادي»).
///
/// خوارزمية جدولية بحتة تعمل أوفلاين بلا اعتماديات:
/// - عهد هجري جدولي: 1 محرم 1 هـ = JDN 1,948,440 (16 يوليو 622 م، تقويم
///   يولياني — العهد المدني القياسي).
/// - دورة 30 سنة فيها 11 سنة كبيسة (السنوات 2،5،7،10،13،16،18،21،24،26،29
///   من كل دورة) بسنة قمرية 354 يوماً (+1 لذي الحجة في الكبيسة).
/// - الأشهر الفردية 30 يوماً والزوجية 29.
///
/// الدقة: مطابقة لأم القرى في الغالب مع انحراف ±1 يوم في بعض الحدود
/// (طبيعة كل التقويمات الجدولية) — كافية تماماً لعرض التاريخ في تطبيق
/// مالي، وليست لأغراض تعبدية.
///
/// تم التحقق من الزوجين المرجعيين: 2022-07-30 = 1 محرم 1444،
/// و2024-01-01 = 19 جمادى الآخرة 1445.
library;

/// تاريخ هجري (سنة، شهر، يوم).
final class HijriDate {
  const HijriDate({required this.year, required this.month, required this.day});

  final int year;
  final int month;
  final int day;

  /// أسماء الشهور الهجرية.
  static const List<String> monthNames = <String>[
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];

  /// الاسم العربي للشهر.
  String get monthName => monthNames[month - 1];

  @override
  String toString() => '$day ${monthNames[month - 1]} $year هـ';

  @override
  bool operator ==(Object other) =>
      other is HijriDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

/// تحويلات التقويم الهجري الجدولية (نقية، قابلة للاختبار).
class HijriCalendar {
  const HijriCalendar._();

  /// العهد الهجري الجدولي (1 محرم 1 هـ) برقم اليوم اليولياني.
  static const int _epochJdn = 1948440;

  /// طول الدورة: 30 سنة قمرية = 10,631 يوماً.
  static const int _cycleDays = 10631;

  /// مواضع السنوات الكبيسة داخل الدورة (1-based).
  static const Set<int> _leapPositions = <int>{
    2,
    5,
    7,
    10,
    13,
    16,
    18,
    21,
    24,
    26,
    29,
  };

  /// يحوّل تاريخاً ميلادياً إلى هجري (الدلالة: التاريخ فقط بلا وقت).
  static HijriDate fromDateTime(DateTime gregorian) {
    final jd = gregorianToJdn(gregorian.year, gregorian.month, gregorian.day);
    var days = jd - _epochJdn;
    if (days < 0) {
      throw ArgumentError('التاريخ قبل بداية التقويم الهجري');
    }
    // دورات 30 سنة.
    final cycle = days ~/ _cycleDays;
    days -= cycle * _cycleDays;
    // سنوات داخل الدورة (0-based).
    var yearInCycle = 0;
    while (true) {
      final yearLength = _isLeapPosition(yearInCycle + 1) ? 355 : 354;
      if (days < yearLength) break;
      days -= yearLength;
      yearInCycle++;
    }
    // أشهر داخل السنة (days = 0-based يوم داخل السنة).
    var month = 1;
    while (true) {
      final monthLength = _monthLength(month, _isLeapPosition(yearInCycle + 1));
      if (days < monthLength) break;
      days -= monthLength;
      month++;
    }
    return HijriDate(
      year: cycle * 30 + yearInCycle + 1,
      month: month,
      day: days + 1,
    );
  }

  /// يحوّل تاريخاً هجرياً إلى ميلادي (UTC — الدلالة: التاريخ فقط).
  static DateTime toDateTime(HijriDate hijri) {
    var days = (hijri.year - 1) ~/ 30 * _cycleDays;
    final yearInCycle = (hijri.year - 1) % 30;
    for (var pos = 1; pos <= yearInCycle; pos++) {
      days += _isLeapPosition(pos) ? 355 : 354;
    }
    final leap = _isLeapPosition(yearInCycle + 1);
    for (var m = 1; m < hijri.month; m++) {
      days += _monthLength(m, leap);
    }
    days += hijri.day - 1;
    final jd = days + _epochJdn;
    return jdnToGregorian(jd);
  }

  /// اليوم الهجري الحالي (بالتاريخ المحلي للجهاز).
  static HijriDate today() => fromDateTime(DateTime.now());

  /// طول شهر (الأشهر الفردية 30 والزوجية 29؛ ذو الحجة 30 في الكبيسة).
  static int _monthLength(int month, bool leapYear) {
    if (month == 12) return leapYear ? 30 : 29;
    return month.isOdd ? 30 : 29;
  }

  /// هل السنة (بموضعها 1-based داخل الدورة) كبيسة؟
  static bool _isLeapPosition(int position) =>
      _leapPositions.contains(((position - 1) % 30) + 1);

  /// رقم اليوم اليولياني من تاريخ ميلادي (غريغوري) — صيغة Fliegel.
  static int gregorianToJdn(int year, int month, int day) {
    final a = (14 - month) ~/ 12;
    final y = year + 4800 - a;
    final m = month + 12 * a - 3;
    return day +
        (153 * m + 2) ~/ 5 +
        365 * y +
        y ~/ 4 -
        y ~/ 100 +
        y ~/ 400 -
        32045;
  }

  /// تاريخ ميلادي (غريغوري) من رقم اليوم اليولياني — معكوس Fliegel.
  static DateTime jdnToGregorian(int jdn) {
    final a = jdn + 32044;
    final b = (4 * a + 3) ~/ 146097;
    final c = a - (146097 * b) ~/ 4;
    final d = (4 * c + 3) ~/ 1461;
    final e = c - (1461 * d) ~/ 4;
    final m = (5 * e + 2) ~/ 153;
    final day = e - (153 * m + 2) ~/ 5 + 1;
    final month = m + 3 - 12 * (m ~/ 10);
    final year = 100 * b + d - 4800 + m ~/ 10;
    return DateTime.utc(year, month, day);
  }
}
