/// شاشة الوردية (FR-04-04 — الشريحة 9) — مسار `/cash/shift`: بطاقة بطلة
/// «لا توجد وردية مفتوحة» عند غيابها (رصيد افتتاحي + فتح)، وبطاقة حية
/// عند وجودها (الفتح/الافتتاحي/الوارد/الصادر/المتوقع — تحديث تلقائي كل
/// 30 ثانية)، وزر إقفال يفتح نافذة سفلية (نمط payment_sheet): العدّ
/// الفعلي + مقارنة حية بفرق ملوّن (زيادة/عجز/مطابق) + تفصيل المعادلة
/// الشاملة القابل للطي + ملاحظات، ونجاح الإقفال يعرض حواراً بمعاينة
/// تقرير PDF. قسم «آخر الورديات» — نقر وردية مقفلة يفتح تقريرها.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/shift_repository.dart';
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
import '../../printing/services/shift_report_pdf_builder.dart';
import '../../printing/shift_print_doc.dart';
import '../../printing/views/pdf_preview_dialog.dart';
import '../view_models/shift_view_model.dart';
import 'widgets/cash_widgets.dart';

/// منازل العملة للعرض — قرار المستدعي: YER = 0 (قاعدة 5.4-9) والباقي 2.
int shiftDecimals(String? currencyCode) => currencyCode == 'YER' ? 0 : 2;

/// تاريخ ووقت `يوم/شهر/سنة ساعة:دقيقة` بأرقام بسيطة (نمط الوحدة).
String shiftFormatDateTime(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/${date.year} $hour:$minute';
}

DateTime? _tryParseIso(String? iso) =>
    iso == null ? null : DateTime.tryParse(iso);

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
            const ListSkeleton(rows: 6)
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
              const _NoShiftCard()
            else
              const _LiveShiftCard(),
            const SizedBox(height: 20),
            const _HistorySection(),
          ],
        ],
      ),
    );
  }
}

/// البطاقة البطلة عند غياب وردية مفتوحة — رصيد افتتاحي + زر فتح كبير.
class _NoShiftCard extends StatefulWidget {
  const _NoShiftCard();

  @override
  State<_NoShiftCard> createState() => _NoShiftCardState();
}

class _NoShiftCardState extends State<_NoShiftCard> {
  final TextEditingController _openingController = TextEditingController(
    text: '0',
  );
  int? _selectedBoxId;

  @override
  void dispose() {
    _openingController.dispose();
    super.dispose();
  }

  double? get _openingCount {
    final raw = _openingController.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return 0;
    final value = double.tryParse(raw);
    if (value == null || value.isNaN || value.isInfinite || value < 0) {
      return null;
    }
    return value;
  }

  Future<void> _open(ShiftViewModel vm) async {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    if (state.boxes.isEmpty) return;
    final fallback = state.boxFor(null);
    final boxId = _selectedBoxId ?? fallback?.box.id;
    if (boxId == null) return;
    final opening = _openingCount;
    if (opening == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.shiftInvalidAmount)));
      return;
    }
    final result = await vm.openShift(boxId, opening);
    if (!mounted) return;
    if (result.isErr) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.errorOrNull!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ShiftViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final state = vm.state;
    final box = state.boxFor(null);

    return FinCard(
      accent: colors.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primary,
                      Color.lerp(scheme.primary, Colors.black, 0.25)!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.lock_clock_rounded,
                  color: scheme.onPrimary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.shiftOpenNoneTitle,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.shiftOpenNoneBody,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (state.boxes.length > 1 && box != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<int>(
                initialValue: box.box.id,
                decoration: InputDecoration(
                  labelText: l10n.shiftPrintBox,
                  prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final b in state.boxes)
                    DropdownMenuItem<int>(
                      value: b.box.id,
                      child: Text(b.box.name),
                    ),
                ],
                onChanged: (value) {
                  // اختيار الصندوق للفتح — يُقرأ عند الضغط (قيمة الحالة
                  // تُحل عبر boxFor كل مرة، وهنا نخزّن الاختيار يدوياً).
                  if (value != null) _selectedBoxId = value;
                },
              ),
            ),
          TextField(
            controller: _openingController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,4}')),
            ],
            decoration: InputDecoration(
              labelText: l10n.shiftOpeningCountLabel,
              prefixIcon: const Icon(Icons.payments_rounded),
              suffixText: box?.box.currencyCode ?? '',
            ),
          ),
          if (vm.actionError != null) ...[
            const SizedBox(height: 12),
            CashErrorCard(message: vm.actionError!),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: vm.opening || state.boxes.isEmpty
                ? null
                : () => unawaited(_open(vm)),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              textStyle: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            child: vm.opening
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : Text(l10n.shiftOpenButton),
          ),
        ],
      ),
    );
  }
}

/// بطاقة الوردية الحية — الفتح والافتتاحي والوارد/الصادر/المتوقع.
class _LiveShiftCard extends StatelessWidget {
  const _LiveShiftCard();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ShiftViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final state = vm.state;
    final current = state.current!;
    final box = state.boxFor(current.cashboxId);
    final decimals = shiftDecimals(box?.box.currencyCode);
    final opened = _tryParseIso(current.openedAt);

    return FinCard(
      accent: colors.positive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.positive,
                      Color.lerp(colors.positive, Colors.black, 0.25)!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.timelapse_rounded,
                  color: colors.onPositiveContainer,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.shiftLiveTitle,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${box?.box.name ?? ''}'
                      '${opened == null ? '' : ' · ${l10n.shiftOpenedAtLabel}: '
                                '${shiftFormatDateTime(opened.toLocal())}'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFeatures: FinText.tabularNums,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SummaryRow(
            label: l10n.shiftOpeningCountLabel,
            amount: current.openingCount ?? 0,
            decimals: decimals,
            currencyCode: box?.box.currencyCode,
          ),
          _SummaryRow(
            label: l10n.shiftRunningIn,
            amount: state.equation.totalIn,
            decimals: decimals,
            currencyCode: box?.box.currencyCode,
            sign: FinSign.incoming,
          ),
          _SummaryRow(
            label: l10n.shiftRunningOut,
            amount: state.equation.totalOut,
            decimals: decimals,
            currencyCode: box?.box.currencyCode,
            sign: FinSign.outgoing,
          ),
          const Divider(height: 20, thickness: 0.8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.shiftExpectedSoFar,
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    AmountText(
                      amount: state.expectedSoFar,
                      size: AmountSize.large,
                      decimals: decimals,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                box?.box.currencyCode ?? '',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.gold,
                  fontWeight: FontWeight.w800,
                  fontFeatures: FinText.tabularNums,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.shiftAutoRefreshNote,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => unawaited(showShiftCloseSheet(context, vm)),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: colors.negative,
              foregroundColor: colors.onNegativeContainer,
              textStyle: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            child: Text(l10n.shiftCloseButton),
          ),
        ],
      ),
    );
  }
}

/// سطر ملخص «تسمية + مبلغ» داخل البطاقة الحية.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.amount,
    required this.decimals,
    this.currencyCode,
    this.sign = FinSign.neutral,
  });

  final String label;
  final double amount;
  final int decimals;
  final String? currencyCode;
  final FinSign sign;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 8),
          AmountText(amount: amount, decimals: decimals, sign: sign),
          if ((currencyCode ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                currencyCode!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: FinText.tabularNums,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// قسم «آخر الورديات» — نقر وردية مقفلة يفتح تقرير PDF.
class _HistorySection extends StatelessWidget {
  const _HistorySection();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ShiftViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            l10n.shiftHistoryTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (state.recent.isEmpty)
          EmptyState(
            icon: Icons.history_rounded,
            title: l10n.shiftHistoryTitle,
            message: l10n.shiftHistoryEmpty,
            compact: true,
          )
        else
          for (final shift in state.recent)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ShiftHistoryCard(shift: shift),
            ),
      ],
    );
  }
}

/// بطاقة وردية مقفلة في السجل — نطاقها + المتوقع/المعدود/الفرق الملوّن.
class _ShiftHistoryCard extends StatelessWidget {
  const _ShiftHistoryCard({required this.shift});

  final ShiftRow shift;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ShiftViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final box = vm.state.boxFor(shift.cashboxId);
    final decimals = shiftDecimals(box?.box.currencyCode);
    final opened = _tryParseIso(shift.openedAt)?.toLocal();
    final closed = _tryParseIso(shift.closedAt)?.toLocal();

    return FinCard(
      padding: const EdgeInsets.all(14),
      onTap: () => _openShiftPdf(context, vm: vm, shift: shift),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  opened == null
                      ? box?.box.name ?? ''
                      : '${shiftFormatDateTime(opened)}'
                            '${closed == null ? '' : ' ← ${shiftFormatDateTime(closed)}'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: FinText.tabularNums,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if ((box?.box.currencyCode ?? '').isNotEmpty)
                Text(
                  box!.box.currencyCode,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: FinText.tabularNums,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _HistoryAmount(
                  label: l10n.shiftExpectedLabel,
                  amount: shift.expected ?? 0,
                  decimals: decimals,
                ),
              ),
              Expanded(
                child: _HistoryAmount(
                  label: l10n.shiftCountedLabel,
                  amount: shift.counted ?? 0,
                  decimals: decimals,
                ),
              ),
              Expanded(
                child: _HistoryAmount(
                  label: l10n.shiftDifferenceLabel,
                  amount: shift.difference ?? 0,
                  decimals: decimals,
                  emphasizeDifference: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// عمود مبلغ داخل بطاقة السجل.
class _HistoryAmount extends StatelessWidget {
  const _HistoryAmount({
    required this.label,
    required this.amount,
    required this.decimals,
    this.emphasizeDifference = false,
  });

  final String label;
  final double amount;
  final int decimals;
  final bool emphasizeDifference;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final diff = emphasizeDifference
        ? (amount > 0.005
              ? FinSign.incoming
              : amount < -0.005
              ? FinSign.outgoing
              : FinSign.neutral)
        : FinSign.neutral;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        AmountText(
          amount: emphasizeDifference ? amount.abs() : amount,
          decimals: decimals,
          sign: diff,
          showSignMarker: false,
        ),
        if (emphasizeDifference)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              amount > 0.005
                  ? AppLocalizations.of(context)!.shiftSurplus
                  : amount < -0.005
                  ? AppLocalizations.of(context)!.shiftDeficit
                  : AppLocalizations.of(context)!.shiftMatched,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: switch (diff) {
                  FinSign.incoming => colors.positive,
                  FinSign.outgoing => colors.negative,
                  FinSign.neutral => scheme.onSurfaceVariant,
                },
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// نافذة الإقفال (نمط payment_sheet السفلية)
// ─────────────────────────────────────────────────────────────────────

/// يفتح نافذة إقفال الوردية — العدّ الفعلي + مقارنة حية + تفصيل المعادلة
/// القابل للطي + ملاحظات + تأكيد. عند النجاح تُغلق وتُعرض نافذة النجاح.
Future<void> showShiftCloseSheet(BuildContext context, ShiftViewModel vm) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // فوق شريط التبويبات (متصفح الفرع) — لا من أسفل الشاشة خلفه.
    useRootNavigator: false,
    builder: (_) => ChangeNotifierProvider<ShiftViewModel>.value(
      value: vm,
      child: const _ShiftCloseSheet(),
    ),
  );
}

class _ShiftCloseSheet extends StatefulWidget {
  const _ShiftCloseSheet();

  @override
  State<_ShiftCloseSheet> createState() => _ShiftCloseSheetState();
}

class _ShiftCloseSheetState extends State<_ShiftCloseSheet> {
  final TextEditingController _countedController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // يبدأ العدّ من المتوقع الحي (أسهل حالة: مطابق) — المستخدم يعدّل.
    final vm = context.read<ShiftViewModel>();
    _countedController.text = _fmtNumber(vm.state.expectedSoFar);
  }

  @override
  void dispose() {
    _countedController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  static String _fmtNumber(double value) => value == value.truncateToDouble()
      ? value.truncate().toString()
      : value.toStringAsFixed(2);

  double? get _counted {
    final raw = _countedController.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    final value = double.tryParse(raw);
    if (value == null || value.isNaN || value.isInfinite || value < 0) {
      return null;
    }
    return value;
  }

  Future<void> _confirm(ShiftViewModel vm) async {
    final l10n = AppLocalizations.of(context)!;
    final counted = _counted;
    if (counted == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.shiftInvalidAmount)));
      return;
    }
    final result = await vm.closeShift(
      counted: counted,
      notes: _notesController.text,
    );
    if (!mounted) return;
    if (result.isErr) {
      // الرفض يظهر كبطاقة حمراء داخل النافذة (vm.actionError).
      return;
    }
    Navigator.of(context).pop();
    unawaited(_showCloseSuccess(context, vm, result.valueOrNull!));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ShiftViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final state = vm.state;
    final current = state.current;
    final box = state.boxFor(current?.cashboxId);
    final decimals = shiftDecimals(box?.box.currencyCode);
    final expected = state.expectedSoFar;
    final counted = _counted;
    final difference = counted == null ? null : counted - expected;

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
              l10n.shiftCloseButton,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _countedController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,4}')),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.shiftCountedLabel,
                helperText: l10n.shiftCountedHint,
                prefixIcon: const Icon(Icons.countertops_rounded),
                suffixText: box?.box.currencyCode ?? '',
              ),
            ),
            const SizedBox(height: 14),
            _ComparisonCard(
              expected: expected,
              counted: counted,
              difference: difference,
              decimals: decimals,
              currencyCode: box?.box.currencyCode,
            ),
            const SizedBox(height: 10),
            // تفصيل المعادلة الشاملة — قابل للطي.
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.shiftEquationTitle,
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...[
              const SizedBox(height: 10),
              _EquationBreakdown(equation: state.equation, decimals: decimals),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              enabled: !vm.closing,
              maxLines: 2,
              maxLength: 140,
              decoration: InputDecoration(
                labelText: l10n.shiftNotesLabel,
                helperText: l10n.shiftNotesHint,
                prefixIcon: const Icon(Icons.notes_rounded),
              ),
            ),
            if (vm.actionError != null) ...[
              const SizedBox(height: 12),
              CashErrorCard(message: vm.actionError!),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: vm.closing ? null : () => unawaited(_confirm(vm)),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: colors.negative,
                foregroundColor: colors.onNegativeContainer,
                textStyle: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              child: vm.closing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : Text(l10n.shiftConfirmClose),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: vm.closing ? null : () => Navigator.of(context).pop(),
              child: Text(l10n.commonCancel),
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة المقارنة الحية: المتوقع مقابل المعدود + شارة الفرق الملوّنة.
class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({
    required this.expected,
    required this.counted,
    required this.difference,
    required this.decimals,
    this.currencyCode,
  });

  final double expected;
  final double? counted;
  final double? difference;
  final int decimals;
  final String? currencyCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final diff = difference;
    final badgeColor = diff == null
        ? scheme.surfaceContainerLow
        : diff > 0.005
        ? colors.positiveContainer
        : diff < -0.005
        ? colors.negativeContainer
        : scheme.surfaceContainerLow;
    final badgeText = diff == null
        ? '—'
        : diff > 0.005
        ? l10n.shiftSurplus
        : diff < -0.005
        ? l10n.shiftDeficit
        : l10n.shiftMatched;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _CompareColumn(
                  label: l10n.shiftExpectedLabel,
                  amount: expected,
                  decimals: decimals,
                  currencyCode: currencyCode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CompareColumn(
                  label: l10n.shiftCountedLabel,
                  amount: counted,
                  decimals: decimals,
                  currencyCode: currencyCode,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${l10n.shiftDifferenceLabel}:',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              if (diff != null)
                AmountText(
                  amount: diff.abs(),
                  decimals: decimals,
                  sign: diff > 0.005
                      ? FinSign.incoming
                      : diff < -0.005
                      ? FinSign.outgoing
                      : FinSign.neutral,
                  showSignMarker: false,
                )
              else
                Text(
                  '—',
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(fontFeatures: FinText.tabularNums),
                ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeText,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// عمود مقارنة (تسمية + مبلغ أو شرطة).
class _CompareColumn extends StatelessWidget {
  const _CompareColumn({
    required this.label,
    required this.amount,
    required this.decimals,
    this.currencyCode,
  });

  final String label;
  final double? amount;
  final int decimals;
  final String? currencyCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (amount == null)
              Text('—', style: Theme.of(context).textTheme.titleMedium)
            else
              Flexible(
                child: AmountText(
                  amount: amount!,
                  size: AmountSize.large,
                  decimals: decimals,
                ),
              ),
            if (amount != null && (currencyCode ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  currencyCode!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: FinText.tabularNums,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// تفصيل المعادلة الشاملة — قسم وارد أخضر وقسم صادر أحمر + أخرى + حاشية
/// الشيكات المؤجلة (كل مكون بتسميته العربية وقيمته بعملة الصندوق).
class _EquationBreakdown extends StatelessWidget {
  const _EquationBreakdown({required this.equation, required this.decimals});

  final ShiftEquation equation;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final inRows = <(String, double)>[
      (l10n.shiftCompCashSales, equation.cashSales),
      (l10n.shiftCompCollections, equation.collections),
      (l10n.shiftCompOwnerDeposits, equation.ownerDeposits),
      (l10n.shiftCompTransfersIn, equation.transfersIn),
      (l10n.shiftCompBankIn, equation.bankIn),
      (l10n.shiftCompChequesCleared, equation.chequesCleared),
    ];
    final outRows = <(String, double)>[
      (l10n.shiftCompSupplierPayments, equation.supplierPayments),
      (l10n.shiftCompExpenses, equation.expenses),
      (l10n.shiftCompOwnerDraws, equation.ownerDraws),
      (l10n.shiftCompTransfersOut, equation.transfersOut),
      (l10n.shiftCompBankOut, equation.bankOut),
      (l10n.shiftCompChequesPaid, equation.chequesPaid),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EquationSection(
          title: l10n.shiftPrintDirIn,
          rows: inRows,
          totalLabel: l10n.shiftPrintTotalIn,
          total: equation.totalIn,
          incoming: true,
          decimals: decimals,
        ),
        const SizedBox(height: 10),
        _EquationSection(
          title: l10n.shiftPrintDirOut,
          rows: outRows,
          totalLabel: l10n.shiftPrintTotalOut,
          total: equation.totalOut,
          incoming: false,
          decimals: decimals,
        ),
        if (equation.other.abs() > 0.005) ...[
          const SizedBox(height: 10),
          _EquationSection(
            title: l10n.shiftCompOther,
            rows: <(String, double)>[
              (l10n.shiftCompOther, equation.other.abs()),
            ],
            totalLabel: l10n.shiftCompOther,
            total: equation.other,
            incoming: equation.other > 0,
            decimals: decimals,
          ),
        ],
        const SizedBox(height: 8),
        Text(
          l10n.shiftChequesDeferredNote,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// قسم من أقسام تفصيل المعادلة (وارد/صادر/أخرى) بتظليل لونه.
class _EquationSection extends StatelessWidget {
  const _EquationSection({
    required this.title,
    required this.rows,
    required this.totalLabel,
    required this.total,
    required this.incoming,
    required this.decimals,
  });

  final String title;
  final List<(String, double)> rows;
  final String totalLabel;
  final double total;
  final bool incoming;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final colors = FinColors.of(context);
    final tint = incoming ? colors.positiveContainer : colors.negativeContainer;
    final onTint = incoming
        ? colors.onPositiveContainer
        : colors.onNegativeContainer;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: onTint, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: onTint),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SectionValue(
                    value: value,
                    incoming: incoming,
                    decimals: decimals,
                  ),
                ],
              ),
            ),
          const Divider(height: 10, thickness: 0.6),
          Row(
            children: [
              Expanded(
                child: Text(
                  totalLabel,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: onTint, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              _SectionValue(
                value: total,
                incoming: incoming,
                decimals: decimals,
                strong: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// قيمة بند داخل أقسام التفصيل — صفرية البنود غير المنطبقة تظهر «—».
class _SectionValue extends StatelessWidget {
  const _SectionValue({
    required this.value,
    required this.incoming,
    required this.decimals,
    this.strong = false,
  });

  final double value;
  final bool incoming;
  final int decimals;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final sign = incoming ? FinSign.incoming : FinSign.outgoing;
    if (value.abs() < 0.005 && !strong) {
      return Text(
        '—',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontFeatures: FinText.tabularNums,
        ),
      );
    }
    return AmountText(
      amount: value,
      decimals: decimals,
      sign: sign,
      showSignMarker: false,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// نجاح الإقفال + تقرير PDF
// ─────────────────────────────────────────────────────────────────────

/// حوار نجاح الإقفال: ملخص + معاينة تقرير PDF + تم.
Future<void> _showCloseSuccess(
  BuildContext context,
  ShiftViewModel vm,
  ShiftCloseResult result,
) {
  final l10n = AppLocalizations.of(context)!;
  final colors = FinColors.of(context);
  final box = vm.state.boxFor(result.shift.cashboxId);
  final decimals = shiftDecimals(box?.box.currencyCode);
  final diff = result.shift.difference ?? 0;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: colors.positive, size: 26),
          const SizedBox(width: 10),
          Expanded(child: Text(l10n.shiftCloseSuccessTitle)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DialogRow(
            label: l10n.shiftExpectedLabel,
            amount: result.shift.expected ?? 0,
            decimals: decimals,
          ),
          _DialogRow(
            label: l10n.shiftCountedLabel,
            amount: result.shift.counted ?? 0,
            decimals: decimals,
          ),
          _DialogRow(
            label: l10n.shiftDifferenceLabel,
            amount: diff,
            decimals: decimals,
            colored: true,
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
          label: Text(l10n.shiftPdfPreviewAction),
          onPressed: () {
            Navigator.of(dialogContext).pop();
            _openShiftPdf(context, vm: vm, shift: result.shift);
          },
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.commonDone),
        ),
      ],
    ),
  );
}

/// سطر مبلغ داخل حوار النجاح.
class _DialogRow extends StatelessWidget {
  const _DialogRow({
    required this.label,
    required this.amount,
    required this.decimals,
    this.colored = false,
  });

  final String label;
  final double amount;
  final int decimals;
  final bool colored;

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
          const SizedBox(width: 8),
          AmountText(
            amount: amount,
            decimals: decimals,
            sign: colored
                ? (amount > 0.005
                      ? FinSign.incoming
                      : amount < -0.005
                      ? FinSign.outgoing
                      : FinSign.neutral)
                : FinSign.neutral,
            showSignMarker: false,
          ),
        ],
      ),
    );
  }
}

/// يفتح معاينة تقرير وردية PDF — المعادلة تُحسب على نافذة الوردية
/// المغلقة [opened_at, closed_at] داخل بنّاء الوثيقة (كل القيم تُلتقط
/// قبل أي await — لا سياق عبر فجوة غير متزامنة).
void _openShiftPdf(
  BuildContext context, {
  required ShiftViewModel vm,
  required ShiftRow shift,
}) {
  final l10n = AppLocalizations.of(context)!;
  final app = context.read<AppController>();
  final company = app.company;
  final box = vm.state.boxFor(shift.cashboxId);
  final boxName = box?.box.name ?? '';
  final currencyCode = box?.box.currencyCode ?? '';
  final decimals = shiftDecimals(currencyCode);
  final userName = vm.userName;
  unawaited(
    showPdfPreviewDialog(
      context,
      title: '${l10n.shiftPrintTitle} - $boxName',
      build: () async {
        final equation = await _equationForShift(vm, shift);
        final doc = buildShiftPrintDoc(
          l10n: l10n,
          shift: shift,
          equation: equation,
          boxName: boxName,
          userName: userName,
          company: company,
          currencyCode: currencyCode,
          decimals: decimals,
        );
        return const ShiftReportPdfBuilder().build(doc);
      },
      whatsappPhone: company?.whatsapp ?? company?.phone,
      shareMessage: l10n.shiftPrintShareMessage(
        boxName,
        AmountText.format(shift.expected ?? 0, decimals),
        AmountText.format(shift.difference ?? 0, decimals),
      ),
    ),
  );
}

/// معادلة وردية مقفلة — تُعاد من المستودع على نافذتها [opened, closed].
Future<ShiftEquation> _equationForShift(ShiftViewModel vm, ShiftRow shift) {
  return vm.shiftRepo.equationFor(
    cashboxId: shift.cashboxId,
    fromIso: shift.openedAt,
    toIso: shift.closedAt ?? DateTime.now().toUtc().toIso8601String(),
  );
}
