/// نافذة «اختر الصنف» (دليل 04/03 — FR-02-02): بحث بالاسم/الباركود +
/// بطاقات الأصناف بسعرها بعملة الفاتورة ومخزونها + مسح باركود بإدخال
/// يدوي وEnter يضيف أول تطابق مباشرة. نقرة بطاقة تضيف بكمية 1 وتبقى
/// النافذة مفتوحة لسرعة الكاشير، مع وميض تأكيد على البطاقة.
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
import '../../view_models/item_picker_view_model.dart';
import 'sell_widgets.dart';

/// يفتح نافذة اختيار الصنف — [onPick] يُستدعى عند كل إضافة (كمية 1).
Future<void> showItemPickerSheet(
  BuildContext context, {
  required ItemRepository itemRepo,
  required int? currencyId,
  required int decimals,
  required String? currencyCode,
  required ValueChanged<ItemStockInfo> onPick,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // فوق شريط التبويبات (متصفح الفرع) — لا من أسفل الشاشة خلفه.
    useRootNavigator: false,
    builder: (_) => ChangeNotifierProvider<ItemPickerViewModel>(
      create: (_) {
        final vm = ItemPickerViewModel(
          itemRepo: itemRepo,
          currencyId: currencyId,
        );
        unawaited(vm.search(''));
        return vm;
      },
      child: _ItemPickerSheet(
        decimals: decimals,
        currencyCode: currencyCode,
        onPick: onPick,
      ),
    ),
  );
}

class _ItemPickerSheet extends StatefulWidget {
  const _ItemPickerSheet({
    required this.decimals,
    required this.currencyCode,
    required this.onPick,
  });

  final int decimals;
  final String? currencyCode;
  final ValueChanged<ItemStockInfo> onPick;

  @override
  State<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends State<_ItemPickerSheet> {
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
    final vm = context.read<ItemPickerViewModel>();
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
    // وإلا فبحث المستودع النصي (الباركود داخل نطاق LIKE) ثم التطابق الدقيق.
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
    final vm = context.watch<ItemPickerViewModel>();
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
                      l10n.sellPickerTitle,
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
              _BarcodeField(
                controller: _barcodeController,
                error: _barcodeError,
                onSubmit: _submitBarcode,
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('sell_picker_search_field'),
                controller: _searchController,
                onChanged: vm.onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.sellPickerSearchHint,
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

  Widget _buildResults(BuildContext context, ItemPickerViewModel vm) {
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
                title: l10n.sellPickerEmptyTitle,
                message: l10n.sellPickerEmptyBody,
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
      key: const Key('sell_picker_grid'),
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
          decimals: widget.decimals,
          currencyCode: widget.currencyCode,
          flashed: _flashedProductId == info.item.id,
          onTap: () => _pick(info),
        );
      },
    );
  }
}

class _BarcodeField extends StatelessWidget {
  const _BarcodeField({
    required this.controller,
    required this.error,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String? error;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      key: const Key('sell_barcode_field'),
      controller: controller,
      onSubmitted: onSubmit,
      textInputAction: TextInputAction.done,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: l10n.sellBarcodeHint,
        prefixIcon: Icon(Icons.qr_code_scanner_rounded, color: scheme.primary),
        errorText: error,
        counterText: '',
      ),
      maxLength: 20,
    );
  }
}

/// بطاقة صنف واحدة في الشبكة — السعر بعملة الفاتورة + المخزون + وميض
/// تأكيد عند الإضافة.
class _PickerItemCard extends StatelessWidget {
  const _PickerItemCard({
    required this.info,
    required this.decimals,
    required this.currencyCode,
    required this.flashed,
    required this.onTap,
  });

  final ItemStockInfo info;
  final int decimals;
  final String? currencyCode;
  final bool flashed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final item = info.item;
    final outOfStock = !item.isService && info.totalQty <= 0;
    final price = info.retailPrice;

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
              if (price != null)
                Row(
                  children: [
                    AmountText(amount: price, decimals: decimals),
                    if (currencyCode != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        currencyCode!,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: colors.gold),
                      ),
                    ],
                  ],
                ),
              const SizedBox(height: 6),
              if (item.isService)
                StatusChip(
                  label: l10n.itemServiceBadge,
                  tone: ChipTone.brand,
                  dense: true,
                )
              else if (outOfStock)
                StatusChip(
                  label: l10n.sellPickerOutOfStock,
                  tone: ChipTone.negative,
                  dense: true,
                )
              else
                Text(
                  l10n.sellPickerAvailable(sellQtyText(info.totalQty)),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: FinText.tabularNums,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
