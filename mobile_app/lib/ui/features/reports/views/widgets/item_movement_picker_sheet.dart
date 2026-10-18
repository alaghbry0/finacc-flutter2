/// نافذة اختيار الصنف لتقرير حركة صنف (R19-D3a — مستخرجة حرفياً من
/// `item_movement_screen.dart` بلا أي تغيير دلالة؛ كانت `_openProductPicker`
/// و`_ProductPickerSheet` و`_PickerProductRow`).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../data/repositories/item_repository.dart';
import '../../../../../domain/models/item.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/fin_search_field.dart';
import '../../../../core/widgets/fin_sheet_drag_handle.dart';
import '../../../../core/session/app_controller.dart';
import '../../view_models/movement_reports_view_model.dart';
import 'item_movement_format.dart';

/// يفتح نافذة اختيار الصنف (بحث + مخزون) — بنمط نافذة البيع.
Future<void> openItemMovementProductPicker(
  BuildContext context,
  ItemMovementViewModel vm,
) async {
  final app = context.read<AppController>();
  final itemRepo = app.items ?? ItemRepository(app.database!.db);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ItemMovementProductPickerSheet(
      itemRepo: itemRepo,
      onPick: vm.setProduct,
    ),
  );
}

/// نافذة اختيار الصنف لحركة صنف — نقرة واحدة تختار وتغلق.
class ItemMovementProductPickerSheet extends StatefulWidget {
  const ItemMovementProductPickerSheet({
    super.key,
    required this.itemRepo,
    required this.onPick,
  });

  final ItemRepository itemRepo;
  final ValueChanged<int> onPick;

  @override
  State<ItemMovementProductPickerSheet> createState() =>
      _ItemMovementProductPickerSheetState();
}

class _ItemMovementProductPickerSheetState
    extends State<ItemMovementProductPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  /// نتائج البحث الجارية (null = جارٍ الجلب).
  List<ItemStockInfo>? _results;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_search(''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() {
      _error = null;
      _results = null;
    });
    try {
      final results = await widget.itemRepo.searchItems(query);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      unawaited(_search(query));
    });
  }

  void _pick(ItemStockInfo info) {
    Navigator.of(context).pop();
    widget.onPick(info.item.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final height = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: height * 0.82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FinSheetDragHandle(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.itemMovementPickerTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.commonDone,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FinSearchField(
                fieldKey: const Key('itemMovement_picker_search_field'),
                controller: _searchController,
                onChanged: _onQueryChanged,
                hint: l10n.itemMovementPickerSearchHint,
                autofocus: true,
                onCleared: () {
                  _searchController.clear();
                  unawaited(_search(''));
                },
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildResults(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_error != null) {
      return Center(
        child: ErrorState(
          title: l10n.genericErrorTitle,
          message: l10n.dbOpenErrorMessage,
          technicalDetails: _error.toString(),
          retryLabel: l10n.commonRetry,
          onRetry: () => unawaited(_search(_searchController.text)),
          compact: true,
        ),
      );
    }
    final results = _results;
    if (results == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    if (results.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: l10n.itemMovementPickerNoResults,
          message: l10n.itemMovementPickerSearchHint,
          compact: true,
        ),
      );
    }
    return ListView.builder(
      key: const Key('itemMovement_picker_list'),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final info = results[index];
        return ItemMovementPickerProductRow(
          info: info,
          onTap: () => _pick(info),
        );
      },
    );
  }
}

/// صف صنف واحد في نافذة الاختيار — الاسم + الباركود + المخزون.
class ItemMovementPickerProductRow extends StatelessWidget {
  const ItemMovementPickerProductRow({
    super.key,
    required this.info,
    required this.onTap,
  });

  final ItemStockInfo info;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final item = info.item;
    final outOfStock = !item.isService && info.totalQty <= 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (item.isService ? scheme.tertiary : scheme.primary)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item.isService
                        ? Icons.miscellaneous_services_rounded
                        : Icons.inventory_2_rounded,
                    size: 20,
                    color: item.isService ? scheme.tertiary : scheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (item.barcode != null && item.barcode!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.barcode!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ] else
                        const SizedBox(height: 2),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (item.isService)
                  Text(
                    l10n.itemServiceBadge,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.tertiary),
                  )
                else
                  Text(
                    outOfStock
                        ? l10n.sellPickerOutOfStock
                        : l10n.sellPickerAvailable(
                            itemMovementQtyText(info.totalQty),
                          ),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: outOfStock
                          ? colors.negative
                          : scheme.onSurfaceVariant,
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
