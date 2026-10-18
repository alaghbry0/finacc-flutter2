/// تفاصيل عرض السعر — الرأس (رقم/حالة/عميل/عملة/صلاحية) + البنود +
/// الصافي + أزرار: تحويل إلى فاتورة (يفتح PaymentSheet مختصراً ثم
/// convertToInvoice الذرّي)، تعليم «مُرسَل»، إلغاء بتأكيد.
/// المحتوى والصفوف وشريط الأزرار بملفاتها المركزّة بجوارها (R20-D3b) —
/// هذا الملف: الحرّاس (تحميل ← خطأ ← غير موجود ← المحتوى).
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
import '../view_models/quotations_view_model.dart';
import 'widgets/quotation_detail_actions_bar.dart';
import 'widgets/quotation_detail_content.dart';

/// تفاصيل عرض السعر (مسار مقترح `/sell/quotations/:id`).
class QuotationDetailScreen extends StatelessWidget {
  const QuotationDetailScreen({super.key, required this.quotationId});

  final int quotationId;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    final vm = QuotationDetailViewModel(
      quotationRepo: app.quotations!,
      companyRepo: app.companies!,
      quotationId: quotationId,
      // P2-5: لجلب رقم INV الحقيقي للفاتورة المحوَّل إليها.
      saleRepo: app.sales,
    );
    unawaited(() async {
      vm.setUserId((await app.companies!.findAdminUserId()) ?? 1);
      await vm.load();
    }());
    return ChangeNotifierProvider<QuotationDetailViewModel>.value(
      value: vm,
      child: const _QuotationDetailBody(),
    );
  }
}

class _QuotationDetailBody extends StatelessWidget {
  const _QuotationDetailBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<QuotationDetailViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    final quotation = vm.quotation;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/sell/quotations')),
        title: Text(quotation?.quotationNo ?? l10n.sellQuotationDetailTitle),
      ),
      body: state.loading
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: const [ListSkeleton()],
            )
          : state.error != null
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                ErrorState(
                  title: l10n.genericErrorTitle,
                  message: l10n.dbOpenErrorMessage,
                  technicalDetails: state.error.toString(),
                  retryLabel: l10n.commonRetry,
                  onRetry: vm.load,
                  compact: true,
                ),
              ],
            )
          : state.detail == null
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                EmptyState(
                  icon: Icons.request_quote_rounded,
                  title: l10n.sellQuotationNotFoundTitle,
                  message: l10n.sellQuotationNotFoundBody,
                  compact: true,
                ),
              ],
            )
          : QuotationDetailContent(vm: vm),
      bottomNavigationBar:
          (state.detail != null && quotation!.status.convertible)
          ? QuotationActionsBar(vm: vm)
          : null,
    );
  }
}
