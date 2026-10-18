/// كبسولة رمز العملة الصغيرة لتقرير الأعمار (R19-D3a — مستخرجة حرفياً
/// من `aging_report_screen.dart` بلا أي تغيير دلالة؛ كانت `_CurrencyPill`).
library;

import 'package:flutter/material.dart';

/// كبسولة رمز العملة الصغيرة.
class AgingCurrencyPill extends StatelessWidget {
  const AgingCurrencyPill({super.key, required this.code, this.accent});

  final String code;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: accent?.withValues(alpha: 0.14) ?? scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        code,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
