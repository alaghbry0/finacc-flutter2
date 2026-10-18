/// بطاقة بيانات الجرد: المخزن (عند التعدد) + تاريخ العدّ + اسم الجانِد +
/// الملاحظات المجموعة.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/stocktake_view_model.dart';
import 'stocktake_format.dart';

class StocktakeMetaCard extends StatelessWidget {
  const StocktakeMetaCard({
    super.key,
    required this.countedByController,
    required this.notesController,
    required this.onPickDate,
  });

  final TextEditingController countedByController;
  final TextEditingController notesController;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StocktakeViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    final countedAt = state.countedAt ?? DateTime.now();

    return FinCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.warehouses.length > 1) ...[
            DropdownButtonFormField<int>(
              initialValue: state.warehouseId,
              decoration: InputDecoration(
                labelText: l10n.stocktakeWarehouseLabel,
                prefixIcon: const Icon(Icons.warehouse_rounded),
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final warehouse in state.warehouses)
                  DropdownMenuItem<int>(
                    value: warehouse.id,
                    child: Text(warehouse.name),
                  ),
              ],
              onChanged: state.posting
                  ? null
                  : (value) {
                      if (value != null) unawaited(vm.setWarehouse(value));
                    },
            ),
            const SizedBox(height: 12),
          ],
          InkWell(
            onTap: state.posting ? null : onPickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.stocktakeCountedAtLabel,
                prefixIcon: const Icon(Icons.event_rounded),
                border: const OutlineInputBorder(),
              ),
              child: Text(
                stocktakeFormatDate(countedAt),
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(fontFeatures: FinText.tabularNums),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('stocktake_counted_by_field'),
            controller: countedByController,
            enabled: !state.posting,
            onChanged: vm.setCountedBy,
            decoration: InputDecoration(
              labelText: l10n.stocktakeCountedByLabel,
              helperText: l10n.stocktakeCountedByHint,
              prefixIcon: const Icon(Icons.badge_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesController,
            enabled: !state.posting,
            maxLength: 140,
            onChanged: vm.setNotes,
            decoration: InputDecoration(
              labelText: l10n.stocktakeNotesLabel,
              prefixIcon: const Icon(Icons.notes_rounded),
              counterText: '',
            ),
          ),
        ],
      ),
    );
  }
}
