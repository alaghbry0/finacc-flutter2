/// شاشات الوحدات المؤجلة لشرائحها — هوية تعريفية غنية لكل وحدة
/// (أيقونة داخل حلقة متدرجة + نقاط خريطة الطريق) بحالة فراغ واضحة
/// (لا مسودة شاشة بيضاء أبداً — DS-32/DS-25).
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/fin_card.dart';

/// الوحدة الممثلة.
enum ComingFeature { sell, inventory, cash, more }

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.feature});

  final ComingFeature feature;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final (title, featureName, icon, highlights) = switch (feature) {
      ComingFeature.sell => (
        l10n.tabSell,
        l10n.featureSell,
        Icons.point_of_sale_rounded,
        <String>[l10n.comingSellH1, l10n.comingSellH2],
      ),
      ComingFeature.inventory => (
        l10n.tabInventory,
        l10n.featureInventory,
        Icons.inventory_2_rounded,
        <String>[l10n.comingInventoryH1, l10n.comingInventoryH2],
      ),
      ComingFeature.cash => (
        l10n.tabCash,
        l10n.featureCash,
        Icons.account_balance_rounded,
        <String>[l10n.comingCashH1, l10n.comingCashH2],
      ),
      ComingFeature.more => (
        l10n.tabMore,
        l10n.featureMore,
        Icons.grid_view_rounded,
        <String>[l10n.comingMoreH1, l10n.comingMoreH2],
      ),
    };
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          // بطاقة تعريف الوحدة: حلقة متدرجة حول الأيقونة + اسم + شرح.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) {
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 16 * (1 - t)),
                  child: child,
                ),
              );
            },
            child: FinCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colors.gold.withValues(alpha: 0.9),
                            Theme.of(context).colorScheme.primary,
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(2.6),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: Icon(
                          icon,
                          size: 36,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      featureName,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.comingSoonBody(featureName),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    // نقاط خريطة الطريق: ما ستفعله الوحدة في شريحتها.
                    for (final h in highlights)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: colors.positiveContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: colors.onPositiveContainer,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                h,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // شارة الحالة: بانتظار اعتماد المرحلة الأولى.
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colors.warningContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_clock_rounded,
                    size: 16,
                    color: colors.onWarningContainer,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.comingGatedBadge,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onWarningContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
