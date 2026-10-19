/// ترويسة الشاشة الرئيسية — نمط Simple Invoice Manager (V3):
/// زر القائمة (يفتح الدرج) + العنوان الأزرق بجانبه، وفي الجهة المقابلة
/// ثلاثة عناصر أيقونية عمودية (تنبيه/مزامنة/إعدادات) بأهداف لمس ≥ 48dp.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../l10n/app_localizations.dart';

/// ترويسة مركز المعاملات.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.title,
    required this.onRefresh,
  });

  /// عنوان الترويسة (اسم المنشأة — أو اسم التطبيق احتياطاً).
  final String title;

  /// يُستدعى عند ضغط «مزامنة» (إعادة تحميل + إشعار).
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: Row(
        children: [
          // RTL: يظهر أقصى اليمين — القائمة ثم العنوان.
          IconButton(
            key: const Key('home_menu_button'),
            tooltip: l10n.homeMenuLabel,
            icon: const Icon(Icons.menu_rounded),
            color: scheme.onSurfaceVariant,
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _HeaderIconItem(
            icon: Icons.notifications_none_rounded,
            label: l10n.homeBellLabel,
            iconColor: scheme.error,
            onTap: () => _noAlerts(context),
          ),
          _HeaderIconItem(
            key: const Key('home_sync_button'),
            icon: Icons.sync_rounded,
            label: l10n.homeSyncLabel,
            onTap: onRefresh,
          ),
          _HeaderIconItem(
            icon: Icons.settings_outlined,
            label: l10n.homeSettingsLabel,
            onTap: () => context.go('/more'),
          ),
        ],
      ),
    );
  }

  void _noAlerts(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.homeBellNoAlerts), duration: const Duration(seconds: 2)),
      );
  }
}

/// عنصر أيقوني عمودي صغير (أيقونة فوق تسمية) — لمسة ≥ 48dp.
class _HeaderIconItem extends StatelessWidget {
  const _HeaderIconItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 56,
        height: 48,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: iconColor ?? scheme.onSurfaceVariant),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
