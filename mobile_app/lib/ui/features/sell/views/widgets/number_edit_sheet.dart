/// محرر رقم عشري بنافذة سفلية — للسعر/الكمية/الخصم/المبلغ النقدي.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../l10n/app_localizations.dart';
import 'sell_format.dart';

/// محرر رقم عشري بنافذة سفلية — للسعر/الكمية/الخصم/المبلغ النقدي.
/// R17-a: هو بوابة «تعديل الكمية» الفورية من نقرة قيمة QtyStepper.
Future<double?> showNumberEditSheet(
  BuildContext context, {
  required String title,
  required double initial,
  required String confirmLabel,
  String? hint,
  bool allowZero = true,
  int decimals = 2,
  IconData? icon,
}) => showModalBottomSheet<double>(
  context: context,
  isScrollControlled: true,
  // فوق شريط التبويبات: تُفتح على متصفح الفرع لا الجذر — تنزلق
  // من فوق الشريط السفلي بدل أن تغطيه من أسفل الشاشة.
  useRootNavigator: false,
  builder: (sheetContext) => _NumberEditSheet(
    title: title,
    initial: initial,
    confirmLabel: confirmLabel,
    hint: hint,
    allowZero: allowZero,
    decimals: decimals,
    icon: icon,
  ),
);

/// جسم محرر الرقم — StatefulWidget يملك متحكمه (يُنشأ بـ initState
/// ويُدمَّر بـ dispose): المتحكم يبقى حياً طوال حياة النافذة **بما فيها
/// حركة الخروج** (دماره عند اكتمال مستقبل showModalBottomSheet مبكراً
/// كان يفجر «used after being disposed» بإعادة بناء الحقل أثناء
/// الحركة — نفس علة محرر السطر الموحّد المكتشفة باختبارات R16-a،
/// كشفتها هنا اختبارات R17-a بفتح النافذة من قيمة الكمية).
class _NumberEditSheet extends StatefulWidget {
  const _NumberEditSheet({
    required this.title,
    required this.initial,
    required this.confirmLabel,
    required this.allowZero,
    required this.decimals,
    this.hint,
    this.icon,
  });

  final String title;
  final double initial;
  final String confirmLabel;
  final String? hint;
  final bool allowZero;
  final int decimals;
  final IconData? icon;

  @override
  State<_NumberEditSheet> createState() => _NumberEditSheetState();
}

class _NumberEditSheetState extends State<_NumberEditSheet> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initial == widget.initial.truncateToDouble()
          ? widget.initial.truncate().toString()
          : widget.initial.toStringAsFixed(widget.decimals),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = parseSheetNumber(_controller.text);
    if (value == null || value.isNaN || value.isInfinite) {
      setState(() => _error = 'invalid');
      return;
    }
    if (value < 0 || (!widget.allowZero && value == 0)) {
      setState(() => _error = 'invalid');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: scheme.primary, size: 22),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: false,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,4}')),
              ],
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) =>
                  Navigator.of(context).pop(parseSheetNumber(_controller.text)),
              decoration: InputDecoration(
                hintText: widget.hint,
                errorText: _error == null ? null : l10n.sellInvalidNumber,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(widget.confirmLabel),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonCancel),
            ),
          ],
        ),
      ),
    );
  }
}
