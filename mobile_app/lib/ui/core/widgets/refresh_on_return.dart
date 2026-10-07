/// إعادة تحميل عند عودة الصفحة للظهور — didPopNext.
///
/// **المشكلة التي يعالجها**: الشاشات ذات المسارات الفرعية (نموذج إضافة/
/// تعديل تحتها) يستعيدها go_router من مكدس الصفحات **بلا rebuild** عند
/// رجوع النموذج (maybePop) — فيبقى نموذج العرض القديم ببياته القديمة
/// (خلل «لا عملاء بعد» رغم حفظ العميل — اكتُشف بالتحقق الحي).
///
/// الاستخدام: غلّف جسم الشاشة ومرّر إعادة التحميل:
/// ```dart
/// RefreshOnReturn(onReappear: vm.refresh, child: const _Body())
/// ```
///
/// [routeObserver] يُمرَّر لموجّه go_router (observers) ليصل إشعارات
/// جذر التصفح — انظر buildAppRouter.
library;

import 'dart:async';

import 'package:flutter/material.dart';

/// مراقب المسارات العام — يسجَّل في GoRouter(observers:).
final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();

/// يلف جسم شاشة ويعيد تحميلها عند عودتها للظهور بعد pop لمسار أعلى.
class RefreshOnReturn extends StatefulWidget {
  const RefreshOnReturn({
    super.key,
    required this.onReappear,
    required this.child,
  });

  /// يُستدعى عند didPopNext — إعادة تحميل محفوظة للفلترة/البحث الحاليين.
  final FutureOr<void> Function() onReappear;

  final Widget child;

  @override
  State<RefreshOnReturn> createState() => _RefreshOnReturnState();
}

class _RefreshOnReturnState extends State<RefreshOnReturn> with RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    unawaited(Future.sync(widget.onReappear));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
