/// بطاقة «للإضافة فقط» — شرح حماية FR-12-04 داخل ملف القاعدة.
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/fin_tokens.dart';
import '../../../../core/widgets/fin_card.dart';

class AuditAppendOnlyCard extends StatelessWidget {
  const AuditAppendOnlyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return FinCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.gold,
                  Color.lerp(colors.gold, Colors.black, 0.3)!,
                ],
              ),
              borderRadius: BorderRadius.circular(FinRadius.control),
            ),
            child: Icon(
              Icons.verified_user_rounded,
              color: scheme.surface,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.auditProtectedTitle,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.warningContainer,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        l10n.auditAppendOnlyBadge,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onWarningContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.auditProtectedBody,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
