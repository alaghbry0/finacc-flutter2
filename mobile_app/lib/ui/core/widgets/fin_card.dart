/// FinCard — بطاقة التطبيق الفاخرة (16dp + ظل ناعم متعدد الطبقات + حد رفيع).
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// بطاقة موحّدة بظلال ناعمة — قاعدة كل حاويات المحتوى.
class FinCard extends StatelessWidget {
  const FinCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.accent,
  });

  final Widget child;

  final EdgeInsetsGeometry padding;

  final EdgeInsetsGeometry? margin;

  final VoidCallback? onTap;

  /// شريط تمييز علوي (ذهبي للبطاقات المميزة).
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final isDark = scheme.brightness == Brightness.dark;
    final body = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.cardBorder),
        boxShadow: isDark
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF06322C).withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: const Color(0xFF06322C).withValues(alpha: 0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (accent != null) Container(height: 3, color: accent),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: body,
      ),
    );
  }
}

/// ترويسة قسم قياسية.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(4, 0, 4, 10),
  });

  final String title;

  final Widget? trailing;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
