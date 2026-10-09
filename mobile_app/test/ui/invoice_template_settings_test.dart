/// اختبارات نموذج إعدادات القالب (موجة UX-3) — نقاء JSON: roundtrip
/// كامل، copyWith انتقائي، التحمّل الدفاعي (كل قيمة تالفة/غائبة ترد
/// للافتراض فلا يكسر تخصيصٌ سيئ طباعةَ المتجر)، واشتقاق الورق.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/ui/features/printing/templates/invoice_template_settings.dart';

void main() {
  test('copyWith يعدّل المفتاح المطلوب حصراً ويبقي البقية', () {
    const base = InvoiceTemplateSettings();
    final toggled = base.copyWith(
      templateId: kInvoiceTemplateThermal80,
      showBarcode: true,
      badge: InvoiceBadgeMode.copy,
    );
    expect(toggled.templateId, kInvoiceTemplateThermal80);
    expect(toggled.showBarcode, isTrue);
    expect(toggled.badge, InvoiceBadgeMode.copy);
    // البقية كما كانت.
    expect(toggled.showDiscountColumn, base.showDiscountColumn);
    expect(toggled.tableHeadArgb, base.tableHeadArgb);
    // والأصل لم يُمس.
    expect(base.templateId, kInvoiceTemplateSimpleA4);
    expect(base.showBarcode, isFalse);
  });

  test('toJson/fromJson roundtrip كامل بلا فقد', () {
    const original = InvoiceTemplateSettings(
      templateId: kInvoiceTemplateClassicA4,
      tableHeadArgb: 0xFF9DC3E6,
      borderArgb: 0xFF37474F,
      accentRedArgb: 0xFFC62828,
      showDiscountColumn: false,
      showUnitColumn: true,
      showBarcode: true,
      showTax: true,
      showSignatures: false,
      showStampArea: false,
      showFooter: false,
      showNotes: false,
      badge: InvoiceBadgeMode.original,
    );
    final restored = InvoiceTemplateSettings.fromJson(
      Map<String, Object?>.from(
        jsonDecode(jsonEncode(original.toJson())) as Map,
      ),
    );
    expect(restored, original);
  });

  test('من JSON خام: قيم تالفة كلها ترد للافتراض لا للاستثناء', () {
    final restored = InvoiceTemplateSettings.fromJson(
      Map<String, Object?>.from(
        jsonDecode(
          '{"templateId":"pos_58","tableHeadArgb":42,'
          '"borderArgb":"blue","accentRedArgb":0,'
          '"showDiscountColumn":"yes","showUnitColumn":1,'
          '"showBarcode":null,"showTax":false,'
          '"showSignatures":[],"showStampArea":{},'
          '"showFooter":"on","showNotes":true,"badge":"duplicate"}',
        ) as Map,
      ),
    );
    // قالب مجهول → البسيط.
    expect(restored.templateId, kInvoiceTemplateSimpleA4);
    // ألوان غير ARGB صالحة (بلا ألفا / نص / صفر) → الافتراض.
    expect(restored.tableHeadArgb, 0xFFDFEBE7);
    expect(restored.borderArgb, 0xFFDCE7E1);
    expect(restored.accentRedArgb, 0xFFC62828);
    // أعلام غير منطقية → الافتراض.
    expect(restored.showDiscountColumn, isTrue);
    expect(restored.showUnitColumn, isFalse);
    expect(restored.showBarcode, isFalse);
    expect(restored.showTax, isFalse);
    expect(restored.showSignatures, isTrue);
    expect(restored.showStampArea, isTrue);
    expect(restored.showFooter, isTrue);
    expect(restored.showNotes, isTrue);
    // شارة مجهولة → بلا.
    expect(restored.badge, InvoiceBadgeMode.none);
  });

  test('fromJsonString: null/فارغ/ليس JSON/ليس Map → الافتراضي دائماً', () {
    expect(InvoiceTemplateSettings.fromJsonString(null),
        const InvoiceTemplateSettings());
    expect(InvoiceTemplateSettings.fromJsonString(''),
        const InvoiceTemplateSettings());
    expect(InvoiceTemplateSettings.fromJsonString('   '),
        const InvoiceTemplateSettings());
    expect(InvoiceTemplateSettings.fromJsonString('{not json'),
        const InvoiceTemplateSettings());
    expect(InvoiceTemplateSettings.fromJsonString('[1,2,3]'),
        const InvoiceTemplateSettings());
    expect(InvoiceTemplateSettings.fromJsonString('"plain"'),
        const InvoiceTemplateSettings());
    // وسليم يُفك.
    expect(
      InvoiceTemplateSettings.fromJsonString(
        '{"templateId":"thermal_80","showBarcode":true}',
      ).templateId,
      kInvoiceTemplateThermal80,
    );
  });

  test('paper مشتق من القالب: أفقي/عمودي/رول + equality بالقيمة', () {
    const classic = InvoiceTemplateSettings(
      templateId: kInvoiceTemplateClassicA4,
    );
    const simple = InvoiceTemplateSettings();
    const thermal = InvoiceTemplateSettings(
      templateId: kInvoiceTemplateThermal80,
    );
    expect(classic.paper, 'a4-landscape');
    expect(simple.paper, 'a4-portrait');
    expect(thermal.paper, 'roll80');
    // equality بالقيمة (نفس JSON = نفس الكائن منطقياً).
    expect(const InvoiceTemplateSettings(), simple);
    expect(
      simple.copyWith(showBarcode: true) == simple,
      isFalse,
    );
    expect(simple.hashCode, const InvoiceTemplateSettings().hashCode);
  });
}
