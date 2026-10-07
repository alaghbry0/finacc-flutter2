/// سجل حركات الصندوق (FR-04-08) — مسار `/cash/movements?box={id}`:
/// مرشحات (صندوق/نوع/فترة/بحث نصي) تحفظ قيمها عند إعادة التحميل +
/// صفوف بأيقونة نوع ومبلغ موقّع ملون (وارد أخضر/صادر أحمر) + رقم السند
/// إن وُجد + فتح تفاصيل (مع التخصيصات) + **إبطال بتأكيد خطير** (حركة
/// معاكسة لا حذف). الجسم مغلّف بـ RefreshOnActive بنمط `^/cash/movements$`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/cash.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/refresh_on_active.dart';
import '../view_models/movements_view_model.dart';
import 'widgets/cash_widgets.dart';

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
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.cashMovementsSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          final vm = context.read<MovementsViewModel>();
                          vm.onSearchChanged('');
                          unawaited(vm.load());
                        },
                      ),
              ),
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
        DropdownMenuItem<int?>(
          value: null,
          child: Text(l10n.cashMovementsAllBoxes),
        ),
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
        DropdownMenuItem<String?>(
          value: null,
          child: Text(l10n.cashMovementsAllTypes),
        ),
        for (final type in CashTxType.values)
          DropdownMenuItem<String?>(
            value: type.code,
            child: Text(cashTxLabel(l10n, type)),
          ),
      ],
    );
  }

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

/// ─────────────────────────────────────────────────────────────────────
/// نافذة تفاصيل الحركة + الإبطال (FR-04-08 — معاكسة لا حذف)
/// ─────────────────────────────────────────────────────────────────────

/// يفتح نافذة التفاصيل؛ بعد إغلاقها يُعاد تحميل السجل إن تغيّر (الإبطال
/// يعيد التحميل من النموذج أصلاً — هذا للأمان العام).
Future<void> showMovementDetailSheet(
  BuildContext context, {
  required MovementsViewModel vm,
  required int movementId,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // فوق شريط التبويبات (متصفح الفرع) — لا من أسفل الشاشة خلفه.
    useRootNavigator: false,
    builder: (_) => _MovementDetailSheet(vm: vm, movementId: movementId),
  );
}

class _MovementDetailSheet extends StatefulWidget {
  const _MovementDetailSheet({required this.vm, required this.movementId});

  final MovementsViewModel vm;
  final int movementId;

  @override
  State<_MovementDetailSheet> createState() => _MovementDetailSheetState();
}

class _MovementDetailSheetState extends State<_MovementDetailSheet> {
  CashMovementDetail? _detail;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final detail = await widget.vm.movementDetail(widget.movementId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _confirmVoid(CashMovementRow movement) async {
    final l10n = AppLocalizations.of(context)!;
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.cashMovementVoidTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.cashMovementVoidBody),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: l10n.cashMovementVoidReasonLabel,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.cashMovementVoidConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      final result = await widget.vm.voidMovement(
        movement.id,
        reason: reasonController.text.trim().isEmpty
            ? null
            : reasonController.text.trim(),
      );
      reasonController.dispose();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (result.isOk) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(l10n.cashMovementVoidedSnackBar)),
          );
        Navigator.of(context).pop();
      } else {
        // رفض المستودع برسالة عربية — تُعرض كما هي.
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              content: Text(
                result.errorOrNull!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          );
      }
    } else {
      reasonController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CashSheetDragHandle(),
            const SizedBox(height: 14),
            Text(
              l10n.cashMovementDetailTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              )
            else if (_error != null)
              ErrorState(
                title: l10n.genericErrorTitle,
                message: l10n.dbOpenErrorMessage,
                technicalDetails: _error.toString(),
                retryLabel: l10n.commonRetry,
                onRetry: _load,
                compact: true,
              )
            else if (_detail == null)
              EmptyState(
                icon: Icons.search_off_rounded,
                title: l10n.cashMovementsNoResultsTitle,
                message: l10n.cashMovementsNoResultsBody,
                compact: true,
              )
            else ...[
              FinCard(
                padding: const EdgeInsets.all(14),
                child: CashMovementTile(
                  movement: _detail!.movement,
                  dimmed: _detail!.movement.isVoided,
                ),
              ),
              const SizedBox(height: 12),
              FinCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DetailRow(
                      label: l10n.cashMovementFieldDate,
                      value: cashFormatDate(_detail!.movement.txDate),
                    ),
                    _DetailRow(
                      label: l10n.cashMovementFieldBox,
                      value:
                          '${_detail!.movement.cashboxName} '
                          '(${_detail!.movement.currencyCode})',
                    ),
                    if (_detail!.movement.toCashboxName != null)
                      _DetailRow(
                        label: l10n.cashMovementFieldTo,
                        value: _detail!.movement.toCashboxName!,
                      ),
                    if (_detail!.movement.voucherNo != null)
                      _DetailRow(
                        label: l10n.cashMovementFieldVoucher,
                        value: _detail!.movement.voucherNo!,
                      ),
                    if (_detail!.movement.customerName != null)
                      _DetailRow(
                        label: l10n.cashMovementFieldParty,
                        value: _detail!.movement.customerName!,
                      ),
                    if (_detail!.movement.supplierName != null)
                      _DetailRow(
                        label: l10n.cashMovementFieldParty,
                        value: _detail!.movement.supplierName!,
                      ),
                    if (_detail!.movement.expenseCategoryName != null)
                      _DetailRow(
                        label: l10n.cashMovementFieldCategory,
                        value: _detail!.movement.expenseCategoryName!,
                      ),
                    _RateRow(
                      label: l10n.cashMovementFieldRate,
                      value: _detail!.movement.exchangeRate,
                    ),
                    if (_detail!.movement.settlementRate != null)
                      _RateRow(
                        label: l10n.cashMovementFieldSettlement,
                        value: _detail!.movement.settlementRate!,
                      ),
                    if ((_detail!.movement.fxGainLoss.abs()) > 0.005)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.cashMovementFieldFx,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ),
                            AmountText(
                              amount: _detail!.movement.fxGainLoss,
                              decimals: 2,
                              sign: _detail!.movement.fxGainLoss > 0
                                  ? FinSign.incoming
                                  : FinSign.outgoing,
                            ),
                          ],
                        ),
                      ),
                    if (_detail!.movement.description != null &&
                        _detail!.movement.description!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.cashMovementFieldDescription,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _detail!.movement.description!,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (_detail!.allocations.isNotEmpty) ...[
                const SizedBox(height: 12),
                FinCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.cashMovementAllocationsTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      for (final allocation in _detail!.allocations)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      allocation.invoiceNo,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            fontFeatures: FinText.tabularNums,
                                          ),
                                    ),
                                    Text(
                                      allocation.invoiceTypeCode == 'sale'
                                          ? l10n.cashAllocSaleInvoice
                                          : l10n.cashAllocPurchaseInvoice,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                  ],
                                ),
                              ),
                              AmountText(
                                amount: allocation.allocatedAmount,
                                decimals: 2,
                                showSignMarker: false,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                allocation.currencyCode,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: colors.gold,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (_detail!.movement.isVoidable)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.negative,
                    foregroundColor: colors.onNegative,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: widget.vm.state.voidingId == _detail!.movement.id
                      ? null
                      : () => unawaited(_confirmVoid(_detail!.movement)),
                  icon: widget.vm.state.voidingId == _detail!.movement.id
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Icon(Icons.block_rounded, size: 20),
                  label: Text(l10n.cashMovementVoidButton),
                )
              else if (!_detail!.movement.isVoided)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.cashMovementNotVoidableNote,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonDone),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: FinText.tabularNums,
              ),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _RateRow extends StatelessWidget {
  const _RateRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Text(
            AmountText.format(value, 4),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: FinText.tabularNums,
            ),
          ),
        ],
      ),
    );
  }
}
