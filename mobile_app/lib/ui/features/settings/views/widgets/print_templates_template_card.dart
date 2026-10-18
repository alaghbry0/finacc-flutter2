/// بطاقة قالب مصغرة (اسم + وصف + أيقونة وحدّ مزدوج عند الاختيار) —
/// مستخرجة حرفياً من `print_templates_screen.dart` (R20-D3d؛ كانت
/// `_TemplateCard`).
library;

import 'package:flutter/material.dart';

import '../../../printing/templates/invoice_template_engine.dart';

/// بطاقة قالب مصغرة: اسم + وصف + أيقونة، وحدّ مزدوج عند الاختيار.
class PrintTemplatesTemplateCard extends StatelessWidget {
  const PrintTemplatesTemplateCard({
    super.key,
    required this.code,
    required this.name,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final String name;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final descriptor = InvoiceTemplateEngine.templates
        .where((t) => t.code == code)
        .firstOrNull;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? scheme.onPrimaryContainer : scheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                color: selected
                                    ? scheme.onPrimaryContainer
                                    : null,
                              ),
                        ),
                      ),
                      if (selected)
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: scheme.onPrimaryContainer,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: selected
                          ? scheme.onPrimaryContainer.withValues(alpha: 0.85)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  if (descriptor != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      descriptor.paper,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected
                            ? scheme.onPrimaryContainer.withValues(alpha: 0.7)
                            : scheme.outline,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
