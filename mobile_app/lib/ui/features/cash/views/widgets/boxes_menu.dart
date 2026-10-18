/// قائمة إجراءات الصندوق النشط (افتراضي/تعديل/أرشفة) بإدارة الصناديق —
/// مستخرجة حرفياً من `boxes_screen.dart` (R20-D3d؛ كانت `_BoxMenu`
/// بطريقتَي `_setDefault` و`_confirmArchive`).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../../domain/models/cash.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../view_models/boxes_view_model.dart';
import 'boxes_notify.dart';

/// قائمة إجراءات الصندوق النشط (افتراضي/تعديل/أرشفة).
class BoxesMenu extends StatelessWidget {
  const BoxesMenu({super.key, required this.box});

  final CashboxWithBalance box;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BoxesViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final busy = vm.state.busyBoxId == box.box.id;
    if (busy) {
      return const SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(strokeWidth: 2.2),
      );
    }
    return PopupMenuButton<String>(
      tooltip: l10n.commonDetails,
      icon: const Icon(Icons.more_vert_rounded),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (action) {
        switch (action) {
          case 'default':
            unawaited(_setDefault(context, vm));
          case 'edit':
            context.go('/cash/box-form/${box.box.id}');
          case 'archive':
            unawaited(_confirmArchive(context, vm));
        }
      },
      itemBuilder: (context) => [
        if (!box.box.isDefault)
          PopupMenuItem(
            value: 'default',
            child: Row(
              children: [
                const Icon(Icons.star_rounded, size: 20),
                const SizedBox(width: 10),
                Text(l10n.cashBoxesSetDefault),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const Icon(Icons.edit_rounded, size: 20),
              const SizedBox(width: 10),
              Text(l10n.cashBoxesEditTooltip),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'archive',
          child: Row(
            children: [
              const Icon(Icons.archive_rounded, size: 20),
              const SizedBox(width: 10),
              Text(l10n.cashBoxesArchiveTooltip),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _setDefault(BuildContext context, BoxesViewModel vm) async {
    final result = await vm.setDefault(box.box.id);
    if (!context.mounted) return;
    if (result.isOk) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.cashBoxesDefaultDone(box.box.name))),
        );
    } else {
      boxesNotifyResult(context, false, result.errorOrNull);
    }
  }

  /// أرشفة بتأكيد — رصيد ≠ 0 يستلزم تأكيداً صريحاً أقوى (FR-04-01).
  Future<void> _confirmArchive(BuildContext context, BoxesViewModel vm) async {
    final l10n = AppLocalizations.of(context)!;
    final nonZero =
        box.nativeBalance.abs() > 0.005 ||
        box.foreignBuckets.any((b) => b.amount.abs() > 0.005);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          nonZero
              ? l10n.cashBoxesArchiveNonZeroTitle(box.box.name)
              : l10n.cashBoxesArchiveTitle(box.box.name),
        ),
        content: Text(
          nonZero
              ? l10n.cashBoxesArchiveNonZeroBody
              : l10n.cashBoxesArchiveBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: nonZero
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              nonZero ? l10n.cashBoxesArchiveForce : l10n.commonConfirm,
            ),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      final result = await vm.archive(box.box.id);
      if (!context.mounted) return;
      boxesNotifyResult(context, result.isOk, result.errorOrNull);
    }
  }
}
