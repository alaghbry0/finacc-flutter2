/// حارس «التغييرات غير المحفوظة» — نمط حماية موحد للنماذج الطويلة (P1-4).
///
/// كانت شاشة الاستعادة الشاشة الوحيدة المحمية من مغادرة عرضية تضيع
/// إدخال المستخدم؛ الآن يلف النموذج بهذا الحارس فيمنع الرجوع المباشر
/// (`PopScope.canPop = !dirty`) ويعرض حوار «هناك تغييرات غير محفوظة —
/// مغادرة/بقاء». القرار الصريح من المستخدم يفتح الباب مرة واحدة (لا
/// حلقة حوار).
///
/// للتنقل البرمجي الصريح (زر رجوع بنمط `context.go`) يستخدم المتصل
/// [confirmDiscardChanges] قبل مغادرته.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// حوار التأكيد الموحد — true = مغادرة دون حفظ.
Future<bool> confirmDiscardChanges(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final leave = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.appFixUnsavedTitle),
      content: Text(l10n.appFixUnsavedBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.appFixUnsavedStay),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.appFixUnsavedLeave),
        ),
      ],
    ),
  );
  return leave == true;
}

/// يمنع الرجوع المباشر عن نموذج فيه تغييرات غير محفوظة حتى يؤكد
/// المستخدم المغادرة صراحةً.
class DirtyFormGuard extends StatefulWidget {
  const DirtyFormGuard({super.key, required this.isDirty, required this.child});

  /// هل في النموذج تغييرات غير محفوظة؟ (يحسبها المتصل بمقارنة الحالة
  /// بلقطة ما بعد التحميل).
  final bool isDirty;

  final Widget child;

  @override
  State<DirtyFormGuard> createState() => _DirtyFormGuardState();
}

class _DirtyFormGuardState extends State<DirtyFormGuard> {
  /// فتح صريح بعد تأكيد المستخدم — الرجوع التالي يمر بلا حوار.
  bool _leaveConfirmed = false;

  @override
  Widget build(BuildContext context) {
    final blocked = widget.isDirty && !_leaveConfirmed;
    return PopScope(
      canPop: !blocked,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_askAndLeave());
      },
      child: widget.child,
    );
  }

  Future<void> _askAndLeave() async {
    final leave = await confirmDiscardChanges(context);
    if (!leave || !mounted) return;
    // فتح الباب مرة واحدة ثم الرجوع — يجب أن يلتقط PopScope المُعاد
    // بناؤه canPop=true قبل محاولة الرجوع، وإلا اعترض نفسه مرة ثانية
    // (canPop القديم ما زال false حتى يُبنى الإطار التالي).
    setState(() => _leaveConfirmed = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }
}
