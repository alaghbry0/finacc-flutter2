/// تحويل الأرقام بين النظامين الغربي والعربي الشرقي — `display.numerals`.
///
/// western (الافتراضي): `1,234.50` — arabic_indic: `١٬٢٣٤٫٥٠` بفواصل
/// عربية قياسية (U+066C للمئات وU+066B للكسور). التحويل عرضي صرف ولا
/// يمس التخزين (المبالغ تُخزَّن دائماً بأرقام غربية داخل JSON/SQL).
library;

/// أدوات تحويل نصوص الأرقام بين النظامين.
final class Numerals {
  const Numerals._();

  static const _westernToArabic = <String, String>{
    '0': '٠',
    '1': '١',
    '2': '٢',
    '3': '٣',
    '4': '٤',
    '5': '٥',
    '6': '٦',
    '7': '٧',
    '8': '٨',
    '9': '٩',
  };

  static const _arabicToWestern = <String, String>{
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
  };

  /// يحوّل الأرقام الغربية إلى عربية شرقية مع الفواصل القياسية
  /// (`,`→`٬` للمئات و`.`→`٫` للكسور).
  static String toArabicIndic(String input) {
    var out = input.replaceAll(',', '\u066C').replaceAll('.', '\u066B');
    for (final entry in _westernToArabic.entries) {
      out = out.replaceAll(entry.key, entry.value);
    }
    return out;
  }

  /// يحوّل الأرقام العربية الشرقية إلى غربية مع الفواصل الغربية.
  static String toWestern(String input) {
    var out = input.replaceAll('\u066C', ',').replaceAll('\u066B', '.');
    for (final entry in _arabicToWestern.entries) {
      out = out.replaceAll(entry.key, entry.value);
    }
    return out;
  }
}
