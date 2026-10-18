/// حالة السجل الفارغ (قبل أول حدث أمني).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/fin_card.dart';

class AuditEmptyState extends StatelessWidget {
  const AuditEmptyState({
    super.key,
    required this.eventCount,
    required this.filtered,
    required this.onClearFilter,
  });

  final int eventCount;

  /// فراغ داخل تصنيف مُصفّى (لا السجل كله) — رسالة وإزالة تصفية.
  final bool filtered;
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    if (filtered) {
      return FinCard(
        child: Column(
          children: [
            Icon(
              Icons.filter_alt_off_rounded,
              size: 44,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              l10n.auditFilterEmptyTitle,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.auditFilterEmptyBody,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onClearFilter,
              child: Text(l10n.auditFilterAll),
            ),
          ],
        ),
      );
    }
    return FinCard(
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 44,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.auditEmptyTitle,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.auditEmptyBody,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
