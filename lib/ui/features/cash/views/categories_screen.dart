/// فئات المصاريف (FR-04-05) — مسار `/cash/categories`: قائمة + إضافة
/// (حوار سريع) + إعادة تسمية + أرشفة بتأكيد («رواتب» محمية نظامياً لا
/// تُؤرشف) + قسم المؤرشفة بإلغاء الأرشفة. الجسم مغلّف بـ RefreshOnActive
/// بنمط `^/cash/categories$` (درس §10).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/cash.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/refresh_on_active.dart';
import '../view_models/categories_view_model.dart';

/// فئات المصاريف (فرع /cash).
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final CategoriesViewModel vm;
    vm = CategoriesViewModel(cashRepo: app.cash!);
    unawaited(vm.load());
    return ChangeNotifierProvider<CategoriesViewModel>.value(
      value: vm,
      // تحديث حي عند تبديل التبويب/الرجوع (درس §10).
      child: RefreshOnActive(
        routePattern: RegExp(r'^/cash/categories$'),
        onActivate: vm.load,
        child: const _CategoriesBody(),
      ),
    );
  }
}

class _CategoriesBody extends StatelessWidget {
  const _CategoriesBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CategoriesViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/cash')),
        title: Text(l10n.cashCategoriesTitle),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => unawaited(_showAddDialog(context, vm)),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.cashCategoriesAdd),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        children: [
          if (state.loading)
            const ListSkeleton(rows: 4)
          else if (state.error != null)
            ErrorState(
              title: l10n.genericErrorTitle,
              message: l10n.dbOpenErrorMessage,
              technicalDetails: state.error.toString(),
              retryLabel: l10n.commonRetry,
              onRetry: vm.load,
              compact: true,
            )
          else if (state.categories.isEmpty && state.archived.isEmpty)
            EmptyState(
              icon: Icons.category_rounded,
              title: l10n.cashCategoriesEmptyTitle,
              message: l10n.cashCategoriesEmptyBody,
              actionLabel: l10n.cashCategoriesAdd,
              onAction: () => unawaited(_showAddDialog(context, vm)),
              compact: true,
            )
          else ...[
            for (final category in state.categories)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CategoryCard(category: category),
              ),
            if (state.archived.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Text(
                  l10n.cashCategoriesArchivedSection,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final category in state.archived)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ArchivedCategoryCard(category: category),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

/// بطاقة فئة نشطة — «رواتب» محمية (قفل + لا أرشفة).
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});

  final ExpenseCategoryInfo category;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CategoriesViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final busy = vm.state.busyId == category.id;

    return FinCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              category.isProtected
                  ? Icons.lock_rounded
                  : Icons.category_rounded,
              size: 19,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              category.name,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (category.isProtected)
            Tooltip(
              message: l10n.cashCategoriesProtectedTooltip,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.cashCategoriesProtected,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onTertiaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 4),
          if (busy)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          else ...[
            if (!category.isProtected)
              IconButton(
                tooltip: l10n.cashCategoriesRename,
                icon: const Icon(Icons.edit_rounded, size: 20),
                onPressed: () =>
                    unawaited(_showRenameDialog(context, vm, category)),
              ),
            if (!category.isProtected)
              IconButton(
                tooltip: l10n.cashCategoriesArchive,
                icon: const Icon(Icons.archive_rounded, size: 20),
                onPressed: () =>
                    unawaited(_confirmArchive(context, vm, category)),
              ),
          ],
        ],
      ),
    );
  }
}

/// بطاقة فئة مؤرشفة — إلغاء الأرشفة + إعادة تسمية.
class _ArchivedCategoryCard extends StatelessWidget {
  const _ArchivedCategoryCard({required this.category});

  final ExpenseCategoryInfo category;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CategoriesViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final busy = vm.state.busyId == category.id;

    return Opacity(
      opacity: 0.62,
      child: FinCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            const SizedBox(
              width: 38,
              height: 38,
              child: Icon(Icons.category_rounded, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                category.name,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (busy)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            else ...[
              IconButton(
                tooltip: l10n.cashCategoriesUnarchive,
                icon: const Icon(Icons.unarchive_rounded, size: 20),
                onPressed: () => unawaited(_unarchive(context, vm, category)),
              ),
              IconButton(
                tooltip: l10n.cashCategoriesRename,
                icon: const Icon(Icons.edit_rounded, size: 20),
                onPressed: () =>
                    unawaited(_showRenameDialog(context, vm, category)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// حوار الاسم (إضافة/إعادة تسمية) — يعيد الاسم أو null.
Future<String?> _showNameDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? initial,
}) async {
  final controller = TextEditingController(text: initial ?? '');
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        decoration: InputDecoration(
          labelText: AppLocalizations.of(dialogContext)!
              .cashCategoriesNameLabel,
          helperText: AppLocalizations.of(dialogContext)!
              .cashCategoriesNameHint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(AppLocalizations.of(dialogContext)!.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

Future<void> _showAddDialog(
  BuildContext context,
  CategoriesViewModel vm,
) async {
  final l10n = AppLocalizations.of(context)!;
  final name = await _showNameDialog(
    context,
    title: l10n.cashCategoriesAdd,
    confirmLabel: l10n.cashCategoriesAddButton,
  );
  if (name == null || name.trim().isEmpty) return;
  final result = await vm.add(name.trim());
  if (!context.mounted) return;
  _notifyResult(context, result.isOk, result.errorOrNull);
}

Future<void> _showRenameDialog(
  BuildContext context,
  CategoriesViewModel vm,
  ExpenseCategoryInfo category,
) async {
  final l10n = AppLocalizations.of(context)!;
  final name = await _showNameDialog(
    context,
    title: l10n.cashCategoriesRenameTitle,
    confirmLabel: l10n.commonConfirm,
    initial: category.name,
  );
  if (name == null || name.trim().isEmpty) return;
  final result = await vm.rename(category.id, name.trim());
  if (!context.mounted) return;
  _notifyResult(context, result.isOk, result.errorOrNull);
}

Future<void> _confirmArchive(
  BuildContext context,
  CategoriesViewModel vm,
  ExpenseCategoryInfo category,
) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.cashCategoriesArchiveTitle(category.name)),
      content: Text(l10n.cashCategoriesArchiveBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.cashCategoriesArchive),
        ),
      ],
    ),
  );
  if (confirmed ?? false) {
    final result = await vm.archive(category.id);
    if (!context.mounted) return;
    _notifyResult(context, result.isOk, result.errorOrNull);
  }
}

Future<void> _unarchive(
  BuildContext context,
  CategoriesViewModel vm,
  ExpenseCategoryInfo category,
) async {
  final result = await vm.unarchive(category.id);
  if (!context.mounted) return;
  _notifyResult(context, result.isOk, result.errorOrNull);
}

/// نجاح = القائمة تتحدث من النموذج؛ فشل = SnackBar برسالة المستودع.
void _notifyResult(BuildContext context, bool ok, String? error) {
  if (ok) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        content: Text(
          error ?? '',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onErrorContainer),
        ),
      ),
    );
}
