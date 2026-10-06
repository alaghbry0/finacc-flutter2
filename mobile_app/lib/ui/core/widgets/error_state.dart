/// ErrorState — DS-33: أيقونة + «ماذا حدث» بكلمات المستخدم + زر إعادة
/// المحاولة + تفاصيل تقنية قابلة للتوسيع.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// حالة خطأ موحّدة (فشل فتح القاعدة/الحفظ/الطباعة...).
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.title,
    required this.message,
    this.technicalDetails,
    this.retryLabel,
    this.onRetry,
    this.compact = false,
  });

  /// «ماذا حدث» — بكلمات المستخدم.
  final String title;

  /// ما الحل — خطوة عملية.
  final String message;

  /// تفاصيل تقنية (قابلة للتوسيع).
  final String? technicalDetails;

  final String? retryLabel;

  final VoidCallback? onRetry;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 56 : 76,
              height: compact ? 56 : 76,
              decoration: BoxDecoration(
                color: colors.negativeContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: compact ? 26 : 34,
                color: colors.onNegativeContainer,
              ),
            ),
            SizedBox(height: compact ? 10 : 16),
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
            if (onRetry != null) ...[
              SizedBox(height: compact ? 10 : 18),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: Text(retryLabel ?? 'إعادة المحاولة'),
              ),
            ],
            if (technicalDetails != null) ...[
              const SizedBox(height: 8),
              _TechnicalDetails(details: technicalDetails!),
            ],
          ],
        ),
      ),
    );
  }
}

class _TechnicalDetails extends StatefulWidget {
  const _TechnicalDetails({required this.details});

  final String details;

  @override
  State<_TechnicalDetails> createState() => _TechnicalDetailsState();
}

class _TechnicalDetailsState extends State<_TechnicalDetails> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: () => setState(() => _expanded = !_expanded),
          icon: Icon(
            _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            size: 18,
          ),
          label: Text(
            _expanded ? 'إخفاء التفاصيل التقنية' : 'التفاصيل التقنية',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          style: TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
        ),
        if (_expanded)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.details,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontFamily: 'monospace', fontSize: 11),
              textDirection: TextDirection.ltr,
            ),
          ),
      ],
    );
  }
}
