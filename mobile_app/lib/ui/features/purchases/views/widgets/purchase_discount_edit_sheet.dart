/// محرر خصم الشراء بنافذة سفلية (R19-D3a — مستخرج حرفياً من
/// `purchase_widgets.dart` بلا أي تغيير دلالة).
library;

import 'package:flutter/material.dart';

import '../../../../../domain/models/purchase.dart';
import '../../../../../l10n/app_localizations.dart';

/// محرر خصم شراء (سطر أو رأس) — تبديل نسبة/مبلغ + قيمة.
Future<(PurchaseDiscountType, double)?> showPurchaseDiscountEditSheet(
  BuildContext context, {
  required String title,
  required PurchaseDiscountType initialType,
  required double initialValue,
}) async {
  var type = initialType;
  final controller = TextEditingController(
    text: initialValue == 0
        ? ''
        : initialValue == initialValue.truncateToDouble()
        ? initialValue.truncate().toString()
        : initialValue.toString(),
  );
  String? error;
  final result = await showModalBottomSheet<(PurchaseDiscountType, double)>(
    context: context,
    isScrollControlled: true,
    // فوق شريط التبويبات (نفس قرار بقية نوافذ الوحدة).
    useRootNavigator: false,
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext)!;
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<PurchaseDiscountType>(
                    segments: [
                      ButtonSegment(
                        value: PurchaseDiscountType.amount,
                        label: Text(l10n.sellDiscountAmount),
                        icon: const Icon(Icons.sell_outlined),
                      ),
                      ButtonSegment(
                        value: PurchaseDiscountType.percent,
                        label: Text(l10n.sellDiscountPercent),
                        icon: const Icon(Icons.percent_rounded),
                      ),
                    ],
                    selected: {type},
                    onSelectionChanged: (selection) {
                      setSheetState(() => type = selection.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) {
                      if (error != null) {
                        setSheetState(() => error = null);
                      }
                    },
                    decoration: InputDecoration(
                      suffixText: type == PurchaseDiscountType.percent
                          ? '%'
                          : null,
                      errorText: error,
                      hintText: type == PurchaseDiscountType.percent
                          ? l10n.sellDiscountPercentHint
                          : l10n.sellDiscountAmountHint,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () {
                      final raw = controller.text.trim().replaceAll(',', '.');
                      final value = raw.isEmpty ? 0.0 : double.tryParse(raw);
                      if (value == null ||
                          value.isNaN ||
                          value < 0 ||
                          (type == PurchaseDiscountType.percent &&
                              value > 100)) {
                        setSheetState(
                          () => error = type == PurchaseDiscountType.percent
                              ? l10n.sellDiscountPercentError
                              : l10n.sellDiscountAmountError,
                        );
                        return;
                      }
                      Navigator.of(sheetContext).pop((type, value));
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(l10n.sellDiscountApply),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: Text(l10n.commonCancel),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
  controller.dispose();
  return result;
}
