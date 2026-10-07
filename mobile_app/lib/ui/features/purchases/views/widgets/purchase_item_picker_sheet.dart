/// نافذة «اختر الصنف للشراء» (§4 المشتريات): بحث بالاسم/الباركود + بطاقات
/// الأصناف بمخزونها الحالي وآخر تكلفة WAC. الشراء يزيد المخزون فلا حصر
/// بالنفد — «المتوفر: 0» معلومة لا منع. نقرة بطاقة تضيف بكمية 1 وتبقى
/// النافذة مفتوحة، مع وميض تأكيد على البطاقة.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../data/repositories/item_repository.dart';
import '../../../../../domain/models/item.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../view_models/purchase_item_picker_view_model.dart';
import 'purchase_widgets.dart';

/// يفتح نافذة اختيار صنف الشراء — [onPick] يُستدعى عند كل إضافة (كمية 1).
Future<void> showPurchaseItemPickerSheet(
  BuildContext context, {
  required ItemRepository itemRepo,
  required ValueChanged<ItemStockInfo> onPick,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // فوق شريط التبويبات (متصفح الفرع) — لا من أسفل الشاشة خلفه.
    useRootNavigator: false,
    builder: (_) => ChangeNotifierProvider<PurchaseItemPickerViewModel>(
      create: (_) {
        final vm = PurchaseItemPickerViewModel(itemRepo: itemRepo);
        unawaited(vm.search(''));
        return vm;
      },
      child: _PurchaseItemPickerSheet(onPick: onPick),
    ),
  );
}

class _PurchaseItemPickerSheet extends StatefulWidget {
  const _PurchaseItemPickerSheet({required this.onPick});

  final ValueChanged<ItemStockInfo> onPick;

  @override
  State<_PurchaseItemPickerSheet> createState() =>
      _PurchaseItemPickerSheetState();
}

class _PurchaseItemPickerSheetState extends State<_PurchaseItemPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  String? _barcodeError;
  int? _flashedProductId;

  @override
  void dispose() {
    _searchController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _submitBarcode(String code) async {
    final vm = context.read<PurchaseItemPickerViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final results = vm.state.results;
    // مسار سريع محلي: الباركود مطابق لنتيجة معروضة.
    for (final info in results) {
      if (info.item.barcode == code.trim()) {
        _pick(info);
        setState(() {
          _barcodeController.clear();
          _barcodeError = null;
        });
        return;
      }
    }
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    setState(() => _barcodeError = null);
    await vm.search(trimmed);
    if (!mounted) return;
    ItemStockInfo? exact;
    for (final info in vm.state.results) {
      if (info.item.barcode == trimmed) {
        exact = info;
        break;
      }
    }
    if (exact != null) {
      _pick(exact);
      setState(() => _barcodeController.clear());
      return;
    }
    setState(() => _barcodeError = l10n.sellPickerBarcodeNotFound(trimmed));
  }

  void _pick(ItemStockInfo info) {
    widget.onPick(info);
    setState(() => _flashedProductId = info.item.id);
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _flashedProductId = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PurchaseItemPickerViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final height = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: height * 0.88,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.purPickerTitle,
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
              TextField(
                key: const Key('pur_picker_barcode_field'),
                controller: _barcodeController,
                onSubmitted: _submitBarcode,
                textInputAction: TextInputAction.done,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: l10n.sellBarcodeHint,
                  prefixIcon: Icon(
                    Icons.qr_code_scanner_rounded,
                    color: scheme.primary,
                  ),
                  errorText: _barcodeError,
                  counterText: '',
                ),
                maxLength: 20,
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('pur_picker_search_field'),
                controller: _searchController,
                onChanged: vm.onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.purPickerSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            unawaited(vm.search(''));
                          },
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildResults(context, vm)),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 12),
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(l10n.sellPickerDone),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context, PurchaseItemPickerViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    if (state.loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    if (state.error != null) {
      return Center(
        child: ErrorState(
          title: l10n.genericErrorTitle,
          message: l10n.dbOpenErrorMessage,
          technicalDetails: state.error.toString(),
          retryLabel: l10n.commonRetry,
          onRetry: () => vm.search(state.query),
          compact: true,
        ),
      );
    }
    if (state.results.isEmpty) {
      return Center(
        child: state.query.isEmpty
            ? EmptyState(
                icon: Icons.inventory_2_rounded,
                title: l10n.purPickerEmptyTitle,
                message: l10n.purPickerEmptyBody,
                compact: true,
              )
            : EmptyState(
                icon: Icons.search_off_rounded,
                title: l10n.sellPickerNoResultsTitle,
                message: l10n.sellPickerNoResultsBody,
                compact: true,
              ),
      );
    }
    return GridView.builder(
      key: const Key('pur_picker_grid'),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.98,
      ),
      itemCount: state.results.length,
      itemBuilder: (context, index) {
        final info = state.results[index];
        return _PickerItemCard(
          info: info,
          flashed: _flashedProductId == info.item.id,
          onTap: () => _pick(info),
        );
      },
    );
  }
}

/// بطاقة صنف واحدة في شبكة الشراء — المخزون الحالي + آخر تكلفة WAC.
class _PickerItemCard extends StatelessWidget {
  const _PickerItemCard({
    required this.info,
    required this.flashed,
    required this.onTap,
  });

  final ItemStockInfo info;
  final bool flashed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final item = info.item;

    return Material(
      color: flashed ? scheme.primaryContainer : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: flashed
              ? scheme.primary.withValues(alpha: 0.6)
              : colors.cardBorder,
          width: flashed ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (item.isService ? scheme.tertiary : scheme.primary)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      item.isService
                          ? Icons.miscellaneous_services_rounded
                          : Icons.inventory_2_rounded,
                      size: 18,
                      color: item.isService ? scheme.tertiary : scheme.primary,
                    ),
                  ),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: flashed
                        ? Icon(
                            key: const ValueKey('picked'),
                            Icons.check_circle_rounded,
                            color: colors.positive,
                            size: 20,
                          )
                        : const SizedBox(key: ValueKey('empty')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.name,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              if (item.isService)
                StatusChip(
                  label: l10n.itemServiceBadge,
                  tone: ChipTone.brand,
                  dense: true,
                )
              else ...[
                Text(
                  l10n.purPickerAvailable(purQtyText(info.totalQty)),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: FinText.tabularNums,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.purPickerLastCost(
                    AmountText.format(
                      item.costPrice,
                      item.costPrice == item.costPrice.truncateToDouble()
                          ? 0
                          : 2,
                    ),
                  ),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.gold,
                    fontWeight: FontWeight.w700,
                    fontFeatures: FinText.tabularNums,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
