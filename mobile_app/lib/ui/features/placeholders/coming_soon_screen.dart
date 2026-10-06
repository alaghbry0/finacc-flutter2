/// شاشات الوحدات المؤجلة لشرائحها — عناصر ملاحة جاهزة بحالة فراغ واضحة
/// (لا مسودة شاشة بيضاء أبداً — DS-32/DS-25).
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/fin_card.dart';

/// الوحدة الممثلة.
enum ComingFeature { sell, inventory, cash, more }

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.feature});

  final ComingFeature feature;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (title, featureName, icon) = switch (feature) {
      ComingFeature.sell => (
        l10n.tabSell,
        l10n.featureSell,
        Icons.point_of_sale_rounded,
      ),
      ComingFeature.inventory => (
        l10n.tabInventory,
        l10n.featureInventory,
        Icons.inventory_2_rounded,
      ),
      ComingFeature.cash => (
        l10n.tabCash,
        l10n.featureCash,
        Icons.account_balance_rounded,
      ),
      ComingFeature.more => (
        l10n.tabMore,
        l10n.featureMore,
        Icons.grid_view_rounded,
      ),
    };
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          FinCard(
            child: EmptyState(
              icon: icon,
              title: l10n.comingSoonTitle,
              message: l10n.comingSoonBody(featureName),
            ),
          ),
        ],
      ),
    );
  }
}
