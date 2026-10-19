/// شريط التصفية والبحث — نمط Simple Invoice Manager (V3):
/// سطر أول: مرشح الحالة (نص + سهم) يميناً وأيقونات (بحث/فرز) يساراً؛
/// وسطر بحث مضمّن ينكشف فوقه عند تفعيل أيقونة البحث.
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../view_models/transactions_home_view_model.dart';

/// شريط التصفية + البحث المضمّن لمركز المعاملات.
class HomeFilterBar extends StatelessWidget {
  const HomeFilterBar({
    super.key,
    required this.statusFilter,
    required this.onStatusTap,
    required this.sort,
    required this.onSortTap,
    required this.searchVisible,
    required this.searchController,
    required this.onQueryChanged,
    required this.onToggleSearch,
    required this.showStatusChip,
  });

  /// مرشح الحالة الحالي (يُعرض نصه).
  final HomeStatusFilter statusFilter;

  /// يفتح قائمة مرشح الحالة.
  final VoidCallback onStatusTap;

  /// الفرز الحالي (لتلميح الأداة فقط).
  final HomeSortOption sort;

  /// يفتح قائمة الفرز.
  final VoidCallback onSortTap;

  /// هل شريط البحث ظاهر؟
  final bool searchVisible;

  /// متحكم حقل البحث (يملكه الأب — يبقى النص والؤشر عبر إعادة البناء).
  final TextEditingController searchController;

  /// يتغير نص البحث.
  final ValueChanged<String> onQueryChanged;

  /// يظهر/يخفي شريط البحث.
  final VoidCallback onToggleSearch;

  /// هل يُعرض مرشح الحالة؟ (فواتير البيع/الشراء فقط — للباقي يُخفى).
  final bool showStatusChip;

  String _statusLabel(AppLocalizations l10n) => switch (statusFilter) {
    HomeStatusFilter.all => l10n.homeFilterAll,
    HomeStatusFilter.paid => l10n.homeFilterPaid,
    HomeStatusFilter.partial => l10n.homeFilterPartial,
    HomeStatusFilter.unpaid => l10n.homeFilterUnpaid,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              if (showStatusChip)
                InkWell(
                  key: const Key('home_status_filter_button'),
                  onTap: onStatusTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          _statusLabel(l10n),
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              const Spacer(),
              IconButton(
                key: const Key('home_search_toggle_button'),
                tooltip: l10n.homeSearchHint,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  searchVisible ? Icons.search_off_rounded : Icons.search,
                  size: 20,
                ),
                color: scheme.onSurfaceVariant,
                onPressed: onToggleSearch,
              ),
              IconButton(
                key: const Key('home_sort_button'),
                tooltip: l10n.homeSortTitle,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.sort_rounded, size: 20),
                color: scheme.onSurfaceVariant,
                onPressed: onSortTap,
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: searchVisible
              ? Container(
                  key: const Key('home_inline_search_field'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          key: const Key('home_search_input'),
                          onChanged: onQueryChanged,
                          controller: searchController,
                          textInputAction: TextInputAction.search,
                          style: Theme.of(context).textTheme.bodyMedium,
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: l10n.homeSearchHint,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                        onPressed: onToggleSearch,
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
