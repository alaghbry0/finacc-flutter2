/// طور الإنجاز الاحتياطي للمرتجع (إن أُغلق الإيصال داخل النافذة) — إيصال
/// كبير وزر «مرتجع جديد» (R19-D3c — مستخرج حرفياً من `returns_screen.dart`
/// بلا أي تغيير دلالة).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../view_models/returns_view_model.dart';
import 'posted_return_receipt_card.dart';

/// طور الإنجاز الاحتياطي (إن أُغلق الإيصال داخل النافذة) — إيصال كبير
/// وزر «مرتجع جديد».
class ReturnDoneSection extends StatelessWidget {
  const ReturnDoneSection({super.key, required this.vm, required this.isSale});

  final ReturnFlowVm vm;
  final bool isSale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    final receipt = state.receipt;
    if (receipt == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, size: 48),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: vm.startNewReturn,
              child: Text(l10n.retNewReturn),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        PostedReturnReceiptCard(receipt: receipt),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: vm.startNewReturn,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          icon: const Icon(Icons.post_add_rounded),
          label: Text(l10n.retNewReturn),
        ),
      ],
    );
  }
}
