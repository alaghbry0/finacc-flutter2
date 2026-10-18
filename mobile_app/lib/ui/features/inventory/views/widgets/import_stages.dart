/// مراحل شاشة الاستيراد الأربع (إدخال/ربط/معاينة/نتيجة) — مستخرجة من
/// import_screen (R19-D3b: نقل حرفي بلا أي تغيير سلوكي).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../domain/models/company.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/info_note.dart';
import '../../../../core/widgets/fin_section_title.dart';
import '../../view_models/import_view_model.dart';
import 'import_input_widgets.dart';
import 'import_mapping_widgets.dart';

List<Widget> buildImportInputStage(
  BuildContext context,
  ImportViewModel vm,
  AppLocalizations l10n,
  ImportState state,
  TextEditingController pasteController,
) {
  return [
    ImportModeSelector(state: state, onSelect: vm.setFileMode),
    const SizedBox(height: 16),
    if (state.fileMode)
      ImportFilePickerCard(vm: vm)
    else ...[
      FinCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.importPasteHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('import_csv_field'),
              controller: pasteController,
              onChanged: vm.setPasteText,
              minLines: 6,
              maxLines: 10,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: InputDecoration(hintText: l10n.importPasteFieldHint),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      FilledButton(
        key: const Key('import_continue_btn'),
        onPressed: state.hasSource ? vm.prepareMapping : null,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: Text(l10n.importContinue),
      ),
    ],
    if (state.error == ImportError.noSource) ...[
      const SizedBox(height: 10),
      ImportErrorBanner(message: l10n.importNoSource),
    ],
  ];
}

List<Widget> buildImportMappingStage(
  BuildContext context,
  ImportViewModel vm,
  AppLocalizations l10n,
  ImportState state,
) {
  final semanticFields = _semanticFields(state.currencies);
  return [
    FinCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(
            state.fileName != null
                ? Icons.description_rounded
                : Icons.content_paste_rounded,
            size: 20,
            color: FinColors.of(context).gold,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              state.fileName ?? l10n.importModePaste,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(onPressed: vm.reset, child: Text(l10n.importClearSource)),
        ],
      ),
    ),
    const SizedBox(height: 14),
    FinSectionTitle(icon: Icons.link_rounded, title: l10n.importMappingSection),
    const SizedBox(height: 6),
    InfoNote(icon: Icons.auto_awesome_rounded, message: l10n.importMappingDesc),
    const SizedBox(height: 10),
    FinCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          for (final (index, field) in semanticFields.indexed)
            Padding(
              padding: EdgeInsets.only(
                bottom: index + 1 == semanticFields.length ? 0 : 14,
              ),
              child: ImportMappingRow(
                field: field,
                headers: state.headers,
                value: state.mapping[field.$1] ?? '',
                onChanged: (letter) => vm.setMappingField(field.$1, letter),
              ),
            ),
        ],
      ),
    ),
    if (state.error == ImportError.nameNotMapped) ...[
      const SizedBox(height: 10),
      ImportErrorBanner(message: l10n.importNameNotMapped),
    ],
    if (state.repoError != null) ...[
      const SizedBox(height: 10),
      ImportErrorBanner(message: state.repoError!),
    ],
    const SizedBox(height: 16),
    FilledButton.icon(
      key: const Key('import_analyze_btn'),
      onPressed: state.analyzing ? null : () => unawaited(vm.analyze()),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      icon: state.analyzing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.plagiarism_rounded, size: 20),
      label: Text(state.analyzing ? l10n.importAnalyzing : l10n.importAnalyze),
    ),
  ];
}

List<Widget> buildImportPreviewStage(
  BuildContext context,
  ImportViewModel vm,
  AppLocalizations l10n,
  ImportState state,
) {
  final preview = state.preview!;
  final colors = FinColors.of(context);
  return [
    FinCard(
      accent: preview.isClean ? colors.positive : colors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: colors.positive,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.importValidRows(preview.validRows.length),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colors.positive,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (preview.failedRows.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 20,
                  color: colors.negative,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.importFailedRows(preview.failedRows.length),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colors.negative,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ImportFailuresList(failures: preview.failedRows),
          ],
          if (preview.suggestedNewCategories.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              l10n.importNewCategories(
                preview.suggestedNewCategories.join('، '),
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (preview.suggestedNewUnits.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              l10n.importNewUnits(preview.suggestedNewUnits.join('، ')),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    ),
    // إقرار AC-14 — مطلوب فقط عند وجود صفوف فاشلة.
    if (preview.failedRows.isNotEmpty) ...[
      const SizedBox(height: 14),
      FinCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          children: [
            Checkbox(
              key: const Key('import_ack_checkbox'),
              value: state.acknowledged,
              onChanged: (value) => vm.setAcknowledged(value ?? false),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.importAckLabel,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    ],
    if (state.repoError != null) ...[
      const SizedBox(height: 10),
      ImportErrorBanner(message: state.repoError!),
    ],
    const SizedBox(height: 16),
    FilledButton.icon(
      key: const Key('import_commit_btn'),
      onPressed: state.canCommit && !state.committing
          ? () => unawaited(vm.commit())
          : null,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      icon: state.committing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download_rounded, size: 20),
      label: Text(
        state.committing
            ? l10n.importCommitting
            : (preview.isClean ? l10n.importCommitClean : l10n.importCommit),
      ),
    ),
    const SizedBox(height: 8),
    TextButton.icon(
      onPressed: state.committing ? null : vm.backToMapping,
      icon: const Icon(Icons.edit_rounded, size: 18),
      label: Text(l10n.importMappingSection),
    ),
  ];
}

List<Widget> buildImportDoneStage(
  BuildContext context,
  ImportViewModel vm,
  AppLocalizations l10n,
  ImportState state,
) {
  final result = state.result!;
  final colors = FinColors.of(context);
  return [
    FinCard(
      accent: colors.positive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.task_alt_rounded, size: 22, color: colors.positive),
              const SizedBox(width: 10),
              Text(
                l10n.importResultTitle,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ImportResultRow(
            icon: Icons.check_circle_rounded,
            color: colors.positive,
            text: l10n.importResultInserted(result.inserted),
          ),
          const SizedBox(height: 6),
          ImportResultRow(
            icon: Icons.error_outline_rounded,
            color: colors.negative,
            text: l10n.importResultFailed(result.failures.length),
          ),
          if (result.createdCategories > 0) ...[
            const SizedBox(height: 6),
            ImportResultRow(
              icon: Icons.category_rounded,
              color: colors.gold,
              text: l10n.importResultCategories(result.createdCategories),
            ),
          ],
          if (result.createdUnits > 0) ...[
            const SizedBox(height: 6),
            ImportResultRow(
              icon: Icons.straighten_rounded,
              color: colors.gold,
              text: l10n.importResultUnits(result.createdUnits),
            ),
          ],
        ],
      ),
    ),
    const SizedBox(height: 16),
    OutlinedButton.icon(
      onPressed: vm.reset,
      icon: const Icon(Icons.refresh_rounded, size: 20),
      label: Text(l10n.importRestart),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    ),
  ];
}

/// الحقول الدلالية للربط — الثابتة + عمود سعر لكل عملة نشطة.
List<(String, bool)> _semanticFields(List<Currency> currencies) => [
  ('name', true),
  ('barcode', false),
  ('cost', false),
  ('qty', false),
  ('min_stock', false),
  ('category', false),
  ('unit', false),
  ('notes', false),
  for (final currency in currencies) ('price_${currency.code}', false),
];
