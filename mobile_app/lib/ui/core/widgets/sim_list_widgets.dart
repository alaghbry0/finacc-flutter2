/// مكونات قوائم Simple Invoice Manager المشتركة (V5) — لشاشات العملاء
/// والمنتجات — مطابقة للنموذج الأولي `upload/invoice-manager.html`
/// (أقسام screen-clients وscreen-products) والمرجع التصميمي
/// `docs/sim-design-reference.md` §1/§2:
///
/// - [SimSubHeader]: الترويسة الفرعية (رجوع + عنوان عريض + أيقونات فعل
///   رمادية مزرقة) بخلفية `#F5F7F8` وحد سفلي.
/// - [SimTutorialBanner]: بانر تعليمي أزرق فاتح (خلفية `#E1F5FE`، حد
///   `#B3E5FC`) بأيقونة تشغيل حمراء — قابل للنقر.
/// - [SimModeTabs]: تبويبات نمط (عميل/مورد) بمؤشر سفلي 3dp أزرق للنشط.
/// - [SimAddWideButton]: زر الإضافة الأزرق كامل العرض (`#1976D2`).
/// - [SimSheetTile]: سطر قائمة سفلية (⋮) بأيقونة وتسمية وشيفرون.
///
/// التوكنات دلالية (scheme/FinColors) فتتبع الوضع الداكن والتباين
/// العالي تلقائياً؛ أهداف اللمس ≥ 48dp ونصوص ≥ 12px.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// الترويسة الفرعية — رجوع + عنوان 15sp/700 + أيقونات أفعال (بحث/تصدير/⋮).
class SimSubHeader extends StatelessWidget {
  const SimSubHeader({
    super.key,
    required this.title,
    this.onBack,
    this.titleKey,
    this.actions = const [],
  });

  /// عنوان الترويسة (مثل «عميل / المورد» أو «قائمة المنتجات»).
  final String title;

  /// زر الرجوع — في SIM يعود للمركز الرئيسي. **V7 (نقد F9-a):
  /// اختياري** — جذر تبويب (مثل /more و/reports) لا يعود إلى شيء
  /// فإخفاء الزر عنده أصادق من رجوع اصطناعي إلى /home؛ الشاشات
  /// المدفوعة تمرره كالسابق بلا أي تغيير.
  final VoidCallback? onBack;

  /// مفتاح اختبار للعنوان (اختياري).
  final Key? titleKey;

  /// أيقونات الأفعال في الطرف المقابل (RTL: أقصى اليسار).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? scheme.surface : const Color(0xFFF5F7F8),
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
      padding: const EdgeInsetsDirectional.only(start: 4, end: 8),
      child: Row(
        children: [
          // V7 — بلا onBack (جذر تبويب) لا زر رجوع أصلًا: العنوان
          // يبدأ من حافة البداية بإطار أوسع صادق.
          if (onBack != null) ...[
            IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(Icons.arrow_back_rounded),
              color: scheme.onSurfaceVariant,
              onPressed: onBack,
            ),
            const SizedBox(width: 4),
          ] else
            const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              key: titleKey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// زر أيقونة ترويسة فرعية — أيقونة 22px رمادية مزرقة (#546E7A فاتح).
class SimSubHeaderAction extends StatelessWidget {
  const SimSubHeaderAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// الحالة النشطة (مثل كشف البحث) — أيقونة زرقاء.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 22),
      color: active ? scheme.primary : FinColors.of(context).neutral,
      onPressed: onPressed,
    );
  }
}

/// V7 — صف إعداد SIM (نمط `.setting-row` بالنموذج الأولي حرفياً):
/// بطاقة بيضاء بعنوان عريض 15sp (#263238) ووصف رمادي 12sp تحته
/// وشيفرون بادئ (RTL: يسار) بلون #90A4AE — النقر كله يمشي للوجهة.
/// [leading] اختياري لأيقونة صغيرة قبل العنوان (توسيع مسقبلي)،
/// [valueLabel] اختياري لقيمة موجزة محاذاة قبل الشيفرون.
class SimSettingRow extends StatelessWidget {
  const SimSettingRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleKey,
    this.leading,
    this.valueLabel,
  });

  /// عنوان الصف (h5 بالنموذج).
  final String title;

  /// الوصف التفصيلي (p بالنموذج — رمادي).
  final String subtitle;

  /// النقر — يفتح الشاشة/الورقة الهدف.
  final VoidCallback onTap;

  /// مفتاح اختبار للعنوان.
  final Key? titleKey;

  final Widget? leading;

  final String? valueLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return Material(
      color: scheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      key: titleKey,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (valueLabel != null) ...[
                const SizedBox(width: 8),
                Text(
                  valueLabel!,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.neutral),
                ),
              ],
              const SizedBox(width: 6),
              Icon(Icons.chevron_left_rounded, size: 20, color: colors.neutral),
            ],
          ),
        ),
      ),
    );
  }
}

/// البانر التعليمي — «كيفية إضافة …» بأيقونة تشغيل (نمطة يوتيوب الأصلية).
class SimTutorialBanner extends StatelessWidget {
  const SimTutorialBanner({super.key, required this.text, this.onTap});

  /// نص البانر (سؤال تعليمي).
  final String text;

  /// النقر يفتح شرح الخطوات (حوار مساعدة).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final bg = isDark
        ? scheme.primary.withValues(alpha: 0.10)
        : const Color(0xFFE1F5FE);
    final border = isDark
        ? scheme.primary.withValues(alpha: 0.32)
        : const Color(0xFFB3E5FC);
    final fg = isDark ? scheme.primary : const Color(0xFF0277BD);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.play_circle_fill_rounded,
                  size: 20,
                  color: Color(0xFFE53935),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: fg, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// مواصفة تبويب نمط واحد.
class SimModeTabSpec {
  const SimModeTabSpec({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;
}

/// شريط تبويبات النمط (عميل/مورد) — النشط أزرق بمؤشر سفلي 3dp.
class SimModeTabs extends StatelessWidget {
  const SimModeTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
  });

  /// التبويبان (بالترتيب البصري RTL).
  final List<SimModeTabSpec> tabs;

  /// فهرس التبويب النشط.
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? scheme.surface : const Color(0xFFF5F7F8),
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: _ModeTab(spec: tabs[i], selected: i == selectedIndex),
            ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({required this.spec, required this.selected});

  final SimModeTabSpec spec;
  final bool selected;

  static const double _minHeight = 46;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: spec.onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: _minHeight),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 3,
              color: selected ? scheme.primary : Colors.transparent,
            ),
          ),
        ),
        child: Center(
          child: Text(
            spec.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// زر الإضافة الأزرق كامل العرض — نمط «+ اضافة عميل جديد».
class SimAddWideButton extends StatelessWidget {
  const SimAddWideButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.buttonKey,
  });

  /// التسمية بلا علامة الجمع (الأيقونة تقدمها).
  final String label;

  final VoidCallback onPressed;

  /// مفتاح اختبار (اختياري).
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          key: buttonKey,
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            textStyle: Theme.of(context).textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: Text(label),
        ),
      ),
    );
  }
}

/// سطر قائمة سفلية (⋮) — أيقونة + تسمية + شيفرون، بارتفاع لمس مريح.
class SimSheetTile extends StatelessWidget {
  const SimSheetTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// لون الأيقونة (افتراضي: دلالي محايد).
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: iconColor ?? FinColors.of(context).neutral),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      trailing: Icon(
        Icons.chevron_left_rounded,
        color: scheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}

/// كبسولة الإجراء العائمة بنمط SIM — `#0288D1` بظل أزرق ناعم (نفس
/// كبسولة الرئيسية من V3): أيقونة + ثم النص الأبيض العريض 14sp.
class SimFabPill extends StatelessWidget {
  const SimFabPill({
    super.key,
    required this.label,
    required this.onTap,
    this.buttonKey,
  });

  /// تسمية الكبسولة (مثل «إضافة المنتج»).
  final String label;

  final VoidCallback onTap;

  /// مفتاح اختبار (اختياري).
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        key: buttonKey,
        color: isDark ? scheme.primary : const Color(0xFF0288D1),
        borderRadius: BorderRadius.circular(25),
        elevation: isDark ? 4 : 6,
        shadowColor: const Color(0xFF0288D1)
            .withValues(alpha: isDark ? 0.5 : 0.4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(25),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 20, color: scheme.onPrimary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// زر واحد بشريط الإجراءات السفلي SIM — أيقونة فوق تسمية صغيرة.
///
/// (V6: انتقل من sell/views/widgets/sim_invoice_widgets.dart إلى core —
/// صار مستهلكًا من ميزتين (البيع والنقدية) فمكانه الطبيعي هنا مع بقية
/// مكونات SIM المشتركة، مع سقوط استيراد cash→sell المخالف للطبقات.)
class SimBottomActionItem {
  const SimBottomActionItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.enabled = true,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final bool primary;
}

/// شريط الإجراءات السفلي (حفظ/عرض/خصم/أكثر…) — خلفية سطح فاتحة وحد
/// علوي وفواصل بين الأزرار؛ زر primary (الحفظ) بلون التطبيق وبقية
/// الأزرار محايدة (لقطة 062621 البند G). قرار الأزرار عند المستدعي.
class SimBottomActionBar extends StatelessWidget {
  const SimBottomActionBar({super.key, required this.items});

  final List<SimBottomActionItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: colors.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    color: colors.cardBorder,
                  ),
                Expanded(child: _ActionTile(item: items[i])),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.item});

  final SimBottomActionItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = item.enabled && item.onTap != null;
    final color = !active
        ? scheme.onSurfaceVariant.withValues(alpha: 0.5)
        : item.primary
        ? scheme.primary
        : scheme.onSurfaceVariant;
    return InkWell(
      onTap: active ? item.onTap : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, size: 22, color: color),
          const SizedBox(height: 3),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: item.primary ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
