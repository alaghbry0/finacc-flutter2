/// بطاقة صندوق مؤرشف بإدارة الصناديق — مستخرجة حرفياً من
/// `boxes_screen.dart` (R20-D3d؛ كانت `_ArchivedBoxCard`): باهتة +
/// إلغاء الأرشفة والتعديل.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../../domain/models/cash.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../view_models/boxes_view_model.dart';
import 'boxes_card_shell.dart';
import 'boxes_notify.dart';

/// بطاقة صندوق مؤرشف — باهتة + إلغاء الأرشفة والتعديل.
class BoxesArchivedBoxCard extends StatelessWidget {
  const BoxesArchivedBoxCard({super.key, required this.box});

  final CashboxWithBalance box;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BoxesViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final busy = vm.state.busyBoxId == box.box.id;
    return BoxesCardShell(
      box: box,
      dimmed: true,
      busy: busy,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          else ...[
            IconButton(
              tooltip: l10n.cashBoxesUnarchiveTooltip,
              icon: const Icon(Icons.unarchive_rounded, size: 20),
              onPressed: () => unawaited(_unarchive(context, vm, box)),
            ),
            IconButton(
              tooltip: l10n.cashBoxesEditTooltip,
              icon: const Icon(Icons.edit_rounded, size: 20),
              onPressed: () => context.go('/cash/box-form/${box.box.id}'),
            ),
          ],
        ],
      ),
      defaultBadge: box.box.isDefault,
    );
  }

  Future<void> _unarchive(
    BuildContext context,
    BoxesViewModel vm,
    CashboxWithBalance box,
  ) async {
    final result = await vm.unarchive(box.box.id);
    if (!context.mounted) return;
    boxesNotifyResult(context, result.isOk, result.errorOrNull);
  }
}
