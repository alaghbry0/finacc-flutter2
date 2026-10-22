/// شاشة نموذج الصنف (إضافة/تعديل — دليل 02/02) بهوية Simple Invoice
/// Manager (V10 — modal-product-edit بالنموذج الأولي): ترويسة فرعية
/// «نموذج إدخال المنتج» (والتعديل بعنوانه القائم الأدق)، الحقول ببطاقات
/// SIM (بيانات/أسعار/ملاحظات) مع تلميحات إرشادية صغيرة تحفظ نصوص l10n
/// القائمة، وشريط «حفظ المنتج» الأزرق الثابت أسفل الشاشة. كل منطق الحالة
/// محفوظ حرفياً: اسم إلزامي، باركود بتوليد EAN-13 ومعاينة (FR-01-02)
/// ومزامنة المولَّد للحقل، فئة ووحدة بإضافة فورية، أسعار بكل العملات
/// النشطة، صنف خدمي بلا مخزون (FR-01-16)، وكمية افتتاحية في الإنشاء
/// فقط. الحقول والأقسام والحوارات بملفاتها المركزّة بجوارها (R19-D3b)
/// — هذا الملف: إدارة الحالة وحماية المغادرة والحفظ.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/company.dart';
import '../../../../domain/models/item.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/dirty_form_guard.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/info_note.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/sim_form_widgets.dart';
import '../../../core/widgets/sim_list_widgets.dart';
import '../view_models/item_form_view_model.dart';
import 'widgets/item_form_fields.dart';
import 'widgets/item_form_sections.dart';

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

  /// R16-b — مفتاح لافتة خطأ التحقير (آخر عنصر بالتمرير فوق شريط
  /// الحفظ الثابت): يُسقَط إليها تلقائياً عند ظهورها كي يرى المستخدم
  /// سبب رفض الحفظ حتى لو كان أسفل الشاشة (نموذج أطول من الشاشة).
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
        // الحقول السفلية — الكمية الافتتاحية/الأسعار/شريط الحفظ — قابلة
        // للتمرير إليها دائماً ولا تُحجب خلفها، ويرتفع شريط الحفظ الثابت
        // فوق اللوحة فلا يُفقد زر CTA.
        resizeToAvoidBottomInset: true,
        // V10 (SIM) — الترويسة الفرعية داخل الجسم (لا AppBar): رجوع
        // نظامي maybePop + عنوان «نموذج إدخال المنتج» المقفل.
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SimSubHeader(
                titleKey: const Key('item_form_sim_title'),
                // إنشاء — عنوان النموذج الأولي الموحد (modal-product-edit
                // «نموذج إدخال المنتج»)؛ تعديل — العنوان القائم الأدق.
                title: state.editMode
                    ? l10n.itemFormEditTitle
                    : l10n.itemFormSimTitle,
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: state.loading
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
                        children: const [ListSkeleton()],
                      )
                    : state.loadError != null
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
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
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
                          // R16-b: تمرير مؤكد للجسم الطويل — سحب بالإصبع
                          // يطوي لوحة المفاتيح فوراً (onDrag) فلا يعوق
                          // الوصول للحقول السفلية على الشاشات القصيرة.
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          children: [
                            if (state.editMode) ...[
                              InfoNote(
                                icon: Icons.info_rounded,
                                message: l10n.itemFormEditNote,
                              ),
                              const SizedBox(height: 12),
                            ],
                            // بطاقة البيانات: الاسم ← الباركود ← الفئة ←
                            // الوحدة ← التكلفة ← الخدمي ← المخزون.
                            SimFormCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ItemNameField(controller: _name, vm: vm),
                                  const SizedBox(height: 12),
                                  ItemBarcodeSection(
                                    controller: _barcode,
                                    vm: vm,
                                  ),
                                  const SizedBox(height: 12),
                                  ItemCategoryRow(vm: vm),
                                  const SizedBox(height: 12),
                                  ItemUnitRow(vm: vm),
                                  const SizedBox(height: 12),
                                  ItemCostField(controller: _cost, vm: vm),
                                  ItemServiceSwitch(vm: vm),
                                  if (!state.isService) ...[
                                    ItemTrackBatchesSwitch(vm: vm),
                                    if (!state.editMode)
                                      SimFormBoxRow(
                                        start: ItemMinStockField(
                                          controller: _minStock,
                                          vm: vm,
                                        ),
                                        end: ItemOpeningQtyField(
                                          controller: _openingQty,
                                          vm: vm,
                                        ),
                                      )
                                    else
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: ItemMinStockField(
                                          controller: _minStock,
                                          vm: vm,
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // بطاقة الأسعار: عنوان القسم القائم + سطر رقمي
                            // لكل عملة نشطة (المتحكمات بخريطة الأب كما هي).
                            SimFormCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _ItemFormSectionTitle(
                                    l10n.itemFormPricesSection,
                                  ),
                                  for (final currency in state.currencies)
                                    _priceField(vm, currency),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            SimFormCard(
                              child: ItemNotesField(
                                controller: _notes,
                                vm: vm,
                              ),
                            ),
                            if (state.validationError != null) ...[
                              const SizedBox(height: 12),
                              ItemFormValidationErrorBanner(
                                key: _validationBannerKey,
                                message: _validationMessage(
                                  l10n,
                                  state.validationError!,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
        // V10 (SIM) — شريط «حفظ المنتج» الثابت أسفل الشاشة: لا يختفي
        // بالتمرير (خارج قائمة الجسم) ويتحول لعجلة انتظار أثناء الحفظ؛
        // يظهر مع النموذج الجاهز فقط (لا مع التحميل/الخطأ).
        bottomNavigationBar: (state.loading || state.loadError != null)
            ? null
            : SimFormSaveBar(
                buttonKey: const Key('item_form_save_btn'),
                label: l10n.itemFormSimSave,
                loading: state.saving,
                onPressed: _onSavePressed,
              ),
      ),
    );
  }

  /// حقل سعر عملة واحدة — المتحكم يملكه الأب (خريطة المتحكمات).
  Widget _priceField(ItemFormViewModel vm, Currency currency) {
    final controller = _priceControllers[currency.id];
    if (controller == null) return const SizedBox.shrink();
    return ItemPriceField(controller: controller, vm: vm, currency: currency);
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
}

/// عنوان قسم داخل بطاقة نموذج SIM (بطاقة الأسعار) — 13sp/700 بنمط
/// عناوين البطاقات بالمرجع التصميمي.
class _ItemFormSectionTitle extends StatelessWidget {
  const _ItemFormSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
