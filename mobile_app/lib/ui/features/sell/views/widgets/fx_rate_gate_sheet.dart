/// بوابة سعر الصرف (FR-08-09) — BottomSheet فوري عند اختيار عملة غير
/// الأساس بلا سعر اليوم: يشرح المنع، يستقبل السعر، يكتب عبر fx.setRate
/// ثم يتابع المستخدم الدفع.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/sell_cart_view_model.dart';

/// يفتح بوابة إدخال سعر اليوم — يعيد `true` إذا حُفظ السعر.
Future<bool> showFxRateGateSheet(
  BuildContext context, {
  required SellCartViewModel cartVm,
  required String currencyCode,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // فوق شريط التبويبات (متصفح الفرع) — لا من أسفل الشاشة خلفه.
    useRootNavigator: false,
    builder: (_) =>
        _FxRateGateSheet(cartVm: cartVm, currencyCode: currencyCode),
  );
  return saved ?? false;
}

class _FxRateGateSheet extends StatefulWidget {
  const _FxRateGateSheet({required this.cartVm, required this.currencyCode});

  final SellCartViewModel cartVm;
  final String currencyCode;

  @override
  State<_FxRateGateSheet> createState() => _FxRateGateSheetState();
}

class _FxRateGateSheetState extends State<_FxRateGateSheet> {
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
    final raw = _rateController.text.trim().replaceAll(',', '.');
    final rate = double.tryParse(raw);
    if (rate == null || rate.isNaN || rate.isInfinite || rate <= 0) {
      setState(() => _error = l10n.fxRateInvalid);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await widget.cartVm.saveTodayRate(rate);
    if (!mounted) return;
    if (result.isOk) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = result.errorOrNull!;
      });
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
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
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('sell_fx_rate_field'),
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
