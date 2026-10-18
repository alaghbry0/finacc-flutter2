/// بوابة سعر الصرف (FR-08-09) — مرآة بوابة البيع/الشراء فوق عقد عام.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fin_card.dart';
import 'cash_fields.dart';
import 'cash_sheet_drag_handle.dart';

/// يفتح بوابة إدخال سعر اليوم — يعيد `true` إذا حُفظ السعر بنجاح.
Future<bool> showCashFxGateSheet(
  BuildContext context, {
  required String currencyCode,
  required Future<bool> Function(double rate) onSave,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // فوق شريط التبويبات (متصفح الفرع) — لا من أسفل الشاشة خلفه.
    useRootNavigator: false,
    builder: (_) =>
        _CashFxGateSheet(currencyCode: currencyCode, onSave: onSave),
  );
  return saved ?? false;
}

class _CashFxGateSheet extends StatefulWidget {
  const _CashFxGateSheet({required this.currencyCode, required this.onSave});

  final String currencyCode;
  final Future<bool> Function(double rate) onSave;

  @override
  State<_CashFxGateSheet> createState() => _CashFxGateSheetState();
}

class _CashFxGateSheetState extends State<_CashFxGateSheet> {
  final TextEditingController _rateController = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final rate = CashAmountField.parse(_rateController.text);
    if (rate == null || rate <= 0) {
      setState(() => _error = l10n.fxRateInvalid);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.onSave(rate);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = l10n.genericErrorTitle;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CashSheetDragHandle(),
            const SizedBox(height: 16),
            FinCard(
              accent: colors.warning,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.currency_exchange_rounded,
                        color: colors.warning,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.sellFxGateTitle(widget.currencyCode),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.sellFxGateBody,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _rateController,
              autofocus: true,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,6}')),
              ],
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: l10n.sellFxGateFieldLabel,
                suffixText: widget.currencyCode,
                errorText: _error,
                helperText: l10n.sellFxGateFieldHelper,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : Text(l10n.sellFxGateSave),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _saving
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
          ],
        ),
      ),
    );
  }
}
