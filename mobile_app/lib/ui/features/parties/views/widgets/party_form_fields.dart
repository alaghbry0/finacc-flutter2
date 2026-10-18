/// حقول نموذج الطرف (اسم/هاتف/واتساب/عنوان/منطقة/حد ائتمان/ملاحظات) +
/// زر الحفظ ولافتة خطأ التحقق — مستخرجة من party_form_screen (R20-D3b:
/// نقل حرفي بلا أي تغيير سلوكي؛ المتحكمات يملكها الأب المشيد للحقول).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../view_models/party_form_view_model.dart';
import 'parties_widgets.dart';

class PartyFormNameField extends StatelessWidget {
  const PartyFormNameField({
    super.key,
    required this.controller,
    required this.vm,
  });

  final TextEditingController controller;
  final PartyFormViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TextFormField(
      key: const Key('party_form_name_field'),
      controller: controller,
      onChanged: vm.setName,
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
}

class PartyFormPhoneField extends StatelessWidget {
  const PartyFormPhoneField({
    super.key,
    required this.controller,
    required this.vm,
  });

  final TextEditingController controller;
  final PartyFormViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TextFormField(
      key: const Key('party_form_phone_field'),
      controller: controller,
      onChanged: vm.setPhone,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: l10n.partyFormPhoneLabel,
        prefixIcon: const Icon(Icons.call_rounded),
      ),
    );
  }
}

class PartyFormWhatsappField extends StatelessWidget {
  const PartyFormWhatsappField({
    super.key,
    required this.controller,
    required this.vm,
  });

  final TextEditingController controller;
  final PartyFormViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TextFormField(
      key: const Key('party_form_whatsapp_field'),
      controller: controller,
      onChanged: vm.setWhatsapp,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: l10n.partyFormWhatsappLabel,
        hintText: l10n.partyFormWhatsappHint,
        prefixIcon: const Icon(Icons.chat_rounded),
      ),
    );
  }
}

class PartyFormAddressField extends StatelessWidget {
  const PartyFormAddressField({
    super.key,
    required this.controller,
    required this.vm,
  });

  final TextEditingController controller;
  final PartyFormViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TextFormField(
      key: const Key('party_form_address_field'),
      controller: controller,
      onChanged: vm.setAddress,
      textInputAction: TextInputAction.next,
      minLines: 1,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: l10n.partyFormAddressLabel,
        prefixIcon: const Icon(Icons.location_on_rounded),
      ),
    );
  }
}

class PartyFormAreaField extends StatelessWidget {
  const PartyFormAreaField({
    super.key,
    required this.controller,
    required this.vm,
  });

  final TextEditingController controller;
  final PartyFormViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TextFormField(
      key: const Key('party_form_area_field'),
      controller: controller,
      onChanged: vm.setArea,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: l10n.partyFormAreaLabel,
        prefixIcon: const Icon(Icons.map_rounded),
      ),
    );
  }
}

/// حد الائتمان — دلالة القيمة الصارمة مشروحة تحت الحقل حرفياً.
class PartyFormCreditLimitField extends StatelessWidget {
  const PartyFormCreditLimitField({
    super.key,
    required this.controller,
    required this.vm,
    required this.state,
  });

  final TextEditingController controller;
  final PartyFormViewModel vm;
  final PartyFormState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TextFormField(
      key: const Key('party_form_credit_field'),
      controller: controller,
      enabled: true,
      onChanged: vm.setCreditLimitText,
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
}

class PartyFormNotesField extends StatelessWidget {
  const PartyFormNotesField({
    super.key,
    required this.controller,
    required this.vm,
  });

  final TextEditingController controller;
  final PartyFormViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TextFormField(
      key: const Key('party_form_notes_field'),
      controller: controller,
      onChanged: vm.setNotes,
      minLines: 2,
      maxLines: 5,
      decoration: InputDecoration(
        labelText: l10n.partyFormNotesLabel,
        hintText: l10n.partyFormNotesHint,
        prefixIcon: const Icon(Icons.sticky_note_2_rounded),
      ),
    );
  }
}

class PartyFormSaveButton extends StatelessWidget {
  const PartyFormSaveButton({
    super.key,
    required this.saving,
    required this.onPressed,
  });

  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FilledButton.icon(
      key: const Key('party_form_save_btn'),
      onPressed: saving ? null : onPressed,
      icon: saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save_rounded),
      label: Text(saving ? l10n.fxSavingLabel : l10n.partyFormSaveLabel),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
    );
  }
}

/// لافتة خطأ التحقق فوق زر الحفظ.
class PartyFormValidationErrorBanner extends StatelessWidget {
  const PartyFormValidationErrorBanner({super.key, required this.message});

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
