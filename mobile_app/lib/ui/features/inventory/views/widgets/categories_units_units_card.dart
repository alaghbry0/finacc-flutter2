/// بطاقة الوحدات (اسم + شارة معامل التحويل) — مستخرجة من
/// categories_units_screen (R20-D3c: نقل حرفي بلا أي تغيير سلوكي).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/categories_units_view_model.dart';
import 'categories_units_format.dart';
import 'categories_units_status_badge.dart';

/// بطاقة الوحدات — اسم + شارة معامل التحويل.
class CategoriesUnitsUnitsCard extends StatelessWidget {
  const CategoriesUnitsUnitsCard({super.key, required this.state});

  final CategoriesUnitsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    if (state.units.isEmpty) {
      return FinCard(
        child: Column(
          children: [
            Icon(
              Icons.straighten_rounded,
              size: 40,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.unitsEmptyTitle,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.unitsEmptyBody,
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
          for (final unit in state.units)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: FinColors.of(context).gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.straighten_rounded,
                      size: 18,
                      color: FinColors.of(context).gold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      unit.name,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  CategoriesUnitsStatusBadge(
                    label: l10n.unitFactorTimes(
                      categoriesUnitsFactorText(unit.factor),
                    ),
                    color: FinColors.of(context).gold,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
