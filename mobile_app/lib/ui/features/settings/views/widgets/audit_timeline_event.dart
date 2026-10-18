/// حدث واحد على الخط الزمني.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../domain/models/audit_event.dart';
import '../../../../../domain/services/numerals.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fin_card.dart';

class AuditTimelineEvent extends StatelessWidget {
  const AuditTimelineEvent({
    super.key,
    required this.event,
    required this.arabicIndic,
  });

  final AuditEvent event;
  final bool arabicIndic;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final time = DateFormat('HH:mm').format(event.atLocal);
    final timeText = arabicIndic ? Numerals.toArabicIndic(time) : time;

    final (icon, iconColor, container) = switch (event.category) {
      AuditCategory.setup => (
        Icons.rocket_launch_rounded,
        scheme.primary,
        scheme.primaryContainer,
      ),
      AuditCategory.security => (
        Icons.gpp_maybe_rounded,
        colors.negative,
        colors.negativeContainer,
      ),
      AuditCategory.settings => (
        Icons.tune_rounded,
        colors.warning,
        colors.warningContainer,
      ),
      AuditCategory.other => (
        Icons.event_note_rounded,
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHigh,
      ),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // عمود الخط الزمني: نقطة + خيط واصل.
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 13,
                  height: 13,
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconColor,
                    border: Border.all(color: scheme.surface, width: 2.5),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: scheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: FinCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: container,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, size: 18, color: iconColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _actionLabel(l10n, event.action),
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        timeText,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  if (event.userName != null || event.details != null) ...[
                    const SizedBox(height: 8),
                    if (event.userName != null)
                      Row(
                        children: [
                          Icon(
                            Icons.person_rounded,
                            size: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            event.userName!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    if (event.details != null) ...[
                      if (event.userName != null) const SizedBox(height: 2),
                      Text(
                        event.details!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _actionLabel(AppLocalizations l10n, String action) =>
      switch (action) {
        'app_setup' => l10n.auditActionAppSetup,
        'pin_change' => l10n.auditActionPinChange,
        'pin_lockout_delay' => l10n.auditActionLockoutDelay,
        'pin_lockout_passphrase' => l10n.auditActionLockoutPassphrase,
        'settings_change' => l10n.auditActionSettingsChange,
        _ => l10n.auditActionUnknown(action),
      };
}
