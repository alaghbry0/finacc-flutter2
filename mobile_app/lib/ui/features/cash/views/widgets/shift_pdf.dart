/// يفتح معاينة تقرير وردية PDF — المعادلة تُحسب على نافذة الوردية
/// المغلقة [opened_at, closed_at] داخل بنّاء الوثيقة (كل القيم تُلتقط
/// قبل أي await — لا سياق عبر فجوة غير متزامنة).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../data/repositories/shift_repository.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/session/app_controller.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../printing/services/shift_report_pdf_builder.dart';
import '../../../printing/docs/shift_print_doc.dart';
import '../../../printing/views/pdf_preview_dialog.dart';
import '../../view_models/shift_view_model.dart';
import 'shift_format.dart';

void openShiftPdf(
  BuildContext context, {
  required ShiftViewModel vm,
  required ShiftRow shift,
}) {
  final l10n = AppLocalizations.of(context)!;
  final app = context.read<AppController>();
  final company = app.company;
  final box = vm.state.boxFor(shift.cashboxId);
  final boxName = box?.box.name ?? '';
  final currencyCode = box?.box.currencyCode ?? '';
  final decimals = shiftDecimals(currencyCode);
  final userName = vm.userName;
  unawaited(
    showPdfPreviewDialog(
      context,
      title: '${l10n.shiftPrintTitle} - $boxName',
      build: () async {
        final equation = await _equationForShift(vm, shift);
        final doc = buildShiftPrintDoc(
          l10n: l10n,
          shift: shift,
          equation: equation,
          boxName: boxName,
          userName: userName,
          company: company,
          currencyCode: currencyCode,
          decimals: decimals,
        );
        return const ShiftReportPdfBuilder().build(doc);
      },
      whatsappPhone: company?.whatsapp ?? company?.phone,
      shareMessage: l10n.shiftPrintShareMessage(
        boxName,
        AmountText.format(shift.expected ?? 0, decimals),
        AmountText.format(shift.difference ?? 0, decimals),
      ),
    ),
  );
}

/// معادلة وردية مقفلة — تُعاد من المستودع على نافذتها [opened, closed].
Future<ShiftEquation> _equationForShift(ShiftViewModel vm, ShiftRow shift) {
  return vm.shiftRepo.equationFor(
    cashboxId: shift.cashboxId,
    fromIso: shift.openedAt,
    toIso: shift.closedAt ?? DateTime.now().toUtc().toIso8601String(),
  );
}
