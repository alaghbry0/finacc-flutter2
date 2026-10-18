/// مساعدات تنسيق كمية تقرير حركة صنف (R19-D3a — مستخرجة حرفياً من
/// `item_movement_screen.dart` بلا أي تغيير دلالة).
library;

import '../../../../core/widgets/amount_text.dart';

/// كمية مجردة للعرض (بلا إشارة — أرصدة وافتتاحيات).
String itemMovementQtyPlain(double qty) {
  final decimals = qty == qty.truncateToDouble() ? 0 : 3;
  return AmountText.format(qty.abs(), decimals);
}

/// كمية موقّعة للعرض: إشارة + أرقام غربية بفواصل (صفر منازل للصحيح
/// و٣ للكسري) — داخل LTR دائماً حتى لا تتبدّر في السياق العربي.
String itemMovementQtyText(double qty) =>
    qty < 0 ? '−${itemMovementQtyPlain(qty)}' : '+${itemMovementQtyPlain(qty)}';

/// مقدار صادر للعرض بإشارة السالب (المستودع يعيده موجباً).
String itemMovementQtyOut(double magnitude) =>
    '−${itemMovementQtyPlain(magnitude)}';
