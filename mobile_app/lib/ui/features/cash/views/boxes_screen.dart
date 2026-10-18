/// إدارة الصناديق (FR-04-01) — مسار `/cash/boxes`: قائمة بأرصدتها الحية
/// (سالب = تحذير) + تعيين افتراضي + تعديل + **أرشفة بتأكيد** (رصيد ≠ 0
/// يطلب تأكيداً صريحاً أقوى) + قسم المؤرشفة بإلغاء أرشفة. الجسم مغلّف
/// بـ RefreshOnActive بنمط `^/cash/boxes$` (درس §10).
///
/// بطاقات الصناديق وقائمة الإجراءات وإشعار النتيجة بملفاتها المركزّصة
/// بجوارها (R20-D3d) — هذا الملف: إنشاء النموذج والحرّاس وتجميع
/// القائمة.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/refresh_on_active.dart';
import '../view_models/boxes_view_model.dart';
import 'widgets/boxes_active_box_card.dart';
import 'widgets/boxes_archived_box_card.dart';

/// إدارة الصناديق (التبويب الرابع — فرع /cash).
class BoxesScreen extends StatefulWidget {
  const BoxesScreen({super.key});

  @override
  State<BoxesScreen> createState() => _BoxesScreenState();
}

class _BoxesScreenState extends State<BoxesScreen> {
  BoxesViewModel? _vm;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppController>();
    // النموذج يُنشأ بعد حلّ معرّف المستخدم الإداري (لسجلات التدقيق عند
    // التعيين/الأرشفة) — حتى ذلك الحين هيكل تحميل.
    unawaited(
      app.companies!.findAdminUserId().then((userId) {
        if (!mounted) return;
        final vm = BoxesViewModel(cashRepo: app.cash!, userId: userId);
        setState(() => _vm = vm);
        unawaited(vm.load());
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    if (vm == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ChangeNotifierProvider<BoxesViewModel>.value(
      value: vm,
      // تحديث حي عند العودة من نموذج الصندوق أو ترحيل حركة (درس §10).
      child: RefreshOnActive(
        routePattern: RegExp(r'^/cash/boxes$'),
        onActivate: vm.load,
        child: const _BoxesBody(),
      ),
    );
  }
}

class _BoxesBody extends StatelessWidget {
  const _BoxesBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BoxesViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/cash')),
        title: Text(l10n.cashBoxesTitle),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/cash/box-form'),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.cashBoxesAddBox),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        children: [
          if (state.loading)
            const ListSkeleton(rows: 4)
          else if (state.error != null)
            ErrorState(
              title: l10n.genericErrorTitle,
              message: l10n.dbOpenErrorMessage,
              technicalDetails: state.error.toString(),
              retryLabel: l10n.commonRetry,
              onRetry: vm.load,
              compact: true,
            )
          else if (state.boxes.isEmpty && state.archived.isEmpty)
            EmptyState(
              icon: Icons.account_balance_wallet_rounded,
              title: l10n.cashBoxesEmptyTitle,
              message: l10n.cashBoxesEmptyBody,
              actionLabel: l10n.cashBoxesAddBox,
              onAction: () => context.go('/cash/box-form'),
              compact: true,
            )
          else ...[
            for (final box in state.boxes)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BoxesActiveBoxCard(box: box),
              ),
            if (state.archived.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Text(
                  l10n.cashBoxesArchivedSection,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final box in state.archived)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: BoxesArchivedBoxCard(box: box),
                ),
            ],
          ],
        ],
      ),
    );
  }
}
