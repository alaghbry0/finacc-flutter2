/// شاشة نموذج الصنف (إضافة/تعديل — دليل 02/02): اسم إلزامي، باركود مع
/// توليد EAN-13 ومعاينة (FR-01-02)، فئة ووحدة بإضافة فورية، أسعار بكل
/// العملات النشطة، صنف خدمي بلا مخزون (FR-01-16)، وكمية افتتاحية في
/// الإنشاء فقط.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/company.dart';
import '../../../../domain/models/item.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/dirty_form_guard.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/info_note.dart';
import '../../../core/widgets/fin_section_title.dart';
import '../../../core/widgets/loading_state.dart';
import '../view_models/item_form_view_model.dart';
import 'widgets/inventory_widgets.dart';

class ItemFormScreen extends StatelessWidget {
  const ItemFormScreen({super.key, this.viewModel, this.editItem, this.editId});

  /// Seam اختبار: نموذج محمّل مسبقاً — عند غيابه تُنشئ الشاشة نموذجها.
  final ItemFormViewModel? viewModel;

  /// الصنف الأصلي في وضع التعديل (أو معرّفه فقط — تُحمَّل تفاصيله).
  final Item? editItem;
  final int? editId;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final ItemFormViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = ItemFormViewModel(
        itemRepo: app.items!,
        companyRepo: app.companies!,
        editItem: editItem,
        editId: editId,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<ItemFormViewModel>.value(
      value: vm,
      child: const _ItemFormBody(),
    );
  }
}

class _ItemFormBody extends StatefulWidget {
  const _ItemFormBody();

  @override
  State<_ItemFormBody> createState() => _ItemFormBodyState();
}

class _ItemFormBodyState extends State<_ItemFormBody> {
  final _formKey = GlobalKey<FormState>();

  /// R16-b — مفتاح لافتة خطأ التحقير (أعلى زر الحفظ أسفل النموذج):
  /// يُسقَط إليها تلقائياً عند ظهورها كي يرى المستخدم سبب رفض الحفظ
  /// حتى لو كان أسفل الشاشة (نموذج أطول من الشاشة).
  final GlobalKey _validationBannerKey = GlobalKey();

  late final TextEditingController _name;
  late final TextEditingController _barcode;
  late final TextEditingController _cost;
  late final TextEditingController _minStock;
  late final TextEditingController _openingQty;
  late final TextEditingController _notes;
  final Map<int, TextEditingController> _priceControllers =
      <int, TextEditingController>{};

  bool _controllersReady = false;
  bool _popped = false;

  /// لقطة الحالة ما بعد التحميل — مقارنة التغييرات لحماية المغادرة (P1-4).
  ItemFormState? _dirtyBaseline;

  /// آخر خطأ تحقق أُسقط إليه (R16-b) — يمنع تكرار الإسقاط لنفس الخطأ.
  ItemFormError? _lastValidationError;

  /// هل في النموذج تغييرات غير محفوظة؟ (مقارنة الحالة باللقطة؛ بعد الحفظ
  /// أو قبل التحميل = نظيف).
  bool get _dirty {
    final baseline = _dirtyBaseline;
    if (baseline == null) return false;
    final state = _vm.state;
    if (state.saved) return false;
    return state.name != baseline.name ||
        state.barcode != baseline.barcode ||
        state.categoryId != baseline.categoryId ||
        state.unitId != baseline.unitId ||
        state.costText != baseline.costText ||
        state.minStockText != baseline.minStockText ||
        state.openingQtyText != baseline.openingQtyText ||
        state.notes != baseline.notes ||
        state.isService != baseline.isService ||
        state.trackBatches != baseline.trackBatches ||
        !mapEquals(state.priceTexts, baseline.priceTexts);
  }

  /// النموذج يُخزَّن حقلاً عند أول بناء — القراءة من context داخل dispose
  /// غير آمنة (عنصر معطّل) وتكسر تفكيك الشجرة في الاختبارات.
  late final ItemFormViewModel _storedVm;
  ItemFormViewModel get _vm => _storedVm;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _barcode = TextEditingController();
    _cost = TextEditingController();
    _minStock = TextEditingController();
    _openingQty = TextEditingController();
    _notes = TextEditingController();
    _storedVm = context.read<ItemFormViewModel>();
    _storedVm.addListener(_onVmChanged);
  }

  @override
  void dispose() {
    _storedVm.removeListener(_onVmChanged);
    _name.dispose();
    _barcode.dispose();
    _cost.dispose();
    _minStock.dispose();
    _openingQty.dispose();
    _notes.dispose();
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// تعبئة الحقول مرة واحدة بعد التحميل + مزامنة الباركود المولَّد
  /// + إغلاق الشاشة عند نجاح الحفظ.
  void _onVmChanged() {
    if (!mounted) return;
    final state = _vm.state;
    if (!_controllersReady && !state.loading && state.loadError == null) {
      _controllersReady = true;
      _dirtyBaseline = state;
      _name.text = state.name;
      _barcode.text = state.barcode;
      _cost.text = state.costText;
      _minStock.text = state.minStockText;
      _openingQty.text = state.openingQtyText;
      _notes.text = state.notes;
      _priceControllers
        ..clear()
        ..addAll({
          for (final currency in state.currencies)
            currency.id: TextEditingController(
              text: state.priceTexts[currency.id] ?? '',
            ),
        });
    } else if (_controllersReady && state.barcode != _barcode.text) {
      // باركود مولَّد من الزر — يُزامَن إلى الحقل.
      _barcode.text = state.barcode;
    }
    if (state.saved && !_popped) {
      _popped = true;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.itemFormSavedMessage)));
      // R17 — تأجيل الرجوع لإطار لاحق: الاستدعاء المباشر أثناء البناء
      // يسبق التزام PopScope بقيمة canPop الجديدة (isDirty=false بعد
      // الحفظ) فيرصد الحارسُ رجوعَ ما بعد الحفظ كتغييرات غير محفوظة
      // (علة اكتُشفت تحقياً حياً: حوار «مغادرة/بقاء» بعد نجاح الحفظ).
      // نفس النمط الذي يستخدمه DirtyFormGuard نفسه.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).maybePop();
      });
    }
  }

  Future<void> _submit() async {
    final ok = await _vm.save();
    if (!ok && mounted && _vm.state.repoError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_vm.state.repoError!)));
    }
  }

  void _onSavePressed() {
    if (!_formKey.currentState!.validate()) return;
    unawaited(_submit());
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ItemFormViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    // R16-b — إسقاط تلقائي للافتة خطأ التحقق عند ظهورها (مرة لكل خطأ).
    if (state.validationError != null && _lastValidationError == null) {
      _lastValidationError = state.validationError;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = _validationBannerKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: 0.15,
          );
        }
      });
    } else if (state.validationError == null) {
      _lastValidationError = null;
    }

    // حماية التغييرات غير المحفوظة (P1-4): الرجوع المباشر يعرض حوار
    // «مغادرة/بقاء» — القرار الصريح وحده يفتح الباب.
    return DirtyFormGuard(
      isDirty: _dirty,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        // R16-b — النموذج أطول من الشاشة على الجوال: تفعيل صريح لتقليص
        // الجسم مع لوحة المفاتيح (resizeToAvoidBottomInset) حتى تبقى
        // الحقول السفلية — الكمية الافتتاحية/الأسعار/زر الحفظ — قابلة
        // للتمرير إليها دائماً ولا تُحجب خلفها.
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(
            state.editMode ? l10n.itemFormEditTitle : l10n.itemFormAddTitle,
          ),
        ),
        body: state.loading
            ? ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: const [ListSkeleton(rows: 6)],
              )
            : state.loadError != null
            ? ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  ErrorState(
                    title: l10n.genericErrorTitle,
                    message: l10n.dbOpenErrorMessage,
                    technicalDetails: state.loadError.toString(),
                    retryLabel: l10n.commonRetry,
                    onRetry: vm.load,
                    compact: true,
                  ),
                ],
              )
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  // R16-b: تمرير مؤكد للجسم الطويل — سحب بالإصبع يطوي
                  // لوحة المفاتيح فوراً (onDrag) فلا يعوق الوصول للحقول
                  // السفلية على الشاشات القصيرة.
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    if (state.editMode) ...[
                      InfoNote(
                        icon: Icons.info_rounded,
                        message: l10n.itemFormEditNote,
                      ),
                      const SizedBox(height: 14),
                    ],
                    _nameField(l10n),
                    const SizedBox(height: 14),
                    _barcodeSection(l10n, state),
                    const SizedBox(height: 14),
                    _categoryRow(l10n, state),
                    const SizedBox(height: 14),
                    _unitRow(l10n, state),
                    const SizedBox(height: 14),
                    _costField(l10n),
                    const SizedBox(height: 14),
                    _serviceSwitch(l10n, state),
                    if (!state.isService) ...[
                      const SizedBox(height: 14),
                      _minStockField(l10n),
                      if (!state.editMode) ...[
                        const SizedBox(height: 14),
                        _openingQtyField(l10n),
                      ],
                      const SizedBox(height: 14),
                      _trackBatchesSwitch(l10n, state),
                    ],
                    const SizedBox(height: 18),
                    FinSectionTitle(
                      icon: Icons.sell_rounded,
                      title: l10n.itemFormPricesSection,
                    ),
                    const SizedBox(height: 8),
                    for (final currency in state.currencies)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _priceField(l10n, currency),
                      ),
                    _notesField(l10n),
                    if (state.validationError != null) ...[
                      const SizedBox(height: 14),
                      _ValidationErrorBanner(
                        key: _validationBannerKey,
                        message: _validationMessage(
                          l10n,
                          state.validationError!,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _saveButton(l10n, state),
                  ],
                ),
              ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // الحقول
  // ─────────────────────────────────────────────────────────────────────

  Widget _nameField(AppLocalizations l10n) {
    return TextFormField(
      key: const Key('item_form_name_field'),
      controller: _name,
      onChanged: _vm.setName,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: l10n.itemFormNameLabel,
        hintText: l10n.itemFormNameHint,
        prefixIcon: const Icon(Icons.inventory_2_rounded),
      ),
      validator: (value) =>
          (value ?? '').trim().isEmpty ? l10n.itemFormNameRequired : null,
    );
  }

  Widget _barcodeSection(AppLocalizations l10n, ItemFormState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                key: const Key('item_form_barcode_field'),
                controller: _barcode,
                onChanged: _vm.setBarcode,
                keyboardType: TextInputType.text,
                // الباركود LTR دائماً (§6.2 — أرقام/لاتيني).
                decoration: InputDecoration(
                  labelText: l10n.itemFormBarcodeLabel,
                  hintText: l10n.itemFormBarcodeHint,
                  prefixIcon: const Icon(Icons.qr_code_2_rounded),
                ),
              ),
            ),
            // التوليد في الإنشاء فقط — التعديل لا يولّد من جديد.
            if (!state.editMode) ...[
              const SizedBox(width: 10),
              FilledButton.tonalIcon(
                key: const Key('item_form_generate_btn'),
                onPressed: _vm.generateBarcode,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  state.barcode.isEmpty
                      ? l10n.itemFormBarcodeGenerate
                      : l10n.itemFormBarcodeRegenerate,
                ),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              ),
            ],
          ],
        ),
        if (state.barcode.isNotEmpty) ...[
          const SizedBox(height: 12),
          FinCard(
            padding: const EdgeInsets.all(14),
            child: BarcodePreview(code: state.barcode, name: state.name),
          ),
        ],
      ],
    );
  }

  Widget _categoryRow(AppLocalizations l10n, ItemFormState state) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int?>(
            key: Key('item_form_category_${state.categoryId}'),
            initialValue: state.categoryId,
            onChanged: _vm.setCategory,
            decoration: InputDecoration(
              labelText: l10n.itemFormCategoryLabel,
              prefixIcon: const Icon(Icons.category_rounded),
            ),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text(l10n.itemFormCategoryNone),
              ),
              for (final category in state.categories)
                DropdownMenuItem<int?>(
                  value: category.id,
                  child: Text(category.name),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        IconButton.outlined(
          tooltip: l10n.itemFormCategoryAdd,
          icon: const Icon(Icons.add_rounded),
          onPressed: () => unawaited(_openAddCategoryDialog(context, l10n)),
          style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
        ),
      ],
    );
  }

  Widget _unitRow(AppLocalizations l10n, ItemFormState state) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int?>(
            key: Key('item_form_unit_${state.unitId}'),
            initialValue: state.unitId,
            onChanged: _vm.setUnit,
            decoration: InputDecoration(
              labelText: l10n.itemFormUnitLabel,
              prefixIcon: const Icon(Icons.straighten_rounded),
            ),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text(l10n.itemFormUnitNone),
              ),
              for (final unit in state.units)
                DropdownMenuItem<int?>(value: unit.id, child: Text(unit.name)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        IconButton.outlined(
          tooltip: l10n.itemFormUnitAdd,
          icon: const Icon(Icons.add_rounded),
          onPressed: () => unawaited(_openAddUnitDialog(context, l10n)),
          style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
        ),
      ],
    );
  }

  Widget _costField(AppLocalizations l10n) {
    return TextFormField(
      key: const Key('item_form_cost_field'),
      controller: _cost,
      onChanged: _vm.setCostText,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: l10n.itemFormCostLabel,
        prefixIcon: const Icon(Icons.payments_rounded),
      ),
      validator: (value) {
        final text = (value ?? '').trim();
        final parsed = double.tryParse(text);
        if (text.isEmpty || parsed == null || parsed < 0) {
          return l10n.itemFormCostInvalid;
        }
        return null;
      },
    );
  }

  Widget _minStockField(AppLocalizations l10n) {
    return TextFormField(
      key: const Key('item_form_min_stock_field'),
      controller: _minStock,
      onChanged: _vm.setMinStockText,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: l10n.itemFormMinStockLabel,
        hintText: l10n.itemFormMinStockHint,
        prefixIcon: const Icon(Icons.low_priority_rounded),
      ),
      validator: (value) {
        final text = (value ?? '').trim();
        if (text.isEmpty) return null;
        final parsed = double.tryParse(text);
        if (parsed == null || parsed < 0) return l10n.itemFormMinStockInvalid;
        return null;
      },
    );
  }

  Widget _openingQtyField(AppLocalizations l10n) {
    return TextFormField(
      key: const Key('item_form_opening_qty_field'),
      controller: _openingQty,
      onChanged: _vm.setOpeningQtyText,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: l10n.itemFormOpeningQtyLabel,
        hintText: l10n.itemFormOpeningQtyHint,
        prefixIcon: const Icon(Icons.inventory_rounded),
      ),
      validator: (value) {
        final text = (value ?? '').trim();
        if (text.isEmpty) return null;
        final parsed = double.tryParse(text);
        if (parsed == null || parsed < 0) {
          return l10n.itemFormOpeningQtyInvalid;
        }
        return null;
      },
    );
  }

  Widget _serviceSwitch(AppLocalizations l10n, ItemFormState state) {
    return FinCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Material(
        // ListTile فوق بطاقة مزيّنة — يلزمه Material خاص كي لا تُبتلع
        // خلفيته وموج الحبر داخل DecoratedBox البطاقة.
        color: Colors.transparent,
        child: SwitchListTile(
          key: const Key('item_form_service_switch'),
          value: state.isService,
          onChanged: _vm.setIsService,
          title: Text(
            l10n.itemFormServiceLabel,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            l10n.itemFormServiceDesc,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          secondary: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiary
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.miscellaneous_services_rounded,
              color: Theme.of(context).colorScheme.tertiary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _trackBatchesSwitch(AppLocalizations l10n, ItemFormState state) {
    final colors = FinColors.of(context);
    return FinCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Material(
        // نفس علاج المفتاح الأول — Material شفاف فوق بطاقة مزيّنة.
        color: Colors.transparent,
        child: SwitchListTile(
          key: const Key('item_form_batches_switch'),
          value: state.trackBatches,
          onChanged: _vm.setTrackBatches,
          title: Text(
            l10n.itemFormTrackBatchesLabel,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            l10n.itemFormTrackBatchesDesc,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          secondary: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.layers_rounded, color: colors.warning),
          ),
        ),
      ),
    );
  }

  Widget _priceField(AppLocalizations l10n, Currency currency) {
    final controller = _priceControllers[currency.id];
    if (controller == null) return const SizedBox.shrink();
    return TextFormField(
      key: Key('item_form_price_field_${currency.code}'),
      controller: controller,
      onChanged: (value) => _vm.setPriceText(currency.id, value),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: l10n.itemFormPriceLabel(currency.name),
        prefixIcon: const Icon(Icons.sell_outlined),
        suffixText: currency.code,
      ),
      validator: (value) {
        final text = (value ?? '').trim();
        if (text.isEmpty) return null;
        final parsed = double.tryParse(text);
        if (parsed == null || parsed < 0) return l10n.itemFormPriceInvalid;
        return null;
      },
    );
  }

  Widget _notesField(AppLocalizations l10n) {
    return TextFormField(
      key: const Key('item_form_notes_field'),
      controller: _notes,
      onChanged: _vm.setNotes,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: l10n.itemFormNotesLabel,
        hintText: l10n.itemFormNotesHint,
        prefixIcon: const Icon(Icons.notes_rounded),
      ),
    );
  }

  Widget _saveButton(AppLocalizations l10n, ItemFormState state) {
    return FilledButton(
      key: const Key('item_form_save_btn'),
      onPressed: state.saving ? null : _onSavePressed,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      child: state.saving
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(l10n.itemFormSaving),
              ],
            )
          : Text(l10n.itemFormSave),
    );
  }

  String _validationMessage(AppLocalizations l10n, ItemFormError error) =>
      switch (error) {
        ItemFormError.nameRequired => l10n.itemFormNameRequired,
        ItemFormError.costInvalid => l10n.itemFormCostInvalid,
        ItemFormError.minStockInvalid => l10n.itemFormMinStockInvalid,
        ItemFormError.openingQtyInvalid => l10n.itemFormOpeningQtyInvalid,
        ItemFormError.priceInvalid => l10n.itemFormPriceInvalid,
        ItemFormError.noWarehouse => l10n.genericErrorTitle,
        ItemFormError.noUser => l10n.genericErrorTitle,
      };

  // ─────────────────────────────────────────────────────────────────────
  // حوارات الإضافة الفورية
  // ─────────────────────────────────────────────────────────────────────

  Future<void> _openAddCategoryDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final controller = TextEditingController();
    var errorText = '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.categoryNameLabel),
          // R16-b — جسم الحوار قابل للتمرير (scrollable): لا ينفيض ولا
          // تحتجب حقوله خلف لوحة المفاتيح على الشاشات القصيرة.
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.categoryNameLabel,
                  errorText: errorText.isEmpty ? null : errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  setDialogState(() => errorText = l10n.categoryNameLabel);
                  return;
                }
                final error = await _vm.addCategory(name);
                if (!dialogContext.mounted) return;
                if (error != null) {
                  setDialogState(() => errorText = error);
                  return;
                }
                Navigator.of(dialogContext).pop();
              },
              child: Text(l10n.commonAdd),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _openAddUnitDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final nameController = TextEditingController();
    final factorController = TextEditingController(text: '1');
    var errorText = '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.unitNameLabel),
          // R16-b — نفس علاج حوار الفئة: جسم قابل للتمرير.
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.unitNameLabel),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: factorController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.unitFactorLabel,
                  hintText: l10n.unitFactorHint,
                  errorText: errorText.isEmpty ? null : errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final factor = double.tryParse(factorController.text.trim());
                if (name.isEmpty) {
                  setDialogState(() => errorText = l10n.unitNameLabel);
                  return;
                }
                if (factor == null || factor <= 0) {
                  setDialogState(() => errorText = l10n.unitFactorInvalid);
                  return;
                }
                final error = await _vm.addUnit(name, factor: factor);
                if (!dialogContext.mounted) return;
                if (error != null) {
                  setDialogState(() => errorText = error);
                  return;
                }
                Navigator.of(dialogContext).pop();
              },
              child: Text(l10n.commonAdd),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    factorController.dispose();
  }
}

/// لافتة خطأ التحقق فوق زر الحفظ.
class _ValidationErrorBanner extends StatelessWidget {
  const _ValidationErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = FinColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.negativeContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: colors.onNegativeContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onNegativeContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
