/// شاشة «الطباعة والفواتير» (موجة UX-3) — مسار `/more/print-templates`
/// بنمط شاشات تفضيلات المركز الفرعية (sale_preferences_screen):
///
/// - **اختيار القالب**: بطاقات مصغرة بأسماء وأوصاف (كلاسيكي A4 أفقي /
///   بسيط A4 عمودي — R16-b: الحراري 80مم حُذف نهائياً بقرار المالك) —
///   النقر يعملّ القالب فوراً.
/// - **منتقي الألوان**: لوحات مرجعية لرأس الجدول/الحدود/التمييز الأحمر.
/// - **مفاتيح الإظهار/الإخفاء**: عمود خصم/عمود وحدة/باركود Code128/
///   ضريبة/توقيعات ثلاث/مكان ختم/تذييل/ملاحظات — التي يوفرها القالب
///   المحدد فقط.
/// - **شارة أصل/صورة**.
/// - **معاينة حية**: زر يعيد بناء المستند بالإعدادات الجارية فوق آخر
///   فاتورة (أو بيانات نموذجية) عبر `showPdfPreviewDialog` القائم.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/fin_tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../../printing/templates/invoice_template_engine.dart';
import '../../printing/templates/invoice_template_settings.dart';
import '../../sell/views/widgets/invoice_pdf_preview.dart';
import '../view_models/print_templates_view_model.dart';

/// لوحات الألوان المرجعية للمنتقي — تشكيلة تكفي هوية المتاجر اليمنية
/// (الأزرق السماوي بنموذج المالك + هوية التطبيق + محايدات الورق).
const List<int> kTemplateColorSwatches = <int>[
  0xFF9DC3E6, // أزرق سماوي فاتح (نموذج المالك)
  0xFF64B5F6, // أزرق فاتح
  0xFF2196F3, // أزرق
  0xFF37474F, // كحلي رمادي
  0xFF00695C, // بذرة التطبيق (تيل عميق)
  0xFFDFEBE7, // تيل باهت (رأس البسيط الحالي)
  0xFFA87A2C, // ذهبي
  0xFF2E7D32, // أخضر
  0xFFDCE7E1, // حد فاتح
  0xFF9E9E9E, // رمادي
  0xFF1A2420, // حبر داكن
  0xFF000000, // أسود
];

/// شاشة تخصيص قوالب الطباعة — مسار `/more/print-templates`.
class PrintTemplatesScreen extends StatelessWidget {
  const PrintTemplatesScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً — عند غيابه تُنشئ الشاشة نموذجها.
  final PrintTemplatesViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    late final PrintTemplatesViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      final app = context.read<AppController>();
      vm = PrintTemplatesViewModel(printRepo: app.printTemplates!);
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<PrintTemplatesViewModel>.value(
      value: vm,
      child: const _PrintTemplatesBody(),
    );
  }
}

/// نقطة إنشاء النموذج (وحدة قابلة للاختبار/الحقن).
class PrintTemplatesScreenModelFactory {
  static PrintTemplatesViewModel create(AppController app) =>
      PrintTemplatesViewModel(printRepo: app.printTemplates!);
}

class _PrintTemplatesBody extends StatelessWidget {
  const _PrintTemplatesBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PrintTemplatesViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.tmplScreenTitle)),
      body: state.loading
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: const [ListSkeleton(rows: 6)],
            )
          : state.error != null
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                ErrorState(
                  title: l10n.genericErrorTitle,
                  message: l10n.dbOpenErrorMessage,
                  technicalDetails: state.error.toString(),
                  retryLabel: l10n.commonRetry,
                  onRetry: vm.load,
                  compact: true,
                ),
              ],
            )
          : _PrintTemplatesList(),
    );
  }
}

class _PrintTemplatesList extends StatelessWidget {
  const _PrintTemplatesList();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PrintTemplatesViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final state = vm.state;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // ── اختيار القالب ──
        FinCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeader(
                icon: Icons.receipt_long_rounded,
                title: l10n.tmplTemplateSectionTitle,
              ),
              const SizedBox(height: 12),
              // R16-b: بطاقتان فقط — الحراري 80مم حُذف بقرار المالك.
              for (final (i, code, name, desc, icon) in [
                (
                  0,
                  kInvoiceTemplateClassicA4,
                  l10n.tmplClassicName,
                  l10n.tmplClassicDesc,
                  Icons.article_rounded,
                ),
                (
                  1,
                  kInvoiceTemplateSimpleA4,
                  l10n.tmplSimpleName,
                  l10n.tmplSimpleDesc,
                  Icons.description_rounded,
                ),
              ]) ...[
                if (i > 0) const SizedBox(height: 8),
                _TemplateCard(
                  code: code,
                  name: name,
                  description: desc,
                  icon: icon,
                  selected: state.activeCode == code,
                  onTap: () => vm.selectTemplate(code),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── منتقي الألوان ──
        FinCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeader(icon: Icons.palette_rounded, title: l10n.tmplColorsTitle),
              const SizedBox(height: 12),
              _ColorPickerRow(
                label: l10n.tmplColorTableHead,
                selected: state.settings.tableHeadArgb,
                onSelected: (argb) => vm.updateSettings(
                  state.settings.copyWith(tableHeadArgb: argb),
                ),
              ),
              const SizedBox(height: 12),
              _ColorPickerRow(
                label: l10n.tmplColorBorders,
                selected: state.settings.borderArgb,
                onSelected: (argb) => vm.updateSettings(
                  state.settings.copyWith(borderArgb: argb),
                ),
              ),
              const SizedBox(height: 12),
              _ColorPickerRow(
                label: l10n.tmplColorAccentRed,
                selected: state.settings.accentRedArgb,
                onSelected: (argb) => vm.updateSettings(
                  state.settings.copyWith(accentRedArgb: argb),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── مفاتيح الإظهار/الإخفاء (التي يوفرها القالب المحدد) ──
        FinCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeader(
                icon: Icons.tune_rounded,
                title: l10n.tmplTogglesTitle,
              ),
              const SizedBox(height: 4),
              for (final toggle in _togglesFor(state.activeCode, l10n)) ...[
                _ToggleRow(
                  title: toggle.title,
                  subtitle: toggle.subtitle,
                  value: toggle.read(state.settings),
                  onChanged: (on) => vm.updateSettings(
                    toggle.write(state.settings, on),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── شارة النسخة ──
        FinCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeader(
                icon: Icons.workspace_premium_rounded,
                title: l10n.tmplBadgeTitle,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final (mode, label) in [
                    (InvoiceBadgeMode.none, l10n.tmplBadgeNone),
                    (InvoiceBadgeMode.original, l10n.tmplBadgeOriginal),
                    (InvoiceBadgeMode.copy, l10n.tmplBadgeCopy),
                  ])
                    Expanded(
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(
                          end: mode == InvoiceBadgeMode.none ||
                                  mode == InvoiceBadgeMode.original
                              ? 8
                              : 0,
                        ),
                        child: _BadgeOption(
                          label: label,
                          selected: state.settings.badge == mode,
                          onTap: () => vm.updateSettings(
                            state.settings.copyWith(badge: mode),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── المعاينة الحية + استعادة الافتراضي ──
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => unawaited(
                  openInvoiceTemplatePreview(
                    context,
                    settings: state.settings,
                  ),
                ),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: Text(l10n.tmplPreviewButton),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => unawaited(vm.resetToDefault()),
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: Text(l10n.tmplResetButton),
              ),
            ),
          ],
        ),

        // فشل كتابة آخر تبديل — ظاهر بلا كسر القيم الحية.
        if (state.writeError != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              l10n.tmplWriteFailed,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            l10n.tmplNote,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  /// مفاتيح الإظهار التي يوفرها القالب المحدد (templateSupports).
  List<_ToggleSpec> _togglesFor(String code, AppLocalizations l10n) {
    return [
      _ToggleSpec(
        feature: TemplateFeature.discountColumn,
        title: l10n.tmplShowDiscountCol,
        subtitle: l10n.tmplShowDiscountColDesc,
        read: (s) => s.showDiscountColumn,
        write: (s, on) => s.copyWith(showDiscountColumn: on),
      ),
      _ToggleSpec(
        feature: TemplateFeature.unitColumn,
        title: l10n.tmplShowUnitCol,
        subtitle: l10n.tmplShowUnitColDesc,
        read: (s) => s.showUnitColumn,
        write: (s, on) => s.copyWith(showUnitColumn: on),
      ),
      _ToggleSpec(
        feature: TemplateFeature.barcode,
        title: l10n.tmplShowBarcode,
        subtitle: l10n.tmplShowBarcodeDesc,
        read: (s) => s.showBarcode,
        write: (s, on) => s.copyWith(showBarcode: on),
      ),
      _ToggleSpec(
        feature: TemplateFeature.tax,
        title: l10n.tmplShowTax,
        subtitle: l10n.tmplShowTaxDesc,
        read: (s) => s.showTax,
        write: (s, on) => s.copyWith(showTax: on),
      ),
      _ToggleSpec(
        feature: TemplateFeature.signatures,
        title: l10n.tmplShowSignatures,
        subtitle: l10n.tmplShowSignaturesDesc,
        read: (s) => s.showSignatures,
        write: (s, on) => s.copyWith(showSignatures: on),
      ),
      _ToggleSpec(
        feature: TemplateFeature.stampArea,
        title: l10n.tmplShowStamp,
        subtitle: l10n.tmplShowStampDesc,
        read: (s) => s.showStampArea,
        write: (s, on) => s.copyWith(showStampArea: on),
      ),
      _ToggleSpec(
        feature: TemplateFeature.footer,
        title: l10n.tmplShowFooter,
        subtitle: l10n.tmplShowFooterDesc,
        read: (s) => s.showFooter,
        write: (s, on) => s.copyWith(showFooter: on),
      ),
      _ToggleSpec(
        feature: TemplateFeature.notes,
        title: l10n.tmplShowNotes,
        subtitle: l10n.tmplShowNotesDesc,
        read: (s) => s.showNotes,
        write: (s, on) => s.copyWith(showNotes: on),
      ),
    ]
        .where((t) => templateSupports(code, t.feature))
        .toList();
  }
}

// ─────────────────────────────────────────────────────────────────────
// عناصر البطاقات
// ─────────────────────────────────────────────────────────────────────

/// رأس بطاقة (أيقونة + عنوان).
class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(FinRadius.control),
          ),
          child: Icon(icon, size: 20, color: scheme.primary),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// بطاقة قالب مصغرة: اسم + وصف + أيقونة، وحدّ مزدوج عند الاختيار.
class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.code,
    required this.name,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final String name;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final descriptor = InvoiceTemplateEngine.templates
        .where((t) => t.code == code)
        .firstOrNull;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? scheme.onPrimaryContainer : scheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                color: selected
                                    ? scheme.onPrimaryContainer
                                    : null,
                              ),
                        ),
                      ),
                      if (selected)
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: scheme.onPrimaryContainer,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: selected
                          ? scheme.onPrimaryContainer.withValues(alpha: 0.85)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  if (descriptor != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      descriptor.paper,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected
                            ? scheme.onPrimaryContainer.withValues(alpha: 0.7)
                            : scheme.outline,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// صف منتقي لون: تسمية + لوحات مرجعية أفقية قابلة للتمرير.
class _ColorPickerRow extends StatelessWidget {
  const _ColorPickerRow({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kTemplateColorSwatches.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final argb = kTemplateColorSwatches[index];
              final isSelected = argb == selected;
              return InkWell(
                onTap: () => onSelected(argb),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(argb),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? scheme.primary : scheme.outline,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Colors.white,
                        )
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// صف مفتاح إظهار/إخفاء.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
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

/// بطاقة خيار شارة (بلا/أصل/صورة).
class _BadgeOption extends StatelessWidget {
  const _BadgeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected ? scheme.onPrimaryContainer : null,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// مواصفة مفتاح إظهار لميزة قالب.
class _ToggleSpec {
  const _ToggleSpec({
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
