/// تنسيقات شاشة «الفئات والوحدات» — مستخرجة من
/// categories_units_screen (R20-D3c: نقل حرفي بلا أي تغيير سلوكي؛
/// الدالة الخاصة صارت علوية بادئة categoriesUnits).
library;

/// نص معامل التحويل (الصحيح بلا كسور عشرية زائدة).
String categoriesUnitsFactorText(double factor) {
  if (factor == factor.truncateToDouble()) {
    return factor.truncate().toString();
  }
  return factor.toString();
}
