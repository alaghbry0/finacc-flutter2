/// اختبار انحدار بنّاء PDF السند المرقَّم (موجة 1-a — UX-audit
/// A3/A5/A9): الطرف والصندوق كانا يُرسمان مفككين معكوسين لأن قيمة
/// `_kvLine` تمر بلا `textDirection.rtl`، وكانت أسماء شائعة تكسر
/// `pdf.save` بالكامل. هنا يُبنى سند قبض وسند صرف بخطوط Almarai
/// الحقيقية بأسماء كاسرة ويُفحص: %PDF + الحجم + صفحة A5 واحدة
/// (معطيات السند محدودة أصلاً).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/features/printing/services/voucher_pdf_builder.dart';

import '../helpers/printing_docs_for_tests.dart';

void main() {
  testWidgets('يبني سند قبض كاملاً بصفحة واحدة باسم طرف كاسر', (tester) async {
    await tester.runAsync(() async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      final doc = voucherDocForTests(
        l10n,
        partyName: 'أحمد محمد الشرعبي',
        boxName: 'الصندوق الرئيسي',
      );
      final pdf = await const VoucherPdfBuilder().build(doc);
      final bytes = await pdf.save();
      expect(String.fromCharCodes(bytes, 0, 4), '%PDF');
      expect(bytes.length, greaterThan(6 * 1024));
      expect(pdfPageCount(bytes), 1, reason: 'السند صفحة A5 واحدة دائماً');
    });
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('كل أسماء pdfprobe (الكاسرة سابقاً) تبني سنداً بنجاح', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      for (var i = 0; i < kPdfProbeNames.length; i++) {
        // بالتناوب: قبض/صرف + الاسم مرة طرفاً ومرة صندوقاً (كلاهما
        // يمر عبر `_kvLine` المُصلَحة).
        final name = kPdfProbeNames[i];
        final doc = voucherDocForTests(
          l10n,
          partyName: i.isEven ? name : 'عميل نقدي',
          boxName: i.isOdd ? name : 'الصندوق الرئيسي',
          isReceipt: i.isEven,
        );
        final pdf = await const VoucherPdfBuilder().build(doc);
        final bytes = await pdf.save();
        expect(String.fromCharCodes(bytes, 0, 4), '%PDF', reason: name);
        expect(bytes.length, greaterThan(4 * 1024), reason: name);
        expect(pdfPageCount(bytes), 1, reason: name);
      }
    });
  }, timeout: const Timeout(Duration(minutes: 3)));
}
