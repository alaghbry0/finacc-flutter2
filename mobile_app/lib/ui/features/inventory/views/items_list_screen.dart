/// شاشة «الأصناف المتوفرة» (دليل 02/03): بحث فوري مؤجَّل + تصفية بالفئات
/// + بطاقات أصناف (باركود أحادي، كمية ملونة عند قرب النفاد، سعر القاعدة،
/// شارة خدمي/دفعات) + ترقيم «المزيد» (صفحة 50).
/// شريط الفئات وبطاقة الصنف وزر «المزيد» بملفاتها المركزّة بجوارها
/// (R20-D3b) — هذا الملف: الحرّاس (تحميل ← خطأ ← لا نتائج ← القائمة).
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
import '../view_models/item_list_view_model.dart';
import 'widgets/items_category_filter_bar.dart';
import 'widgets/items_list_card.dart';
import 'widgets/items_load_more_button.dart';

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
        // A7/R17-b (تدقيق R16): حُذفت أيقونة إضافة AppBar — FAB.extended
        // الموحد + Empty هما نمط الإنشاء (ثلاثة أزرار بنفس الوظيفة كانت
        // تكراراً محلياً بشاشة واحدة).
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
          if (!state.loading && state.categories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: ItemsCategoryFilterBar(
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
            child: ItemsListCard(
              info: info,
              baseDecimals: state.baseCurrency?.decimals ?? 2,
            ),
          ),
        if (state.hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 2),
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
