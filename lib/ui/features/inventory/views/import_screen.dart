/// شاشة استيراد الأصناف (FR-01-13 / AC-14): وضعان (ملف CSV/Excel عبر
/// file_picker أو لصق CSV) → ربط أعمدة مُخمَّن → معاينة فحص بلا كتابة →
/// إقرار صريح عند وجود صفوف فاشلة → إدخال الصفوف الصالحة فقط + بطاقة
/// النتيجة.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/services/item_import_service.dart';
import '../../../../domain/models/company.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fin_card.dart';
import 'widgets/inventory_widgets.dart';
import '../view_models/import_view_model.dart';

class ImportScreen extends StatelessWidget {
  const ImportScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً — عند غيابه تُنشئ الشاشة نموذجها.
  final ImportViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final ImportViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = ImportViewModel(
        importService: ItemImportService(app.database!.db),
        companyRepo: app.companies!,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<ImportViewModel>.value(
      value: vm,
      child: const _ImportBody(),
    );
  }
}

class _ImportBody extends StatefulWidget {
  const _ImportBody();

  @override
  State<_ImportBody> createState() => _ImportBodyState();
}

class _ImportBodyState extends State<_ImportBody> {
  final TextEditingController _pasteController = TextEditingController();

  /// النموذج يُخزَّن حقلاً عند التركيب — القراءة من context داخل dispose
  /// غير آمنة (عنصر معطّل) وتكسر تفكيك الشجرة في الاختبارات.
  late final ImportViewModel _storedVm;
  ImportViewModel get _vm => _storedVm;

  @override
  void initState() {
    super.initState();
    _storedVm = context.read<ImportViewModel>();
    _storedVm.addListener(_onVmChanged);
  }

  @override
  void dispose() {
    _storedVm.removeListener(_onVmChanged);
    _pasteController.dispose();
    super.dispose();
  }

  /// مزامنة حقل اللصق مع الحالة (يُمسح عند «بدء استيراد جديد»).
  void _onVmChanged() {
    if (!mounted) return;
    if (_vm.state.pasteText != _pasteController.text) {
      _pasteController.text = _vm.state.pasteText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ImportViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.importTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: switch (state.stage) {
          ImportStage.input => _buildInputStage(context, vm, l10n, state),
          ImportStage.mapping => _buildMappingStage(context, vm, l10n, state),
          ImportStage.preview => _buildPreviewStage(context, vm, l10n, state),
          ImportStage.done => _buildDoneStage(context, vm, l10n, state),
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // مرحلة الإدخال
  // ─────────────────────────────────────────────────────────────────────

  List<Widget> _buildInputStage(
    BuildContext context,
    ImportViewModel vm,
    AppLocalizations l10n,
    ImportState state,
  ) {
    return [
      _ModeSelector(state: state, onSelect: vm.setFileMode),
      const SizedBox(height: 16),
      if (state.fileMode)
        _FilePickerCard(vm: vm)
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
                controller: _pasteController,
                onChanged: vm.setPasteText,
                minLines: 6,
                maxLines: 10,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: InputDecoration(
                  hintText: l10n.importPasteFieldHint,
                ),
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
        _ErrorBanner(message: l10n.importNoSource),
      ],
    ];
  }

  // ─────────────────────────────────────────────────────────────────────
  // مرحلة الربط
  // ─────────────────────────────────────────────────────────────────────

  List<Widget> _buildMappingStage(
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
            TextButton(
              onPressed: vm.reset,
              child: Text(l10n.importClearSource),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      InventorySectionTitle(
        icon: Icons.link_rounded,
        title: l10n.importMappingSection,
      ),
      const SizedBox(height: 6),
      InfoNoteCard(
        icon: Icons.auto_awesome_rounded,
        message: l10n.importMappingDesc,
      ),
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
                child: _MappingRow(
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
        _ErrorBanner(message: l10n.importNameNotMapped),
      ],
      if (state.repoError != null) ...[
        const SizedBox(height: 10),
        _ErrorBanner(message: state.repoError!),
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
        label: Text(
          state.analyzing ? l10n.importAnalyzing : l10n.importAnalyze,
        ),
      ),
    ];
  }

  // ─────────────────────────────────────────────────────────────────────
  // مرحلة المعاينة
  // ─────────────────────────────────────────────────────────────────────

  List<Widget> _buildPreviewStage(
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
              _FailuresList(failures: preview.failedRows),
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
        _ErrorBanner(message: state.repoError!),
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

  // ─────────────────────────────────────────────────────────────────────
  // مرحلة النتيجة
  // ─────────────────────────────────────────────────────────────────────

  List<Widget> _buildDoneStage(
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
            _ResultRow(
              icon: Icons.check_circle_rounded,
              color: colors.positive,
              text: l10n.importResultInserted(result.inserted),
            ),
            const SizedBox(height: 6),
            _ResultRow(
              icon: Icons.error_outline_rounded,
              color: colors.negative,
              text: l10n.importResultFailed(result.failures.length),
            ),
            if (result.createdCategories > 0) ...[
              const SizedBox(height: 6),
              _ResultRow(
                icon: Icons.category_rounded,
                color: colors.gold,
                text: l10n.importResultCategories(result.createdCategories),
              ),
            ],
            if (result.createdUnits > 0) ...[
              const SizedBox(height: 6),
              _ResultRow(
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

  // ─────────────────────────────────────────────────────────────────────
  // مساعدات
  // ─────────────────────────────────────────────────────────────────────

  static List<(String, bool)> _semanticFields(List<Currency> currencies) => [
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
}

/// محدد الوضع — بطاقتان (ملف / لصق) بحركة اختيار.
class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.state, required this.onSelect});

  final ImportState state;
  final ValueChanged<bool> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _ModeOption(
            icon: Icons.upload_file_rounded,
            label: l10n.importModeFile,
            selected: state.fileMode,
            onTap: () => onSelect(true),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ModeOption(
            icon: Icons.content_paste_rounded,
            label: l10n.importModePaste,
            selected: !state.fileMode,
            onTap: () => onSelect(false),
          ),
        ),
      ],
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة اختيار الملف (CSV / xlsx).
class _FilePickerCard extends StatelessWidget {
  const _FilePickerCard({required this.vm});

  final ImportViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return FinCard(
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('import_pick_file_btn'),
              onPressed: () => unawaited(vm.pickFile()),
              icon: const Icon(Icons.upload_file_rounded, size: 22),
              label: Text(l10n.importPickFile),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.importPickFileDesc,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// صف ربط حقل دلالي بعمود.
class _MappingRow extends StatelessWidget {
  const _MappingRow({
    required this.field,
    required this.headers,
    required this.value,
    required this.onChanged,
  });

  final (String, bool) field;
  final List<String> headers;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = _fieldLabel(l10n, field.$1);
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            field.$2 ? '$label *' : label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<String>(
            key: Key('import_mapping_${field.$1}_$value'),
            initialValue: value,
            onChanged: (letter) => onChanged(letter ?? ''),
            isExpanded: true,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: [
              DropdownMenuItem<String>(
                value: '',
                child: Text(
                  l10n.importMappingIgnore,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final (index, header) in headers.indexed)
                DropdownMenuItem<String>(
                  value: _letter(index),
                  child: Text(
                    '${_letter(index)} — ${header.trim().isEmpty ? '(${index + 1})' : header.trim()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _letter(int index) {
    var letter = '';
    var i = index;
    while (i >= 0) {
      letter = String.fromCharCode(0x41 + (i % 26)) + letter;
      i = (i ~/ 26) - 1;
    }
    return letter;
  }

  static String _fieldLabel(AppLocalizations l10n, String key) => switch (key) {
    'name' => l10n.importColumnName,
    'barcode' => l10n.importColumnBarcode,
    'cost' => l10n.importColumnCost,
    'qty' => l10n.importColumnQty,
    'min_stock' => l10n.importColumnMinStock,
    'category' => l10n.importColumnCategory,
    'unit' => l10n.importColumnUnit,
    'notes' => l10n.importColumnNotes,
    _ =>
      key.startsWith('price_')
          ? l10n.importColumnPrice(key.substring('price_'.length))
          : key,
  };
}

/// قائمة الصفوف الفاشلة القابلة للطي.
class _FailuresList extends StatefulWidget {
  const _FailuresList({required this.failures});

  final List<ImportRowFailure> failures;

  @override
  State<_FailuresList> createState() => _FailuresListState();
}

class _FailuresListState extends State<_FailuresList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => setState(() => _expanded = !_expanded),
          icon: Icon(
            _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            size: 18,
          ),
          label: Text(
            _expanded
                ? l10n.importFailuresCollapse
                : l10n.importFailuresExpand(widget.failures.length),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          style: TextButton.styleFrom(
            foregroundColor: scheme.onSurfaceVariant,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
        ),
        if (_expanded)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final failure in widget.failures)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${l10n.importFailureRow(failure.rowNumber)}: ${failure.reason}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// صف نتيجة واحد (أُدخل/فشل/فئات/وحدات).
class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// لافتة خطأ حمراء (أخطاء المصدر/الخدمة).
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = FinColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.negativeContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: colors.onNegativeContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onNegativeContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
