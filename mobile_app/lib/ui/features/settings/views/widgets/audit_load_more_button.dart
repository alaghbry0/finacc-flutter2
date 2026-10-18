/// زر «المزيد» مع عدّاد المعروض من الإجمالي.
library;

import 'package:flutter/material.dart';

import '../../../../../domain/services/numerals.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/numerals_scope.dart';

class AuditLoadMoreButton extends StatelessWidget {
  const AuditLoadMoreButton({
    super.key,
    required this.loading,
    required this.shown,
    required this.total,
    required this.onLoadMore,
  });

  final bool loading;
  final int shown;
  final int total;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final arabicIndic = NumeralsScope.of(context);
    String digits(int n) => arabicIndic ? Numerals.toArabicIndic('$n') : '$n';
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
        l10n.auditLoadMore(digits(shown), digits(total)),
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }
}
