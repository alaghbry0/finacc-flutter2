/// بطاقة شجرة الفئات (رئيسية ثم فرعية مسنودة) — مستخرجة من
/// categories_units_screen (R20-D3c: نقل حرفي بلا أي تغيير سلوكي).
library;

import 'package:flutter/material.dart';

import '../../../../../domain/models/item.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/numerals_scope.dart';
import '../../view_models/categories_units_view_model.dart';
import 'categories_units_status_badge.dart';

/// بطاقة شجرة الفئات — رئيسية ثم فرعية مسنودة.
class CategoriesUnitsCategoriesCard extends StatelessWidget {
  const CategoriesUnitsCategoriesCard({super.key, required this.state});

  final CategoriesUnitsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    if (state.categories.isEmpty) {
      return FinCard(
        child: Column(
          children: [
            Icon(
              Icons.category_outlined,
              size: 40,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.categoriesEmptyTitle,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.categoriesEmptyBody,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return FinCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        children: [
          for (final root in state.roots) ...[
            _CategoryRow(
              category: root,
              isChild: false,
              childCount: state.childrenOf(root.id).length,
            ),
            for (final child in state.childrenOf(root.id))
              _CategoryRow(category: child, isChild: true, childCount: 0),
          ],
        ],
      ),
    );
  }
}

/// صف فئة واحدة (رئيسية بشارة / فرعية مسنودة).
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.isChild,
    required this.childCount,
  });

  final ItemCategory category;
  final bool isChild;
  final int childCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final arabicIndic = NumeralsScope.of(context);
    return Padding(
      padding: EdgeInsets.only(
        right: isChild ? 26 : 0,
        top: 6,
        bottom: 6,
        left: 4,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (isChild ? scheme.tertiary : scheme.primary).withValues(
                alpha: 0.12,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isChild
                  ? Icons.subdirectory_arrow_left_rounded
                  : Icons.folder_rounded,
              size: 18,
              color: isChild ? scheme.tertiary : scheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              category.name,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (!isChild && childCount > 0)
            Text(
              l10n.categoriesChildCount(childCount),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: arabicIndic ? FontWeight.w700 : FontWeight.w700,
              ),
            ),
          if (!isChild)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CategoriesUnitsStatusBadge(
                label: l10n.categoriesRootBadge,
                color: scheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}
