/// صف أزرار التعديل والأرشفة.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../view_models/item_detail_view_model.dart';

class ItemDetailActionsRow extends StatelessWidget {
  const ItemDetailActionsRow({super.key, required this.state});

  final ItemDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final vm = context.read<ItemDetailViewModel>();
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('item_detail_edit_btn'),
            onPressed: () =>
                context.go('/inventory/item/${state.item!.id}/edit'),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: Text(l10n.itemDetailEditAction),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('item_detail_archive_btn'),
            onPressed: state.archiving
                ? null
                : () => unawaited(_confirmArchive(context, vm, l10n)),
            icon: Icon(Icons.archive_rounded, size: 18, color: colors.negative),
            label: Text(
              l10n.itemDetailArchiveAction,
              style: TextStyle(color: colors.negative),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: BorderSide(color: colors.negative.withValues(alpha: 0.5)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmArchive(
    BuildContext context,
    ItemDetailViewModel vm,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.itemDetailArchiveTitle),
        content: Text(l10n.itemDetailArchiveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.itemDetailArchiveAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await vm.archive();
    if (!ok && context.mounted && vm.state.archiveError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(vm.state.archiveError!)));
      return;
    }
    if (ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.itemDetailArchivedMessage)));
    }
  }
}
