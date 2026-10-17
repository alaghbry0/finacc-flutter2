/// قسم الدفعة الواردة لسطر متتبع — رقم الدفعة (حقل نصي) + الصلاحية
/// (رقاقة التاريخ + اختصارات +30/+90/+180 يوماً وسنة + التقويم).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../view_models/purchase_cart_view_model.dart';
import 'purchase_widgets.dart';

/// قسم الدفعة الواردة لسطر متتبع — رقم الدفعة (حقل نصي) + الصلاحية
/// (رقاقة التاريخ + اختصارات +30/+90/+180 يوماً وسنة + التقويم).
class PurchaseIncomingBatchSection extends StatefulWidget {
  const PurchaseIncomingBatchSection({super.key, required this.index});

  final int index;

  @override
  State<PurchaseIncomingBatchSection> createState() =>
      _PurchaseIncomingBatchSectionState();
}

class _PurchaseIncomingBatchSectionState
    extends State<PurchaseIncomingBatchSection> {
  late final TextEditingController _batchController;

  @override
  void initState() {
    super.initState();
    final line = context
        .read<PurchaseCartViewModel>()
        .state
        .lines[widget.index];
    _batchController = TextEditingController(text: line.batchNo);
  }

  @override
  void didUpdateWidget(covariant PurchaseIncomingBatchSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // مزامنة الحقل عند تغيّر قيمة السطر من خارج الحقل (تفريغ الفاتورة).
    final line = context
        .read<PurchaseCartViewModel>()
        .state
        .lines[widget.index];
    if (_batchController.text != line.batchNo) {
      _batchController.text = line.batchNo;
    }
  }

  @override
  void dispose() {
    _batchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PurchaseCartViewModel>();
    final state = vm.state;
    if (widget.index >= state.lines.length) return const SizedBox.shrink();
    final line = state.lines[widget.index];
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final missingBatch = line.batchNo.trim().isEmpty;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: missingBatch
              ? colors.warning.withValues(alpha: 0.7)
              : scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.layers_rounded,
                size: 16,
                color: missingBatch ? colors.warning : scheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.purIncomingBatchTitle,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: missingBatch ? colors.warning : scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: Key('pur_batch_field_${widget.index}'),
            controller: _batchController,
            onChanged: (value) => vm.setBatchNo(widget.index, value),
            decoration: InputDecoration(
              hintText: l10n.purBatchNoHint,
              isDense: true,
              prefixIcon: const Icon(Icons.tag_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  key: Key('pur_expiry_chip_${widget.index}'),
                  onTap: () => _pickExpiry(context, vm),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: line.expiryDate == null
                          ? colors.warningContainer
                          : scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_rounded,
                          size: 16,
                          color: line.expiryDate == null
                              ? colors.onWarningContainer
                              : scheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            line.expiryDate == null
                                ? l10n.purExpiryPick
                                : l10n.purExpiryValue(
                                    purFormatIsoDate(line.expiryDate!),
                                  ),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: line.expiryDate == null
                                      ? colors.onWarningContainer
                                      : scheme.onPrimaryContainer,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (label, days) in [
                (l10n.purExpiryQuickMonth, 30),
                (l10n.purExpiryQuick3Months, 90),
                (l10n.purExpiryQuick6Months, 180),
                (l10n.purExpiryQuickYear, 365),
              ])
                ActionChip(
                  key: Key('pur_expiry_quick_${days}_${widget.index}'),
                  label: Text(label),
                  onPressed: () => vm.setExpiry(
                    widget.index,
                    DateTime.now().add(Duration(days: days)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickExpiry(
    BuildContext context,
    PurchaseCartViewModel vm,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      helpText: l10n.purExpiryDialogTitle,
    );
    if (picked != null) {
      vm.setExpiry(widget.index, picked);
    }
  }
}
