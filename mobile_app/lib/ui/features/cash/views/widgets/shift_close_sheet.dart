// ─────────────────────────────────────────────────────────────────────
// نافذة الإقفال (نمط payment_sheet السفلية)
// ─────────────────────────────────────────────────────────────────────

/// يفتح نافذة إقفال الوردية — العدّ الفعلي + مقارنة حية + تفصيل المعادلة
/// القابل للطي + ملاحظات + تأكيد. عند النجاح تُغلق وتُعرض نافذة النجاح.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fin_error_card.dart';
import '../../view_models/shift_view_model.dart';
import 'cash_widgets.dart';
import 'shift_comparison_card.dart';
import 'shift_equation_breakdown.dart';
import 'shift_format.dart';
import 'shift_success_dialog.dart';

Future<void> showShiftCloseSheet(BuildContext context, ShiftViewModel vm) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // فوق شريط التبويبات (متصفح الفرع) — لا من أسفل الشاشة خلفه.
    useRootNavigator: false,
    builder: (_) => ChangeNotifierProvider<ShiftViewModel>.value(
      value: vm,
      child: const ShiftCloseSheet(),
    ),
  );
}

class ShiftCloseSheet extends StatefulWidget {
  const ShiftCloseSheet({super.key});

  @override
  State<ShiftCloseSheet> createState() => _ShiftCloseSheetState();
}

class _ShiftCloseSheetState extends State<ShiftCloseSheet> {
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
    unawaited(showShiftCloseSuccess(context, vm, result.valueOrNull!));
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
            ShiftComparisonCard(
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
              ShiftEquationBreakdown(
                equation: state.equation,
                decimals: decimals,
              ),
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
              FinErrorCard(message: vm.actionError!),
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
