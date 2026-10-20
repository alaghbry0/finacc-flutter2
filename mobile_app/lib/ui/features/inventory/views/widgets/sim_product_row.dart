/// صف صنف واحد بنمط Simple Invoice Manager (V5) — من النموذج الأولي
/// `screen-products`: أيقونة سلة رمادية مزرقة + الاسم عريضاً + الفئة/
/// الباركود، والطرف المقابل: شارة الجرد (خضراء «جرد ممكن» / تحذيرية
/// عند النفاد) فوق السعر بالوحدة عريضاً. يفتح تفاصيل الصنف.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../domain/models/item.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';

/// شارة الجرد بنمط SIM — خضراء بحد (`#E8F5E9`/`#A5D6A7`/`#2E7D32`).
class SimStockBadge extends StatelessWidget {
  const SimStockBadge({super.key, required this.available});

  /// هل المخزون متوفر (> 0)?
  final bool available;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final bg = available
        ? (isDark
              ? colors.positiveContainer
              : const Color(0xFFE8F5E9))
        : colors.negativeContainer;
    final fg = available
        ? (isDark ? colors.onPositiveContainer : const Color(0xFF2E7D32))
        : colors.onNegativeContainer;
    final border = available
        ? (isDark
              ? colors.positiveContainer
              : const Color(0xFFA5D6A7))
        : colors.negativeContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: border),
      ),
      child: Text(
        available ? l10n.simStockOn : l10n.simStockOut,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}

/// صف منتج بنمط SIM — أبيض بفاصل سفلي 1px.
class SimProductRow extends StatelessWidget {
  const SimProductRow({
    super.key,
    required this.info,
    required this.baseDecimals,
    this.categoryName,
  });

  final ItemStockInfo info;

  /// عدد خانات عملة الأساس.
  final int baseDecimals;

  /// اسم فئة الصنف (من فئات النموذج — اختياري).
  final String? categoryName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final item = info.item;
    final isDark = scheme.brightness == Brightness.dark;
    final isStockable = !item.isService;
    final lowStock = isStockable &&
        (info.totalQty <= 0 || info.totalQty <= item.minStock);

    return InkWell(
      onTap: () => context.go('/inventory/item/${item.id}'),
      child: Container(
        color: scheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        foregroundDecoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? scheme.outlineVariant.withValues(alpha: 0.4)
                  : const Color(0xFFF0F0F0),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                item.isService
                    ? Icons.miscellaneous_services_rounded
                    : Icons.shopping_cart_outlined,
                size: 20,
                color: colors.neutral,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_metaLine().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      _metaLine(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (item.trackBatches) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.itemBatchesBadge,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.neutral,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isStockable) ...[
                  SimStockBadge(available: info.totalQty > 0),
                  const SizedBox(height: 4),
                  // الكمية — حمراء عند قرب النفاد (نفس دلالة القائمة الأصلية).
                  Text(
                    AmountText.formatFor(
                      context,
                      info.totalQty,
                      _qtyDecimals(info.totalQty),
                    ),
                    style: FinText.amountRow(
                      lowStock ? colors.negative : scheme.onSurface,
                    ),
                  ),
                ] else ...[
                  Text(
                    l10n.itemServiceBadge,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.tertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (info.retailPrice != null) ...[
                  const SizedBox(height: 2),
                  AmountText(
                    amount: info.retailPrice!,
                    decimals: baseDecimals,
                  ),
                  Text(
                    l10n.itemsListPriceLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// سطر الميتا — الفئة (إن وُجدت) ثم الباركود.
  String _metaLine() {
    final item = info.item;
    final parts = <String>[];
    if ((categoryName ?? '').isNotEmpty) parts.add(categoryName!);
    if ((item.barcode ?? '').isNotEmpty) parts.add(item.barcode!);
    return parts.join(' · ');
  }

  static int _qtyDecimals(double value) =>
      value == value.truncateToDouble() ? 0 : 2;
}
