/// شاشة «قائمة المنتجات» — نمط Simple Invoice Manager (V5): استنساخ
/// `screen-products` من النموذج الأولي: ترويسة فرعية (رجوع + بحث مضمّن +
/// قائمة المزيد) + بانر تعليمي + شريط الفئات (ميزتنا — يبقى) + صفوف
/// منتجات SIM (شارة الجرد + الكمية + السعر) + كبسولة «تسجيل صنف».
/// البحث الفوري المؤجَّل والترقيم «المزيد» (صفحة 50) كما كانا.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/fin_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_search_field.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/refresh_on_active.dart';
import '../../../core/widgets/sim_list_widgets.dart';
import '../view_models/item_list_view_model.dart';
import 'widgets/items_category_filter_bar.dart';
import 'widgets/items_load_more_button.dart';
import 'widgets/sim_product_row.dart';

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
  bool _searchVisible = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    final vm = context.read<ItemListViewModel>();
    setState(() => _searchVisible = !_searchVisible);
    if (!_searchVisible) {
      _searchController.clear();
      unawaited(vm.setQuery(''));
    }
  }

  void _showMoreSheet() {
    final l10n = AppLocalizations.of(context)!;
    void go(String location) {
      Navigator.of(context).pop();
      context.go(location);
    }

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.simMoreActionsTitle,
                    style: Theme.of(sheetContext).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const Divider(height: 1),
              SimSheetTile(
                icon: Icons.warehouse_rounded,
                label: l10n.simInventoryHubLink,
                onTap: () => go('/inventory'),
              ),
              SimSheetTile(
                icon: Icons.warning_amber_rounded,
                label: l10n.lowStockTitle,
                onTap: () => go('/inventory/low-stock'),
              ),
              SimSheetTile(
                icon: Icons.layers_rounded,
                label: l10n.simBatchesLink,
                onTap: () => go('/inventory/batches'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpDialog() {
    final l10n = AppLocalizations.of(context)!;
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.simProductsTutorial),
          content: Text(l10n.simProductsHelpSteps),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonDone),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ItemListViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: SimFabPill(
        buttonKey: const Key('items_list_fab'),
        label: l10n.simAddProductFab,
        onTap: () => context.go('/inventory/item-form'),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SimSubHeader(
              titleKey: const Key('sim_products_title'),
              title: l10n.simProductsTitle,
              onBack: () {
                // من المحور: يعود إليه؛ من الدرج مباشرة: للمركز الرئيسي.
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
              actions: [
                SimSubHeaderAction(
                  icon: Icons.search_rounded,
                  tooltip: l10n.itemsListSearchHint,
                  active: _searchVisible,
                  onPressed: _toggleSearch,
                ),
                SimSubHeaderAction(
                  icon: Icons.more_vert_rounded,
                  tooltip: l10n.simMoreActionsTitle,
                  onPressed: _showMoreSheet,
                ),
              ],
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              sizeCurve: Curves.easeOutCubic,
              crossFadeState: _searchVisible
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: FinSearchField(
                  controller: _searchController,
                  onChanged: vm.onQueryChanged,
                  fieldKey: const Key('items_search_field'),
                  hint: l10n.itemsListSearchHint,
                  onCleared: () {
                    _searchController.clear();
                    unawaited(vm.setQuery(''));
                  },
                ),
              ),
              secondChild: const SizedBox(width: double.infinity),
            ),
            SimTutorialBanner(
              text: l10n.simProductsTutorial,
              onTap: _showHelpDialog,
            ),
            if (!state.loading && state.categories.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: ItemsCategoryFilterBar(
                  categories: state.categories,
                  selected: state.categoryId,
                  onSelect: vm.setCategory,
                ),
              ),
            Expanded(child: _buildContent(context, vm)),
          ],
        ),
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
        children: const [ListSkeleton()],
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
    // خريطة معرّف الفئة → اسمها لسطر الميتا بكل صف.
    String? categoryNameOf(int? categoryId) {
      if (categoryId == null) return null;
      for (final category in state.categories) {
        if (category.id == categoryId) return category.name;
      }
      return null;
    }

    return ListView(
      // القائمة الرئيسية تحت FAB.extended — قاع 96 يمنع تراكب الزر
      // على آخر صنف.
      padding: const EdgeInsets.only(bottom: FinSpacing.fabClearance),
      children: [
        for (final info in state.items)
          SimProductRow(
            info: info,
            baseDecimals: state.baseCurrency?.decimals ?? 2,
            categoryName: categoryNameOf(info.item.categoryId),
          ),
        if (state.hasMore)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FinSpacing.xl,
              10,
              FinSpacing.xl,
              0,
            ),
            child: ItemsLoadMoreButton(
              loading: vm.loadingMore,
              shown: state.shownCount,
              onLoadMore: vm.loadMore,
            ),
          ),
      ],
    );
  }
}
