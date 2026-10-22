/// تذييل إجماليات تقرير أعمار الديون (V7-C — هوية SIM): شريط «الإجمالي
/// العام» **الداكن** بنمط SimDarkTotalBar (#546E7A ونص أبيض عريض) مع
/// شرح عدد المدينين تحته — نفس بيانات التذييل القائم (الإجمالي العام +
/// عدد المدينين؛ عملة التقرير معلنة بمحدد العملة وبطاقة الملخص).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../data/repositories/debt_aging_repository.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../sell/views/widgets/sim_invoice_widgets.dart'
    show SimDarkTotalBar;

/// تذييل الإجماليات — الشريط الداكن بالإجمالي العام وعدد المدينين.
class AgingFooterCard extends StatelessWidget {
  const AgingFooterCard({
    super.key,
    required this.report,
    required this.decimals,
  });

  final AgingReport report;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SimDarkTotalBar(
          label: l10n.agingTotalLabel,
          amount: AmountText.formatFor(context, report.grandTotal, decimals),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            l10n.agingCustomersCount(report.customersCount),
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
