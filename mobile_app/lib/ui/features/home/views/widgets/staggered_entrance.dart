/// دخول متدرج: انزلاق رأسي خفيف + تلاشٍ بتأخير index*90ms.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/fin_tokens.dart';

class StaggeredEntrance extends StatelessWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      // الدخول المتدرج: المدة الموحدة 420ms + تأخير index*90 (UX-2b).
      duration: FinMotion.standard + Duration(milliseconds: index * 90),
      curve: FinMotion.curve,
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - Curves.easeOutCubic.transform(t))),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
