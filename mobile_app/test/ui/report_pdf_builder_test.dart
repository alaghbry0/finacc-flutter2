/// اختبار باني PDF التقرير الجدولي العام (V7-B): يبني تقارير حقيقية
/// بخطوط Cairo/Noto الفعلية (نمط voucher_pdf_builder_test) ويفحص:
/// %PDF + صفحة واحدة للجدول القصير + **الترتيب الفيزيائي RTL للأعمدة**
/// (تحليل تيار محتوى PDF بعد فك zlib: مواضع أقنعة الأعمدة، عدّد
/// المحارف الرسومية لكل خلية، وخط كل خلية) + صف الإجمالي الداكن
/// (تعبئة brandDeep بنص أبيض) + جدول طويل متعدد الصفحات بلا استثناء
/// مع تكرار رأس الجدول أعلى الصفحة الثانية.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/ui/features/printing/docs/report_print_doc.dart';
import 'package:mobile_app/ui/features/printing/services/report_pdf_builder.dart';

import '../helpers/printing_docs_for_tests.dart' show pdfPageCount, probeHeader;

void main() {
  testWidgets('يبني تقريرًا قصيرًا بصفحة واحدة: %PDF + بنية الجدول RTL', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final pdf = await const ReportPdfBuilder().build(_shortDoc());
      final bytes = await pdf.save();
      expect(String.fromCharCodes(bytes, 0, 4), '%PDF');
      expect(bytes.length, greaterThan(6 * 1024));
      expect(pdfPageCount(bytes), 1, reason: 'الجدول القصير صفحة واحدة');

      final analysis = _analyze(bytes);
      // ── صف الرأس: 5 أعمدة فيزيائية بمواضع قص صاعدة ──
      final bands = analysis.cellBands;
      expect(bands.length, 3, reason: 'رأس + صف بيانات + صف إجمالي');
      final header = _sortedByX(bands[0]);
      expect(
        header.length,
        5,
        reason: 'عدد الأعمدة الفيزيائية = عدد المواصفات',
      );
      expect(
        header.map((c) => c.x).toSet().length,
        5,
        reason: 'خمسة مواضع أعمدة فيزيائية مميزة',
      );

      // ── الرأس RTL: أوسع عمود وأكثر محارف = عمود النص العربي أقصى اليمين
      //    (أول عمود منطقي بالقائمة) ──
      final rightmost = header.last;
      final leftmost = header.first;
      expect(
        rightmost.w,
        greaterThan(leftmost.w * 1.2),
        reason: 'عمود النص العربي (حصة 1.5) أعرض من الأعمدة الرقمية (1.0)',
      );
      expect(
        rightmost.glyphs,
        greaterThan(20),
        reason: 'تسمية العمود الأول الطويل تقع أقصى اليمين',
      );
      expect(
        rightmost.glyphs,
        greaterThan(leftmost.glyphs),
        reason: 'تسمية «إجمالي» القصيرة تقع أقصى اليسار (آخر عمود منطقي)',
      );

      // ── صف البيانات RTL: عدد محارف كل خلية فيزيائيًا يسار→يمين يعكس
      //    ترتيب القائمة المنطقية حرفيًا — الأرقام ASCII فعددها دقيق ──
      final data = _sortedByX(bands[1]);
      expect(
        data.map((c) => c.glyphs).toList(),
        [5, 2, 14, 1, greaterThan(5)],
        reason:
            'فيزيائي [8,500 | 99 | INV-2026-00001 | 3 | الاسم العربي] '
            '= عكس [الاسم، 3، المستند، 99، 8،500]',
      );
      expect(
        data.map((c) => c.font).toList(),
        [
          'NotoSansArabic-Regular',
          'NotoSansArabic-Regular',
          'Cairo-Regular',
          'NotoSansArabic-Regular',
          'Cairo-Regular',
        ],
        reason:
            'الخلايا الرقمية بالخط الجدولي المرافق يسارًا والعربية Cairo '
            'أقصى اليمين — والعمود ltr بخط الجسم',
      );

      // ── صف الإجمالي الداكن: تعبئة brandDeep بعرض الجدول كاملًا ونص
      //    أبيض جدولي عريض للأرقام ──
      expect(
        analysis.darkWideFills,
        greaterThanOrEqualTo(2),
        reason: 'شريط الهوية الداكن + شريط صف الإجمالي الداكن',
      );
      final total = _sortedByX(bands[2]);
      expect(total.length, 5);
      expect(
        total.every((c) => c.whiteText),
        isTrue,
        reason: 'نص صف الإجمالي أبيض فوق الشريط الداكن',
      );
      expect(total.map((c) => c.glyphs).toList(), [
        5,
        2,
        1,
        1,
        greaterThan(2),
      ], reason: 'صف الإجمالي معكوس فيزيائيًا أيضًا');
      expect(
        total.first.font,
        'NotoSansArabic-Bold',
        reason: 'رقم الإجمالي بأرقام جدولية عريضة (tabularHead)',
      );
      expect(
        total.last.font,
        'Cairo-Bold',
        reason: 'تسمية «الإجمالي» عريضة بيضاء',
      );

      // ── الترتيب الرأسي: الرأس أعلى، فالبيانات، فالإجمالي أسفلها ──
      expect(
        bands[2].map((c) => c.y).reduce((a, b) => a < b ? a : b),
        lessThan(bands[1].map((c) => c.y).reduce((a, b) => a > b ? a : b)),
        reason: 'صف الإجمالي أسفل صفوف البيانات (محور PDF لأعلى)',
      );
    });
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('جدول طويل (40 صفًا) يتدفق لصفحات برأس متكرر بلا استثناء', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final pdf = await const ReportPdfBuilder().build(_longDoc());
      final bytes = await pdf.save();
      expect(String.fromCharCodes(bytes, 0, 4), '%PDF');
      final pages = pdfPageCount(bytes);
      expect(pages, greaterThan(1), reason: '40 صفًا لا تتسع في صفحة A4');

      // رأس الجدول يتكرر أعلى كل صفحة: كل تيار محتوى يحمل تعبئة رأس
      // الجدول (tableHead) بعرض الجدول كاملًا.
      final streams = _contentStreams(bytes);
      expect(
        streams.length,
        pages,
        reason: 'تيار محتوى واحد لكل صفحة (البقية برامج خطوط)',
      );
      for (var i = 0; i < streams.length; i++) {
        expect(
          _hasWideTableHeadFill(streams[i]),
          isTrue,
          reason: 'رأس الجدول متكرر أعلى الصفحة ${i + 1}',
        );
      }
    });
  }, timeout: const Timeout(Duration(minutes: 2)));
}

// ---------------------------------------------------------------------
// مستندات الاختبار
// ---------------------------------------------------------------------

const List<ReportColumnSpec> _columns = [
  ReportColumnSpec('اسم الصنف الطويل جدًا لاختبار الترتيب'),
  ReportColumnSpec('كم', numeric: true),
  ReportColumnSpec('المستند', ltr: true),
  ReportColumnSpec('س', numeric: true),
  ReportColumnSpec('إجمالي', numeric: true),
];

ReportPrintDoc _shortDoc() => ReportPrintDoc(
  header: probeHeader(),
  title: 'المبيعات حسب الصنف',
  periodLabel: 'الفترة',
  periodText: 'من 01/10/2026 إلى 08/10/2026',
  dateLabel: 'تاريخ التقرير',
  dateText: '08/10/2026 14:30',
  columns: _columns,
  rows: const [
    ['شامبو كلير', '3', 'INV-2026-00001', '99', '8,500'],
  ],
  totalRow: const ['الإجمالي', '5', '2', '99', '8,500'],
  footerThanks: 'شكراً لتعاملكم معنا',
);

ReportPrintDoc _longDoc() => ReportPrintDoc(
  header: probeHeader(),
  title: 'حركات الأصناف',
  periodLabel: 'الفترة',
  periodText: 'من 01/10/2026 إلى 31/10/2026',
  dateLabel: 'تاريخ التقرير',
  dateText: '31/10/2026 23:45',
  columns: _columns,
  rows: [
    for (var i = 1; i <= 40; i++)
      ['صنف رقم $i بوصف عربي أطول قليلاً', '3', 'MV-2026-000$i', '99', '8,500'],
  ],
  totalRow: const ['الإجمالي', '120', '40', '99', '340,000'],
  footerThanks: 'شكراً لتعاملكم معنا',
);

// ---------------------------------------------------------------------
// محلل تيار محتوى PDF (فك zlib ثم مسح رمزي لعمليات الرسم)
// ---------------------------------------------------------------------

/// خلية جدول مرسومة: قناع القص (re W n) + المحارف المرسومة فيه + الخط.
class _Cell {
  const _Cell(
    this.x,
    this.y,
    this.w,
    this.h,
    this.glyphs,
    this.font,
    this.whiteText,
  );

  final double x;
  final double y;
  final double w;
  final double h;

  /// مجموع المحارف الرسومية (كل محرف رسومي = 4 خانات سداسية عشرية).
  final int glyphs;

  /// اسم BaseFont لآخر عملية نص داخل الخلية.
  final String font;

  /// هل نص الخلية أبيض (1 1 1 rg)؟
  final bool whiteText;
}

class _Analysis {
  const _Analysis({required this.cellBands, required this.darkWideFills});

  /// الصفوف بالترتيب: [رأس، صفوف البيانات…، الإجمالي] — كل صف أعمدته
  /// بترتيب الرسم الفيزيائي (يسار→يمين).
  final List<List<_Cell>> cellBands;

  /// عدد تعبئات brandDeep الداكنة بعرض الجدول (شريط الهوية + الإجمالي).
  final int darkWideFills;
}

_Analysis _analyze(Uint8List bytes) {
  final columnsPerRow = _columns.length;
  final fontNames = _fontNames(bytes);
  final streams = _contentStreams(bytes);
  final cells = <_Cell>[];
  var darkWideFills = 0;
  for (final stream in streams) {
    final scanned = _scanStream(stream);
    cells.addAll([
      for (final cell in scanned.cells)
        _Cell(
          cell.x,
          cell.y,
          cell.w,
          cell.h,
          cell.glyphs,
          fontNames[cell.font] ?? cell.font,
          cell.whiteText,
        ),
    ]);
    darkWideFills += scanned.darkWideFills;
  }
  // الصفوف تُرسم تتابعيًا: رأس ثم صفوف ثم إجمالي — تقطيع بعدد الأعمدة.
  final bands = <List<_Cell>>[];
  for (var i = 0; i + columnsPerRow <= cells.length; i += columnsPerRow) {
    bands.add(cells.sublist(i, i + columnsPerRow));
  }
  return _Analysis(cellBands: bands, darkWideFills: darkWideFills);
}

/// معرّفات الخطوط داخل PDF (‎/F6 مثلًا) → أسمائها (Cairo-Bold…) —
/// من كائنات الخطوط `/Name/F#…/BaseFont/<name>` غير المضغوطة.
Map<String, String> _fontNames(Uint8List bytes) {
  final raw = latin1.decode(bytes, allowInvalid: true);
  final names = <String, String>{};
  for (final match in RegExp(
    r'/Name/(F\d+)[^>]{0,300}?/BaseFont/([A-Za-z0-9+\-]+)',
  ).allMatches(raw)) {
    names[match.group(1)!] = match.group(2)!;
  }
  return names;
}

class _StreamScan {
  const _StreamScan({required this.cells, required this.darkWideFills});
  final List<_Cell> cells;
  final int darkWideFills;
}

/// يمسح تيار محتوى رمزيًا: قناع القص `x y w h re W n` يفتح خلية،
/// `[…]TJ` يضيف محارفها للخلية الجارية بخطها ولونها، و`re … rg f`
/// يسجل التعبئات (الداكنة العريضة منها لصف الإجمالي وشريط الهوية).
_StreamScan _scanStream(String content) {
  final tokens = content
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList(growable: false);

  final cells = <_Cell>[];
  var darkWideFills = 0;

  // حالة المسح.
  var font = '';
  var red = 0.0, green = 0.0, blue = 0.0;
  double? rectX, rectY, rectW, rectH;
  _CellBuilder? current;
  var arrayOpen = false;
  var arrayGlyphs = 0;

  void closeCell() {
    final builder = current;
    if (builder != null) {
      cells.add(builder.build());
      current = null;
    }
  }

  for (var i = 0; i < tokens.length; i++) {
    final token = tokens[i];
    if (token == 're') {
      rectX = _num(tokens, i - 4);
      rectY = _num(tokens, i - 3);
      rectW = _num(tokens, i - 2);
      rectH = _num(tokens, i - 1);
    } else if (token == 'W' && i + 1 < tokens.length && tokens[i + 1] == 'n') {
      // قناع قص خلية — يفتح خلية جديدة (يغلق السابقة).
      closeCell();
      if (rectX != null && rectY != null && rectW != null && rectH != null) {
        current = _CellBuilder(rectX, rectY, rectW, rectH);
      }
    } else if (token == 'rg') {
      red = _num(tokens, i - 3) ?? red;
      green = _num(tokens, i - 2) ?? green;
      blue = _num(tokens, i - 1) ?? blue;
    } else if (token == 'f') {
      // تعبئة المستطيل الأخير باللون الجاري.
      final w = rectW;
      if (w != null && w > 400) {
        // brandDeep = ‎0.05098 0.16863 0.27059 (PrintPalette).
        if ((red - 0.05098).abs() < 0.002 &&
            (green - 0.16863).abs() < 0.002 &&
            (blue - 0.27059).abs() < 0.002) {
          darkWideFills++;
        }
      }
    } else if (token == 'Tf') {
      if (i >= 2 && tokens[i - 2].startsWith('/F')) {
        font = tokens[i - 2].substring(1);
      }
    } else if (token.startsWith('[')) {
      // مصفوفة نص TJ — قد تكتمل بالرمز نفسه ([<…>]TJ بلا فراغات).
      arrayOpen = true;
      arrayGlyphs = _hexGlyphs(token);
      if (token.endsWith(']TJ') || token.endsWith(']Tj')) {
        current?.add(arrayGlyphs, font, red, green, blue);
        arrayOpen = false;
      }
    } else if (arrayOpen) {
      arrayGlyphs += _hexGlyphs(token);
      if (token.endsWith(']TJ') || token.endsWith(']Tj')) {
        current?.add(arrayGlyphs, font, red, green, blue);
        arrayOpen = false;
      }
    }
  }
  closeCell();
  return _StreamScan(cells: cells, darkWideFills: darkWideFills);
}

/// بانٍ خلية أثناء المسح (قابل للتغيير).
class _CellBuilder {
  _CellBuilder(this.x, this.y, this.w, this.h);

  final double x, y, w, h;
  int glyphs = 0;
  String font = '';
  bool whiteText = false;

  void add(int glyphs, String font, double red, double green, double blue) {
    this.glyphs += glyphs;
    if (font.isNotEmpty) this.font = font;
    whiteText = whiteText || (red > 0.99 && green > 0.99 && blue > 0.99);
  }

  _Cell build() => _Cell(x, y, w, h, glyphs, font, whiteText);
}

double? _num(List<String> tokens, int index) {
  if (index < 0 || index >= tokens.length) return null;
  return double.tryParse(tokens[index]);
}

int _hexGlyphs(String token) {
  var glyphs = 0;
  for (final match in RegExp(r'<([0-9a-fA-F]+)>').allMatches(token)) {
    glyphs += match.group(1)!.length ~/ 4;
  }
  return glyphs;
}

List<_Cell> _sortedByX(List<_Cell> band) {
  final sorted = List<_Cell>.of(band)..sort((a, b) => a.x.compareTo(b.x));
  return sorted;
}

/// تيارات محتوى PDF (بعد فك zlib) — تيار لكل صفحة، بترتيب الصفحات.
List<String> _contentStreams(Uint8List bytes) {
  final raw = latin1.decode(bytes, allowInvalid: true);
  final streams = <String>[];
  var searchFrom = 0;
  while (true) {
    final startMatch = RegExp(r'stream\r?\n')
        .firstMatch(raw.substring(searchFrom));
    if (startMatch == null) break;
    final start = searchFrom + startMatch.end;
    final end = raw.indexOf('endstream', start);
    if (end < 0) break;
    try {
      final inflated = ZLibDecoder().convert(
        Uint8List.fromList(latin1.encode(raw.substring(start, end))),
      );
      final text = latin1.decode(inflated, allowInvalid: true);
      if (text.contains('TJ')) streams.add(text);
    } catch (_) {
      // ليس مستخلص zlib (برنامج خط مثلًا) — تجاهل.
    }
    searchFrom = end + 'endstream'.length;
  }
  return streams;
}

bool _hasWideTableHeadFill(String stream) {
  // tableHead = ‎0.87059 0.90588 0.94902 (PrintPalette) بعرض الجدول.
  final pattern = RegExp(
    r'[\d.\-]+ [\d.\-]+ ([\d.]+) [\d.]+ re '
    r'0\.87059 0\.90588 0\.94902 rg f',
  );
  return pattern.allMatches(stream).any((m) {
    final width = double.tryParse(m.group(1) ?? '0') ?? 0;
    return width > 400;
  });
}
