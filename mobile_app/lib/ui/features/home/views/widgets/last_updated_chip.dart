/// شارة «آخر تحديث HH:mm» بأرقام جدولية.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_typography.dart';

class LastUpdatedChip extends StatelessWidget {
  const LastUpdatedChip({super.key, required this.at});

  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 12,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            DateFormat('HH:mm').format(at),
            // وقت حي يتحدث مع كل تحديث — أرقام جدولية حقيقية عبر الخط
            // المرافق (UX-2b): شارة «آخر تحديث» لا ترتجّ عند تغير الدقائق.
            style: FinText.withTabularDigits(
              Theme.of(context).textTheme.labelSmall!.copyWith(
                color: scheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
