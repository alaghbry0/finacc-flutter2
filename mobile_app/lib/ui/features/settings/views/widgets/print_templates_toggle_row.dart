/// صف مفتاح الإظهار/الإخفاء ومواصفاته لشاشة قوالب الطباعة — مستخرج
/// حرفياً من `print_templates_screen.dart` (R20-D3d؛ كانت `_ToggleRow`
/// و`_ToggleSpec` و`_togglesFor`).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../data/models/invoice_template_settings.dart';

/// صف مفتاح إظهار/إخفاء.
class PrintTemplatesToggleRow extends StatelessWidget {
  const PrintTemplatesToggleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// مواصفة مفتاح إظهار لميزة قالب.
class PrintTemplatesToggleSpec {
  const PrintTemplatesToggleSpec({
    required this.feature,
    required this.title,
    required this.subtitle,
    required this.read,
    required this.write,
  });

  final TemplateFeature feature;
  final String title;
  final String subtitle;
  final bool Function(InvoiceTemplateSettings) read;
  final InvoiceTemplateSettings Function(InvoiceTemplateSettings, bool) write;
}

/// مفاتيح الإظهار التي يوفرها القالب المحدد (templateSupports).
List<PrintTemplatesToggleSpec> printTemplatesTogglesFor(
  String code,
  AppLocalizations l10n,
) {
  return [
    PrintTemplatesToggleSpec(
      feature: TemplateFeature.discountColumn,
      title: l10n.tmplShowDiscountCol,
      subtitle: l10n.tmplShowDiscountColDesc,
      read: (s) => s.showDiscountColumn,
      write: (s, on) => s.copyWith(showDiscountColumn: on),
    ),
    PrintTemplatesToggleSpec(
      feature: TemplateFeature.unitColumn,
      title: l10n.tmplShowUnitCol,
      subtitle: l10n.tmplShowUnitColDesc,
      read: (s) => s.showUnitColumn,
      write: (s, on) => s.copyWith(showUnitColumn: on),
    ),
    PrintTemplatesToggleSpec(
      feature: TemplateFeature.barcode,
      title: l10n.tmplShowBarcode,
      subtitle: l10n.tmplShowBarcodeDesc,
      read: (s) => s.showBarcode,
      write: (s, on) => s.copyWith(showBarcode: on),
    ),
    PrintTemplatesToggleSpec(
      feature: TemplateFeature.tax,
      title: l10n.tmplShowTax,
      subtitle: l10n.tmplShowTaxDesc,
      read: (s) => s.showTax,
      write: (s, on) => s.copyWith(showTax: on),
    ),
    PrintTemplatesToggleSpec(
      feature: TemplateFeature.signatures,
      title: l10n.tmplShowSignatures,
      subtitle: l10n.tmplShowSignaturesDesc,
      read: (s) => s.showSignatures,
      write: (s, on) => s.copyWith(showSignatures: on),
    ),
    PrintTemplatesToggleSpec(
      feature: TemplateFeature.stampArea,
      title: l10n.tmplShowStamp,
      subtitle: l10n.tmplShowStampDesc,
      read: (s) => s.showStampArea,
      write: (s, on) => s.copyWith(showStampArea: on),
    ),
    PrintTemplatesToggleSpec(
      feature: TemplateFeature.footer,
      title: l10n.tmplShowFooter,
      subtitle: l10n.tmplShowFooterDesc,
      read: (s) => s.showFooter,
      write: (s, on) => s.copyWith(showFooter: on),
    ),
    PrintTemplatesToggleSpec(
      feature: TemplateFeature.notes,
      title: l10n.tmplShowNotes,
      subtitle: l10n.tmplShowNotesDesc,
      read: (s) => s.showNotes,
      write: (s, on) => s.copyWith(showNotes: on),
    ),
  ].where((t) => templateSupports(code, t.feature)).toList();
}
