/// شاشة لوحة المخزن — جذر تبويب المخزون (دليل الشاشات 02/01): بطاقة
/// بطل «إدارة المخزن» + قائمة صفوف الإجراءات مع عدّادات تنبيه حية
/// (أصناف تحت الحد + دفعات قريبة من الانتهاء).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../view_models/inventory_home_view_model.dart';
import 'widgets/inventory_widgets.dart';

class InventoryHomeScreen extends StatelessWidget {
  const InventoryHomeScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً — عند غيابه تُنشئ الشاشة نموذجها.
  final InventoryHomeViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final InventoryHomeViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = InventoryHomeViewModel(
        itemRepo: app.items!,
        batchRepo: app.batches!,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<InventoryHomeViewModel>.value(
      value: vm,
      child: const _InventoryHomeBody(),
    );
  }
}

class _InventoryHomeBody extends StatelessWidget {
  const _InventoryHomeBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InventoryHomeViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.tabInventory)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const _HeroCard(),
          const SizedBox(height: 16),
          if (state.loading)
            const ListSkeleton(rows: 5)
          else if (state.error != null)
            ErrorState(
              title: l10n.genericErrorTitle,
              message: l10n.dbOpenErrorMessage,
              technicalDetails: state.error.toString(),
              retryLabel: l10n.commonRetry,
              onRetry: vm.load,
              compact: true,
            )
          else
            const _HubCard(),
        ],
      ),
    );
  }
}

/// البطاقة البطلة — هوية الوحدة مع أيقونة داخل تدرج.
class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return FinCard(
      accent: colors.gold,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary,
                  Color.lerp(scheme.primary, Colors.black, 0.25)!,
                ],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.warehouse_rounded,
              color: scheme.onPrimary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.inventoryHomeHeroTitle,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.inventoryHomeHeroSubtitle,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة قائمة الإجراءات — صفوف بأيقونات مصبوغة وعدّادات حية.
class _HubCard extends StatelessWidget {
  const _HubCard();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InventoryHomeViewModel>();
    final state = vm.state;

    return FinCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        children: [
          _HubRow(
            index: 0,
            icon: Icons.add_box_rounded,
            titleKey: (l10n) => l10n.inventoryHubAddItem,
            subtitleKey: (l10n) => l10n.inventoryHubAddItemDesc,
            color: Theme.of(context).colorScheme.primary,
            badgeCount: null,
            badgeColor: null,
            onTap: () => context.go('/inventory/item-form'),
          ),
          _HubDivider(),
          _HubRow(
            index: 1,
            icon: Icons.inventory_2_rounded,
            titleKey: (l10n) => l10n.inventoryHubItems,
            subtitleKey: (l10n) => l10n.inventoryHubItemsDesc,
            color: Theme.of(context).colorScheme.primary,
            badgeCount: null,
            badgeColor: null,
            onTap: () => context.go('/inventory/items'),
          ),
          _HubDivider(),
          _HubRow(
            index: 2,
            icon: Icons.trending_down_rounded,
            titleKey: (l10n) => l10n.inventoryHubLowStock,
            subtitleKey: (l10n) => l10n.inventoryHubLowStockDesc,
            color: FinColors.of(context).warning,
            badgeCount: state.lowStockCount,
            badgeColor: FinColors.of(context).warning,
            onTap: () => context.go('/inventory/low-stock'),
          ),
          _HubDivider(),
          _HubRow(
            index: 3,
            icon: Icons.schedule_rounded,
            titleKey: (l10n) => l10n.inventoryHubBatches,
            subtitleKey: (l10n) => l10n.inventoryHubBatchesDesc,
            color: FinColors.of(context).negative,
            badgeCount: state.expiringCount,
            badgeColor: FinColors.of(context).negative,
            onTap: () => context.go('/inventory/batches'),
          ),
          _HubDivider(),
          _HubRow(
            index: 4,
            icon: Icons.upload_file_rounded,
            titleKey: (l10n) => l10n.inventoryHubImport,
            subtitleKey: (l10n) => l10n.inventoryHubImportDesc,
            color: FinColors.of(context).gold,
            badgeCount: null,
            badgeColor: null,
            onTap: () => context.go('/inventory/import'),
          ),
          _HubDivider(),
          _HubRow(
            index: 5,
            icon: Icons.category_rounded,
            titleKey: (l10n) => l10n.inventoryHubCategoriesUnits,
            subtitleKey: (l10n) => l10n.inventoryHubCategoriesUnitsDesc,
            color: Theme.of(context).colorScheme.tertiary,
            badgeCount: null,
            badgeColor: null,
            onTap: () => context.go('/inventory/categories-units'),
          ),
        ],
      ),
    );
  }
}

class _HubDivider extends StatelessWidget {
  const _HubDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: Theme.of(context).colorScheme.outlineVariant
          .withValues(alpha: 0.4),
    );
  }
}

/// صف إجراء واحد — أيقونة داخل دائرة مصبوغة + عنوان ووصف + شارة عدّاد
/// + سهم، مع حركة دخول متدرجة (fade+slide بتأخير بحسب الترتيب).
class _HubRow extends StatelessWidget {
  const _HubRow({
    required this.index,
    required this.icon,
    required this.titleKey,
    required this.subtitleKey,
    required this.color,
    required this.badgeCount,
    required this.badgeColor,
    required this.onTap,
  });

  final int index;
  final IconData icon;
  final String Function(AppLocalizations) titleKey;
  final String Function(AppLocalizations) subtitleKey;
  final Color color;
  final int? badgeCount;
  final Color? badgeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    // حركة الدخول: فاصل زمني بحسب الترتيب — بلا مؤقتات (Interval).
    final start = (index * 0.07).clamp(0.0, 0.6);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 12),
            child: child,
          ),
        );
      },
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 21, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleKey(l10n),
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleKey(l10n),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (badgeCount != null && badgeColor != null) ...[
                CountBadge(count: badgeCount!, color: badgeColor!),
                const SizedBox(width: 8),
              ],
              Icon(Icons.chevron_left_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
