/// لوحة إدخال PIN والنقاط — مكونات شاشتي إعداد PIN والقفل (الشريحة 1).
///
/// - أهداف لمس ≥ 48dp (الأزرار الفعلية 72×62 — DS-29).
/// - اهتزاز لمسي عند كل ضغطة (إذن VIBRATE في AndroidManifest).
/// - نقاط الحالة مع اهتزاز بصري عند الخطأ.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// لوحة أرقام PIN (3×4): 1-9، فراغ، 0، مسح.
class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
    this.footer,
  });

  final ValueChanged<int> onDigit;

  final VoidCallback onBackspace;

  /// تعطيل أثناء نافذة الانتظار (FR-12-06).
  final bool enabled;

  /// عنصر اختياري مكان زر الفراغ (مثل زر عبارة المرور).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final keyColor = enabled
        ? scheme.surfaceContainerLow
        : scheme.surfaceContainerLow.withValues(alpha: 0.45);
    final digitStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: enabled
          ? scheme.onSurface
          : scheme.onSurface.withValues(alpha: 0.35),
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    Widget key({required Widget child, required VoidCallback onTap}) {
      return Semantics(
        button: true,
        enabled: enabled,
        child: Material(
          color: keyColor,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: enabled
                ? () {
                    // الاهتزاز لا يحجز الإدخال أبداً (fire-and-forget).
                    unawaited(HapticFeedback.lightImpact());
                    onTap();
                  }
                : null,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(width: 72, height: 62, child: child),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final d in row)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: key(
                      child: Center(child: Text('$d', style: digitStyle)),
                      onTap: () => onDigit(d),
                    ),
                  ),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: key(
                child: Center(child: footer ?? const SizedBox.shrink()),
                onTap: () {},
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: key(
                child: Center(child: Text('0', style: digitStyle)),
                onTap: () => onDigit(0),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: key(
                child: Center(
                  child: Icon(
                    Icons.backspace_outlined,
                    size: 26,
                    color: enabled
                        ? scheme.onSurfaceVariant
                        : scheme.onSurfaceVariant.withValues(alpha: 0.35),
                  ),
                ),
                onTap: onBackspace,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// نقاط إدخال PIN مع حالاتها (فارغ/ممتلئ/خطأ).
class PinDots extends StatefulWidget {
  const PinDots({
    super.key,
    required this.length,
    required this.filled,
    this.error = false,
    this.shakeKey,
  });

  /// الطول المتوقع.
  final int length;

  /// عدد الخانات الممتلئة.
  final int filled;

  /// حالة خطأ (احمرار).
  final bool error;

  /// أي تغيير فيه يطلق اهتزازاً (مفتاح اهتزاز).
  final Object? shakeKey;

  @override
  State<PinDots> createState() => _PinDotsState();
}

class _PinDotsState extends State<PinDots> with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(covariant PinDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shakeKey != oldWidget.shakeKey && widget.error) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final errorColor = Theme.of(context).colorScheme.error;
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final t = _shake.value;
        final dx = _shake.isAnimating
            ? 10 * math.sin(t * math.pi * 6) * (1 - t)
            : 0.0;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.length, (i) {
          final filled = i < widget.filled;
          return Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.error
                  ? errorColor
                  : filled
                  ? scheme.primary
                  : Colors.transparent,
              border: Border.all(
                color: widget.error
                    ? errorColor
                    : filled
                    ? scheme.primary
                    : scheme.outlineVariant,
                width: filled ? 0 : 2,
              ),
            ),
          );
        }),
      ),
    );
  }
}
