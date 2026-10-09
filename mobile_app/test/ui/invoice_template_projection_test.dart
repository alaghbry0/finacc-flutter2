/// اختبارات إسقاط التفضيلات على المستند (موجة UX-3) — تبديل مفتاح
/// إظهار من `InvoiceTemplateSettings` **يغيّر المسقط المرسوم فعلاً**:
/// إخفاء عمود الخصم ينقص مواضع النص المرسومة بعدد خاناته المحذوفة،
/// وإدراج عمود الوحدة يضيف خاناته، وتشغيل الباركود الحراري يمدّد رول
/// الإيصال — عبر عدّاد `pdfTextOpCount` (مواضع TJ بعد فك zlib) المعصوم
/// من طوابع الوقت، ومن `MediaBox` للرول المتقلص مع المحتوى.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/features/printing/print_docs.dart';
import 'package:mobile_app/ui/features/printing/templates/invoice_template_engine.dart';
import 'package:mobile_app/ui/features/printing/templates/invoice_template_settings.dart';

import '../helpers/printing_docs_for_tests.dart';

void main() {
  Future<Uint8List> build(
    InvoicePrintDoc doc,
    InvoiceTemplateSettings settings,
  ) async {
    final pdf = await const InvoiceTemplateEngine().build(doc, settings: settings);
    return pdf.save();
  }

  double rollHeight(Uint8List bytes) {
    final parts = pdfMediaBoxes(bytes)
        .first
        .trim()
        .split(RegExp(r'\s+'))
        .map(double.parse)
        .toList();
    return parts[3] - parts[1];
  }

  testWidgets('بسيط A4: إخفاء عمود الخصم ينقص مواضع النص المرسومة', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      final doc = invoiceDocForTests(l10n, itemCount: 2);
      final withDiscount = await build(
        doc,
        const InvoiceTemplateSettings(templateId: kInvoiceTemplateSimpleA4),
      );
      final withoutDiscount = await build(
        doc,
        const InvoiceTemplateSettings(
          templateId: kInvoiceTemplateSimpleA4,
          showDiscountColumn: false,
        ),
      );
      final withCount = pdfTextOpCount(withDiscount);
      final withoutCount = pdfTextOpCount(withoutDiscount);
      // عمود كامل (رأس + صفّان) يختفي من الرسم.
      expect(withoutCount, lessThan(withCount));
      expect(
        withCount - withoutCount,
        greaterThanOrEqualTo(3),
        reason: 'رأس العمود + خانتا الصفين على الأقل',
      );
    });
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('بسيط A4: إدراج عمود الوحدة يضيف خاناته للرسم', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      // الوحدة متوفرة بالمسقط + تسمية العمود معربة.
      final doc = invoiceDocForTests(
        l10n,
        itemCount: 2,
        unitLabel: 'علبة',
        templateLabels: templateLabelsForTests(l10n),
      );
      final withUnit = await build(
        doc,
        const InvoiceTemplateSettings(
          templateId: kInvoiceTemplateSimpleA4,
          showUnitColumn: true,
        ),
      );
      final withoutUnit = await build(
        doc,
        const InvoiceTemplateSettings(templateId: kInvoiceTemplateSimpleA4),
      );
      expect(
        pdfTextOpCount(withUnit),
        greaterThan(pdfTextOpCount(withoutUnit)),
        reason: 'رأس الوحدة + خانتا «علبة» ترسمان الآن',
      );
    });
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('كلاسيكي A4: إخفاء عمود الخصم ينقص مواضع النص المرسومة', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      final doc = invoiceDocForTests(
        l10n,
        itemCount: 2,
        templateLabels: templateLabelsForTests(l10n),
      );
      final withDiscount = await build(
        doc,
        const InvoiceTemplateSettings(templateId: kInvoiceTemplateClassicA4),
      );
      final withoutDiscount = await build(
        doc,
        const InvoiceTemplateSettings(
          templateId: kInvoiceTemplateClassicA4,
          showDiscountColumn: false,
        ),
      );
      final withCount = pdfTextOpCount(withDiscount);
      final withoutCount = pdfTextOpCount(withoutDiscount);
      expect(withoutCount, lessThan(withCount));
      expect(
        withCount - withoutCount,
        greaterThanOrEqualTo(3),
        reason: 'عمود الخصول بالجدول الحكومي يُسقط كاملاً',
      );
    });
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('كلاسيكي A4: إدراج عمود الوحدة يغيّر مسقط الجدول', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      final doc = invoiceDocForTests(
        l10n,
        itemCount: 2,
        unitLabel: 'علبة',
        templateLabels: templateLabelsForTests(l10n),
      );
      final withUnit = await build(
        doc,
        const InvoiceTemplateSettings(
          templateId: kInvoiceTemplateClassicA4,
          showUnitColumn: true,
        ),
      );
      final withoutUnit = await build(
        doc,
        const InvoiceTemplateSettings(templateId: kInvoiceTemplateClassicA4),
      );
      // العمود الجديد يعيد توزيع الجدول (رأس + خانات وحدة + إعادة لف
      // الأعمدة) — المسقط يتغير لا محالة.
      expect(
        pdfTextOpCount(withUnit),
        isNot(pdfTextOpCount(withoutUnit)),
        reason: 'إدراج عمود يعيد توزيع أعمدة الجدول الحكومي',
      );
      // وكلاهما صفحة واحدة مُأطَّرة.
      expect(pdfPageCount(withUnit), 1);
      expect(pdfPageCount(withoutUnit), 1);
    });
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('حراري 80مم: تشغيل الباركود يمدّد رول الإيصال', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      final doc = invoiceDocForTests(
        l10n,
        templateLabels: templateLabelsForTests(l10n),
      );
      final withBarcode = await build(
        doc,
        const InvoiceTemplateSettings(
          templateId: kInvoiceTemplateThermal80,
          showBarcode: true,
        ),
      );
      final withoutBarcode = await build(
        doc,
        const InvoiceTemplateSettings(templateId: kInvoiceTemplateThermal80),
      );
      // الرول يتقلص مع المحتوى: الباركود يضيف ~11مم رسماً + سطر الرقم.
      expect(
        rollHeight(withBarcode),
        greaterThan(rollHeight(withoutBarcode) + 20),
        reason: 'باركود Code128 بارتفاع 11مم يُرسم فعلاً أسفل الإيصال',
      );
      // وكلاهما يبقى رولاً واحدة.
      expect(pdfPageCount(withBarcode), 1);
      expect(pdfPageCount(withoutBarcode), 1);
    });
  }, timeout: const Timeout(Duration(minutes: 2)));
}
