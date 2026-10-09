/// اختبارات ذهبية لمحرك قوالب فواتير المبيعات (موجة UX-3) — بناء مستند
/// كامل لكل قالب بخطوط Almarai/Noto الحقيقية (rootBundle عبر runAsync)
/// ونمط profit_report_pdf_builder_test: ترويسة `%PDF` + حجم منطقي +
/// عدد الصفحات + اتجاه الورق من `MediaBox` (الكلاسيكي أفقي والبسيط
/// عمودي والحراري رول 80مم واحدة)، وتدفق الكلاسيكي MultiPage للبنود
/// الكثيرة، وغياب الإعدادات = سلوك ما قبل الترقية حرفياً، ومصفوفة
/// `templateSupports`.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/features/printing/print_docs.dart';
import 'package:mobile_app/ui/features/printing/templates/classic_a4_template.dart';
import 'package:mobile_app/ui/features/printing/templates/invoice_template_engine.dart';
import 'package:mobile_app/ui/features/printing/templates/invoice_template_settings.dart';

import '../helpers/printing_docs_for_tests.dart';

void main() {
  Future<(Uint8List, int)> buildBytes(
    InvoicePrintDoc doc,
    InvoiceTemplateSettings? settings,
  ) async {
    final pdf = await const InvoiceTemplateEngine().build(doc, settings: settings);
    final bytes = await pdf.save();
    return (bytes, pdfPageCount(bytes));
  }

  /// يفك أبعاد أول MediaBox `[x0 y0 x1 y1]`.
  (double, double) firstPageSize(Uint8List bytes) {
    final box = pdfMediaBoxes(bytes).first;
    final parts = box
        .trim()
        .split(RegExp(r'\s+'))
        .map(double.parse)
        .toList();
    return (parts[2] - parts[0], parts[3] - parts[1]);
  }

  testWidgets('كلاسيكي A4: أفقي بصفحة مُأطَّرة واحدة وبصمة PDF سليمة', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      final doc = invoiceDocForTests(
        l10n,
        templateLabels: templateLabelsForTests(l10n),
        payStatusLabel: l10n.tmplTitleCash,
      );
      final (bytes, pages) = await buildBytes(
        doc,
        const InvoiceTemplateSettings(templateId: kInvoiceTemplateClassicA4),
      );
      expect(String.fromCharCodes(bytes, 0, 4), '%PDF');
      expect(bytes.length, greaterThan(15 * 1024));
      expect(pages, 1, reason: 'بنود ≤ سقف الصفحة الواحدة المُأطَّرة');
      final (w, h) = firstPageSize(bytes);
      expect(w, greaterThan(h), reason: 'الكلاسيكي أفقي بنموذج المالك');
      expect(w, closeTo(841.89, 0.5), reason: 'A4 عرضاً');
    });
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('بسيط A4: عمودي بصفحة واحدة (بصمة المتجر القائمة)', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      final doc = invoiceDocForTests(l10n);
      final (bytes, pages) = await buildBytes(
        doc,
        const InvoiceTemplateSettings(templateId: kInvoiceTemplateSimpleA4),
      );
      expect(String.fromCharCodes(bytes, 0, 4), '%PDF');
      expect(bytes.length, greaterThan(15 * 1024));
      expect(pages, 1);
      final (w, h) = firstPageSize(bytes);
      expect(h, greaterThan(w), reason: 'البسيط عمودي كما كان');
      expect(w, closeTo(595.27, 0.5), reason: 'A4 طولاً');
    });
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('حراري 80مم: رول واحدة بعرض 80مم يتقلص ارتفاعها للمحتوى', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      final doc = invoiceDocForTests(
        l10n,
        templateLabels: templateLabelsForTests(l10n),
        payStatusLabel: l10n.tmplTitleCash,
      );
      final (bytes, pages) = await buildBytes(
        doc,
        const InvoiceTemplateSettings(templateId: kInvoiceTemplateThermal80),
      );
      expect(String.fromCharCodes(bytes, 0, 4), '%PDF');
      expect(bytes.length, greaterThan(10 * 1024));
      expect(pages, 1, reason: 'إيصال رول واحد مهما طال المحتوى');
      final (w, h) = firstPageSize(bytes);
      expect(w, closeTo(80 * 72 / 25.4, 0.5), reason: 'عرض الرول 80مم');
      expect(h, lessThan(900), reason: 'الارتفاع بحجم المحتوى لا صفحة كاملة');
      expect(h, greaterThan(200), reason: 'ليس فارغاً');
    });
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('كلاسيكي ببنود فوق السقف: تدفق MultiPage لصفحات أفقية', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      final doc = invoiceDocForTests(
        l10n,
        itemCount: kClassicSinglePageMaxRows + 6,
        templateLabels: templateLabelsForTests(l10n),
      );
      final (bytes, pages) = await buildBytes(
        doc,
        const InvoiceTemplateSettings(templateId: kInvoiceTemplateClassicA4),
      );
      expect(pages, greaterThan(1), reason: 'فوق السقف يتدفق لصفحات إضافية');
      // كل الصفحات أفقية A4.
      for (final box in pdfMediaBoxes(bytes)) {
        final parts = box
            .trim()
            .split(RegExp(r'\s+'))
            .map(double.parse)
            .toList();
        expect(parts[2] - parts[0], greaterThan(parts[3] - parts[1]));
      }
    });
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('غياب الإعدادات = البسيط الافتراضي (سلوك ما قبل UX-3)', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      final doc = invoiceDocForTests(l10n);
      // بلا إعدادات إطلاقاً — مسار المستدعين القدامى.
      final (noSettings, pagesNone) = await buildBytes(doc, null);
      final (simple, pagesSimple) = await buildBytes(
        doc,
        const InvoiceTemplateSettings(templateId: kInvoiceTemplateSimpleA4),
      );
      expect(pagesNone, 1);
      expect(pagesSimple, 1);
      // نفس الورقة ونفس عدد مواضع النص — البصمة القائمة حرفياً.
      final (wNone, _) = firstPageSize(noSettings);
      final (wSimple, _) = firstPageSize(simple);
      expect(wNone, closeTo(wSimple, 0.01));
      expect(pdfTextOpCount(noSettings), pdfTextOpCount(simple));
    });
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('فهرس المحرك: القوالب الثلاثة بترتيب البذر بورقها واتجاهها', (
    tester,
  ) async {
    expect(
      InvoiceTemplateEngine.templates.map((t) => t.code).toList(),
      kInvoiceTemplateCodes,
    );
    final classic = InvoiceTemplateEngine.templates.first;
    expect(classic.paper, 'a4-landscape');
    expect(classic.landscape, isTrue);
    final simple = InvoiceTemplateEngine.templates[1];
    expect(simple.paper, 'a4-portrait');
    expect(simple.landscape, isFalse);
    final thermal = InvoiceTemplateEngine.templates[2];
    expect(thermal.paper, 'roll80');
    expect(thermal.landscape, isFalse);
  });

  testWidgets('مصفوفة templateSupports: التوقيعات/الختم للكلاسيكي حصراً', (
    tester,
  ) async {
    // مدعومة في الثلاثة.
    for (final code in kInvoiceTemplateCodes) {
      expect(templateSupports(code, TemplateFeature.discountColumn), isTrue);
      expect(templateSupports(code, TemplateFeature.unitColumn), isTrue);
      expect(templateSupports(code, TemplateFeature.barcode), isTrue);
      expect(templateSupports(code, TemplateFeature.tax), isTrue);
      expect(templateSupports(code, TemplateFeature.footer), isTrue);
    }
    // لغة النموذج الحكومي حصراً.
    expect(
      templateSupports(kInvoiceTemplateClassicA4, TemplateFeature.signatures),
      isTrue,
    );
    expect(
      templateSupports(kInvoiceTemplateClassicA4, TemplateFeature.stampArea),
      isTrue,
    );
    expect(
      templateSupports(kInvoiceTemplateSimpleA4, TemplateFeature.signatures),
      isFalse,
    );
    expect(
      templateSupports(kInvoiceTemplateThermal80, TemplateFeature.signatures),
      isFalse,
    );
    expect(
      templateSupports(kInvoiceTemplateSimpleA4, TemplateFeature.stampArea),
      isFalse,
    );
    expect(
      templateSupports(kInvoiceTemplateThermal80, TemplateFeature.stampArea),
      isFalse,
    );
    // الملاحظات: الكلاسيكي والحراري، لا البسيط (يبقى كما كان).
    expect(templateSupports(kInvoiceTemplateSimpleA4, TemplateFeature.notes),
        isFalse);
    expect(templateSupports(kInvoiceTemplateClassicA4, TemplateFeature.notes),
        isTrue);
    expect(templateSupports(kInvoiceTemplateThermal80, TemplateFeature.notes),
        isTrue);
  });
}
