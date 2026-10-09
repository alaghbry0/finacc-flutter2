/// شاشة «الفئات والوحدات» — قسمان: شجرة فئات بمستويين (رئيسية + فرعية)
/// ووحدات بمعامل تحويل، مع حوارات إضافة فورية بأخطاء المستودع العربية.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/item.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/fin_section_title.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/numerals_scope.dart';
import '../view_models/categories_units_view_model.dart';

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
            const ListSkeleton(rows: 6)
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
                  onPressed: () =>
                      unawaited(_openAddCategoryDialog(context, vm, l10n)),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l10n.categoriesAdd),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _CategoriesCard(state: state),
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
                  onPressed: () =>
                      unawaited(_openAddUnitDialog(context, vm, l10n)),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l10n.unitsAdd),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _UnitsCard(state: state),
          ],
        ],
      ),
    );
  }
}

/// بطاقة شجرة الفئات — رئيسية ثم فرعية مسنودة.
class _CategoriesCard extends StatelessWidget {
  const _CategoriesCard({required this.state});

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
              child: StatusBadge(
                label: l10n.categoriesRootBadge,
                color: scheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}

/// شارة نصية صغيرة مصبوغة (رئيسية).
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// بطاقة الوحدات — اسم + شارة معامل التحويل.
class _UnitsCard extends StatelessWidget {
  const _UnitsCard({required this.state});

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
                  StatusBadge(
                    label: l10n.unitFactorTimes(_factorText(unit.factor)),
                    color: FinColors.of(context).gold,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _factorText(double factor) {
    if (factor == factor.truncateToDouble()) {
      return factor.truncate().toString();
    }
    return factor.toString();
  }
}

// ─────────────────────────────────────────────────────────────────────
// حوارات الإضافة
// ─────────────────────────────────────────────────────────────────────

Future<void> _openAddCategoryDialog(
  BuildContext context,
  CategoriesUnitsViewModel vm,
  AppLocalizations l10n,
) async {
  final controller = TextEditingController();
  final roots = vm.state.roots;
  int? parentId;
  var errorText = '';
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(l10n.categoriesAdd),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.categoryNameLabel,
                errorText: errorText.isEmpty ? null : errorText,
              ),
            ),
            if (roots.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                key: ValueKey('cat_parent_$parentId'),
                initialValue: parentId,
                onChanged: (value) => setDialogState(() => parentId = value),
                decoration: InputDecoration(
                  labelText: l10n.categoryParentLabel,
                ),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(l10n.categoryParentNone),
                  ),
                  for (final root in roots)
                    DropdownMenuItem<int?>(
                      value: root.id,
                      child: Text(root.name),
                    ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) {
                setDialogState(() => errorText = l10n.categoryNameLabel);
                return;
              }
              final error = await vm.addCategory(name, parentId: parentId);
              if (!dialogContext.mounted) return;
              if (error != null) {
                setDialogState(() => errorText = error);
                return;
              }
              Navigator.of(dialogContext).pop();
            },
            child: Text(l10n.commonAdd),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
}

Future<void> _openAddUnitDialog(
  BuildContext context,
  CategoriesUnitsViewModel vm,
  AppLocalizations l10n,
) async {
  final nameController = TextEditingController();
  final factorController = TextEditingController(text: '1');
  var errorText = '';
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(l10n.unitsAdd),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.unitNameLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: factorController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.unitFactorLabel,
                hintText: l10n.unitFactorHint,
                errorText: errorText.isEmpty ? null : errorText,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final factor = double.tryParse(factorController.text.trim());
              if (name.isEmpty) {
                setDialogState(() => errorText = l10n.unitNameLabel);
                return;
              }
              if (factor == null || factor <= 0) {
                setDialogState(() => errorText = l10n.unitFactorInvalid);
                return;
              }
              final error = await vm.addUnit(name, factor: factor);
              if (!dialogContext.mounted) return;
              if (error != null) {
                setDialogState(() => errorText = error);
                return;
              }
              Navigator.of(dialogContext).pop();
            },
            child: Text(l10n.commonAdd),
          ),
        ],
      ),
    ),
  );
  nameController.dispose();
  factorController.dispose();
}
