/// اختبار طباعة البونص (موجة UX-4): `InvoicePrintLine.freeQtyLabel` —
/// المسقط الحقيقي (`buildInvoicePrintDoc`) يبني لاحقة «(+N مجاني)» بجوار
/// الكمية حصراً عند وجود بونص (freeQty > 0)، فتصبح خلية الكمية التي
/// ترسمها القوالب الثلاثة (`qtyCellLabel`) «الكمية (+N مجاني)»؛ وبلا
/// بونص تبقى الكمية وحدها كما اليوم (سلوك المتاجر القائمة). والقالب
/// البسيط يبني مستنداً سليماً بالمستند المحمّل بالبونص (نمط اختبارات
/// القوالب القائمة: خطوط حقيقية عبر runAsync + بصمة %PDF + صفحة واحدة).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/domain/models/sale.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/features/printing/templates/invoice_template_engine.dart';
import 'package:mobile_app/ui/features/printing/templates/invoice_template_settings.dart';
import 'package:mobile_app/ui/features/sell/views/widgets/invoice_pdf_preview.dart';

import '../helpers/printing_docs_for_tests.dart';

void main() {
  /// تفاصيل فاتورة مكتملة ببند واحد: 10 وحدات (± [freeQty] بونص) بسعر
  /// 100 — الرأس بأرقام متسقة مع القرار التحاسبي (الإيراد 1000 حصراً
  /// والتكلفة على المنصرف الكلي 720 عند بونص 2).
  SaleInvoiceDetail detailWith({required double freeQty}) => SaleInvoiceDetail(
    invoice: SaleInvoice(
      id: 7,
      invoiceNo: 'INV-2026-00007',
      payStatus: SalePaymentMethod.cash,
      status: 'completed',
      issuedAt: DateTime.utc(2026, 10, 8, 11, 30),
      warehouseId: 1,
      currencyId: 1,
      exchangeRate: 1,
      rateIsFallback: false,
      subtotal: 1000,
      discountAmount: 0,
      total: 1000,
      totalBase: 1000,
      paidAmount: 1000,
      dueAmount: 0,
      costTotal: freeQty > 0 ? 720 : 600,
    ),
    items: [
      SaleInvoiceItemLine(
        productId: 5,
        lineDesc: 'شامبو كلير 400 مل',
        qty: 10,
        unitPrice: 100,
        discountPercent: 0,
        discountAmount: 0,
        lineTotal: 1000,
        lineCost: freeQty > 0 ? 720 : 600,
        freeQty: freeQty,
      ),
    ],
    customerName: 'أحمد محمد الشرعبي',
    currencyCode: 'YER',
    currencySymbol: '﷼',
  );

  testWidgets(
    'المسقط: بند ببونص يحمل «(+2 مجاني)» بجوار الكمية — وبلا بونص الكمية وحدها',
    (tester) async {
      await tester.runAsync(() async {
        final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

        // بند ببونص 2: sellQtyText(2) = '2' → لاحقة «(+2 مجاني)».
        final withBonus = buildInvoicePrintDoc(
          l10n,
          detailWith(freeQty: 2),
          null,
        );
        final line = withBonus.items.single;
        expect(line.freeQtyLabel, '(+2 مجاني)');
        expect(
          line.qtyCellLabel,
          '10 (+2 مجاني)',
          reason: 'اللاحقة بجوار الكمية — الحقل الذي ترسمه القوالب',
        );

        // بند بلا بونص: null — الكمية وحدها (لا يعدّل سلوك المتاجر).
        final withoutBonus = buildInvoicePrintDoc(
          l10n,
          detailWith(freeQty: 0),
          null,
        );
        expect(withoutBonus.items.single.freeQtyLabel, isNull);
        expect(withoutBonus.items.single.qtyCellLabel, '10');
      });
    },
  );

  testWidgets('قالب بسيط A4 بمستند يحمل البونص: بصمة %PDF سليمة بصفحة واحدة', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      // مستند الاختبار القائم + لاحقة البونص كما يبنيها المسقط الحقيقي.
      final doc = invoiceDocForTests(
        l10n,
        itemCount: 1,
        freeQtyLabel: l10n.bonusPrintSuffix('2'),
      );
      expect(doc.items.single.qtyCellLabel, '3 (+2 مجاني)');

      final pdf = await const InvoiceTemplateEngine().build(
        doc,
        settings: const InvoiceTemplateSettings(
          templateId: kInvoiceTemplateSimpleA4,
        ),
      );
      final bytes = await pdf.save();
      expect(String.fromCharCodes(bytes, 0, 4), '%PDF');
      expect(bytes.length, greaterThan(15 * 1024));
      expect(pdfPageCount(bytes), 1);
    });
  }, timeout: const Timeout(Duration(minutes: 2)));
}
