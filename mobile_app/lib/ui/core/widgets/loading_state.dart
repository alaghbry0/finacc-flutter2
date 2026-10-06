/// LoadingState — DS-32: هيكل Skeleton للقوائم والبطاقات والتقارير —
/// **لا شاشة بيضاء أبداً**.
///
/// الوميض: **Shimmer انسيابي** — مسح متدرج قطري يمر فوق الهيكل كل
/// دورة (مظهر Premium متعارف عليه في تطبيقات المالية) بدل النبض الثابت.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// وميض Shimmer — يلف أي عنصر يجعله يلمع بتمرير ضوء قطري دوراني.
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = FinColors.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // موجة المسح: من -1.2 إلى 2.2 لخروج كامل خارج الحدود.
        final t = _controller.value * 3.4 - 1.2;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              stops: [
                0.0,
                (t - 0.18).clamp(0.0, 1.0),
                t.clamp(0.0, 1.0),
                (t + 0.18).clamp(0.0, 1.0),
                1.0,
              ],
              colors: [
                colors.skeletonBase,
                colors.skeletonBase,
                colors.skeletonHighlight,
                colors.skeletonBase,
                colors.skeletonBase,
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.skeletonBase),
        child: widget.child,
      ),
    );
  }
}

/// هيكل عظمي لشبكة بلاطات الداشبورد.
class StatTilesSkeleton extends StatelessWidget {
  const StatTilesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: List.generate(4, (_) {
        return SkeletonPulse(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.transparent,
            ),
          ),
        );
      }),
    );
  }
}

/// هيكل عظمي لقائمة صفوف (ListRow ≥ 64dp — DS-22).
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.rows = 6});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final colors = FinColors.of(context);
    return Column(
      children: List.generate(rows, (_) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SkeletonPulse(
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: colors.skeletonHighlight,
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// هيكل عظمي لبطاقة رسم (30 يوماً) — أعمدة وهمية بنسب متفاوتة.
class ChartSkeleton extends StatelessWidget {
  const ChartSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = FinColors.of(context);
    // 30 عموداً بارتفاعات عشوائية ثابتة (مظهر رسم حقيقي قيد التحميل).
    final heights = List.generate(30, (i) => 18.0 + (i * 37 % 13) * 5.2);
    return SkeletonPulse(
      child: SizedBox(
        height: 120,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final h in heights)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.2),
                  height: h,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(2),
                    ),
                    color: colors.skeletonHighlight,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
