/// مساعدات تنسيق ثابتة الأرقام الغربية — تاريخ «يوم/شهر/سنة» وكميات
/// مجدولة بفواصل آلاف.
///
/// هذه ليست سياقية مثل `FinDateText`/`AmountText.formatFor` (التي تتبع
/// `display.numerals` الحي) — بل صيغ ثابتة الأرقام الغربية استُخرجت من
/// `sell_format` (R20-D1) لأن بيت الطباعة الموحد
/// (`features/printing/docs/invoice_print_doc_builder.dart`) يحتاجها ولا
/// يستورد ميزة بيع إطلاقاً؛ `sell_format` يصدّر هذا الملف فبقي كل
/// مستهلك تاريخي يعمل بلا أي تعديل. الأسماء تحتفظ ببادئة `sell`
/// التاريخية حفاظاً على صفر تغيير بالمستدعين.
library;

import 'amount_text.dart';

/// ينسّق تاريخاً للعرض `يوم/شهر/سنة` بأرقام جدولية بسيطة.
String sellFormatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year}';

/// نص كمية معروض بأرقام جدولية (المتاح: N).
String sellQtyText(double qty) =>
    AmountText.format(qty, qty == qty.truncateToDouble() ? 0 : 3);
