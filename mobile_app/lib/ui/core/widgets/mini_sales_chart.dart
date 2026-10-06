/// رسم أعمدة 30 يوماً — CustomPainter خفيف (بلا اعتماديات رسوم خارجية).
///
/// الجزء البصري لبطاقة «مبيعات آخر 30 يوماً» في الداشبورد (FR-09-01).
library;

import 'package:flutter/material.dart';

import '../../../data/repositories/dashboard_repository.dart';
import '../theme/app_colors.dart';

/// بطاقة رسم المبيعات اليومية (30 يوماً).
class MiniSalesChart extends StatelessWidget {
  const MiniSalesChart({super.key, required this.points});

  /// 30 نقطة (الأيام الفارغة = 0).
  final List<DailySalesPoint> points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final hasData = points.any((p) => p.total > 0);
    return SizedBox(
      height: 128,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (hasData)
            CustomPaint(
              size: Size.infinite,
              painter: _BarsPainter(
                values: points.map((p) => p.total).toList(growable: false),
                barColor: scheme.primary,
                dimBarColor: scheme.primary.withValues(alpha: 0.28),
                baseline: colors.divider,
              ),
            )
          else
            Text(
              'ستظهر مبيعاتك هنا بعد أول فاتورة',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.values,
    required this.barColor,
    required this.dimBarColor,
    required this.baseline,
  });

  final List<double> values;
  final Color barColor;
  final Color dimBarColor;
  final Color baseline;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 2.5;
    final n = values.length;
    final barWidth = (size.width - gap * (n - 1)) / n;
    final max = values.fold<double>(0, (a, b) => a > b ? a : b);
    final usableHeight = size.height - 6;

    // خط الأساس.
    final basePaint = Paint()
      ..color = baseline
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      basePaint,
    );

    for (var i = 0; i < n; i++) {
      final v = values[i];
      if (v <= 0) continue;
      final h = max <= 0 ? 0.0 : (v / max) * usableHeight;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * (barWidth + gap), size.height - h, barWidth, h),
        const Radius.circular(2),
      );
      // آخر 7 أيام بوضوح كامل، والأقدم بتدرج خافت (تركيز بصري حديث).
      final paint = Paint()..color = i >= n - 7 ? barColor : dimBarColor;
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter oldDelegate) =>
      oldDelegate.values != values;
}
