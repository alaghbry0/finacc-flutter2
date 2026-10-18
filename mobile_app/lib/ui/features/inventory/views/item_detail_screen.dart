/// شاشة بطاقة الصنف (FR-01-03 / FR-09-03): رأس بالاسم والباركود (EAN-13
/// + QR قابلة للمسح)، رقائق الأسعار بكل العملات، بطاقة المخزون بمؤشر
/// حد الطلب، الدفعات FEFO برقائق أيام ملونة، آخر الحركات، وتعديل/أرشفة.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/info_note.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/refresh_on_return.dart';
import '../view_models/item_detail_view_model.dart';
import 'widgets/item_detail_actions_row.dart';
import 'widgets/item_detail_batches_card.dart';
import 'widgets/item_detail_header_card.dart';
import 'widgets/item_detail_movements_card.dart';
import 'widgets/item_detail_prices_card.dart';
import 'widgets/item_detail_stock_card.dart';

class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({super.key, required this.itemId, this.viewModel});

  /// معرّف الصنف المطلوب.
  final int itemId;

  /// Seam اختبار: نموذج محمّل مسبقاً — عند غيابه تُنشئ الشاشة نموذجها.
  final ItemDetailViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final ItemDetailViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = ItemDetailViewModel(
        itemRepo: app.items!,
        batchRepo: app.batches!,
        companyRepo: app.companies!,
        itemId: itemId,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<ItemDetailViewModel>.value(
      value: vm,
      // تحديث البطاقة عند العودة من مسار التعديل الفرعي (item/:id/edit).
      child: RefreshOnReturn(
        onReappear: vm.load,
        child: const _ItemDetailBody(),
      ),
    );
  }
}

class _ItemDetailBody extends StatelessWidget {
  const _ItemDetailBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ItemDetailViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.itemDetailTitle),
        actions: [
          IconButton(
            tooltip: l10n.commonRetry,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: vm.load,
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (state.loading) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: const [ListSkeleton(rows: 6)],
            );
          }
          if (state.notFound) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                ErrorState(
                  title: l10n.genericErrorTitle,
                  message: l10n.itemDetailNotFound,
                  retryLabel: l10n.commonRetry,
                  onRetry: vm.load,
                  compact: true,
                ),
              ],
            );
          }
          if (state.error != null) {
            return ListView(
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
            );
          }
          final detail = state.detail!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              ItemDetailHeaderCard(state: state),
              const SizedBox(height: 14),
              if (!state.archived) ItemDetailActionsRow(state: state),
              const SizedBox(height: 14),
              ItemDetailPricesCard(state: state),
              const SizedBox(height: 14),
              if (detail.item.isService)
                InfoNote(
                  icon: Icons.miscellaneous_services_rounded,
                  message: l10n.itemDetailServiceNote,
                )
              else
                ItemDetailStockCard(state: state),
              if (detail.item.trackBatches) ...[
                const SizedBox(height: 14),
                ItemDetailBatchesCard(state: state),
              ],
              const SizedBox(height: 14),
              ItemDetailMovementsCard(state: state),
            ],
          );
        },
      ),
    );
  }
}
