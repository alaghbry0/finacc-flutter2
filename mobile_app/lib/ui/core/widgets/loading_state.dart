/// LoadingState — DS-32: هيكل Skeleton للقوائم والبطاقات والتقارير —
/// **لا شاشة بيضاء أبداً**.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// وميض الهيكل العظمي.
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
    duration: const Duration(milliseconds: 1300),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = FinColors.of(context);
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.55,
        end: 1,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
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

/// هيكل عظمي لبطاقة رسم (30 يوماً).
class ChartSkeleton extends StatelessWidget {
  const ChartSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.transparent,
        ),
      ),
    );
  }
}
