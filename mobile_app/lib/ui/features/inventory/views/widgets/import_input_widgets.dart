/// ويدجت إدخال الاستيراد: محدد الوضع وبطاقة اختيار الملف — مستخرجة من
/// import_screen (R19-D3b: نقل حرفي بلا أي تغيير سلوكي).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/import_view_model.dart';

/// محدد الوضع — بطاقتان (ملف / لصق) بحركة اختيار.
class ImportModeSelector extends StatelessWidget {
  const ImportModeSelector({
    super.key,
    required this.state,
    required this.onSelect,
  });

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
class ImportFilePickerCard extends StatelessWidget {
  const ImportFilePickerCard({super.key, required this.vm});

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
