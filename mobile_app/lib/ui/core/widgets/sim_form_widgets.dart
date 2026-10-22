/// عدة حقول نماذج Simple Invoice Manager (V10) — مطابقة للنموذج الأولي
/// `upload/invoice-manager.html` (أنماط `.input-line` / `.input-box` /
/// `.input-box-row`) واللقطات المرجعية `upload/Screenbox_*.png` لنموذجي
/// المنتج (08_03/08_04) والعميل (09_02/09_03):
///
/// - [SimFormCard]: بطاقة بيضاء مستديرة (12px) تضم مجموعة حقول سطور.
/// - [SimFormLineField]: حقل سطري بحد سفلي فقط (`#CFD8DC` → أزرق عند
///   التركيز) بحشو 8/4 وخط 13sp — نمط `.input-line` حرفياً.
/// - [SimFormBoxField]: حقل صندوقي بحد رباعي (4px) وحشو 7/10 — نمط
///   `.input-box` (للأزواج الرقمية كسعر البيع وفتح الأسهم).
/// - [SimFormBoxRow]: صف حقلين صندوقيين بفاصل 10px — نمط
///   `.input-box-row`.
/// - [SimFormSwitchRow]: سطر مفتاح تبديل بتسمية يمين ومفتاح يسار وحد
///   سفلي خفيف — نمط «تمكين جرد المنتج» بالنموذج الأولي.
/// - [SimFormSaveBar]: شريط الحفظ الأزرق الثابت أسفل الشاشة (CTA
///   كامل العرض) بحالة تحميل — نمط «حفظ المنتج»/«حفظ هذا».
///
/// التوكنات دلالية (scheme) فتتبع الوضع الداكن تلقائياً؛ أهداف اللمس
/// ≥ 48dp للأزرار، ونصوص ≥ 12sp، وتُدار RTL بالاتجاه العام.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// بطاقة نموذج بيضاء — حاوية موحّدة لمجموعة حقول النموذج.
class SimFormCard extends StatelessWidget {
  const SimFormCard({super.key, required this.child, this.padding});

  /// محتوى البطاقة (حقول السطور عادة).
  final Widget child;

  /// حشو خاص (الافتراضي 14/12).
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: padding ?? const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: child,
    );
  }
}

/// حقل سطري بحد سفلي — نمط `.input-line` (13sp، حشو 8/4، حد
/// `#CFD8DC` يتحول للأزرق عند التركيز). [required] يضيف نجمة حمراء
/// بعد التلميح (نمط «اسم المنتج *»).
class SimFormLineField extends StatelessWidget {
  const SimFormLineField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.required = false,
    this.enabled = true,
    this.suffix,
    this.maxLines = 1,
    this.focusNode,
    this.onFieldSubmitted,
    this.autofocus = false,
    this.fieldKey,
  });

  /// تلميح الحقل (نص العنصر النائب كما بالنموذج الأولي).
  final String hint;

  final TextEditingController? controller;

  final ValueChanged<String>? onChanged;

  /// نوع لوحة المفاتيح (أرقام للأسعار مثلاً).
  final TextInputType? keyboardType;

  /// منسّقات الإدخال (تصفية الأرقام مثلاً).
  final List<TextInputFormatter>? inputFormatters;

  /// مدقق TextFormField القياسي.
  final FormFieldValidator<String>? validator;

  /// حقل إلزامي — نجمة حمراء بعد التلميح.
  final bool required;

  final bool enabled;

  /// لاحقة (زر توليد الباركود مثلاً).
  final Widget? suffix;

  /// عدد الأسطر (الملاحظات متعددة الأسطر).
  final int? maxLines;

  final FocusNode? focusNode;

  final ValueChanged<String>? onFieldSubmitted;

  final bool autofocus;

  /// مفتاح اختبار للحقل.
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7));
    final focused = BorderSide(color: scheme.primary, width: 1.6);
    return TextFormField(
      key: fieldKey,
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      enabled: enabled,
      focusNode: focusNode,
      onFieldSubmitted: onFieldSubmitted,
      autofocus: autofocus,
      maxLines: maxLines,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
      decoration: InputDecoration(
        hintText: required ? '$hint *' : hint,
        hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 13,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        enabledBorder: UnderlineInputBorder(borderSide: border),
        focusedBorder: UnderlineInputBorder(borderSide: focused),
        disabledBorder: UnderlineInputBorder(borderSide: border),
        suffixIcon: suffix,
      ),
    );
  }
}

/// حقل صندوقي — نمط `.input-box` (حد رباعي 4px، حشو 7/10، 13sp).
class SimFormBoxField extends StatelessWidget {
  const SimFormBoxField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.required = false,
    this.fieldKey,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final bool required;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(4);
    final border = BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7));
    final focused = BorderSide(color: scheme.primary, width: 1.4);
    return TextFormField(
      key: fieldKey,
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
      decoration: InputDecoration(
        hintText: required ? '$hint *' : hint,
        hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 13,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
        ),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
        enabledBorder: OutlineInputBorder(borderSide: border, borderRadius: radius),
        focusedBorder:
            OutlineInputBorder(borderSide: focused, borderRadius: radius),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: scheme.error),
          borderRadius: radius,
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: scheme.error, width: 1.4),
          borderRadius: radius,
        ),
        filled: true,
        fillColor: scheme.surface,
      ),
    );
  }
}

/// صف حقلين صندوقيين بفاصل 10px — نمط `.input-box-row` (سعر البيع +
/// فتح الأسهم). [end] الحقل الثاني (أقصى الطرف في RTL يظل بترتيب
/// النموذج الأولي: الأول يمينًا).
class SimFormBoxRow extends StatelessWidget {
  const SimFormBoxRow({super.key, required this.start, required this.end});

  /// الحقل الأول (يمين الشاشة RTL).
  final Widget start;

  /// الحقل الثاني (يسار الشاشة RTL).
  final Widget end;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: start),
          const SizedBox(width: 10),
          Expanded(child: end),
        ],
      ),
    );
  }
}

/// سطر مفتاح تبديل — تسمية 13sp يمينًا ومفتاح يسارًا وحد سفلي خفيف؛
/// نمط «تمكين جرد المنتج» بالنموذج الأولي. النقر على السطر كله يبدّل.
class SimFormSwitchRow extends StatelessWidget {
  const SimFormSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
  });

  /// تسمية السطر (13sp).
  final String label;

  final bool value;

  final ValueChanged<bool>? onChanged;

  /// وصف صغير اختياري تحت التسمية (12sp رمادي).
  final String? description;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontSize: 13, color: scheme.onSurface),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ],
      ),
    );
  }
}

/// شريط الحفظ الثابت أسفل الشاشة — CTA أزرق كامل العرض (48dp)
/// بحالة تحميل وحالة تعطيل اختيارية؛ نمط «حفظ المنتج» بالنموذج
/// الأولي و«حفظ هذا» بلقطة نموذج العميل.
class SimFormSaveBar extends StatelessWidget {
  const SimFormSaveBar({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
    this.buttonKey,
    this.margin = const EdgeInsets.fromLTRB(14, 8, 14, 14),
  });

  /// تسمية الزر («حفظ المنتج» / «حفظ هذا»).
  final String label;

  final VoidCallback? onPressed;

  /// عرض مؤشر انتظار بدل الأيقونة وتعطيل النقر.
  final bool loading;

  /// تعطيل صريح (نموذج غير جاهز).
  final bool enabled;

  /// مفتاح اختبار للزر.
  final Key? buttonKey;

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = enabled && !loading;
    return SafeArea(
      top: false,
      child: Padding(
        padding: margin,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            key: buttonKey,
            onPressed: active ? onPressed : null,
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              disabledBackgroundColor:
                  scheme.primary.withValues(alpha: 0.45),
              disabledForegroundColor: scheme.onPrimary.withValues(alpha: 0.8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.check_rounded, size: 20),
            label: Text(label),
          ),
        ),
      ),
    );
  }
}
