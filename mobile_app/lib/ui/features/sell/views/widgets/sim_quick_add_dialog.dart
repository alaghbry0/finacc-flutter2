/// نافذة «إضافة بند» السريعة داخل الفاتورة (V10) — مطابقة للقطة
/// المرجعية `upload/Screenbox_20261019_065028.png`: نافذة بيضاء بعنوان
/// «إضافة بند» وحقلا اسم الصنف وسعر الوحدة + مربع اختيار «حفظ الصنف
/// في قائمة المنتجات» + تلميح العابر عند إلغائه + زرا إلغاء/متابعة.
///
/// الإنشاء نفسه خارج النافذة: [onCreate] يُستدعى بمتابعة صحيحة ويعيد
/// `Result<ItemStockInfo, String>` — الخطأ يُعرض داخل النافذة (نمط
/// P1-3 بإنشاء العميل السريع) والنجاح يغلقها بالصنف المُنشأ.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_app/l10n/app_localizations.dart';

import '../../../../../domain/core/result.dart';
import '../../../../../domain/models/item.dart';
import '../../../../core/widgets/sim_form_widgets.dart';

/// مستدعى الإنشاء — يُرجع الصنف الجاهز للإضافة للسلة أو رسالة خطأ.
typedef QuickAddItemCreator = Future<Result<ItemStockInfo, String>> Function(
  String name,
  double price,
  bool saveToProducts,
);

/// تفتح نافذة الإضافة السريعة — تعيد الصنف المُنشأ أو null عند الإلغاء.
///
/// [initialName] نص البحث الحالي بالمنتقي يُحقن مسبقاً في حقل الاسم
/// (المستخدم بحث عن صنف غير موجود فيكتب فقط الباقي).
Future<ItemStockInfo?> showQuickAddItemDialog(
  BuildContext context, {
  required String initialName,
  required QuickAddItemCreator onCreate,
}) async {
  return showDialog<ItemStockInfo>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _QuickAddItemDialog(initialName: initialName, onCreate: onCreate),
  );
}

class _QuickAddItemDialog extends StatefulWidget {
  const _QuickAddItemDialog({
    required this.initialName,
    required this.onCreate,
  });

  final String initialName;
  final QuickAddItemCreator onCreate;

  @override
  State<_QuickAddItemDialog> createState() => _QuickAddItemDialogState();
}

class _QuickAddItemDialogState extends State<_QuickAddItemDialog> {
  late final TextEditingController _name;
  late final TextEditingController _price;
  bool _saveToProducts = true;
  String? _error;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName.trim());
    _price = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.sellQuickAddNameRequired);
      return;
    }
    final price = double.tryParse(_price.text.trim());
    if (price == null || price < 0) {
      setState(() => _error = l10n.sellQuickAddPriceInvalid);
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });
    final result = await widget.onCreate(name, price, _saveToProducts);
    if (!mounted) return;
    if (result.isErr) {
      setState(() {
        _creating = false;
        _error = result.errorOrNull;
      });
      return;
    }
    Navigator.of(context).pop(result.valueOrNull);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    // V10-REVIEW 🟡-8 — رجوع النظام أثناء الإنشاء ممنوع: مغادرة النافذة
    // لا تلغي الطلب الجاري (بدل صنف يُخلق بلا سطر ونتيجة تُبتلع).
    return PopScope<Object?>(
      canPop: !_creating,
      child: AlertDialog(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Text(
          l10n.sellQuickAddTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SimFormLineField(
              fieldKey: const Key('quick_add_name_field'),
              controller: _name,
              hint: l10n.sellQuickAddNameHint,
              required: true,
              enabled: !_creating,
              autofocus: true,
              onFieldSubmitted: (_) => unawaited(_continue()),
            ),
            const SizedBox(height: 10),
            SimFormLineField(
              fieldKey: const Key('quick_add_price_field'),
              controller: _price,
              hint: l10n.sellQuickAddPriceHint,
              enabled: !_creating,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onFieldSubmitted: (_) => unawaited(_continue()),
            ),
            const SizedBox(height: 6),
            // مربع «حفظ الصنف في قائمة المنتجات» — نمط لقطة 065028.
            InkWell(
              key: const Key('quick_add_save_toggle'),
              onTap: _creating
                  ? null
                  : () => setState(() => _saveToProducts = !_saveToProducts),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    Checkbox(
                      value: _saveToProducts,
                      onChanged: _creating
                          ? null
                          : (v) => setState(() => _saveToProducts = v ?? false),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.sellQuickAddSaveToProducts,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!_saveToProducts) ...[
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
                child: Text(
                  l10n.sellQuickAddOneOffHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                key: const Key('quick_add_error_text'),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: scheme.error,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _creating ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton.icon(
            key: const Key('quick_add_continue_btn'),
            onPressed: _creating ? null : () => unawaited(_continue()),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
            ),
            icon: _creating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_rounded, size: 18),
            label: Text(l10n.sellQuickAddContinue),
          ),
        ],
      ),
    );
  }
}
