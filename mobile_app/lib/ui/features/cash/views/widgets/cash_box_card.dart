/// بطاقة صندوق واحدة (المحور + إدارة الصناديق): الاسم/العملة/الرصيد
/// الحي — **سالب = أحمر مع أيقونة تحذير** (FR-04-06/09) — ودلاء العملات
/// الأخرى إن وصلت للصندوق من حركات مخالفة العملة (فصل العملات 5.4-7).
library;

import 'package:flutter/material.dart';

import '../../../../../domain/models/cash.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';

class CashBoxCard extends StatelessWidget {
  const CashBoxCard({
    super.key,
    required this.box,
    required this.onTap,
    this.trailing,
    this.subtitle,
  });

  final CashboxWithBalance box;

  final VoidCallback onTap;

  /// عنصر ذيل (رقاقة افتراضي/أزرار إدارة).
  final Widget? trailing;

  /// سطر إضافي تحت الرصيد (استخدام إدارة الصناديق).
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final negative = box.isNegative;
    final sign = negative ? FinSign.outgoing : FinSign.neutral;
    return FinCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (negative ? colors.negative : scheme.primary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 22,
                  color: negative ? colors.negative : scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      box.box.name,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      box.box.currencyCode,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.gold,
                        fontWeight: FontWeight.w800,
                        fontFeatures: FinText.tabularNums,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      AmountText(
                        amount: box.nativeBalance,
                        size: AmountSize.row,
                        decimals: 2,
                        sign: sign,
                      ),
                    ],
                  ),
                  if (negative) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 13,
                          color: colors.negative,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.cashNegativeBalance,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colors.negative,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ] else
                    ?subtitle,
                ],
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
          // دلاء عملات أخرى داخل الصندوق — سطر لكل عملة بعملتها.
          for (final bucket in box.foreignBuckets)
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 54),
              child: Row(
                children: [
                  Icon(
                    Icons.currency_exchange_rounded,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      bucket.currencyCode,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(fontFeatures: FinText.tabularNums),
                    ),
                  ),
                  AmountText(
                    amount: bucket.amount,
                    decimals: 2,
                    sign: bucket.amount < 0
                        ? FinSign.outgoing
                        : FinSign.neutral,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
