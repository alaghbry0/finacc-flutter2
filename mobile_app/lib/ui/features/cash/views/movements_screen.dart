/// سجل حركات الصندوق (FR-04-08) — مسار `/cash/movements?box={id}`:
/// مرشحات (صندوق/نوع/فترة/بحث نصي) تحفظ قيمها عند إعادة التحميل +
/// صفوف بأيقونة نوع ومبلغ موقّع ملون (وارد أخضر/صادر أحمر) + رقم السند
/// إن وُجد + فتح تفاصيل (مع التخصيصات) + **إبطال بتأكيد خطير** (حركة
/// معاكسة لا حذف). الجسم مغلّف بـ RefreshOnActive بنمط `^/cash/movements$`.
///
/// (R19-D3a: نافذة التفاصيل والإبطال في `widgets/movement_detail_sheet.dart`
/// وإسقاط طباعة السند في `widgets/movement_voucher_pdf.dart`.)
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/cash.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/fin_search_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/refresh_on_active.dart';
import '../view_models/movements_view_model.dart';
import 'widgets/cash_widgets.dart';
import 'widgets/movement_detail_sheet.dart';

/// سجل الحركات — [initialBoxId] من `?box=` (نقر بطاقة صندوق في المحور).
class MovementsScreen extends StatefulWidget {
  const MovementsScreen({super.key, this.initialBoxId});

  final int? initialBoxId;

  @override
  State<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends State<MovementsScreen> {
  MovementsViewModel? _vm;
  List<CashboxWithBalance> _boxes = const <CashboxWithBalance>[];
  Object? _boxesError;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppController>();
    final vm = MovementsViewModel(
      cashRepo: app.cash!,
      companyRepo: app.companies!,
    );
    _vm = vm;
    if (widget.initialBoxId != null) {
      vm.setBoxFilter(widget.initialBoxId);
    }
    unawaited(vm.load());
    // قائمة الصناديق لمرشح الصندوق — تحميل مساعد في الشاشة (النموذج
    // يكشف setBoxFilter فقط) عبر مستودع AppController؛ موثق في سجل
    // العمل 12.
    unawaited(_loadBoxes(app));
  }

  Future<void> _loadBoxes(AppController app) async {
    try {
      final boxes = await app.cash!.listBoxes();
      if (!mounted) return;
      setState(() {
        _boxes = boxes;
        _boxesError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _boxesError = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    if (vm == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ChangeNotifierProvider<MovementsViewModel>.value(
      value: vm,
      // تحديث حي عند تبديل التبويب/الرجوع (درس §10) — المرشحات محفوظة
      // في النموذج فتُطبَّق عند إعادة التحميل.
      child: RefreshOnActive(
        routePattern: RegExp(r'^/cash/movements$'),
        onActivate: vm.load,
        child: _MovementsBody(boxes: _boxes, boxesError: _boxesError),
      ),
    );
  }
}

class _MovementsBody extends StatefulWidget {
  const _MovementsBody({required this.boxes, required this.boxesError});

  final List<CashboxWithBalance> boxes;
  final Object? boxesError;

  @override
  State<_MovementsBody> createState() => _MovementsBodyState();
}

class _MovementsBodyState extends State<_MovementsBody> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    final vm = context.read<MovementsViewModel>();
    vm.onSearchChanged(value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(vm.load());
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MovementsViewModel>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/cash')),
        title: Text(l10n.cashMovementsTitle),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: FinSearchField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              hint: l10n.cashMovementsSearchHint,
              onCleared: () {
                _searchController.clear();
                final vm = context.read<MovementsViewModel>();
                vm.onSearchChanged('');
                unawaited(vm.load());
              },
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(
              children: [
                Expanded(child: _buildBoxFilter(context, vm)),
                const SizedBox(width: 10),
                Expanded(child: _buildTypeFilter(context, vm)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<CashPeriodFilter>(
                segments: [
                  ButtonSegment(
                    value: CashPeriodFilter.all,
                    label: Text(l10n.cashMovementsPeriodAll),
                  ),
                  ButtonSegment(
                    value: CashPeriodFilter.today,
                    label: Text(l10n.cashMovementsPeriodToday),
                  ),
                  ButtonSegment(
                    value: CashPeriodFilter.week,
                    label: Text(l10n.cashMovementsPeriodWeek),
                  ),
                  ButtonSegment(
                    value: CashPeriodFilter.month,
                    label: Text(l10n.cashMovementsPeriodMonth),
                  ),
                ],
                selected: {vm.period},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  vm.setPeriod(selection.first);
                  unawaited(vm.load());
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildContent(context, vm)),
        ],
      ),
    );
  }

  Widget _buildBoxFilter(BuildContext context, MovementsViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    if (widget.boxesError != null) {
      return TextFormField(
        enabled: false,
        decoration: InputDecoration(
          labelText: l10n.cashMovementsAllBoxes,
          prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
        ),
      );
    }
    return DropdownButtonFormField<int?>(
      initialValue: vm.boxFilter,
      onChanged: (boxId) {
        vm.setBoxFilter(boxId);
        unawaited(vm.load());
      },
      decoration: InputDecoration(
        labelText: l10n.cashMovementsAllBoxes,
        prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
      ),
      items: [
        DropdownMenuItem<int?>(child: Text(l10n.cashMovementsAllBoxes)),
        for (final box in widget.boxes)
          DropdownMenuItem<int?>(
            value: box.box.id,
            child: Text(
              '${box.box.name} · ${box.box.currencyCode}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  Widget _buildTypeFilter(BuildContext context, MovementsViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    return DropdownButtonFormField<String?>(
      initialValue: vm.typeFilter,
      onChanged: (type) {
        vm.setTypeFilter(type);
        unawaited(vm.load());
      },
      decoration: InputDecoration(
        labelText: l10n.cashMovementsAllTypes,
        prefixIcon: const Icon(Icons.filter_alt_rounded),
      ),
      items: [
        DropdownMenuItem<String?>(child: Text(l10n.cashMovementsAllTypes)),
        for (final type in CashTxType.values)
          DropdownMenuItem<String?>(
            value: type.code,
            child: Text(cashTxLabel(l10n, type)),
          ),
      ],
    );
  }

  /// محتوى السجل بحرّاس خروج مبكرين: تحميل ← خطأ ← فراغ/لا نتائج ←
  /// القائمة (نفس دلالة السلاسل الأصلية حرفياً).
  Widget _buildContent(BuildContext context, MovementsViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    if (state.loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: const [ListSkeleton(rows: 7)],
      );
    }
    if (state.error != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
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
    final filtered =
        vm.search.trim().isNotEmpty ||
        vm.boxFilter != null ||
        vm.typeFilter != null ||
        vm.period != CashPeriodFilter.all;
    if (state.movements.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          EmptyState(
            icon: Icons.receipt_long_rounded,
            title: filtered
                ? l10n.cashMovementsNoResultsTitle
                : l10n.cashMovementsEmptyTitle,
            message: filtered
                ? l10n.cashMovementsNoResultsBody
                : l10n.cashMovementsEmptyBody,
            compact: true,
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      itemCount: state.movements.length,
      itemBuilder: (context, index) {
        final movement = state.movements[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: FinCard(
            padding: const EdgeInsets.all(12),
            onTap: () => unawaited(
              showMovementDetailSheet(context, vm: vm, movementId: movement.id),
            ),
            child: CashMovementTile(
              movement: movement,
              dimmed: movement.isVoided,
            ),
          ),
        );
      },
    );
  }
}
