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
///
/// عناصر البطاقات (الرأس/بطاقة القالب/صف اللون/صف المفتاح/خيار الشارة)
/// بملفاتها المركزّة بجوارها (R20-D3d) — هذا الملف: الحرّاس وتجميع
/// القائمة.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../../printing/views/invoice_template_preview.dart';
import '../../../../data/models/invoice_template_settings.dart';
import '../view_models/print_templates_view_model.dart';
import 'widgets/print_templates_badge_option.dart';
import 'widgets/print_templates_card_header.dart';
import 'widgets/print_templates_color_picker_row.dart';
import 'widgets/print_templates_template_card.dart';
import 'widgets/print_templates_toggle_row.dart';

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
              children: const [ListSkeleton()],
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
          : const _PrintTemplatesList(),
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
              PrintTemplatesCardHeader(
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
                PrintTemplatesTemplateCard(
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
              PrintTemplatesCardHeader(
                icon: Icons.palette_rounded,
                title: l10n.tmplColorsTitle,
              ),
              const SizedBox(height: 12),
              PrintTemplatesColorPickerRow(
                label: l10n.tmplColorTableHead,
                selected: state.settings.tableHeadArgb,
                onSelected: (argb) => vm.updateSettings(
                  state.settings.copyWith(tableHeadArgb: argb),
                ),
              ),
              const SizedBox(height: 12),
              PrintTemplatesColorPickerRow(
                label: l10n.tmplColorBorders,
                selected: state.settings.borderArgb,
                onSelected: (argb) => vm.updateSettings(
                  state.settings.copyWith(borderArgb: argb),
                ),
              ),
              const SizedBox(height: 12),
              PrintTemplatesColorPickerRow(
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
              PrintTemplatesCardHeader(
                icon: Icons.tune_rounded,
                title: l10n.tmplTogglesTitle,
              ),
              const SizedBox(height: 4),
              for (final toggle in printTemplatesTogglesFor(
                state.activeCode,
                l10n,
              )) ...[
                PrintTemplatesToggleRow(
                  title: toggle.title,
                  subtitle: toggle.subtitle,
                  value: toggle.read(state.settings),
                  onChanged: (on) =>
                      vm.updateSettings(toggle.write(state.settings, on)),
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
              PrintTemplatesCardHeader(
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
                          end:
                              mode == InvoiceBadgeMode.none ||
                                  mode == InvoiceBadgeMode.original
                              ? 8
                              : 0,
                        ),
                        child: PrintTemplatesBadgeOption(
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
                  openInvoiceTemplatePreview(context, settings: state.settings),
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
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: scheme.error, fontWeight: FontWeight.w700),
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
}
