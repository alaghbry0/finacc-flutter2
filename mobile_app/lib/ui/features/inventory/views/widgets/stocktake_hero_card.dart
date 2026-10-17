/// البطاقة البطلة للجرد — شرح مفهوم تكلفة اللقطة وقفل الأرصدة
/// (HubHeroCard الموحدة — W3/R17-b: سطر المستودع بفتحة underSubtitle
/// داخل عمود النص كما كان).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/hub_hero_card.dart';
import '../../view_models/stocktake_view_model.dart';

class StocktakeHeroCard extends StatelessWidget {
  const StocktakeHeroCard({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StocktakeViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);

    return HubHeroCard(
      icon: Icons.fact_check_rounded,
      title: l10n.stocktakeHeroTitle,
      subtitle: Text(
        l10n.stocktakeHeroSubtitle,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      underSubtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.warehouse_rounded, size: 14, color: colors.gold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  vm.state.warehouseName ?? '',
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
