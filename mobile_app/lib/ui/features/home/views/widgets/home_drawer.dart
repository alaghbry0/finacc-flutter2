/// الدرج الجانبي — نمط Simple Invoice Manager (V3):
/// شبكة أيقونات 3×3 للوصول السريع أعلى الدرج، ثم قوائم الوحدات
/// (بمداخل موسّعة للمخزون والتقارير والأطراف) وتذييل الإصدار.
/// كل المداخل مسارات go_router قائمة — لا شاشات جديدة.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../core/app_version.dart';

/// درج مركز المعاملات الجانبي.
class HomeDrawer extends StatelessWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Drawer(
      key: const Key('home_drawer'),
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(4)),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _sectionTitle(context, l10n.homeDrawerQuickSection),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.15,
              children: [
                _DrawerGridItem(
                  key: const Key('drawer_new_invoice'),
                  icon: Icons.receipt_long_rounded,
                  label: l10n.sellHomeNewInvoice,
                  onTap: () => _go(context, '/sell/new'),
                ),
                _DrawerGridItem(
                  key: const Key('drawer_new_quotation'),
                  icon: Icons.request_quote_rounded,
                  label: l10n.homeDrawerNewQuotation,
                  onTap: () => _go(context, '/sell'),
                ),
                _DrawerGridItem(
                  key: const Key('drawer_new_customer'),
                  icon: Icons.person_add_alt_rounded,
                  label: l10n.homeDrawerNewCustomer,
                  onTap: () => _go(context, '/parties/customers/form'),
                ),
                _DrawerGridItem(
                  key: const Key('drawer_items'),
                  icon: Icons.inventory_2_rounded,
                  label: l10n.tabInventory,
                  onTap: () => _go(context, '/inventory'),
                ),
                _DrawerGridItem(
                  key: const Key('drawer_parties'),
                  icon: Icons.groups_rounded,
                  label: l10n.partiesTabTitle,
                  onTap: () => _go(context, '/parties'),
                ),
                _DrawerGridItem(
                  key: const Key('drawer_cash'),
                  icon: Icons.account_balance_wallet_rounded,
                  label: l10n.tabCash,
                  onTap: () => _go(context, '/cash'),
                ),
                _DrawerGridItem(
                  key: const Key('drawer_purchases'),
                  icon: Icons.local_shipping_rounded,
                  label: l10n.homeTabPurchases,
                  onTap: () => _go(context, '/purchases'),
                ),
                _DrawerGridItem(
                  key: const Key('drawer_dashboard'),
                  icon: Icons.dashboard_rounded,
                  label: l10n.homeDrawerDashboard,
                  onTap: () => _go(context, '/home/dashboard'),
                ),
                _DrawerGridItem(
                  key: const Key('drawer_reports'),
                  icon: Icons.assessment_rounded,
                  label: l10n.homeTabReports,
                  onTap: () => _go(context, '/reports'),
                ),
              ],
            ),
            _sectionTitle(context, l10n.homeDrawerModulesSection),
            _DrawerExpandableItem(
              key: const Key('drawer_inventory_section'),
              icon: Icons.warehouse_rounded,
              label: l10n.tabInventory,
              children: [
                _DrawerSubItem(
                  label: l10n.inventoryHubItems,
                  onTap: () => _go(context, '/inventory/items'),
                ),
                _DrawerSubItem(
                  label: l10n.stocktakeTitle,
                  onTap: () => _go(context, '/inventory/stocktake'),
                ),
                _DrawerSubItem(
                  label: l10n.inventoryHubLowStock,
                  onTap: () => _go(context, '/inventory/low-stock'),
                ),
              ],
            ),
            _DrawerExpandableItem(
              key: const Key('drawer_reports_section'),
              icon: Icons.pie_chart_rounded,
              label: l10n.homeTabReports,
              children: [
                _DrawerSubItem(
                  label: l10n.profitTitle,
                  onTap: () => _go(context, '/reports/profit'),
                ),
                _DrawerSubItem(
                  label: l10n.homeDrawerReportsSubAging,
                  onTap: () => _go(context, '/reports/aging'),
                ),
                _DrawerSubItem(
                  label: l10n.itemMovementTitle,
                  onTap: () => _go(context, '/reports/item-movement'),
                ),
              ],
            ),
            _DrawerLinkItem(
              key: const Key('drawer_suppliers'),
              icon: Icons.local_shipping_outlined,
              label: l10n.homeDrawerNewSupplier,
              onTap: () => _go(context, '/parties/suppliers/form'),
            ),
            _DrawerLinkItem(
              key: const Key('drawer_backup'),
              icon: Icons.backup_rounded,
              label: l10n.settingsBackupTitle,
              onTap: () => _go(context, '/more/backup'),
            ),
            _DrawerLinkItem(
              key: const Key('drawer_settings'),
              icon: Icons.settings_rounded,
              label: l10n.homeSettingsLabel,
              onTap: () => _go(context, '/more'),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                l10n.homeDrawerVersion(appVersion),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// يغلق الدرج ثم يتنقل (بترتيب واحد يمنع وميض الدرج فوق الوجهة).
  void _go(BuildContext context, String location) {
    Navigator.of(context).pop();
    context.go(location);
  }
}

/// خلية شبكة الوصول السريع — أيقونة زرقاء فوق تسمية.
class _DrawerGridItem extends StatelessWidget {
  const _DrawerGridItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.25),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: scheme.primary),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// سطر قابل للتوسيع (وحدة بمداخل فرعية).
class _DrawerExpandableItem extends StatelessWidget {
  const _DrawerExpandableItem({
    super.key,
    required this.icon,
    required this.label,
    required this.children,
  });

  final IconData icon;
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Theme(
      // يمدد اللمسة لكامل السطر بلا سهم مزدوج.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: key,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.only(bottom: 4),
        leading: Icon(icon, size: 22, color: scheme.onSurfaceVariant),
        title: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontSize: 13.5),
        ),
        iconColor: scheme.onSurfaceVariant,
        children: children,
      ),
    );
  }
}

/// مدخل فرعي داخل وحدة موسّعة.
class _DrawerSubItem extends StatelessWidget {
  const _DrawerSubItem({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 44, top: 10, bottom: 10),
        child: Row(
          children: [
            Icon(
              Icons.chevron_left_rounded,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// سطر رابط مباشر.
class _DrawerLinkItem extends StatelessWidget {
  const _DrawerLinkItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      key: key,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, size: 22, color: scheme.onSurfaceVariant),
      title: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 13.5),
      ),
      onTap: onTap,
    );
  }
}
