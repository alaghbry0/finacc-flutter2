/// الشريط السفلي الثابت لشاشة السند — خطأ الرفض إن وُجد + زر الترحيل
/// الضخم.
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../view_models/voucher_view_model.dart';

/// الشريط السفلي الثابت — خطأ الرفض إن وُجد + زر الترحيل الضخم.
class VoucherBottomPostBar extends StatelessWidget {
  const VoucherBottomPostBar({
    super.key,
    required this.vm,
    required this.onPost,
  });

  final VoucherViewModel vm;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: colors.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (vm.saveError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: colors.negative,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          vm.saveError!,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: colors.negative,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              FilledButton(
                onPressed: vm.saving ? null : onPost,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  textStyle: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                child: vm.saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : Text(l10n.cashVoucherPost),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
