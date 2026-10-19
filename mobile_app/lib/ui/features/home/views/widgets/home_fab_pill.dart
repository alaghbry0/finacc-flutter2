/// كبسولة الإجراء العائمة — نمط Simple Invoice Manager (V3):
/// زر ممدود بزاوية حبة الدواء في منتصف أسفل الشاشة («إنشاء فاتورة»)،
/// بظل أزرق ناعم — أهم فعل يومي (§6.4) بصيغة SIM.
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';

/// كبسولة «إنشاء فاتورة» العائمة.
class HomeFabPill extends StatelessWidget {
  const HomeFabPill({super.key, required this.onTap});

  /// يُستدعى عند الضغط (فتح الكاشير).
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Padding(
      // يرفع الكبسولة فوق شريط التنقل السفلي (الهيكل الخمسي).
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(26),
        elevation: isDark ? 4 : 6,
        shadowColor: scheme.primary.withValues(alpha: isDark ? 0.5 : 0.4),
        child: InkWell(
          key: const Key('home_fab_pill'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: 20,
                  color: scheme.onPrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.homeFabNewInvoice,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
