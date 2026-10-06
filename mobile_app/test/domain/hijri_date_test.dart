/// اختبارات التقويم الهجري الجدولي — مراسي أم القرى المتحقق منها يدوياً.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/domain/services/hijri_date.dart';

void main() {
  group('HijriCalendar — تحويلات موثقة', () {
    test('مرسى 6 أكتوبر 2026 = 23 ربيع الآخر 1448 (تحقق حي بالمعاينة)', () {
      final hijri = HijriCalendar.fromDateTime(DateTime(2026, 10, 6));
      expect(hijri.year, 1448);
      expect(hijri.month, 4, reason: 'ربيع الآخر هو الشهر الرابع');
      expect(hijri.day, 23);
      expect(hijri.monthName, 'ربيع الآخر');
      expect(hijri.toString(), '23 ربيع الآخر 1448 هـ');
    });

    test('مراسٍ إضافية محسوبة (تقويم جدولي موثق من المرسى الأساسي)', () {
      // 1 محرم 1447.
      final h1447Start = HijriCalendar.fromDateTime(DateTime(2025, 6, 27));
      expect(h1447Start.year, 1447);
      expect(h1447Start.month, 1);
      expect(h1447Start.day, 1);
      // اليوم السابق = آخر ذي الحجة 1446.
      final prev = HijriCalendar.fromDateTime(DateTime(2025, 6, 26));
      expect(prev.month, 12);
      expect(prev.year, 1446);

      // 1 محرم 1448 وعاشوراء 10 محرم 1448.
      final h1448Start = HijriCalendar.fromDateTime(DateTime(2026, 6, 17));
      expect(h1448Start.year, 1448);
      expect(h1448Start.month, 1);
      final ashura = HijriCalendar.fromDateTime(DateTime(2026, 6, 26));
      expect(ashura.month, 1);
      expect(ashura.day, 10);
    });

    test('دورة ذهاب وإياب: ميلادي ← هجري ← ميلادي بنفس اليوم', () {
      for (final g in [
        DateTime(2026, 1, 1),
        DateTime(2026, 6, 15),
        DateTime(2026, 12, 31),
        DateTime(2024, 2, 29), // يوم كبيس
        DateTime(2030, 5, 20),
      ]) {
        final hijri = HijriCalendar.fromDateTime(g);
        final back = HijriCalendar.toDateTime(hijri);
        expect(
          (back.year, back.month, back.day),
          (g.year, g.month, g.day),
          reason: 'فشلت الدورة لـ $g',
        );
      }
    });

    test('أسماء الأشهر الاثنا عشر كاملة', () {
      const expected = [
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
      expect(HijriDate.monthNames, expected);
    });

    test('شهور السنة بين 29 و30 يوماً والأيام ضمن الحدود', () {
      // تحقق بنائي: طول كل شهر في سنة كاملة ضمن [29, 30].
      final start = DateTime(2026, 10, 6);
      var current = HijriCalendar.fromDateTime(start);
      var g = start;
      for (var i = 0; i < 360; i++) {
        g = g.add(const Duration(days: 1));
        final next = HijriCalendar.fromDateTime(g);
        if (next.month != current.month) {
          final length = next.day == 1
              ? (current.day == 30 ? 30 : (current.day == 29 ? 29 : -1))
              : -1;
          expect(
            length,
            isIn([29, 30]),
            reason: 'شهر ${current.monthName} طوله غير صالح ($length)',
          );
          expect(next.day, 1, reason: 'الشهر الجديد يجب أن يبدأ بيوم 1');
        }
        current = next;
      }
    });
  });
}
