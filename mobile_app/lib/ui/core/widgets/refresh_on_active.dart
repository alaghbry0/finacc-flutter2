/// إعادة تحميل عندما يصبح مسار هذه الشاشة هو المسار النشط.
///
/// **المشكلة التي يعالجها**: تبديل التبويبات بين فروع StatefulShellRoute
/// يستعيد فرع القائمة من IndexedStack **بلا rebuild ولا didPopNext**
/// (لا pop يحدث على الإطلاق) — فتظهر بيانات قديمة بعد ترحيل فاتورة في
/// فرع البيع مثلاً (قائمة الأصناف تعرض «المتوفر» القديم).
/// اكتُشف بالتحقق الحي من المتصفح (جولة منهجية المتصفح 2026-10-07).
///
/// يعمل هذا الوسيط على «نشاط المسار»: يراقب تغيّرات الموجّه، ومتى عاد
/// مسار الشاشة (المطابق للنمط) ليكون المسار النشط بعد أن كان مسار آخر
/// نشطاً (تبديل تبويب، أو رجوع من مسار أعمق داخل فرع آخر) — يستدعي
/// [onActivate]. وهو بذلك يغطي حالة didPopNext أيضاً للقوائم.
///
/// الاستخدام:
/// ```dart
/// RefreshOnActive(
///   routePattern: RegExp(r'^/inventory/items$'),
///   onActivate: vm.load,
///   child: const _Body(),
/// )
/// ```
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// يلف جسم شاشة قائمة ويعيد تحميلها كلما عاد مسارها للنشاط.
class RefreshOnActive extends StatefulWidget {
  const RefreshOnActive({
    super.key,
    required this.routePattern,
    required this.onActivate,
    required this.child,
  });

  /// نمط يطابق مسار هذه الشاشة (مثل `^/inventory/items$`).
  final RegExp routePattern;

  /// إعادة تحميل محفوظة للبحث/التصفية الحاليين.
  final FutureOr<void> Function() onActivate;

  final Widget child;

  @override
  State<RefreshOnActive> createState() => _RefreshOnActiveState();
}

class _RefreshOnActiveState extends State<RefreshOnActive> {
  GoRouterDelegate? _delegate;
  bool _active = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final delegate = GoRouter.of(context).routerDelegate;
    if (!identical(_delegate, delegate)) {
      _delegate?.removeListener(_handleRouteChange);
      _delegate = delegate;
      delegate.addListener(_handleRouteChange);
    }
    if (!_initialized) {
      // التحميل الأول تتكفل به الشاشة نفسها (vm.load عند إنشاء النموذج)
      // — لا نطلق إعادة تحميل مزدوجة عند أول بناء.
      _initialized = true;
      _active = _isActive();
    }
  }

  @override
  void dispose() {
    _delegate?.removeListener(_handleRouteChange);
    super.dispose();
  }

  bool _isActive() {
    final uri = _delegate?.currentConfiguration.uri.toString() ?? '';
    return widget.routePattern.hasMatch(uri);
  }

  void _handleRouteChange() {
    final active = _isActive();
    if (active && !_active) {
      // عاد مسارنا للنشاط بعد غيابه: تبديل تبويب أو رجوع من مسار آخر.
      unawaited(Future.sync(widget.onActivate));
    }
    _active = active;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
