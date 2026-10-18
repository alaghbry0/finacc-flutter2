/// شاشة الوردية (FR-04-04 — الشريحة 9) — مسار `/cash/shift`: بطاقة بطلة
/// «لا توجد وردية مفتوحة» عند غيابها (رصيد افتتاحي + فتح)، وبطاقة حية
/// عند وجودها (الفتح/الافتتاحي/الوارد/الصادر/المتوقع — تحديث تلقائي كل
/// 30 ثانية)، وزر إقفال يفتح نافذة سفلية (نمط payment_sheet): العدّ
/// الفعلي + مقارنة حية بفرق ملوّن (زيادة/عجز/مطابق) + تفصيل المعادلة
/// الشاملة القابل للطي + ملاحظات، ونجاح الإقفال يعرض حواراً بمعاينة
/// تقرير PDF. قسم «آخر الورديات» — نقر وردية مقفلة يفتح تقريرها.
///
/// R18-D3b: الشاشة صارت هيكلاً ركيباً — كل مكوّناتها (بطاقتا الغياب
/// والحضور، السجل، نافذة الإقفال بمقارنتها ومعادلتها، حوار النجاح،
/// معاينة PDF) انتقلت إلى `views/widgets/` بملفات مركزة.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/shift_repository.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/refresh_on_active.dart';
import '../view_models/shift_view_model.dart';
import 'widgets/shift_history_section.dart';
import 'widgets/shift_live_card.dart';
import 'widgets/shift_no_shift_card.dart';

/// شاشة الوردية — تُركَّب على `/cash/shift`.
class ShiftScreen extends StatelessWidget {
  const ShiftScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final ShiftViewModel vm;
    vm = ShiftViewModel(
      shiftRepo: ShiftRepository(app.database!.db),
      cashRepo: app.cash!,
      companyRepo: app.companies!,
      userRepo: app.users!,
    );
    unawaited(vm.load());
    return ChangeNotifierProvider<ShiftViewModel>.value(
      value: vm,
      child: RefreshOnActive(
        routePattern: RegExp(r'^/cash/shift$'),
        onActivate: vm.load,
        child: const _ShiftBody(),
      ),
    );
  }
}

class _ShiftBody extends StatefulWidget {
  const _ShiftBody();

  @override
  State<_ShiftBody> createState() => _ShiftBodyState();
}

class _ShiftBodyState extends State<_ShiftBody> {
  @override
  void initState() {
    super.initState();
    // التحديث الحي كل 30 ثانية بينما الشاشة مركَّبة — يُلغى عند الإخلاء.
    context.read<ShiftViewModel>().startAutoRefresh();
  }

  @override
  void dispose() {
    context.read<ShiftViewModel>().stopAutoRefresh();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ShiftViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.shiftTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (state.loading)
            const ListSkeleton()
          else if (state.error != null)
            ErrorState(
              title: l10n.genericErrorTitle,
              message: l10n.dbOpenErrorMessage,
              technicalDetails: state.error.toString(),
              retryLabel: l10n.commonRetry,
              onRetry: vm.load,
              compact: true,
            )
          else ...[
            if (state.current == null)
              const ShiftNoShiftCard()
            else
              const ShiftLiveCard(),
            const SizedBox(height: 20),
            const ShiftHistorySection(),
          ],
        ],
      ),
    );
  }
}
