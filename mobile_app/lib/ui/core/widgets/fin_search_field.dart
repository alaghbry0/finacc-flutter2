/// FinSearchField — حقل بحث القوائم الموحد (W6/R17-b — تدقيق R16 §2.1
/// عائلة #16): بادئة بحث ولاحقة مسح تظهر عند وجود نص فقط. كانت أربع
/// نسخ حرفية متطابقة (`_SearchField` بقوائم الأصناف والعملاء/الموردين
/// وأرصدة الأطراف والجرد) فاستُخرجت واحدة بالنواة؛ مفتاح الاختبار
/// (يوضع على الـTextField نفسه كما كان) والتلميح يمرَّران معاملَين.
library;

import 'package:flutter/material.dart';

/// حقل بحث قائمة — بادئة بحث ولاحقة مسح.
class FinSearchField extends StatelessWidget {
  const FinSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onCleared,
    this.fieldKey,
    this.hint,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;

  /// مفتاح الاختبار — يوضع على الـTextField نفسه (كما بالنسخ الأصلية)
  /// حتى تستمر find.byKey/enterText بالعمل بلا تغيير.
  final Key? fieldKey;

  /// تلميح البحث المترجم.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          key: fieldKey,
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: onCleared,
                  ),
          ),
        );
      },
    );
  }
}
