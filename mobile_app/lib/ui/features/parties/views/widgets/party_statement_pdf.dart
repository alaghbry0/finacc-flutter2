/// ─────────────────────────────────────────────────────────────────────
/// طباعة كشف الحساب PDF (الشريحة 7 — مستند #3) — إسقاط + معاينة
/// ─────────────────────────────────────────────────────────────────────
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/session/app_controller.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../printing/services/statement_pdf_builder.dart';
import '../../../printing/docs/statement_print_doc.dart';
import '../../../printing/views/pdf_preview_dialog.dart';
import '../../view_models/party_detail_view_model.dart';

/// يفتح نافذة معاينة طباعة كشف حساب الطرف — القيم كلها تُلتقط قبل أي
/// await (لا سياق عبر فجوة غير متزامنة). يطبع الكشف **كما هو معروض**:
/// بعملته المحددة وفترته المختارة (افتراضياً من أول حركة حتى اليوم)،
/// والرصيد الافتتاحي/«رصيد ماضٍ» يظهر كأول سطر داخل الجدول كما في
/// الشاشة. واتساب = واتساب المنشأة وإلا واتساب الطرف فهاتفه، ورسالة
/// المشاركة تحمل اسم الطرف ورصيده الختامي.
void openPartyStatementPdf(BuildContext context, PartyDetailState state) {
  final l10n = AppLocalizations.of(context)!;
  final company = context.read<AppController>().company;
  final record = state.record!;
  final statement = state.statement!;
  final doc = buildStatementPrintDoc(
    l10n: l10n,
    statement: statement,
    partyName: record.name,
    partyPhone: record.phone,
    company: company,
    decimals: state.statementDecimals,
    from: state.from,
    to: state.to,
  );
  unawaited(
    showPdfPreviewDialog(
      context,
      title: '${l10n.printingStatementDocTitle} - ${record.name}',
      build: () => const StatementPdfBuilder().build(doc),
      whatsappPhone: company?.whatsapp ?? record.whatsapp ?? record.phone,
      shareMessage: l10n.printingShareMessageStatement(
        record.name,
        AmountText.format(statement.finalBalance, state.statementDecimals),
      ),
    ),
  );
}
