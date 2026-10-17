/// شاشة الجرد الفعلي (FR-01-08 + AC-04 — الشريحة 10): كشف عدّ للمخزن
/// المحدد — لكل صنف رصيد دفتري + لقطة تكلفة + حقل الرصيد الفعلي مع
/// رقاقة «＝ الدفتري» وشارة فرق ملوّنة (زيادة/عجز/مطابق)، وشريط سفلي
/// ثابت بالملخص الحي (المعدود/الزيادة/العجز/الصافي) وزر «اعتماد الجرد»
/// يفتح نافذة مراجعة للفروقات فقط (كمية + قيمة بتكلفة اللقطة + تحذير
/// قفل الأرصدة) ثم حوار نجاح. قسم سجل عمليات الجرد أسفل الكشف.
///
/// R18-D3b: الشاشة صارت هيكلاً ركيباً — المكوّنات (البطاقة البطلة،
/// بطاقة البيانات، كشف العدّ، الشريط السفلي، السجل، نافذة المراجعة،
/// حوار النجاح) انتقلت إلى `views/widgets/` بملفات مركزة.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/stocktake_repository.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_search_field.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/refresh_on_active.dart';
import '../view_models/stocktake_session.dart';
import '../view_models/stocktake_view_model.dart';
import 'widgets/stocktake_counted_sheet.dart';
import 'widgets/stocktake_hero_card.dart';
import 'widgets/stocktake_history_section.dart';
import 'widgets/stocktake_meta_card.dart';
import 'widgets/stocktake_review_sheet.dart';
import 'widgets/stocktake_summary_bar.dart';

/// شاشة الجرد الفعلي — تُركَّب على مسار الجرد.
class StocktakeScreen extends StatelessWidget {
  const StocktakeScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً — عند غيابه تتصل الشاشة بجلسة
  /// الجرد التطبيقية (نمط SellCartSession — P0-1a) فتنجو مسودة العدّ من
  /// التنقل والقفل التلقائي وتبديل التبويبات.
  final StocktakeViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final provided = viewModel;
    late final StocktakeViewModel vm;
    if (provided != null) {
      vm = provided;
    } else {
      // المتحكم يُقرأ هنا حصراً — الجلسة تعيد النموذج الحي فوق القاعدة
      // الحالية (مسودة جديدة تلقائياً بعد مسح/استعادة يبدّلان القاعدة).
      final app = context.read<AppController>();
      vm = stocktakeSession.attach(
        database: app.database!,
        stocktakeRepo: StocktakeRepository(app.database!.db),
        userRepo: app.users!,
        companyRepo: app.companies!,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<StocktakeViewModel>.value(
      value: vm,
      child: RefreshOnActive(
        routePattern: RegExp(r'^/inventory/stocktake$'),
        // إعادة التحميل عند التنشيط تحفظ المسودة (تحديث مرجعي فقط —
        // الأعداد المُدخلة تُرحّل داخل load() لنفس المخزن).
        onActivate: vm.load,
        child: const _StocktakeBody(),
      ),
    );
  }
}

class _StocktakeBody extends StatefulWidget {
  const _StocktakeBody();

  @override
  State<_StocktakeBody> createState() => _StocktakeBodyState();
}

class _StocktakeBodyState extends State<_StocktakeBody> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _countedByController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _countedByController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(StocktakeViewModel vm) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.state.countedAt ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      vm.setCountedAt(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StocktakeViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    // مزامنة حقلي التوقيع/الملاحظات مع الحالة بعد إعادة التحميل (التعيين
    // البرمجي لا يطلق onChanged — فقط عند اختلاف النص فعلاً).
    if (_countedByController.text != state.countedBy) {
      _countedByController.text = state.countedBy;
    }
    if (_notesController.text != state.notes) {
      _notesController.text = state.notes;
    }

    final showBar =
        !state.loading && state.error == null && state.lines.isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.stocktakeTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (state.loading)
            const ListSkeleton(rows: 7)
          else if (state.error != null)
            ErrorState(
              title: l10n.genericErrorTitle,
              message: l10n.dbOpenErrorMessage,
              technicalDetails: state.error.toString(),
              retryLabel: l10n.commonRetry,
              onRetry: vm.load,
              compact: true,
            )
          else if (state.warehouseId == null)
            EmptyState(
              icon: Icons.warehouse_outlined,
              title: l10n.stocktakeNoWarehouseTitle,
              message: l10n.stocktakeNoWarehouseBody,
              compact: true,
            )
          else ...[
            const StocktakeHeroCard(),
            const SizedBox(height: 14),
            StocktakeMetaCard(
              countedByController: _countedByController,
              notesController: _notesController,
              onPickDate: () => unawaited(_pickDate(vm)),
            ),
            const SizedBox(height: 14),
            FinSearchField(
              controller: _searchController,
              onChanged: vm.setQuery,
              fieldKey: const Key('stocktake_search_field'),
              hint: l10n.stocktakeSearchHint,
              onCleared: () {
                _searchController.clear();
                vm.setQuery('');
              },
            ),
            const SizedBox(height: 14),
            if (state.lines.isEmpty)
              EmptyState(
                icon: Icons.celebration_rounded,
                title: l10n.stocktakeEmptyTitle,
                message: l10n.stocktakeEmptyBody,
                compact: true,
              )
            else if (state.visibleLines.isEmpty)
              EmptyState(
                icon: Icons.search_off_rounded,
                title: l10n.stocktakeSearchEmptyTitle,
                message: l10n.stocktakeSearchEmptyBody,
                compact: true,
              )
            else
              const StocktakeCountedSheet(),
            const SizedBox(height: 20),
            const StocktakeHistorySection(),
          ],
        ],
      ),
      // الشريط السفلي الثابت — الملخص الحي + زر الاعتماد.
      bottomNavigationBar: showBar
          ? StocktakeSummaryBar(onPost: () => showStocktakeReview(context, vm))
          : null,
    );
  }
}
