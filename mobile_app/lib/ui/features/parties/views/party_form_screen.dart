/// شاشتا نموذج الطرف — «تسجيل عميل جديد/تعديله» و«تسجيل مورد جديد/
/// تعديله» (دليل 06/02 و05/01): الاسم إلزامي، حد الائتمان بدلالاته
/// الثلاث مع شرح دقيق، ورصيد افتتاحي بعملته وتاريخه (مقفل عند وجود
/// حركات)، وحفظ عبر المستودع مع تحقق فوري وأخطاء مترجمة.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/dirty_form_guard.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../view_models/party_form_view_model.dart';
import '../view_models/party_kind.dart';
import '../view_models/party_lookup.dart';
import 'widgets/parties_widgets.dart';

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
        partyLookup: PartyLookup(app.database!.db),
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
        partyLookup: PartyLookup(app.database!.db),
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
      unawaited(Navigator.of(context).maybePop());
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
                  children: [
                    if (state.editMode && state.openingLocked) ...[
                      PartiesInfoNote(
                        icon: Icons.lock_rounded,
                        message: l10n.partyFormOpeningLockedNote,
                        warning: true,
                      ),
                      const SizedBox(height: 14),
                    ],
                    _nameField(l10n),
                    const SizedBox(height: 14),
                    _phoneField(l10n),
                    if (isCustomer) ...[
                      const SizedBox(height: 14),
                      _whatsappField(l10n),
                    ],
                    const SizedBox(height: 14),
                    _addressField(l10n),
                    if (isCustomer) ...[
                      const SizedBox(height: 14),
                      _areaField(l10n),
                      const SizedBox(height: 14),
                      _creditLimitField(l10n, state),
                    ],
                    const SizedBox(height: 18),
                    PartiesSectionTitle(
                      icon: Icons.account_balance_wallet_rounded,
                      title: l10n.partyFormOpeningSection,
                    ),
                    const SizedBox(height: 8),
                    _openingSection(l10n, state),
                    const SizedBox(height: 18),
                    _notesField(l10n),
                    if (state.validationError != null) ...[
                      const SizedBox(height: 14),
                      _ValidationErrorBanner(
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

  // ─────────────────────────────────────────────────────────────────────
  // الحقول
  // ─────────────────────────────────────────────────────────────────────

  Widget _nameField(AppLocalizations l10n) {
    return TextFormField(
      key: const Key('party_form_name_field'),
      controller: _name,
      onChanged: _storedVm.setName,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: l10n.partyFormNameLabel,
        hintText: l10n.partyFormNameHint,
        prefixIcon: const Icon(Icons.badge_rounded),
      ),
      validator: (value) =>
          (value ?? '').trim().isEmpty ? l10n.partyFormNameRequired : null,
    );
  }

  Widget _phoneField(AppLocalizations l10n) {
    return TextFormField(
      key: const Key('party_form_phone_field'),
      controller: _phone,
      onChanged: _storedVm.setPhone,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: l10n.partyFormPhoneLabel,
        prefixIcon: const Icon(Icons.call_rounded),
      ),
    );
  }

  Widget _whatsappField(AppLocalizations l10n) {
    return TextFormField(
      key: const Key('party_form_whatsapp_field'),
      controller: _whatsapp,
      onChanged: _storedVm.setWhatsapp,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: l10n.partyFormWhatsappLabel,
        hintText: l10n.partyFormWhatsappHint,
        prefixIcon: const Icon(Icons.chat_rounded),
      ),
    );
  }

  Widget _addressField(AppLocalizations l10n) {
    return TextFormField(
      key: const Key('party_form_address_field'),
      controller: _address,
      onChanged: _storedVm.setAddress,
      textInputAction: TextInputAction.next,
      minLines: 1,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: l10n.partyFormAddressLabel,
        prefixIcon: const Icon(Icons.location_on_rounded),
      ),
    );
  }

  Widget _areaField(AppLocalizations l10n) {
    return TextFormField(
      key: const Key('party_form_area_field'),
      controller: _area,
      onChanged: _storedVm.setArea,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: l10n.partyFormAreaLabel,
        prefixIcon: const Icon(Icons.map_rounded),
      ),
    );
  }

  /// حد الائتمان — دلالة القيمة الصارمة مشروحة تحت الحقل حرفياً.
  Widget _creditLimitField(AppLocalizations l10n, PartyFormState state) {
    return TextFormField(
      key: const Key('party_form_credit_field'),
      controller: _creditLimit,
      enabled: true,
      onChanged: _storedVm.setCreditLimitText,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: l10n.partyFormCreditLimitLabel,
        hintText: l10n.partyFormCreditLimitHint,
        prefixIcon: const Icon(Icons.speed_rounded),
        helperText: l10n.partyFormCreditLimitHelp,
        helperMaxLines: 3,
        suffixIcon: CreditLimitChip(creditLimit: state.parsedCreditLimit),
      ),
      validator: (value) {
        final text = (value ?? '').trim();
        if (text.isEmpty) return null;
        final parsed = double.tryParse(text);
        if (parsed == null || parsed < 0) {
          return l10n.partyFormCreditLimitInvalid;
        }
        return null;
      },
    );
  }

  /// قسم الرصيد الافتتاحي — مبلغ + عملة + تاريخ (مقفل عند وجود حركات).
  Widget _openingSection(AppLocalizations l10n, PartyFormState state) {
    final locked = state.openingLocked;
    return FinCard(
      padding: const EdgeInsets.all(14),
      child: IgnorePointer(
        ignoring: locked,
        child: Opacity(
          opacity: locked ? 0.55 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const Key('party_form_opening_field'),
                controller: _opening,
                enabled: !locked,
                onChanged: _storedVm.setOpeningText,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.partyFormOpeningAmountLabel,
                  hintText: l10n.partyFormOpeningAmountHint,
                  prefixIcon: const Icon(Icons.savings_rounded),
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return null;
                  final parsed = double.tryParse(text);
                  if (parsed == null || parsed < 0) {
                    return l10n.partyFormOpeningAmountInvalid;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                key: Key(
                  'party_form_opening_currency_${state.openingCurrencyId}',
                ),
                initialValue: state.openingCurrencyId,
                onChanged: _storedVm.setOpeningCurrency,
                decoration: InputDecoration(
                  labelText: l10n.partyFormOpeningCurrencyLabel,
                  prefixIcon: const Icon(Icons.currency_exchange_rounded),
                ),
                items: [
                  DropdownMenuItem<int>(
                    value: null,
                    child: Text(l10n.partyFormOpeningCurrencyNone),
                  ),
                  for (final currency in state.currencies)
                    DropdownMenuItem<int>(
                      value: currency.id,
                      child: Text('${currency.name} (${currency.code})'),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('party_form_opening_date_field'),
                readOnly: true,
                controller: _openingDate,
                onTap: locked ? null : () => unawaited(_pickOpeningDate()),
                decoration: InputDecoration(
                  labelText: l10n.partyFormOpeningDateLabel,
                  prefixIcon: const Icon(Icons.event_rounded),
                  suffixIcon: locked
                      ? const Icon(Icons.lock_rounded)
                      : const Icon(Icons.edit_calendar_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget _notesField(AppLocalizations l10n) {
    return TextFormField(
      key: const Key('party_form_notes_field'),
      controller: _notes,
      onChanged: _storedVm.setNotes,
      minLines: 2,
      maxLines: 5,
      decoration: InputDecoration(
        labelText: l10n.partyFormNotesLabel,
        hintText: l10n.partyFormNotesHint,
        prefixIcon: const Icon(Icons.sticky_note_2_rounded),
      ),
    );
  }

  Widget _saveButton(AppLocalizations l10n, PartyFormState state) {
    return FilledButton.icon(
      key: const Key('party_form_save_btn'),
      onPressed: state.saving ? null : _onSavePressed,
      icon: state.saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save_rounded),
      label: Text(state.saving ? l10n.fxSavingLabel : l10n.partyFormSaveLabel),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
    );
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

/// لافتة خطأ التحقق فوق زر الحفظ.
class _ValidationErrorBanner extends StatelessWidget {
  const _ValidationErrorBanner({required this.message});

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
        crossAxisAlignment: CrossAxisAlignment.start,
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
