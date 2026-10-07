/// EmptyState — DS-25: رسمة + جملة + زر إجراء («لا فواتير بعد — أنشئ
/// أول فاتورة»).
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// حالة فراغ موحّدة (بدل الشاشات البيضاء).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  /// أيقونة تمثيلية داخل دائرة زخرفية.
  final IconData icon;

  /// الجملة الرئيسية.
  final String title;

  /// الشرح الثانوي.
  final String message;

  /// نص زر الإجراء (إن وُجد).
  final String? actionLabel;

  final VoidCallback? onAction;

  /// وضع مضغوط داخل بطاقة.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 20 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 64 : 84,
              height: compact ? 64 : 84,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                shape: BoxShape.circle,
                border: Border.all(color: colors.cardBorder, width: 1),
              ),
              child: Icon(
                icon,
                size: compact ? 28 : 36,
                color: scheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: compact ? 12 : 18),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: compact ? 12 : 20),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
