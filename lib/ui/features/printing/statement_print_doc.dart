/// مسقط كشف حساب الطرف للطباعة (الشريحة 7 — مستند #3): إسقاط **نقي**
/// يُحوَّله قالب PDF إلى ورق، ودالة تجميع تبنيه من كشف المستودع مباشرة.
///
/// قاعدة الملزمة المعمارية (كما في `print_docs.dart`): كل نص داخل ملف PDF
/// يمر عبر هذا المسقط كتسمية **مسبقة التعريب** (يبنيها المجمِّع من l10n)
/// — القالب نفسه بلا أي نص حرفي قابل للترجمة غير اسم المنتج الثابت.
/// الأرقام تُنسَّق عبر `AmountText.format` (غربية بفواصل آلاف) فتصل سلاسل
/// جاهزة، والتواريخ بصيغة `يوم/شهر/سنة` بأرقام غربية.
library;

import '../../../domain/models/company.dart';
import '../../../domain/models/party.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/widgets/amount_text.dart';
import 'print_docs.dart';

/// سطر حركة في جدول الكشف — كل القيم سلاسل جاهزة للعرض.
class StatementPrintLine {
  const StatementPrintLine({
    required this.dateLabel,
    required this.descLabel,
    required this.debitLabel,
    required this.creditLabel,
    required this.balanceLabel,
  });

  /// تاريخ القيد منسَّقاً (سلسلة جاهزة).
  final String dateLabel;

  /// البيان: نوع القيد + رقم مستنده إن وُجد (سلسلة جاهزة).
  final String descLabel;

  /// المدين منسَّقاً («—» إن كان القيد دائناً/محايداً).
  final String debitLabel;

  /// الدائن منسَّقاً («—» إن كان القيد مديناً/محايداً).
  final String creditLabel;

  /// الرصيد الرأسي بعد القيد منسَّقاً (قد يكون سالباً).
  final String balanceLabel;
}

/// كل تسميات مستند الكشف داخل الـPDF — مبنية من l10n عند التجميع.
class StatementLabels {
  const StatementLabels({
    required this.title,
    required this.party,
    required this.generatedAt,
    required this.period,
    required this.currency,
    required this.dateCol,
    required this.descCol,
    required this.debitCol,
    required this.creditCol,
    required this.balanceCol,
    required this.totalDebit,
    required this.totalCredit,
    required this.closing,
    required this.emptyBody,
    required this.footerThanks,
  });

  /// عنوان المستند («كشف حساب»).
  final String title;

  /// تسمية حقل الطرف.
  final String party;

  /// تسمية حقل تاريخ الإصدار.
  final String generatedAt;

  /// تسمية حقل الفترة.
  final String period;

  /// تسمية حقل العملة.
  final String currency;

  /// تسمية عمود التاريخ.
  final String dateCol;

  /// تسمية عمود البيان.
  final String descCol;

  /// تسمية عمود المدين.
  final String debitCol;

  /// تسمية عمود الدائن.
  final String creditCol;

  /// تسمية عمود الرصيد.
  final String balanceCol;

  /// تسمية سطر إجمالي المدين.
  final String totalDebit;

  /// تسمية سطر إجمالي الدائن.
  final String totalCredit;

  /// تسمية الرصيد الختامي.
  final String closing;

  /// نص «لا قيود في هذه الفترة» عند كشف فارغ.
  final String emptyBody;

  /// عبارة الشكر في التذييل.
  final String footerThanks;
}

/// مستند كشف حساب طرف قابل للطباعة — يغذي قالب A4.
///
/// القيود مرتَّبة زمنياً تصاعدياً كما أعادها المستودع، والرصيد الافتتاحي
/// (أو «رصيد ماضٍ» عند تحديد بداية فترة) يظهر كأول سطر داخل الجدول —
/// مطابقاً حرفياً لما يعرضه كشف الحساب على الشاشة.
class StatementPrintDoc {
  const StatementPrintDoc({
    required this.header,
    required this.partyName,
    this.partyPhone,
    required this.generatedAtLabel,
    required this.periodLabel,
    required this.currencyCode,
    required this.decimals,
    required this.lines,
    required this.totalDebit,
    required this.totalCredit,
    required this.closingBalance,
    required this.labels,
  });

  /// رأس المنشأة.
  final PrintHeader header;

  /// اسم الطرف (عميل/مورد).
  final String partyName;

  /// هاتف الطرف (اختياري).
  final String? partyPhone;

  /// تاريخ إصدار الكشف منسَّقاً (سلسلة جاهزة).
  final String generatedAtLabel;

  /// الفترة المغطاة منسَّقة «من … إلى …» (سلسلة جاهزة).
  final String periodLabel;

  /// رمز عملة الكشف.
  final String currencyCode;

  /// منازل العملة للعرض (YER = 0 — قرار المستدعي، قاعدة 5.4-9).
  final int decimals;

  /// سطور الحركات منسَّقة مسبقاً.
  final List<StatementPrintLine> lines;

  /// إجمالي المدين (مجموع القيود الموجبة).
  final double totalDebit;

  /// إجمالي الدائن (مجموع القيم المطلقة للقيود السالبة).
  final double totalCredit;

  /// الرصيد الختامي (يطابق رصيد الطرف في عملة الكشف).
  final double closingBalance;

  /// كل تسميات المستند (مسبقة التعريب).
  final StatementLabels labels;
}

/// يجمع مسقط الكشف من نتيجة مستودع الأطراف — **نقيّ وقابل للاختبار**:
/// لا BuildContext ولا I/O؛ l10n يُمرَّر معلماً والتسميات تُبنى هنا كلها.
///
/// [statement] نتيجة `CustomerRepository.statement` / `SupplierRepository
/// .statement` (FR-03-04) بعملتها وفترتها. [from]/[to] فترة الكشف نفسها
/// (null = من أول حركة / حتى الآن) لتظهر في رأس المستند كما اختيرت على
/// الشاشة. [decimals] منازل عملة الكشف.
StatementPrintDoc buildStatementPrintDoc({
  required AppLocalizations l10n,
  required StatementResult statement,
  required String partyName,
  String? partyPhone,
  Company? company,
  required int decimals,
  DateTime? from,
  DateTime? to,
  DateTime? now,
}) {
  final generatedAt = now ?? DateTime.now();

  // الفترة المغطاة: من بداية الفترة المطلوبة أو أقدم حركة، حتى نهايتها
  // أو لحظة الإصدار (كشف بلا حركات ولا فترة = اليوم نفسه).
  final oldestEntry = statement.entries.isEmpty
      ? null
      : statement.entries.first.date;
  final effectiveFrom = from ?? oldestEntry ?? generatedAt;
  final effectiveTo = to ?? generatedAt;

  var totalDebit = 0.0;
  var totalCredit = 0.0;
  final lines = <StatementPrintLine>[];
  for (final entry in statement.entries) {
    final amount = entry.amount;
    if (amount > 0.005) totalDebit += amount;
    if (amount < -0.005) totalCredit -= amount;
    lines.add(
      StatementPrintLine(
        dateLabel: _fmtDate(entry.date),
        descLabel: _entryDesc(l10n, entry),
        debitLabel: amount > 0.005 ? AmountText.format(amount, decimals) : '—',
        creditLabel: amount < -0.005
            ? AmountText.format(-amount, decimals)
            : '—',
        balanceLabel: AmountText.format(entry.runningBalance, decimals),
      ),
    );
  }

  return StatementPrintDoc(
    header: PrintHeader(
      name: company?.name ?? '',
      phone: company?.phone,
      address: company?.address,
      footerText: company?.footerText,
    ),
    partyName: partyName,
    partyPhone: partyPhone,
    generatedAtLabel: _fmtDate(generatedAt),
    periodLabel: l10n.printingStatementPeriodRange(
      _fmtDate(effectiveFrom),
      _fmtDate(effectiveTo),
    ),
    currencyCode: statement.currencyCode,
    decimals: decimals,
    lines: lines,
    totalDebit: totalDebit,
    totalCredit: totalCredit,
    closingBalance: statement.finalBalance,
    labels: StatementLabels(
      title: l10n.printingStatementDocTitle,
      party: l10n.printingLblParty,
      generatedAt: l10n.printingLblGeneratedAt,
      period: l10n.printingLblPeriod,
      currency: l10n.printingLblCurrency,
      dateCol: l10n.printingLblDate,
      descCol: l10n.printingLblDescription,
      debitCol: l10n.printingStatementDebit,
      creditCol: l10n.printingStatementCredit,
      balanceCol: l10n.printingStatementBalance,
      totalDebit: l10n.printingStatementTotalDebit,
      totalCredit: l10n.printingStatementTotalCredit,
      closing: l10n.printingStatementClosing,
      emptyBody: l10n.printingStatementEmpty,
      footerThanks: l10n.printingFooterThanks,
    ),
  );
}

/// بيان القيد: نوعه المترجم + رقم مستنده إن وُجد.
String _entryDesc(AppLocalizations l10n, StatementEntry entry) {
  final kind = switch (entry.code) {
    StatementEntryCode.invoice => l10n.statementKindInvoice,
    StatementEntryCode.receipt => l10n.statementKindReceipt,
    StatementEntryCode.saleReturn => l10n.statementKindSaleReturn,
    StatementEntryCode.purchase => l10n.statementKindPurchase,
    StatementEntryCode.payment => l10n.statementKindPayment,
    StatementEntryCode.purchaseReturn => l10n.statementKindPurchaseReturn,
    StatementEntryCode.opening => l10n.statementKindOpening,
    StatementEntryCode.carryIn => l10n.statementKindCarryIn,
  };
  final docNo = (entry.docNo ?? '').trim();
  return docNo.isEmpty ? kind : '$kind $docNo';
}

/// تاريخ `يوم/شهر/سنة` بأرقام غربية جدولية (نمط طباعة الفاتورة/السند).
String _fmtDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year}';
