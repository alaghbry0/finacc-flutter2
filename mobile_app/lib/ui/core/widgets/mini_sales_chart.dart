/// رسم أعمدة 30 يوماً — CustomPainter خفيف (بلا اعتماديات رسوم خارجية).
///
/// الجزء البصري لبطاقة «مبيعات آخر 30 يوماً» في الداشبورد (FR-09-01):
/// - أعمدة تنمو بحركة ناعمة عند البناء (Tween من 0 إلى القيمة).
/// - خط متوسط متقطع قراءةً سريعة للأداء.
/// - **تفاعل اللمس**: لمس عمود يبرزه ويعرض فقاعة قيمته وتاريخه
///   (يداخل بشري بدل رسم صامت — لمسة Premium).
library;

import 'package:flutter/material.dart';

import '../../../data/repositories/dashboard_repository.dart';
import '../theme/app_colors.dart';

/// بطاقة رسم المبيعات اليومية (30 يوماً).
class MiniSalesChart extends StatefulWidget {
  const MiniSalesChart({super.key, required this.points, this.currency});

  /// 30 نقطة (الأيام الفارغة = 0).
  final List<DailySalesPoint> points;

  /// رمز العملة (اختياري — لفقاعة التفاصيل).
  final String? currency;

  @override
  State<MiniSalesChart> createState() => _MiniSalesChartState();
}

class _MiniSalesChartState extends State<MiniSalesChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _grow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();

  /// فهرس العمود المحدد باللمس (أو null).
  int? _selected;

  @override
  void didUpdateWidget(covariant MiniSalesChart old) {
    super.didUpdateWidget(old);
    if (old.points != widget.points) {
      _grow.forward(from: 0);
      _selected = null;
    }
  }

  @override
  void dispose() {
    _grow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final hasData = widget.points.any((p) => p.total > 0);
    if (!hasData) {
      return SizedBox(
        height: 128,
        child: Center(
          child: Text(
            'ستظهر مبيعاتك هنا بعد أول فاتورة',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // فقاعة تفاصيل اليوم المحدد (تظهر فوق الرسم عند اللمس).
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.bottomCenter,
          child: _selected != null
              ? _SelectionBubble(
                  point: widget.points[_selected!],
                  currency: widget.currency,
                )
              : const SizedBox(height: 6, width: double.infinity),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 128,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => _selectAt(details.localPosition.dx),
            onHorizontalDragUpdate: (details) =>
                _selectAt(details.localPosition.dx),
            child: AnimatedBuilder(
              animation: _grow,
              builder: (context, _) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: _BarsPainter(
                    values: widget.points.map((p) => p.total).toList(),
                    progress: Curves.easeOutCubic.transform(_grow.value),
                    selectedIndex: _selected,
                    barColor: scheme.primary,
                    selectedColor: colors.gold,
                    dimBarColor: scheme.primary.withValues(alpha: 0.28),
                    baseline: colors.divider,
                    averageLineColor: scheme.onSurfaceVariant.withValues(
                      alpha: 0.55,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// يحوّل موضع اللمس الأفقي إلى فهرس عمود (يدعم RTL بإحكام).
  void _selectAt(double dx) {
    final n = widget.points.length;
    if (n == 0) return;
    final w = context.size?.width;
    if (w == null || w <= 0) return;
    // الرسم يُرسم بإحداثيات فيزيائية (LTR) — اللمس نفسه فيزيائي.
    final idx = ((dx / w) * n).floor().clamp(0, n - 1);
    if (_selected != idx) setState(() => _selected = idx);
  }
}

/// فقاعة قيمة اليوم المحدد: التاريخ + المبلغ بأرقام جدولية.
class _SelectionBubble extends StatelessWidget {
  const _SelectionBubble({required this.point, this.currency});

  final DailySalesPoint point;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final label = point.date.length >= 10
        ? '${point.date.substring(5, 7)}/${point.date.substring(8, 10)}'
        : point.date;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.gold.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatAmount(point.total),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (currency != null) ...[
            const SizedBox(width: 4),
            Text(
              currency!,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatAmount(double v) {
    final fixed = v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
    final parts = fixed.split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
    return parts.length == 2 ? '$whole.${parts[1]}' : whole;
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.values,
    required this.progress,
    required this.selectedIndex,
    required this.barColor,
    required this.selectedColor,
    required this.dimBarColor,
    required this.baseline,
    required this.averageLineColor,
  });

  final List<double> values;
  final double progress;
  final int? selectedIndex;
  final Color barColor;
  final Color selectedColor;
  final Color dimBarColor;
  final Color baseline;
  final Color averageLineColor;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 2.5;
    final n = values.length;
    if (n == 0) return;
    final barWidth = (size.width - gap * (n - 1)) / n;
    final max = values.fold<double>(0, (a, b) => a > b ? a : b);
    final usableHeight = size.height - 6;
    final average = values.fold<double>(0, (a, b) => a + b) / n;

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
      final h = max <= 0 ? 0.0 : (v / max) * usableHeight * progress;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * (barWidth + gap), size.height - h, barWidth, h),
        const Radius.circular(2),
      );
      final selected = i == selectedIndex;
      // آخر 7 أيام بوضوح كامل، والأقدم بتدرج خافت (تركيز بصري حديث).
      final paint = Paint()
        ..color = selected
            ? selectedColor
            : i >= n - 7
            ? barColor
            : dimBarColor;
      canvas.drawRRect(rect, paint);
    }

    // خط المتوسط متقطعاً (قراءة سريعة للأداء مقابل الأيام).
    if (max > 0 && average > 0) {
      final avgY = size.height - (average / max) * usableHeight;
      final avgPaint = Paint()
        ..color = averageLineColor
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round;
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, avgY), Offset(x + 5, avgY), avgPaint);
        x += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.progress != progress ||
      oldDelegate.selectedIndex != selectedIndex;
}
