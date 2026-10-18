/// زر «المزيد» بترقيم قائمة الأصناف (صفحة 50) مع العدد المعروض —
/// مستخرج من items_list_screen (R20-D3b: نقل حرفي بلا أي تغيير سلوكي).
library;

import 'package:flutter/material.dart';

import '../../../../../domain/services/numerals.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/numerals_scope.dart';

/// زر «المزيد» مع العدد المعروض.
class ItemsLoadMoreButton extends StatelessWidget {
  const ItemsLoadMoreButton({
    super.key,
    required this.loading,
    required this.shown,
    required this.onLoadMore,
  });

  final bool loading;
  final int shown;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final arabicIndic = NumeralsScope.of(context);
    final digits = arabicIndic ? Numerals.toArabicIndic('$shown') : '$shown';
    return OutlinedButton.icon(
      onPressed: loading ? null : onLoadMore,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.expand_more_rounded),
      label: Text(
        l10n.itemsListLoadMore(digits),
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }
}
