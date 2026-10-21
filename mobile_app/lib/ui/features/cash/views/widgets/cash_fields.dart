/// عناصر نماذج النقدية: حقل مبلغ موحد ومنتقي صندوق.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../domain/models/cash.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';

/// حقل مبلغ موحد (لوحة أرقام عشرية + منع الصفر/السالب عند التحويل).
class CashAmountField extends StatelessWidget {
  const CashAmountField({
    super.key,
    required this.controller,
    required this.label,
    this.helper,
    this.suffixCode,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;
  final String? suffixCode;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,6}')),
      ],
      onChanged: onChanged,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        suffixText: suffixCode,
        prefixIcon: const Icon(Icons.payments_rounded),
      ),
    );
  }

  /// يحل نص الحقل رقماً (يقبل الفاصلة العشرية «,») — null عند اللاغي.
  static double? parse(String raw) {
    final trimmed = raw.trim().replaceAll(',', '.');
    if (trimmed.isEmpty) return null;
    final value = double.tryParse(trimmed);
    if (value == null || value.isNaN || value.isInfinite) return null;
    return value;
  }
}

/// منتقي صندوق (Dropdown) — يعرض الاسم والعملة والرصيد الحي في البند.
class CashBoxPickerField extends StatelessWidget {
  const CashBoxPickerField({
    super.key,
    required this.boxes,
    required this.selectedId,
    required this.label,
    required this.onChanged,
    this.enabled = true,
    this.icon = Icons.account_balance_wallet_rounded,
  });

  final List<CashboxWithBalance> boxes;
  final int? selectedId;
  final String label;
  final ValueChanged<int?> onChanged;
  final bool enabled;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = FinColors.of(context);
    return DropdownButtonFormField<int>(
      initialValue: selectedId,
      // isExpanded — النص المختار (اسم الصندوق · العملة · الرصيد) يُقيَّد
      // بعرض الحقل المتاح فيعمل ellipsis بدل الفيض الأفقي (كُشف بجولة V6:
      // أول تغطية ويدجت لشاشة السند — كان يفيض ~210px على شاشة 390).
      isExpanded: true,
      onChanged: enabled ? onChanged : null,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: [
        for (final b in boxes)
          DropdownMenuItem<int>(
            value: b.box.id,
            child: Text(
              '${b.box.name} · ${b.box.currencyCode} · '
              '${b.nativeBalance < 0 ? '−' : ''}${AmountText.format(b.nativeBalance.abs(), 2)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: b.isNegative ? colors.negative : null,
                fontFeatures: FinText.tabularNums,
              ),
            ),
          ),
      ],
    );
  }
}
