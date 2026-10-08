/// خطوط الطباعة (الشريحة 7) — تحميل أوجه Almarai مرة واحدة لكل عزل.
///
/// الخطوط من أصول التطبيق المحلية (`assets/fonts/almarai/`) — الطباعة
/// أوفلاين حصراً: لا يجوز أبداً جلب خط من الشبكة هنا (قاعدة SRS §0.3).
library;

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// محمّل خطوط PDF — يُحمَّل مرة واحدة ويُخزَّن ثابتاً على مستوى العزل.
class PrintFonts {
  PrintFonts._();

  static pw.Font? _regular;
  static pw.Font? _bold;
  static pw.Font? _extraBold;

  /// Almarai Regular (نص الجسم والأرقام).
  static pw.Font get regular {
    final font = _regular;
    if (font == null) {
      throw StateError(
        'PrintFonts.load() must be awaited before building a PDF',
      );
    }
    return font;
  }

  /// Almarai Bold (العناوين والإجماليات ورقم السند).
  static pw.Font get bold {
    final font = _bold;
    if (font == null) {
      throw StateError(
        'PrintFonts.load() must be awaited before building a PDF',
      );
    }
    return font;
  }

  /// Almarai ExtraBold (عناوين المستندات الكبيرة — إصلاح UX-audit:
  /// الوجه مصرَّح به في pubspec وموجود في الأصول لكنه كان غير مستغل).
  static pw.Font get extraBold {
    final font = _extraBold;
    if (font == null) {
      throw StateError(
        'PrintFonts.load() must be awaited before building a PDF',
      );
    }
    return font;
  }

  /// هل نجح التحميل من قبل؟ (لإعادة التحميل بعد hot restart).
  static bool get loaded =>
      _regular != null && _bold != null && _extraBold != null;

  /// يحمّل ملفات TTF — **idempotent**: آمن استدعاؤه قبل كل بناء.
  static Future<void> load() async {
    if (loaded) return;
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/almarai/Almarai-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/almarai/Almarai-Bold.ttf'),
    );
    final extraBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/almarai/Almarai-ExtraBold.ttf'),
    );
    _regular = regular;
    _bold = bold;
    _extraBold = extraBold;
  }
}
