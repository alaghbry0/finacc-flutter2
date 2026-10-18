/// ويدجت الربط والنتائج بالاستيراد: صف الربط/قائمة الفشل/صف النتيجة/
/// لافتة الخطأ — مستخرجة من import_screen (R19-D3b: نقل حرفي بلا تغيير).
library;

import 'package:flutter/material.dart';

import '../../../../../data/services/item_import_service.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

/// صف ربط حقل دلالي بعمود.
class ImportMappingRow extends StatelessWidget {
  const ImportMappingRow({
    super.key,
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
class ImportFailuresList extends StatefulWidget {
  const ImportFailuresList({super.key, required this.failures});

  final List<ImportRowFailure> failures;

  @override
  State<ImportFailuresList> createState() => _ImportFailuresListState();
}

class _ImportFailuresListState extends State<ImportFailuresList> {
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
class ImportResultRow extends StatelessWidget {
  const ImportResultRow({
    super.key,
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
class ImportErrorBanner extends StatelessWidget {
  const ImportErrorBanner({super.key, required this.message});

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
