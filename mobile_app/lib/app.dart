/// FinAcc — «المُحاسِب الشخصي» — جذر التطبيق.
///
/// عربية RTL حصراً (§6.1) بمعايرة أرقام غربية، ثيم Material 3 من بذرة
/// المالية بلونَي الوضعين مع وضع ثيم محفوظ (نظام/فاتح/داكن)، وتوجيه
/// تصريحي محروس بأطوار الجلسة.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'ui/core/router/app_router.dart';
import 'ui/core/session/app_controller.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/core/widgets/numerals_scope.dart';

/// الجذر — يستقبل متحكم الجلسة (يُنشأ في main) ويبني الموجّه مرة واحدة.
class FinAccApp extends StatefulWidget {
  const FinAccApp({super.key, required this.controller});

  final AppController controller;

  @override
  State<FinAccApp> createState() => _FinAccAppState();
}

class _FinAccAppState extends State<FinAccApp> with WidgetsBindingObserver {
  late final GoRouter _router = buildAppRouter(widget.controller);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // RTL قسري عالمي (DS-16) — على المنصات الأصلية فقط (قناة أصلية).
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        widget.controller.appHidden();
      case AppLifecycleState.resumed:
        widget.controller.appResumed();
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ListenableBuilder(
      // إعادة بناء الجذر عند تغيّر وضع الثيم (ومرحلة الجلسة).
      listenable: controller,
      builder: (context, _) {
        return ChangeNotifierProvider<AppController>.value(
          value: controller,
          child: MaterialApp.router(
            onGenerateTitle: (context) =>
                '${AppLocalizations.of(context)!.appBrand} — '
                '${AppLocalizations.of(context)!.appTitle}',
            theme: FinTheme.light(),
            darkTheme: FinTheme.dark(),
            // وضع الثيم المحفوظ (نظام/فاتح/داكن) — يتغير فورياً من
            // شاشة الإعدادات ويُقرأ من القاعدة عند كل إقلاع.
            themeMode: switch (controller.themeMode) {
              'light' => ThemeMode.light,
              'dark' => ThemeMode.dark,
              _ => ThemeMode.system,
            },
            debugShowCheckedModeBanner: false,
            // عربية حصراً في V1 (§6.1) — اتجاه RTL تلقائي عبر Locale.
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: _router,
            builder: (context, child) {
              // تجديد نشاط الجلسة عند أي لمس (القفل التلقائي — FR-12-05).
              return NumeralsScope(
                // نظام الأرقام (`display.numerals`) — يبثّ لكل المبالغ
                // والتواريخ وينعكس فور التبديل من شاشة الإعدادات.
                arabicIndic: controller.arabicIndicNumerals,
                child: Listener(
                  onPointerDown: (_) => widget.controller.touch(),
                  child: child,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
