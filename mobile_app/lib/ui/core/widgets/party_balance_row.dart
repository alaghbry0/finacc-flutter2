/// PartyBalanceRow — سطر طرف برصيده بعملته في منتقيات الأطراف
/// (R19-D2: توحيد نسخ `_CustomerRow`/`_SupplierRow`/`_PartyRow` المتطابقة
/// بمنتقيات عميل الكاشير ومورد الشراء وطرف السند — مصدر واحد).
///
/// البطاقة: صورة الحرف الأول + الاسم/الهاتف + المبلغ بإحدى عشريتين
/// ورمز العملة + سطر دلالة الرصيد. **التسمية وألوانها قرار المستدعي**
/// (دلالة «مستحق/دائن» تختلف بين البيع والشراء والسند) فتُمرَّران
/// معاملَين صريحَين.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'amount_text.dart';

/// سطر طرف واحد برصيده بعملته — لمنتقيات الأطراف.
class PartyBalanceRow extends StatelessWidget {
  const PartyBalanceRow({
    super.key,
    required this.name,
    required this.phone,
    required this.balance,
    required this.currencyCode,
    required this.label,
    required this.labelColor,
    required this.currencyColor,
    required this.onTap,
  });

  /// اسم الطرف (يُعرض حرفه الأول في الصورة الدائرية).
  final String name;

  /// هاتف الطرف — يُخفى سطره عند فراغه.
  final String? phone;

  /// الرصيد بعملته (موجب/سالب/صفر — تُعرض القيمة المطلقة).
  final double balance;

  /// رمز عملة الرصيد.
  final String currencyCode;

  /// دلالة الرصيد المترجمة («مستحق لك»/«دائن»/«خالص»…).
  final String label;

  /// لون دلالة الرصيد.
  final Color labelColor;

  /// لون رمز العملة.
  final Color currencyColor;

  /// نقرة السطر.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.cardBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name.trim().isEmpty ? '؟' : name.trim().characters.first,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (phone != null && phone!.isNotEmpty)
                      Text(
                        phone!,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(fontFeatures: FinText.tabularNums),
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      AmountText(
                        amount: balance.abs(),
                        size: AmountSize.row,
                        decimals: 2,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        currencyCode,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: currencyColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: labelColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
