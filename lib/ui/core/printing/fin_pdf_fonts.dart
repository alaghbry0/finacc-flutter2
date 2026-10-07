/// خطوط ومنسّقات PDF المشتركة — الشريحة 7 (FR-10-01/02/05).
///
/// عائلة المراعي (Almarai) تدعم تشكيل العربية داخل حزمة `pdf`
/// (تُحمَّل من الأصول المحلية — أوفلاين أولاً)، وتُخزَّن في كاش ثابت
/// حتى لا تُعاد قراءة ملفات الخطوط مع كل مستند.
///
/// المنسّقات هنا (أرقام غربية بفواصل آلاف) تتبع قاعدة §6.2/DS-18:
/// مبالغ المستندات المطبوعة بأرقام غربية دائماً حتى لا تتبدّر داخل
/// الترويسة العربية — انظر `AmountText.format` في واجهات التطبيق.
library;

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

/// خطوط PDF لعائلة المراعي (Regular/Bold/ExtraBold).
class FinPdfFonts {
  FinPdfFonts._({
    required this.regular,
    required this.bold,
    required this.extraBold,
  });

  /// الوزن العادي (400).
  final pw.Font regular;

  /// الوزن الثقيل (700) — يُستخدم عبر `fontWeight: bold` تلقائياً
  /// مع ثيم `theme()`.
  final pw.Font bold;

  /// الوزن الثقيل جداً (800) — للعناوين البطلة (اسم المنشأة/المبلغ).
  final pw.Font extraBold;

  /// كاش ثابت للجلسة (تحميل الخطوط عملية I/O لا تُكرَّر).
  static FinPdfFonts? _cache;

  /// يحمّل الأوزان الثلاثة مرة واحدة ويعيد النسخة المخزنة بعدها.
  static Future<FinPdfFonts> load() async {
    final cached = _cache;
    if (cached != null) {
      return cached;
    }
    final fonts = FinPdfFonts._(
      regular: pw.Font.ttf(
        await rootBundle.load('assets/fonts/almarai/Almarai-Regular.ttf'),
      ),
      bold: pw.Font.ttf(
        await rootBundle.load('assets/fonts/almarai/Almarai-Bold.ttf'),
      ),
      extraBold: pw.Font.ttf(
        await rootBundle.load('assets/fonts/almarai/Almarai-ExtraBold.ttf'),
      ),
    );
    _cache = fonts;
    return fonts;
  }

  /// ثيم المستند: العادي أساساً والثقيل للـ bold (الوزن 800 يُطلب صراحة
  /// بحقل `font` في `TextStyle`).
  pw.ThemeData theme() => pw.ThemeData.withFont(base: regular, bold: bold);
}

/// مبلغ بنقطتين عشريتين وأرقام غربية بفواصل آلاف (قاعدة 5.4-9 للعرض).
String pdfMoney(double value) =>
    NumberFormat('#,##0.00', 'en_US').format(value);

/// كمية نظيفة: بلا منازل عشرية زائدة (2 → «2»، 2.5 → «2.5»).
String pdfQty(double value) => NumberFormat('#,##0.###', 'en_US').format(value);

/// سعر صرف بأربع منازل (نفس عرف شاشات التفاصيل).
String pdfRate(double value) =>
    NumberFormat('#,##0.0000', 'en_US').format(value);

/// تاريخ `dd/MM/yyyy`.
String pdfDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year}';

/// تاريخ ووقت `dd/MM/yyyy HH:mm` (24 ساعة — للمستندات المطبوعة).
String pdfDateTime(DateTime date) =>
    '${pdfDate(date)} '
    '${date.hour.toString().padLeft(2, '0')}:'
    '${date.minute.toString().padLeft(2, '0')}';
