/// ميتا تقرير الأرباح (الفترة + لحظة الإنشاء) — مستخرجة حرفياً من
/// `profit_report_screen.dart` (R20-D3d؛ كانت `_MetaFooter`).
library;

import 'package:flutter/material.dart';

import '../../../../../data/repositories/profit_report_repository.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/fin_date_text.dart';
import '../../view_models/profit_report_view_model.dart';

/// ميتا التقرير: الفترة + لحظة الإنشاء.
class ProfitReportMetaFooter extends StatelessWidget {
  const ProfitReportMetaFooter({
    super.key,
    required this.state,
    required this.report,
  });

  final ProfitReportState state;
  final ProfitReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final loadedAt = state.loadedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.profitPeriodLabel(
            FinDateText.date(context, report.from),
            FinDateText.date(context, report.to),
          ),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (loadedAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              l10n.profitGeneratedAt(FinDateText.dateTime(context, loadedAt)),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}
