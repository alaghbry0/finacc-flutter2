/// البطاقة البطلة عند غياب وردية مفتوحة — رصيد افتتاحي + زر فتح كبير.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/fin_error_card.dart';
import '../../../../core/widgets/hub_hero_card.dart';
import '../../view_models/shift_view_model.dart';

class ShiftNoShiftCard extends StatefulWidget {
  const ShiftNoShiftCard({super.key});

  @override
  State<ShiftNoShiftCard> createState() => _ShiftNoShiftCardState();
}

class _ShiftNoShiftCardState extends State<ShiftNoShiftCard> {
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
    final state = vm.state;
    final box = state.boxFor(null);

    return HubHeroCard(
      icon: Icons.lock_clock_rounded,
      title: l10n.shiftOpenNoneTitle,
      subtitle: Text(
        l10n.shiftOpenNoneBody,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      // نموذج الفتح أسفل صف البطولة بفتحة below (W3/R17-b).
      below: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            FinErrorCard(message: vm.actionError!),
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
