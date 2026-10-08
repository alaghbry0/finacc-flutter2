/// حوار «التأكيد بكتابة الكلمة» — النمط الموحد للأفعال المدمرة (AC-15).
///
/// كان القفل يتطلب كتابة كلمة التأكيد بينما مسح كل البيانات من
/// الإعدادات يمر بتأكيد واحد (تناقض P1-5 + P0 المسح) — هذا المساعد
/// يوحّد المسارين: حوار تحذير ← **كتابة الكلمة حرفياً** ← تنفيذ.
///
/// ويتضمن مسار المسح المحروس كاملاً: بعد مطابقة الكلمة تُنشأ **نسخة
/// أمان إجبارية** قبل المسح (درس التراجع — بلا نسخة أخيرة = ضياع نهائي)
/// ويُخبر المستخدم باسم ملفها في حوار النجاح. فشل النسخة يحجب المسح
/// ويترك الخيار صراحةً (إعادة المحاولة أو المتابعة بلا نسخة).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/app_localizations.dart';
import '../session/app_controller.dart';

/// يعرض حوار الكتابة ويعيد true فقط عند مطابقة كلمة التأكيد حرفياً.
Future<bool> showConfirmWordDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController();
  final typed = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.wipeFinalTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.wipeFinalBody),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: '«${l10n.wipeConfirmWord}»'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(null),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          child: Text(l10n.commonConfirm),
        ),
      ],
    ),
  );
  return typed != null && typed.trim() == l10n.wipeConfirmWord;
}

/// مسار المسح المحروس الموحد (الإعدادات وشاشة القفل):
/// تأكيد ← كتابة الكلمة ← نسخة أمان إجبارية ← مسح ← حوار نجاح يذكر
/// اسم ملف النسخة الأخيرة.
Future<void> runGuardedWipeFlow(BuildContext context, AppController app) async {
  final l10n = AppLocalizations.of(context)!;
  // 1) حوار التحذير الأول.
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.wipeDialogTitle),
      content: Text(l10n.wipeDialogBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.wipeConfirmWord),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  // 2) التأكيد بكتابة الكلمة (نمط AC-15 الموحد).
  final wordMatched = await showConfirmWordDialog(context);
  if (!wordMatched) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.wipeFinalTitle)));
    return;
  }
  if (!context.mounted) return;

  // 3) التنفيذ المحروس (نسخة أمان إجبارية داخل المتحكم).
  unawaited(HapticFeedback.heavyImpact());
  final outcome = await app.wipeAllData();
  if (!context.mounted) return;

  switch (outcome) {
    case final WipeSucceeded succeeded:
      // 4) النجاح — مع اسم ملف نسخة الأمان الأخيرة إن أُنشئت.
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.wipeDoneTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.wipeDoneBody),
              if (succeeded.safetyBackupFileName != null) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.appFixWipeSafetyBackupAt(
                    succeeded.safetyBackupFileName!,
                  ),
                  style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                    color: Theme.of(dialogContext).colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonDone),
            ),
          ],
        ),
      );
    case WipeBlockedByBackupFailure():
      // 5) حجب المسح — فشلت نسخة الأمان ولم يُمسَح شيء؛ المتابعة بلا
      //    نسخة قرار صريح لا افتراضياً.
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.appFixWipeBackupFailedTitle),
          content: Text(l10n.appFixWipeBackupFailedBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.appFixWipeProceedNoBackup),
            ),
          ],
        ),
      );
      if (proceed == true && context.mounted) {
        final retried = await app.wipeAllData(skipSafetyBackup: true);
        if (retried is WipeSucceeded && context.mounted) {
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(l10n.wipeDoneTitle),
              content: Text(l10n.wipeDoneBody),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.commonDone),
                ),
              ],
            ),
          );
        }
      }
    // تفاصيل الفشل التقنية تُسجَّل داخل سجل النسخ (backup_log) — الحوار
    // يكتفي بالرسالة الواضحة للمستخدم.
  }
}
