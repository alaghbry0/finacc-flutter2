/// مكونات نموذج فاتورة Simple Invoice Manager (V4) — مطابقة للقطة
/// 062621 والمرجع التصميمي `docs/sim-design-reference.md` §3.7:
///
/// - [SimInvoiceTopRow]: رقم INV كبير عريض + التاريخ بأيقونة تقويم (LTR).
/// - [SimAccordionHeader]: ترويسة أكورديون بيضاء (أيقونة رمادية مزرقة +
///   عنوان + مبلغ ملخص LTR + شيفرون يدور).
/// - [SimItemsTotalBar]: شريط «إجمالي عناصر» الأزرق النشط (primary، نص
///   أبيض، أيقونة سلة، نجم إلزامي أحمر، مبلغ حي «(+)»، شيفرون أعلى).
/// - [SimDarkTotalBar]: شريط «مجموع» الداكن (#546E7A = colors.neutral) —
///   نص أبيض عريض 15sp.
/// - [SimAddItemSquareButton]: زر «اضافة عنصر» المربع الأزرق.
/// - [SimBottomActionBar]: شريط الإجراءات السفلي الرباعي (أيقونة فوق
///   تسمية 11sp، فواصل، خلفية #F5F7F8 وحد علوي) — قرار الأزرار عند
///   المستدعي لأنها دلالات نطاق البيع لا مظهر SIM.
///
/// الألوان من توكنات الثيم الدلالية (neutral/primary) فتتبع وضع
/// التباين العالي تلقائياً؛ المبالغ بتنسيق AmountText (أرقام Noto
/// الجدولية — قاعدة DS-18n).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'sell_format.dart';

/// سطر INV العلوي — الرقم كبير عريض (22sp/700) والتاريخ بأيقونة تقويم
/// على الطرف المقابل (LTR للنص الرقمي).
class SimInvoiceTopRow extends StatelessWidget {
  const SimInvoiceTopRow({super.key, required this.invoiceNo, this.dateLabel});

  /// رقم الفاتورة القادم (INV…) — أو عنوان بديل قصير.
  final String invoiceNo;
  final String? dateLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final date = dateLabel ?? sellFormatDate(DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              invoiceNo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
                fontFeatures: FinText.tabularNums,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 15,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                date,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: FinText.tabularNums,
                ),
              ),
              if (dateLabel == null) ...[
                const SizedBox(width: 4),
                Text(
                  l10n.simInvoiceTodayBadge,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// ترويسة أكورديون SIM البيضاء — أيقونة + عنوان + مبلغ حي اختياري +
/// شيفرون يدور مع الطي.
class SimAccordionHeader extends StatelessWidget {
  const SimAccordionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailingAmount,
    this.amountSign = '',
    this.requiredMark = false,
    required this.expanded,
    required this.onToggle,
  });

  final IconData icon;
  final String title;

  /// مبلغ الملخص الحي (LTR) — يُعرض عريضاً بإشارة (+/-) قبله.
  final String? trailingAmount;
  final String amountSign;
  final bool requiredMark;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return Material(
      color: scheme.surface,
      child: InkWell(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: colors.cardBorder),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: colors.neutral),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (requiredMark) ...[
                Text(
                  ' *',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colors.negative,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              if (trailingAmount != null) ...[
                const SizedBox(width: 8),
                Text(
                  '$amountSign$trailingAmount',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: FinText.tabularNums,
                  ),
                ),
              ],
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 22,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// شريط «إجمالي عناصر» الأزرق النشط — رأس قسم البنود بلقطة 062621:
/// خلفية primary، أيقونة سلة يمينًا، العنوان أبيض عريض بنجم أحمر،
/// المبلغ الحي «(+)» أبيض LTR، شيفرون أعلى عند التوسيع.
class SimItemsTotalBar extends StatelessWidget {
  const SimItemsTotalBar({
    super.key,
    required this.label,
    required this.amount,
    this.itemCount,
    required this.expanded,
    required this.onToggle,
  });

  final String label;
  final String amount;

  /// عدد البنود الحي داخل قوسين بجانب العنوان (اختياري).
  final int? itemCount;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary,
      child: InkWell(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.shopping_cart_outlined,
                size: 20,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  itemCount != null && itemCount! > 0
                      ? '$label ($itemCount)'
                      : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                ' *',
                // النجم الإلزامي أبيض فوق الأزرق (النموذج: .blue-active .req-star).
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$amount (+)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontFeatures: FinText.tabularNums,
                ),
              ),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// شريط «مجموع» الداكن — خلفية neutral (#546E7A) ونص أبيض عريض
/// (لقطة 062621: Dark Slate للمجموع بعد الخصومات).
class SimDarkTotalBar extends StatelessWidget {
  const SimDarkTotalBar({super.key, required this.label, required this.amount});

  final String label;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final colors = FinColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      color: colors.neutral,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            amount,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontFeatures: FinText.tabularNums,
            ),
          ),
        ],
      ),
    );
  }
}

/// زر «اضافة عنصر» المربع الأزرق — إيقاع SIM: أيقونة + والتسمية
/// بجانبها، حواف 10dp، ارتفاع 44dp، primary مع أبيض.
class SimAddItemSquareButton extends StatelessWidget {
  const SimAddItemSquareButton({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// زر واحد بشريط الإجراءات السفلي SIM — أيقونة فوق تسمية صغيرة.
class SimBottomActionItem {
  const SimBottomActionItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.enabled = true,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final bool primary;
}

/// شريط الإجراءات السفلي الرباعي (حفظ/عرض/خصم/أكثر) — خلفية سطح
/// فاتحة وحد علوي وفواصل بين الأزرار؛ زر primary (الحفظ) بلون
/// التطبيق وبقية الأزرار محايدة (لقطة 062621 البند G).
class SimBottomActionBar extends StatelessWidget {
  const SimBottomActionBar({super.key, required this.items});

  final List<SimBottomActionItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: colors.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                    Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      color: colors.cardBorder,
                    ),
                Expanded(child: _ActionTile(item: items[i])),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.item});

  final SimBottomActionItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = item.enabled && item.onTap != null;
    final color = !active
        ? scheme.onSurfaceVariant.withValues(alpha: 0.5)
        : item.primary
        ? scheme.primary
        : scheme.onSurfaceVariant;
    return InkWell(
      onTap: active ? item.onTap : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, size: 22, color: color),
          const SizedBox(height: 3),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: item.primary ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
