/// صف منتقي لون شاشة قوالب الطباعة (تسمية + لوحات مرجعية أفقية) —
/// مستخرج حرفياً من `print_templates_screen.dart` (R20-D3d؛ كان
/// `_ColorPickerRow` وثابت اللوحات `kTemplateColorSwatches`).
library;

import 'package:flutter/material.dart';

/// لوحات الألوان المرجعية للمنتقي — تشكيلة تكفي هوية المتاجر اليمنية
/// (الأزرق السماوي بنموذج المالك + هوية التطبيق + محايدات الورق).
const List<int> kTemplateColorSwatches = <int>[
  0xFF9DC3E6, // أزرق سماوي فاتح (نموذج المالك)
  0xFF64B5F6, // أزرق فاتح
  0xFF2196F3, // أزرق
  0xFF37474F, // كحلي رمادي
  0xFF00695C, // بذرة التطبيق (تيل عميق)
  0xFFDFEBE7, // تيل باهت (رأس البسيط الحالي)
  0xFFA87A2C, // ذهبي
  0xFF2E7D32, // أخضر
  0xFFDCE7E1, // حد فاتح
  0xFF9E9E9E, // رمادي
  0xFF1A2420, // حبر داكن
  0xFF000000, // أسود
];

/// صف منتقي لون: تسمية + لوحات مرجعية أفقية قابلة للتمرير.
class PrintTemplatesColorPickerRow extends StatelessWidget {
  const PrintTemplatesColorPickerRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kTemplateColorSwatches.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final argb = kTemplateColorSwatches[index];
              final isSelected = argb == selected;
              return InkWell(
                onTap: () => onSelected(argb),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(argb),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? scheme.primary : scheme.outline,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Colors.white,
                        )
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
