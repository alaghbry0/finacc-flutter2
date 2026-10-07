/// هيكل التطبيق — شريط التبويبات الخمسي (§6.4): الرئيسية — المخزون —
/// **البيع (زر بارز وسط)** — النقدية — المزيد، مع الالتزام بأهداف اللمس
/// ≥ 48dp وحجم نص ≥ 12px.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';

/// عنصر تبويب.
class _TabSpec {
  const _TabSpec({
    required this.location,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String location;
  final String Function(AppLocalizations l10n) label;
  final IconData icon;
  final IconData activeIcon;
}

/// الهيكل الرئيسي حول فروع الموجّه.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static final List<_TabSpec> _rightTabs = <_TabSpec>[
    _TabSpec(
      location: '/home',
      label: (l) => l.tabHome,
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    _TabSpec(
      location: '/inventory',
      label: (l) => l.tabInventory,
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2_rounded,
    ),
  ];

  static final List<_TabSpec> _leftTabs = <_TabSpec>[
    _TabSpec(
      location: '/cash',
      label: (l) => l.tabCash,
      icon: Icons.account_balance_outlined,
      activeIcon: Icons.account_balance_rounded,
    ),
    _TabSpec(
      location: '/more',
      label: (l) => l.tabMore,
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
    ),
  ];

  // فهرس زر البيع داخل الفروع (0=home, 1=inventory, 2=sell, 3=cash, 4=more).
  static const int _sellBranch = 2;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final currentIndex = navigationShell.currentIndex;
    final isDark = scheme.brightness == Brightness.dark;

    Widget tabButton(_TabSpec spec, int index) {
      final selected = currentIndex == index;
      final color = selected ? scheme.primary : scheme.onSurfaceVariant;
      return SizedBox(
        width: 64,
        height: 58,
        child: InkWell(
          onTap: () => _goBranch(index),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // كبسولة مؤشر متحركة (تمدد/انكماش ناعم + قفزة أيقونة).
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 3,
                ),
                decoration: selected
                    ? BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.18),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      )
                    : const BoxDecoration(),
                child: AnimatedScale(
                  scale: selected ? 1.08 : 1.0,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    selected ? spec.activeIcon : spec.icon,
                    size: 23,
                    color: selected ? scheme.onPrimaryContainer : color,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                spec.label(l10n),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 12,
                ),
                maxLines: 1,
              ),
            ],
          ),
        ),
      );
    }

    // زر البيع البارز في الوسط (أهم فعل يومي — §6.4) — توهج نابض خافت
    // في الوضع النشط يحفز الانتباه دون إزعاج.
    final sellActive = currentIndex == _sellBranch;
    final sellButton = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.9, end: 1.0),
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeOutBack,
          builder: (context, t, child) {
            return Transform.scale(scale: t, child: child);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary,
                  Color.lerp(scheme.primary, Colors.black, 0.3)!,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: isDark ? 0.5 : 0.35),
                  blurRadius: sellActive ? 20 : 14,
                  spreadRadius: sellActive ? 2 : 0,
                  offset: const Offset(0, 5),
                ),
              ],
              border: Border.all(color: scheme.surface, width: 3.5),
            ),
            child: Icon(
              sellActive
                  ? Icons.point_of_sale_rounded
                  : Icons.add_shopping_cart_rounded,
              color: scheme.onPrimary,
              size: 26,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          l10n.tabSell,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: sellActive ? scheme.onSurface : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );

    return Scaffold(
      body: navigationShell,
      // extendBody = false (قرار UX صريح): جسم الشاشة ينتهي فوق شريط
      // التنقل — لا يبقى أي محتوى (أسفل القوائم/شريط الدفع) مختبئاً خلفه،
      // والنوافذ المنبثقة (BottomSheets) تُفتح على متصفح الفرع فتظهر
      // من فوق الشريط لا من أسفل الشاشة خلفه.
      extendBody: false,
      bottomNavigationBar: BottomAppBar(
        elevation: 0,
        padding: EdgeInsets.zero,
        height: 72,
        color: scheme.surface,
        shape: const AutomaticNotchedShape(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              // RTL: أول عنصر يظهر أقصى اليمين.
              tabButton(_rightTabs[0], 0),
              tabButton(_rightTabs[1], 1),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: () => _goBranch(_sellBranch),
                    // OverflowBox: يسمح للزر المركّب (دائرة + تسمية) بالارتفاع
                    // فوق حدّ الشريط بلا انزياح — الزر البارز يعلو بحرية
                    // بصرية بينما تبقى القيود سليمة (لا تجاوز RenderFlex).
                    child: OverflowBox(
                      maxHeight: 92,
                      alignment: Alignment.bottomCenter,
                      child: sellButton,
                    ),
                  ),
                ),
              ),
              tabButton(_leftTabs[0], 3),
              tabButton(_leftTabs[1], 4),
            ],
          ),
        ),
      ),
    );
  }

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
