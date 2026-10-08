/// مسقط تقرير الوردية للطباعة (الشريحة 9 — FR-04-04): إسقاط **نقي**
/// يُحوِّله قالب PDF إلى ورق — لا Flutter ولا I/O هنا إطلاقاً (نمط
/// `statement_print_doc.dart`).
///
/// قاعدة الملزمة المعمارية: كل نص داخل ملف PDF يمر عبر هذا المسقط
/// كتسمية **مسبقة التعريب** (يبنيها المجمِّع من l10n) — القالب نفسه بلا
/// أي نص حرفي قابل للترجمة غير اسم المنتج الثابت. الأرقام تُنسَّق عبر
/// `AmountText.format` (غربية بفواصل آلاف) والتواريخ والأزمنة بصيغة
/// `يوم/شهر/سنة ساعة:دقيقة` بأرقام غربية.
library;

import '../../../data/repositories/shift_repository.dart';
import '../../../domain/models/company.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/widgets/amount_text.dart';
import 'print_docs.dart';

/// سطر بند في جدول المعادلة — القيم سلاسل جاهزة للعرض.
class ShiftEquationLine {
  const ShiftEquationLine({
    required this.itemLabel,
    required this.directionLabel,
    required this.valueLabel,
  });

  /// اسم البند (مبيعات نقدية/تحصيلات/… — سلسلة جاهزة).
  final String itemLabel;

  /// اتجاه البند («وارد (+)»/«صادر (−)»/«—» — سلسلة جاهزة).
  final String directionLabel;

  /// القيمة منسَّقة («—» عند غير المنطبق — البنكي المدمج/الشيك المؤجل).
  final String valueLabel;
}

/// كل تسميات تقرير الوردية داخل الـPDF — مبنية من l10n عند التجميع.
class ShiftLabels {
  const ShiftLabels({
    required this.title,
    required this.box,
    required this.user,
    required this.opened,
    required this.closed,
    required this.itemCol,
    required this.directionCol,
    required this.valueCol,
    required this.dirIn,
    required this.dirOut,
    required this.dirNone,
    required this.openingCount,
    required this.totalIn,
    required this.totalOut,
    required this.expected,
    required this.counted,
    required this.difference,
    required this.surplus,
    required this.deficit,
    required this.matched,
    required this.notesRow,
    required this.chequesNote,
    required this.footerThanks,
  });

  /// عنوان المستند («تقرير الوردية»).
  final String title;

  /// تسمية حقل الصندوق.
  final String box;

  /// تسمية حقل المستخدم.
  final String user;

  /// تسمية حقل وقت الفتح.
  final String opened;

  /// تسمية حقل وقت الإقفال.
  final String closed;

  /// تسمية عمود البند.
  final String itemCol;

  /// تسمية عمود الاتجاه.
  final String directionCol;

  /// تسمية عمود القيمة.
  final String valueCol;

  /// تسمية اتجاه الوارد.
  final String dirIn;

  /// تسمية اتجاه الصادر.
  final String dirOut;

  /// بلا اتجاه (بنود غير منطبقة).
  final String dirNone;

  /// تسمية سطر الرصيد الافتتاحي.
  final String openingCount;

  /// تسمية سطر إجمالي الوارد.
  final String totalIn;

  /// تسمية سطر إجمالي الصادر.
  final String totalOut;

  /// تسمية سطر المتوقع.
  final String expected;

  /// تسمية سطر العدّ الفعلي.
  final String counted;

  /// تسمية سطر الفرق.
  final String difference;

  /// كلمة «زيادة».
  final String surplus;

  /// كلمة «عجز».
  final String deficit;

  /// كلمة «مطابق».
  final String matched;

  /// تسمية سطر ملاحظات الإقفال.
  final String notesRow;

  /// حاشية الشيكات المؤجلة أسفل الجدول.
  final String chequesNote;

  /// عبارة الشكر في التذييل.
  final String footerThanks;
}

/// مستند تقرير وردية قابل للطباعة — يغذي قالب A4.
class ShiftPrintDoc {
  const ShiftPrintDoc({
    required this.header,
    required this.boxName,
    this.userName,
    required this.openedAtLabel,
    required this.closedAtLabel,
    required this.currencyCode,
    required this.decimals,
    required this.lines,
    required this.openingCount,
    required this.totalIn,
    required this.totalOut,
    required this.expected,
    required this.counted,
    required this.difference,
    this.notes,
    required this.labels,
  });

  /// رأس المنشأة.
  final PrintHeader header;

  /// اسم الصندوق.
  final String boxName;

  /// اسم المستخدم (اختياري).
  final String? userName;

  /// وقت الفتح منسَّقاً (سلسلة جاهزة).
  final String openedAtLabel;

  /// وقت الإقفال منسَّقاً (سلسلة جاهزة).
  final String closedAtLabel;

  /// رمز عملة الصندوق.
  final String currencyCode;

  /// منازل العملة للعرض (YER = 0 — قرار المستدعي، قاعدة 5.4-9).
  final int decimals;

  /// بنود المعادلة منسَّقة مسبقاً.
  final List<ShiftEquationLine> lines;

  /// الرصيد الافتتاحي المسجَّل عند الفتح.
  final double openingCount;

  /// إجمالي الوارد.
  final double totalIn;

  /// إجمالي الصادر.
  final double totalOut;

  /// المتوقع = الافتتاحي + Σ الوارد − Σ الصادر (+ أخرى).
  final double expected;

  /// العدّ الفعلي المُدخل.
  final double counted;

  /// الفرق = المعدود − المتوقع (موجب زيادة/سالب عجز).
  final double difference;

  /// ملاحظات الإقفال (اختياري).
  final String? notes;

  /// كل تسميات المستند (مسبقة التعريب).
  final ShiftLabels labels;
}

/// يجمع مسقط تقرير الوردية — **نقيّ وقابل للاختبار**: لا BuildContext
/// ولا I/O؛ l10n يُمرَّر معلماً والتسميات تُبنى هنا كلها.
///
/// [shift] صف الوردية **المقفلة** (من `ShiftRepository.closeShift` أو
/// السجل) و[equation] معادلتها — لو مُرِّرت معادلة معدومة (تقرير من
/// السجل التاريخي دون إعادة الحساب) تُعرض البنود صفرية.
ShiftPrintDoc buildShiftPrintDoc({
  required AppLocalizations l10n,
  required ShiftRow shift,
  required ShiftEquation equation,
  required String boxName,
  String? userName,
  Company? company,
  required String currencyCode,
  required int decimals,
}) {
  final opened = DateTime.tryParse(shift.openedAt);
  final closed = shift.closedAt == null
      ? null
      : DateTime.tryParse(shift.closedAt!);

  String fmtMoney(double value) => AmountText.format(value, decimals);
  String fmtDir(double value) => value > 0.005
      ? l10n.shiftPrintDirIn
      : value < -0.005
      ? l10n.shiftPrintDirOut
      : '—';

  final inRows = <(String, double)>[
    (l10n.shiftCompCashSales, equation.cashSales),
    (l10n.shiftCompCollections, equation.collections),
    (l10n.shiftCompOwnerDeposits, equation.ownerDeposits),
    (l10n.shiftCompTransfersIn, equation.transfersIn),
  ];
  final outRows = <(String, double)>[
    (l10n.shiftCompSupplierPayments, equation.supplierPayments),
    (l10n.shiftCompExpenses, equation.expenses),
    (l10n.shiftCompOwnerDraws, equation.ownerDraws),
    (l10n.shiftCompTransfersOut, equation.transfersOut),
  ];
  // البنكي مدموج في التحويلات (لا عمود بنك في المخطط) والشيكات مؤجلة
  // (V1.1) — تُعرض «—» لتوثيق بنود المعادلة الشاملة كما وردت في SRS.
  final notApplicable = <String>[
    l10n.shiftCompBankIn,
    l10n.shiftCompChequesCleared,
    l10n.shiftCompBankOut,
    l10n.shiftCompChequesPaid,
  ];

  final lines = <ShiftEquationLine>[
    for (final (label, value) in inRows)
      ShiftEquationLine(
        itemLabel: label,
        directionLabel: l10n.shiftPrintDirIn,
        valueLabel: fmtMoney(value),
      ),
    for (final (label, value) in outRows)
      ShiftEquationLine(
        itemLabel: label,
        directionLabel: l10n.shiftPrintDirOut,
        valueLabel: fmtMoney(value),
      ),
    // «أخرى» موقعية (استردادات مرتجعات ورواتب مؤجلة) — تظهر إن أثّرت.
    if (equation.other.abs() > 0.005)
      ShiftEquationLine(
        itemLabel: l10n.shiftCompOther,
        directionLabel: fmtDir(equation.other),
        valueLabel: fmtMoney(equation.other.abs()),
      ),
    for (final label in notApplicable)
      ShiftEquationLine(itemLabel: label, directionLabel: '—', valueLabel: '—'),
  ];

  return ShiftPrintDoc(
    header: PrintHeader(
      name: company?.name ?? '',
      phone: company?.phone,
      address: company?.address,
      footerText: company?.footerText,
    ),
    boxName: boxName,
    userName: (userName ?? '').trim().isEmpty ? null : userName!.trim(),
    openedAtLabel: _fmtDateTime(opened),
    closedAtLabel: closed == null ? '—' : _fmtDateTime(closed),
    currencyCode: currencyCode,
    decimals: decimals,
    lines: lines,
    openingCount: shift.openingCount ?? 0,
    totalIn: equation.totalIn,
    totalOut: equation.totalOut,
    expected: shift.expected ?? 0,
    counted: shift.counted ?? 0,
    difference: shift.difference ?? 0,
    notes: (shift.notes ?? '').trim().isEmpty ? null : shift.notes!.trim(),
    labels: ShiftLabels(
      title: l10n.shiftPrintTitle,
      box: l10n.shiftPrintBox,
      user: l10n.shiftPrintUser,
      opened: l10n.shiftPrintOpened,
      closed: l10n.shiftPrintClosed,
      itemCol: l10n.shiftPrintItemCol,
      directionCol: l10n.shiftPrintDirectionCol,
      valueCol: l10n.shiftPrintValueCol,
      dirIn: l10n.shiftPrintDirIn,
      dirOut: l10n.shiftPrintDirOut,
      dirNone: '—',
      openingCount: l10n.shiftOpeningCountLabel,
      totalIn: l10n.shiftPrintTotalIn,
      totalOut: l10n.shiftPrintTotalOut,
      expected: l10n.shiftExpectedLabel,
      counted: l10n.shiftCountedLabel,
      difference: l10n.shiftDifferenceLabel,
      surplus: l10n.shiftSurplus,
      deficit: l10n.shiftDeficit,
      matched: l10n.shiftMatched,
      notesRow: l10n.shiftPrintNotesRow,
      chequesNote: l10n.shiftChequesDeferredNote,
      footerThanks: l10n.printingFooterThanks,
    ),
  );
}

/// تاريخ ووقت `يوم/شهر/سنة ساعة:دقيقة` بأرقام غربية جدولية.
String _fmtDateTime(DateTime? date) {
  if (date == null) return '—';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/${date.year} $hour:$minute';
}
