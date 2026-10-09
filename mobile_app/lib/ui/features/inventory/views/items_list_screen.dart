/// شاشة «الأصناف المتوفرة» (دليل 02/03): بحث فوري مؤجَّل + تصفية بالفئات
/// + بطاقات أصناف (باركود أحادي، كمية ملونة عند قرب النفاد، سعر القاعدة،
/// شارة خدمي/دفعات) + ترقيم «المزيد» (صفحة 50).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/item.dart';
import '../../../../domain/services/numerals.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/fin_tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/numerals_scope.dart';
import '../../../core/widgets/refresh_on_active.dart';
import '../../../core/widgets/status_chip.dart';
import '../view_models/item_list_view_model.dart';
import 'widgets/inventory_widgets.dart';

class ItemsListScreen extends StatelessWidget {
  const ItemsListScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً — عند غيابه تُنشئ الشاشة نموذجها.
  final ItemListViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final ItemListViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = ItemListViewModel(itemRepo: app.items!, companyRepo: app.companies!);
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<ItemListViewModel>.value(
      value: vm,
      // تحديث حي عند تبديل التبويب/الرجوع: ترحيل فاتورة بيع في فرع آخر
      // يغيّر «المتوفر» — والفرع يُستعاد من IndexedStack بلا rebuild
      // (اكتُشف بالتحقق الحي 2026-10-07).
      child: RefreshOnActive(
        routePattern: RegExp(r'^/inventory/items$'),
        onActivate: vm.load,
        child: const _ItemsListBody(),
      ),
    );
  }
}

class _ItemsListBody extends StatefulWidget {
  const _ItemsListBody();

  @override
  State<_ItemsListBody> createState() => _ItemsListBodyState();
}

class _ItemsListBodyState extends State<_ItemsListBody> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ItemListViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    // عنوان فرعي بالعدد الكلي (دقيق، أو «{pageSize}+» عند وجود صفحات).
    final total = state.exactTotal;
    final subtitle = total != null
        ? l10n.itemsListSubtitleCount(total)
        : l10n.itemsListSubtitleApprox(itemsPageSize);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.itemsListTitle),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.itemsListAddTooltip,
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.go('/inventory/item-form'),
          ),
        ],
      ),
      // نمط الإنشاء الموحد للقوائم التشغيلية (UX-2b): FAB.extended
      // كنمط قائمة الأطراف — زر إنشاء بارز دائم أسفل الشاشة.
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('items_list_fab'),
        onPressed: () => context.go('/inventory/item-form'),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.visFixItemsAddFab),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: _SearchField(
              controller: _searchController,
              onChanged: vm.onQueryChanged,
              onCleared: () {
                _searchController.clear();
                unawaited(vm.setQuery(''));
              },
            ),
          ),
          if (!state.loading && state.categories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: _CategoryFilterBar(
                categories: state.categories,
                selected: state.categoryId,
                onSelect: vm.setCategory,
              ),
            ),
          const SizedBox(height: 10),
          Expanded(child: _buildContent(context, vm)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, ItemListViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    if (state.loading) {
      return ListView(
        // حشو القوائم الموحد (UX-2b): رأس 8 وقاع 32 (وقاع 96 للقائمة
        // الرئيسية تحت FAB.extended) — كان رأس 4 شاذاً بين 4/8/16.
        padding: const EdgeInsets.fromLTRB(
          FinSpacing.xl,
          FinSpacing.sm,
          FinSpacing.xl,
          FinSpacing.fabClearance,
        ),
        children: const [ListSkeleton(rows: 6)],
      );
    }
    if (state.error != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          FinSpacing.xl,
          FinSpacing.sm,
          FinSpacing.xl,
          FinSpacing.bottom,
        ),
        children: [
          ErrorState(
            title: l10n.genericErrorTitle,
            message: l10n.dbOpenErrorMessage,
            technicalDetails: state.error.toString(),
            retryLabel: l10n.commonRetry,
            onRetry: vm.load,
            compact: true,
          ),
        ],
      );
    }
    final filtered = state.query.trim().isNotEmpty || state.categoryId != null;
    if (state.items.isEmpty) {
      if (filtered) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            FinSpacing.xl,
            FinSpacing.sm,
            FinSpacing.xl,
            FinSpacing.bottom,
          ),
          children: [
            EmptyState(
              icon: Icons.search_off_rounded,
              title: l10n.itemsListSearchEmptyTitle,
              message: l10n.itemsListSearchEmptyBody,
              compact: true,
            ),
          ],
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          FinSpacing.xl,
          FinSpacing.sm,
          FinSpacing.xl,
          FinSpacing.bottom,
        ),
        children: [
          EmptyState(
            icon: Icons.inventory_2_rounded,
            title: l10n.itemsListEmptyTitle,
            message: l10n.itemsListEmptyBody,
            actionLabel: l10n.itemsListEmptyAction,
            onAction: () => context.go('/inventory/item-form'),
            compact: true,
          ),
        ],
      );
    }
    return ListView(
      // القائمة الرئيسية تحت FAB.extended — قاع 96 يمنع تراكب الزر
      // على آخر صنف (نمط قائمة الأطراف).
      padding: const EdgeInsets.fromLTRB(
        FinSpacing.xl,
        FinSpacing.sm,
        FinSpacing.xl,
        FinSpacing.fabClearance,
      ),
      children: [
        for (final info in state.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ItemCard(
              info: info,
              baseDecimals: state.baseCurrency?.decimals ?? 2,
            ),
          ),
        if (state.hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _LoadMoreButton(
              loading: vm.loadingMore,
              shown: state.shownCount,
              onLoadMore: vm.loadMore,
            ),
          ),
      ],
    );
  }
}

/// حقل البحث — بادئة بحث ولاحقة مسح.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onCleared,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          key: const Key('items_search_field'),
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.itemsListSearchHint,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: onCleared,
                  ),
          ),
        );
      },
    );
  }
}

/// شريط رقائق الفئات (الكل + الفئات) — أفقي متمرر.
class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<ItemCategory> categories;
  final int? selected;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          _CategoryChip(
            label: l10n.itemsListFilterAll,
            selected: selected == null,
            accent: scheme.primary,
            onTap: () => onSelect(null),
          ),
          for (final category in categories) ...[
            const SizedBox(width: 8),
            _CategoryChip(
              label: category.name,
              selected: selected == category.id,
              accent: scheme.primary,
              onTap: () => onSelect(category.id),
            ),
          ],
        ],
      ),
    );
  }
}

/// رقاقة فئة واحدة — حركة اختيار متحركة.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effective = accent ?? scheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Material(
        color: selected
            ? effective.withValues(alpha: 0.14)
            : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: selected
              ? BorderSide(color: effective.withValues(alpha: 0.55), width: 1.4)
              : BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? effective : scheme.onSurface,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// بطاقة صنف واحدة.
class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.info, required this.baseDecimals});

  final ItemStockInfo info;
  final int baseDecimals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final item = info.item;

    final lowStock =
        !item.isService &&
        (info.totalQty <= 0 || info.totalQty <= item.minStock);
    final qtyColor = lowStock ? colors.negative : scheme.onSurface;

    return FinCard(
      onTap: () => context.go('/inventory/item/${item.id}'),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (item.isService ? scheme.tertiary : scheme.primary)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item.isService
                  ? Icons.miscellaneous_services_rounded
                  : Icons.inventory_2_rounded,
              size: 21,
              color: item.isService ? scheme.tertiary : scheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.barcode != null && item.barcode!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  MonoText(
                    item.barcode!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (item.isService)
                      StatusChip(
                        label: l10n.itemServiceBadge,
                        tone: ChipTone.brand,
                        dense: true,
                      ),
                    if (item.trackBatches)
                      StatusChip(
                        label: l10n.itemBatchesBadge,
                        tone: ChipTone.neutral,
                        icon: Icons.layers_rounded,
                        dense: true,
                      ),
                    if (!item.isService && info.totalQty <= 0)
                      StatusChip(
                        label: l10n.itemsListOutOfStockBadge,
                        tone: ChipTone.negative,
                        dense: true,
                      )
                    else if (lowStock && item.minStock > 0)
                      StatusChip(
                        label: l10n.itemsListLowStockBadge,
                        tone: ChipTone.warning,
                        dense: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _TrailingNumbers(
            info: info,
            qtyColor: qtyColor,
            baseDecimals: baseDecimals,
          ),
        ],
      ),
    );
  }
}

/// عمود الأرقام الطرفي — الكمية والسعر بالعملة الأساسية.
class _TrailingNumbers extends StatelessWidget {
  const _TrailingNumbers({
    required this.info,
    required this.qtyColor,
    required this.baseDecimals,
  });

  final ItemStockInfo info;
  final Color qtyColor;
  final int baseDecimals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    if (info.item.isService) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Icon(
            Icons.miscellaneous_services_rounded,
            size: 20,
            color: scheme.tertiary,
          ),
          const SizedBox(height: 2),
          Text(
            l10n.itemServiceBadge,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // الكمية — حمراء عند قرب النفاد/النفاد (نفس كومة نمط AmountText).
        Text(
          AmountText.formatFor(
            context,
            info.totalQty,
            _qtyDecimals(info.totalQty),
          ),
          style: FinText.amountRow(qtyColor),
        ),
        Text(
          l10n.itemsListStockLabel,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (info.retailPrice != null) ...[
          const SizedBox(height: 8),
          AmountText(amount: info.retailPrice!, decimals: baseDecimals),
          Text(
            l10n.itemsListPriceLabel,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: colors.gold, fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );
  }

  static int _qtyDecimals(double value) =>
      value == value.truncateToDouble() ? 0 : 2;
}

/// زر «المزيد» مع العدد المعروض.
class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({
    required this.loading,
    required this.shown,
    required this.onLoadMore,
  });

  final bool loading;
  final int shown;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final arabicIndic = NumeralsScope.of(context);
    final digits = arabicIndic ? Numerals.toArabicIndic('$shown') : '$shown';
    return OutlinedButton.icon(
      onPressed: loading ? null : onLoadMore,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.expand_more_rounded),
      label: Text(
        l10n.itemsListLoadMore(digits),
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }
}
