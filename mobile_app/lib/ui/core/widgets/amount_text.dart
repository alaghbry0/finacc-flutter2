/// AmountText — DS-18 (§6.3): مبلغ بأرقام جدولية + دلالة العملية + علامة
/// غير لونية إلزامية (إشارة +/−) + فواصل آلاف قياسية.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../domain/services/numerals.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'numerals_scope.dart';

/// حجم عرض المبلغ.
enum AmountSize { display, large, row }

/// عرض مبلغ مالي موحّد عبر التطبيق كله.
class AmountText extends StatelessWidget {
  const AmountText({
    super.key,
    required this.amount,
    this.sign = FinSign.neutral,
    this.size = AmountSize.row,
    this.decimals = 2,
    this.showSignMarker = true,
    this.textAlign,
  });

  /// القيمة (موجبة دائماً — الاتجاه يعبَّر عنه بـ [sign]).
  final double amount;

  /// دلالة العملية (إيجابية/سلبية/محايدة) — §6.1.
  final FinSign sign;

  /// الحجم.
  final AmountSize size;

  /// عدد المنازل العشرية (YER = 0 — قاعدة 5.4-9).
  final int decimals;

  /// إظهار العلامة غير اللونية (+/−) — إلزامي افتراضياً.
  final bool showSignMarker;

  final TextAlign? textAlign;

  static String format(double value, int decimals) {
    final pattern = decimals == 0 ? '#,##0' : '#,##0.${'0' * decimals}';
    // أرقام غربية بفواصل آلاف قياسية (افتراض display.numerals = western).
    return NumberFormat(pattern, 'en_US').format(value);
  }

  /// تنسيق المبلغ بنظام أرقام السياق (`display.numerals`).
  static String formatFor(BuildContext context, double value, int decimals) {
    final formatted = format(value, decimals);
    return NumeralsScope.of(context)
        ? Numerals.toArabicIndic(formatted)
        : formatted;
  }

  @override
  Widget build(BuildContext context) {
    final colors = FinColors.of(context);
    final color = switch (sign) {
      FinSign.incoming => colors.positive,
      FinSign.outgoing => colors.negative,
      FinSign.neutral => Theme.of(context).colorScheme.onSurface,
    };
    final style = switch (size) {
      AmountSize.display => FinText.amountDisplay(color),
      AmountSize.large => FinText.amountLarge(color),
      AmountSize.row => FinText.amountRow(color),
    };
    final marker = switch (sign) {
      FinSign.incoming => showSignMarker ? '+' : '',
      FinSign.outgoing => showSignMarker ? '−' : '',
      FinSign.neutral => '',
    };
    final text = switch (NumeralsScope.of(context)) {
      false => '$marker${format(amount, decimals)}',
      true => '$marker${Numerals.toArabicIndic(format(amount, decimals))}',
    };
    // الأرقام LTR دائماً حتى لا تتبدّر داخل السياق العربي RTL (§6.2).
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(text, style: style, textAlign: textAlign),
    );
  }
}
