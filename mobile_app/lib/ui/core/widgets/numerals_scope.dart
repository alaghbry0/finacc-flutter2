/// NumeralsScope — بث نظام الأرقام (`display.numerals`) لشجرة العرض.
///
/// يُركَّب فوق MaterialApp (من AppController) وتقرأه المكونات العرضية
/// (AmountText وخطوط التواريخ) — غيابه يعني western (الافتراضي الآمن
/// للاختبارات والاستخدام المعزول).
library;

import 'package:flutter/widgets.dart';

/// يبث وضع الأرقام نحو الأسفل.
class NumeralsScope extends InheritedWidget {
  const NumeralsScope({
    super.key,
    required super.child,
    required this.arabicIndic,
  });

  /// true = عربي شرقي (١٢٣)، false = غربي (123).
  final bool arabicIndic;

  /// الوضع الحالي من أقرب جدّ NumeralsScope — western عند غيابه.
  static bool of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<NumeralsScope>();
    return scope?.arabicIndic ?? false;
  }

  @override
  bool updateShouldNotify(NumeralsScope oldWidget) =>
      arabicIndic != oldWidget.arabicIndic;
}
