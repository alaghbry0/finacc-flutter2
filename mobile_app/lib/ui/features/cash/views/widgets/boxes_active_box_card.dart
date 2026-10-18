/// بطاقة صندوق نشط بإدارة الصناديق — مستخرجة حرفياً من `boxes_screen.dart`
/// (R20-D3d؛ كانت `_ActiveBoxCard`): الرصيد الحي + قائمة إجراءات
/// (افتراضي/تعديل/أرشفة).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../../domain/models/cash.dart';
import '../../view_models/boxes_view_model.dart';
import 'boxes_card_shell.dart';
import 'boxes_menu.dart';

/// بطاقة صندوق نشط — النقر يفتح دفتر حركات الصندوق.
class BoxesActiveBoxCard extends StatelessWidget {
  const BoxesActiveBoxCard({super.key, required this.box});

  final CashboxWithBalance box;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BoxesViewModel>();
    return BoxesCardShell(
      box: box,
      dimmed: false,
      onTap: () => context.go('/cash/movements?box=${box.box.id}'),
      trailing: BoxesMenu(box: box),
      defaultBadge: box.box.isDefault,
      busy: vm.state.busyBoxId == box.box.id,
    );
  }
}
