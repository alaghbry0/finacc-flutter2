/// هيكل بطاقة الصندوق المشترك (نشطة/مؤرشفة) بإدارة الصناديق — مستخرج
/// حرفياً من `boxes_screen.dart` (R20-D3d؛ كان `_BoxCardShell`).
library;

import 'package:flutter/material.dart';

import '../../../../../domain/models/cash.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';

/// هيكل بطاقة الصندوق المشترك (نشطة/مؤرشفة): الصورة/الاسم/رقاقة
/// الافتراضي/العملة/الرصيد الحي (سالب = تحذير أحمر) + دلاء العملات
/// الأخرى + عنصر ذيل.
class BoxesCardShell extends StatelessWidget {
  const BoxesCardShell({
    super.key,
    required this.box,
    required this.trailing,
    required this.dimmed,
    required this.defaultBadge,
    this.onTap,
    this.busy = false,
  });

  final CashboxWithBalance box;
  final Widget trailing;
  final bool dimmed;
  final bool defaultBadge;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final negative = box.isNegative;
    return Opacity(
      opacity: dimmed ? 0.62 : 1,
      child: FinCard(
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              box.box.name,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (defaultBadge) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                l10n.cashDefaultChip,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: scheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                          ],
                        ],
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
                    AmountText(
                      amount: box.nativeBalance,
                      sign: negative ? FinSign.outgoing : FinSign.neutral,
                    ),
                    if (negative)
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
                  ],
                ),
                const SizedBox(width: 4),
                trailing,
              ],
            ),
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
                      sign: bucket.amount < 0
                          ? FinSign.outgoing
                          : FinSign.neutral,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
