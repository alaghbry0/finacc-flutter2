/// شاشة «الفئات والوحدات» — قسمان: شجرة فئات بمستويين (رئيسية + فرعية)
/// ووحدات بمعامل تحويل، مع حوارات إضافة فورية بأخطاء المستودع العربية.
///
/// (R20-D3c: البطاقتان والشارة والحوارات والتنسيق في views/widgets/
/// categories_units_* — هذه الشاشة: Scaffold والحرّاس ورؤوس القسمين.)
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_section_title.dart';
import '../../../core/widgets/loading_state.dart';
import '../view_models/categories_units_view_model.dart';
import 'widgets/categories_units_categories_card.dart';
import 'widgets/categories_units_dialogs.dart';
import 'widgets/categories_units_units_card.dart';

class CategoriesUnitsScreen extends StatelessWidget {
  const CategoriesUnitsScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً — عند غيابه تُنشئ الشاشة نموذجها.
  final CategoriesUnitsViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final CategoriesUnitsViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = CategoriesUnitsViewModel(itemRepo: app.items!);
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<CategoriesUnitsViewModel>.value(
      value: vm,
      child: const _CategoriesUnitsBody(),
    );
  }
}

class _CategoriesUnitsBody extends StatelessWidget {
  const _CategoriesUnitsBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CategoriesUnitsViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.categoriesUnitsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (state.loading)
            const ListSkeleton()
          else if (state.error != null)
            ErrorState(
              title: l10n.genericErrorTitle,
              message: l10n.dbOpenErrorMessage,
              technicalDetails: state.error.toString(),
              retryLabel: l10n.commonRetry,
              onRetry: vm.load,
              compact: true,
            )
          else ...[
            // ── قسم الفئات ──
            Row(
              children: [
                Expanded(
                  child: FinSectionTitle(
                    icon: Icons.category_rounded,
                    title: l10n.categoriesSectionTitle,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => unawaited(
                    openCategoriesUnitsAddCategoryDialog(context, vm, l10n),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l10n.categoriesAdd),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CategoriesUnitsCategoriesCard(state: state),
            const SizedBox(height: 18),
            // ── قسم الوحدات ──
            Row(
              children: [
                Expanded(
                  child: FinSectionTitle(
                    icon: Icons.straighten_rounded,
                    title: l10n.unitsSectionTitle,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => unawaited(
                    openCategoriesUnitsAddUnitDialog(context, vm, l10n),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l10n.unitsAdd),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CategoriesUnitsUnitsCard(state: state),
          ],
        ],
      ),
    );
  }
}
