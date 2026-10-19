/// شريط التبويبات الأفقي القابل للتمرير — نمط Simple Invoice Manager (V3):
/// ألسنة نصية بلا حدود، النشطة منها بأسفل أزرق بارز (3px) وخط أثقل،
/// والشريط كله بحدّ سفلي رقيق. يُخفى شريط التمرير ليبقى المظهر نظيفاً.
library;

import 'package:flutter/material.dart';

/// شريحة تبويب واحدة.
class HomeTabChip {
  const HomeTabChip({required this.key, required this.label});

  /// مفتاح مستقر للاختبارات والتمرير التلقائي.
  final Key key;

  final String label;
}

/// شريط تبويبات مركز المعاملات.
class HomeTabsBar extends StatelessWidget {
  const HomeTabsBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
  });

  /// الألسنة بالترتيب.
  final List<HomeTabChip> tabs;

  /// الفهرس النشط.
  final int selectedIndex;

  /// يُستدعى بفهرس اللسان المضغوط.
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: SizedBox(
        height: 44,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          itemCount: tabs.length,
          itemBuilder: (context, index) {
            final tab = tabs[index];
            final selected = index == selectedIndex;
            return InkWell(
              key: tab.key,
              onTap: () => onSelect(index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? scheme.primary : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  tab.label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 13,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
