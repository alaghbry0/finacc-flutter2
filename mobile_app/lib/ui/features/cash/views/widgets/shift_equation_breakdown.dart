/// تفصيل المعادلة الشاملة — قسم وارد أخضر وقسم صادر أحمر + أخرى + حاشية
/// الشيكات المؤجلة (كل مكون بتسميته العربية وقيمته بعملة الصندوق).
library;

import 'package:flutter/material.dart';

import '../../../../../data/repositories/shift_repository.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';

class ShiftEquationBreakdown extends StatelessWidget {
  const ShiftEquationBreakdown({
    super.key,
    required this.equation,
    required this.decimals,
  });

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
