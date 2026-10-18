/// محرر الرقم العشري بنافذة سفلية للشراء (R19-D3a — مستخرج حرفياً من
/// `purchase_widgets.dart` بلا أي تغيير دلالة).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../l10n/app_localizations.dart';

/// محرر رقم عشري بنافذة سفلية — للتكلفة/الكمية/الخصم/المبلغ النقدي.
/// R17-a: هو بوابة «تعديل الكمية» الفورية من نقرة قيمة PurchaseQtyStepper.
Future<double?> showPurchaseNumberEditSheet(
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
  // فوق شريط التبويبات (متصفح الفرع) — لا من أسفل الشاشة خلفه.
  useRootNavigator: false,
  builder: (sheetContext) => _PurchaseNumberEditSheet(
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
/// الحركة — نفس علة محرر السطر الموحّد بالبيع (R16-a)، عولجت هنا
/// باختبارات R17-a بفتح النافذة من قيمة الكمية). مرآة _NumberEditSheet
/// بالبيع بلا استيراد بين الوحدتين (feature-first).
class _PurchaseNumberEditSheet extends StatefulWidget {
  const _PurchaseNumberEditSheet({
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
  State<_PurchaseNumberEditSheet> createState() =>
      _PurchaseNumberEditSheetState();
}

class _PurchaseNumberEditSheetState extends State<_PurchaseNumberEditSheet> {
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
    final value = _parse(_controller.text);
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
                  Navigator.of(context).pop(_parse(_controller.text)),
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

double? _parse(String text) {
  final normalized = text.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}
