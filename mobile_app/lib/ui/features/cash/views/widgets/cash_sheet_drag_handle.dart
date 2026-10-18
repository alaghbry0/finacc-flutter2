/// مقبض سحب نوافذ BottomSheet — القالب الموحد (يفوِّض إلى
/// `FinSheetDragHandle` بالنواة — مصدر الشكل الوحيد).
library;

import 'package:flutter/material.dart';

import '../../../../core/widgets/fin_sheet_drag_handle.dart';

class CashSheetDragHandle extends StatelessWidget {
  const CashSheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) => const FinSheetDragHandle();
}
