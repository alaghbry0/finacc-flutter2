/// محرر خصم (سطر أو رأس) — تبديل نسبة/مبلغ + قيمة، بنتيجة (نوع، قيمة).
library;

import 'package:flutter/material.dart';

import '../../../../../domain/models/sale.dart';
import '../../../../../l10n/app_localizations.dart';

/// محرر خصم (سطر أو رأس) — تبديل نسبة/مبلغ + قيمة، بنتيجة (نوع، قيمة).
Future<(SaleDiscountType, double)?> showDiscountEditSheet(
  BuildContext context, {
  required String title,
  required SaleDiscountType initialType,
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
  final result = await showModalBottomSheet<(SaleDiscountType, double)>(
    context: context,
    isScrollControlled: true,
    // فوق شريط التبويبات (نفس قرار بقية نوافذ الكاشير).
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
                  SegmentedButton<SaleDiscountType>(
                    segments: [
                      ButtonSegment(
                        value: SaleDiscountType.amount,
                        label: Text(l10n.sellDiscountAmount),
                        icon: const Icon(Icons.sell_outlined),
                      ),
                      ButtonSegment(
                        value: SaleDiscountType.percent,
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
                      suffixText: type == SaleDiscountType.percent ? '%' : null,
                      errorText: error,
                      hintText: type == SaleDiscountType.percent
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
                          (type == SaleDiscountType.percent && value > 100)) {
                        setSheetState(
                          () => error = type == SaleDiscountType.percent
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
