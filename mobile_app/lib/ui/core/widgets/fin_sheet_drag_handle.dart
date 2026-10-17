/// FinSheetDragHandle — مقبض النافذة السفلية الموحد (R19-D2: توحيد
/// 12 نسخة حرفية من مقبض السحب (44×5 بلون outlineVariant) عبر منتقيات
/// البيع/الشراء/حركة الصنف وبوابات سعر الصرف وأوراق الدفع، مع بقاء
/// `CashSheetDragHandle` غلافاً رقيقاً مفوَّضاً له — مصدر واحد).
///
/// شريط ٤٤×٥ بلون `outlineVariant` وحواف دائرية كاملة — النمط القياسي
/// لكل نوافذ `showModalBottomSheet` في التطبيق.
library;

import 'package:flutter/material.dart';

/// مقبض سحب النافذة السفلية — شريط مصغّر في المنتصف.
class FinSheetDragHandle extends StatelessWidget {
  const FinSheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: scheme.outlineVariant,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
