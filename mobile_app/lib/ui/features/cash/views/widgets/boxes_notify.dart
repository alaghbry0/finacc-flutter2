/// إشعار نتيجة عملية صندوق (إدارة الصناديق) — مستخرج حرفياً من
/// `boxes_screen.dart` (R20-D3d؛ كان `_notifyResult`).
library;

import 'package:flutter/material.dart';

/// إشعار نتيجة عملية (نجاح صامت — القائمة تتحدث؛ الفشل برسالة المستودع).
void boxesNotifyResult(BuildContext context, bool ok, String? error) {
  if (ok) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        content: Text(
          error ?? '',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onErrorContainer),
        ),
      ),
    );
}
