/// شعار FinAcc — علامة العلامة التجارية (رسم متجهي خالص، بلا صور).
///
/// دائرة زمردية متدرجة + رمز دفتر الحسابات بشرطة أرصدة وقطعة نقد ذهبية.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// العلامة البصرية للتطبيق (الافتتاح/القفل/العناوين).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 96, this.showWordmark = false});

  /// قطر الدائرة.
  final double size;

  /// إظهار الاسم تحت العلامة.
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                FinTheme.seed.withValues(alpha: isDark ? 0.95 : 1),
                Color.lerp(FinTheme.seed, Colors.black, 0.28)!,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: FinTheme.seed.withValues(alpha: isDark ? 0.45 : 0.3),
                blurRadius: size * 0.28,
                offset: Offset(0, size * 0.08),
              ),
            ],
          ),
          child: CustomPaint(
            size: Size.square(size),
            painter: _LedgerPainter(),
          ),
        ),
        if (showWordmark) ...[
          const SizedBox(height: 14),
          Text(
            'FinAcc',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontFamily: FinText.fontFamily,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ],
    );
  }
}

class _LedgerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.width / 96; // معامل القياس من تصميم 96.

    // دفتر مائل بزوايا مستديرة (لوح الحسابات).
    final bookPath = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          Rect.fromCenter(
            center: Offset(cx, cy + 4 * s),
            width: 40 * s,
            height: 50 * s,
          ),
          topLeft: Radius.circular(6 * s),
          topRight: Radius.circular(6 * s),
          bottomLeft: Radius.circular(4 * s),
          bottomRight: Radius.circular(4 * s),
        ),
      );
    final bookPaint = Paint()..color = Colors.white.withValues(alpha: 0.96);
    canvas.drawShadow(bookPath, Colors.black, 6 * s, false);
    canvas.drawPath(bookPath, bookPaint);

    // شرطات أرصدة متدرجة (كشف حساب).
    final linePaint = Paint()
      ..color = FinTheme.seed.withValues(alpha: 0.85)
      ..strokeWidth = 3.2 * s
      ..strokeCap = StrokeCap.round;
    final widths = [26.0, 18.0, 22.0, 12.0];
    for (var i = 0; i < widths.length; i++) {
      final w = widths[i] * s;
      canvas.drawLine(
        Offset(cx - w / 2, cy + (-12 + i * 9.5) * s),
        Offset(cx + w / 2, cy + (-12 + i * 9.5) * s),
        linePaint,
      );
    }

    // قطعة نقد ذهبية أعلى يمين الدفتر.
    final coinCenter = Offset(cx + 15 * s, cy - 18 * s);
    final coinPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE7CB8C), Color(0xFFC79A3E)],
      ).createShader(Rect.fromCircle(center: coinCenter, radius: 11 * s));
    canvas.drawCircle(coinCenter, 11 * s, coinPaint);
    final coinRing = Paint()
      ..color = const Color(0xFF8F6A22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * s;
    canvas.drawCircle(coinCenter, 8.2 * s, coinRing);
    // شطرنج رمز الريال المبسط على القطعة.
    final rialPaint = Paint()
      ..color = const Color(0xFF8F6A22)
      ..strokeWidth = 2.1 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      coinCenter + Offset(-3.4 * s, 3 * s),
      coinCenter + Offset(3.4 * s, -3 * s),
      rialPaint,
    );
    canvas.drawLine(
      coinCenter + Offset(-3.4 * s, -3 * s),
      coinCenter + Offset(3.4 * s, 3 * s),
      rialPaint,
    );
    // لمعة على القطعة.
    final shine = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 2.4 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      coinCenter + Offset(-4.5 * s, -5.5 * s),
      coinCenter + Offset(-1.5 * s, -6.5 * s),
      shine,
    );

    // قوس زخرفي خافت حول العلامة.
    final arcPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * s
      ..strokeCap = StrokeCap.round;
    final arcRect = Rect.fromCircle(center: Offset(cx, cy), radius: 42 * s);
    canvas.drawArc(arcRect, -math.pi * 0.62, math.pi * 0.34, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _LedgerPainter oldDelegate) => false;
}
