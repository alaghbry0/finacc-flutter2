/// شاشتا نموذج الطرف — «تسجيل عميل جديد/تعديله» و«تسجيل مورد جديد/
/// تعديله» (دليل 06/02 و05/01): الاسم إلزامي، حد الائتمان بدلالاته
/// الثلاث مع شرح دقيق، ورصيد افتتاحي بعملته وتاريخه (مقفل عند وجود
/// حركات)، وحفظ عبر المستودع مع تحقق فوري وأخطاء مترجمة.
/// الحقول وقسم الافتتاحي بملفاتها المركزّة بجوارها (R20-D3b) — هذا
/// الملف: آلة الحالة (المتحكمات + لقطة التغييرات + حرّاس التحميل).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/dirty_form_guard.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/info_note.dart';
import '../../../core/widgets/fin_section_title.dart';
import '../../../core/widgets/loading_state.dart';
import '../view_models/party_form_view_model.dart';
import '../view_models/party_kind.dart';
import '../view_models/party_lookup.dart';
import 'widgets/party_form_fields.dart';
import 'widgets/party_form_opening_section.dart';
import 'widgets/parties_widgets.dart' show partyFormatDate;

/// شاشة نموذج العميل (إضافة/تعديل — دليل 06/02).
class CustomerFormScreen extends StatelessWidget {
  const CustomerFormScreen({super.key, this.viewModel, this.editId});

  /// Seam اختبار: نموذج محمّل مسبقاً — عند غيابه تُنشئ الشاشة نموذجها.
  final PartyFormViewModel? viewModel;

  /// معرّف العميل في وضع التعديل.
  final int? editId;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final PartyFormViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = PartyFormViewModel(
        customerRepo: app.customers!,
        supplierRepo: app.suppliers!,
        companyRepo: app.companies!,
        fxRepo: app.fxRates!,
        partyLookup: PartyLookup.fromRepositories(
          app.customers!,
          app.suppliers!,
        ),
        partyKind: PartyKind.customer,
        editPartyId: editId,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<PartyFormViewModel>.value(
      value: vm,
      child: const _PartyFormBody(),
    );
  }
}

/// شاشة نموذج المورد (إضافة/تعديل — دليل 05/01).
class SupplierFormScreen extends StatelessWidget {
  const SupplierFormScreen({super.key, this.viewModel, this.editId});

  /// Seam اختبار: نموذج محمّل مسبقاً.
  final PartyFormViewModel? viewModel;

  /// معرّف المورد في وضع التعديل.
  final int? editId;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final PartyFormViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = PartyFormViewModel(
        customerRepo: app.customers!,
        supplierRepo: app.suppliers!,
        companyRepo: app.companies!,
        fxRepo: app.fxRates!,
        partyLookup: PartyLookup.fromRepositories(
          app.customers!,
          app.suppliers!,
        ),
        partyKind: PartyKind.supplier,
        editPartyId: editId,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<PartyFormViewModel>.value(
      value: vm,
      child: const _PartyFormBody(),
    );
  }
}

class _PartyFormBody extends StatefulWidget {
  const _PartyFormBody();

  @override
  State<_PartyFormBody> createState() => _PartyFormBodyState();
}

class _PartyFormBodyState extends State<_PartyFormBody> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _whatsapp;
  late final TextEditingController _address;
  late final TextEditingController _area;
  late final TextEditingController _creditLimit;
  late final TextEditingController _opening;
  late final TextEditingController _openingDate;
  late final TextEditingController _notes;

  bool _controllersReady = false;
  bool _popped = false;

  /// لقطة الحالة ما بعد التحميل — مقارنة التغييرات لحماية المغادرة (P1-4).
  PartyFormState? _dirtyBaseline;

  /// هل في النموذج تغييرات غير محفوظة؟ (مقارنة الحالة باللقطة؛ بعد الحفظ
  /// أو قبل التحميل = نظيف).
  bool get _dirty {
    final baseline = _dirtyBaseline;
    if (baseline == null) return false;
    final state = _storedVm.state;
    if (state.saved) return false;
    return state.name != baseline.name ||
        state.phone != baseline.phone ||
        state.whatsapp != baseline.whatsapp ||
        state.address != baseline.address ||
        state.area != baseline.area ||
        state.creditLimitText != baseline.creditLimitText ||
        state.openingText != baseline.openingText ||
        state.openingCurrencyId != baseline.openingCurrencyId ||
        state.openingDate != baseline.openingDate ||
        state.notes != baseline.notes;
  }

  /// النموذج يُخزَّن حقلاً عند أول بناء (قراءة context داخل dispose غير آمنة).
  late final PartyFormViewModel _storedVm;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _phone = TextEditingController();
    _whatsapp = TextEditingController();
    _address = TextEditingController();
    _area = TextEditingController();
    _creditLimit = TextEditingController();
    _opening = TextEditingController();
    _openingDate = TextEditingController();
    _notes = TextEditingController();
    _storedVm = context.read<PartyFormViewModel>();
    _storedVm.addListener(_onVmChanged);
  }

  @override
  void dispose() {
    _storedVm.removeListener(_onVmChanged);
    _name.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _address.dispose();
    _area.dispose();
    _creditLimit.dispose();
    _opening.dispose();
    _openingDate.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// تعبئة الحقول مرة واحدة بعد التحميل + إغلاق الشاشة عند نجاح الحفظ.
  void _onVmChanged() {
    if (!mounted) return;
    final state = _storedVm.state;
    if (!_controllersReady && !state.loading && state.loadError == null) {
      _controllersReady = true;
      _dirtyBaseline = state;
      _name.text = state.name;
      _phone.text = state.phone;
      _whatsapp.text = state.whatsapp;
      _address.text = state.address;
      _area.text = state.area;
      _creditLimit.text = state.creditLimitText;
      _opening.text = state.openingText;
      _openingDate.text = partyFormatDate(context, state.openingDate);
      _notes.text = state.notes;
    }
    if (state.saved && !_popped) {
      _popped = true;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.kind == PartyKind.customer
                ? l10n.partyFormSavedCustomer
                : l10n.partyFormSavedSupplier,
          ),
        ),
      );
      // R17 — تأجيل الرجوع لإطار لاحق (نفس علة نموذج الصنف): الاستدعاء
      // أثناء البناء يسبق التزام PopScope بcanPop الجديدة فيرتد حوار
      // «مغادرة/بقاء» بعد نجاح الحفظ.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).maybePop();
      });
    }
  }

  /// تاريخ الافتتاحي يتغير من منتقي التاريخ — يُزامن إلى الحقل.
  void _syncOpeningDateField() {
    final text = partyFormatDate(context, _storedVm.state.openingDate);
    if (_openingDate.text != text) {
      _openingDate.text = text;
    }
  }

  Future<void> _submit() async {
    final ok = await _storedVm.save();
    if (!ok && mounted && _storedVm.state.repoError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_storedVm.state.repoError!)));
    }
  }

  void _onSavePressed() {
    if (!_formKey.currentState!.validate()) return;
    unawaited(_submit());
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PartyFormViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    final isCustomer = state.kind == PartyKind.customer;

    // حماية التغييرات غير المحفوظة (P1-4): الرجوع المباشر يعرض حوار
    // «مغادرة/بقاء» — القرار الصريح وحده يفتح الباب.
    return DirtyFormGuard(
      isDirty: _dirty,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: Text(_titleFor(l10n, state))),
        body: state.loading
            ? ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: const [ListSkeleton()],
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
                  children: [
                    if (state.editMode && state.openingLocked) ...[
                      InfoNote(
                        icon: Icons.lock_rounded,
                        message: l10n.partyFormOpeningLockedNote,
                        warning: true,
                      ),
                      const SizedBox(height: 14),
                    ],
                    PartyFormNameField(controller: _name, vm: vm),
                    const SizedBox(height: 14),
                    PartyFormPhoneField(controller: _phone, vm: vm),
                    if (isCustomer) ...[
                      const SizedBox(height: 14),
                      PartyFormWhatsappField(controller: _whatsapp, vm: vm),
                    ],
                    const SizedBox(height: 14),
                    PartyFormAddressField(controller: _address, vm: vm),
                    if (isCustomer) ...[
                      const SizedBox(height: 14),
                      PartyFormAreaField(controller: _area, vm: vm),
                      const SizedBox(height: 14),
                      PartyFormCreditLimitField(
                        controller: _creditLimit,
                        vm: vm,
                        state: state,
                      ),
                    ],
                    const SizedBox(height: 18),
                    FinSectionTitle(
                      icon: Icons.account_balance_wallet_rounded,
                      title: l10n.partyFormOpeningSection,
                    ),
                    const SizedBox(height: 8),
                    PartyFormOpeningSection(
                      vm: vm,
                      state: state,
                      openingController: _opening,
                      openingDateController: _openingDate,
                      onPickOpeningDate: () => unawaited(_pickOpeningDate()),
                    ),
                    const SizedBox(height: 18),
                    PartyFormNotesField(controller: _notes, vm: vm),
                    if (state.validationError != null) ...[
                      const SizedBox(height: 14),
                      PartyFormValidationErrorBanner(
                        message: _validationMessage(
                          l10n,
                          state.validationError!,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    PartyFormSaveButton(
                      saving: state.saving,
                      onPressed: _onSavePressed,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  static String _titleFor(AppLocalizations l10n, PartyFormState state) {
    if (state.kind == PartyKind.customer) {
      return state.editMode
          ? l10n.partyFormEditCustomerTitle
          : l10n.partyFormAddCustomerTitle;
    }
    return state.editMode
        ? l10n.partyFormEditSupplierTitle
        : l10n.partyFormAddSupplierTitle;
  }

  Future<void> _pickOpeningDate() async {
    final state = _storedVm.state;
    final picked = await showDatePicker(
      context: context,
      initialDate: state.openingDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) {
      _storedVm.setOpeningDate(DateTime(picked.year, picked.month, picked.day));
      _syncOpeningDateField();
    }
  }

  static String _validationMessage(
    AppLocalizations l10n,
    PartyFormError error,
  ) => switch (error) {
    PartyFormError.nameRequired => l10n.partyFormNameRequired,
    PartyFormError.creditLimitInvalid => l10n.partyFormCreditLimitInvalid,
    PartyFormError.openingInvalid => l10n.partyFormOpeningAmountInvalid,
    PartyFormError.openingCurrencyRequired =>
      l10n.partyFormOpeningCurrencyRequired,
    PartyFormError.noRate => l10n.partyFormNoRateError,
    PartyFormError.noUser => l10n.partyFormNoUserError,
  };
}
