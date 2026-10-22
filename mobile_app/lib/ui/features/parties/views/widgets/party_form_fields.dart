/// حقول نموذج الطرف بهوية Simple Invoice Manager (V10-B) — الاسم/الهاتف/
/// الواتساب/العنوان/الحي/حد الائتمان/الملاحظات حقول سطرية بنمط
/// `input-line` (حد سفلي فقط) داخل بطاقات الشاشة، مع تلميحات صغيرة
/// أسفل الحقول التي كان لها hintText/helperText — جلد بصري فقط فوق
/// نفس المنطق (R20-D3b → V10-B): المتحكمات يملكها الأب، وonChanged
/// والمدققون ومفاتيح الاختبار كما كانت حرفياً. زر الحفظ القديم
/// (PartyFormSaveButton) انتقل إلى شريط SimFormSaveBar الثابت أسفل
/// الشاشة، ولافتة خطأ التحقق باقية بلا أي تغيير.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sim_form_widgets.dart';
import '../../view_models/party_form_view_model.dart';
import 'parties_widgets.dart';

/// تلميح صغير أسفل الحقل (12sp رمادي) — يحمل نصوص hintText/helperText
/// القديمة (مثال الاسم، دلالات حد الائتمان) بنمط وصف سطر المفتاح
/// بالعدة (SimFormSwitchRow.description).
class _FieldHint extends StatelessWidget {
  const _FieldHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SimFormLineField(
          fieldKey: const Key('party_form_name_field'),
          hint: l10n.partyFormNameLabel,
          controller: controller,
          onChanged: vm.setName,
          required: true,
          validator: (value) =>
              (value ?? '').trim().isEmpty ? l10n.partyFormNameRequired : null,
        ),
        _FieldHint(l10n.partyFormNameHint),
      ],
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
    return SimFormLineField(
      fieldKey: const Key('party_form_phone_field'),
      hint: l10n.partyFormPhoneLabel,
      controller: controller,
      onChanged: vm.setPhone,
      keyboardType: TextInputType.phone,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SimFormLineField(
          fieldKey: const Key('party_form_whatsapp_field'),
          hint: l10n.partyFormWhatsappLabel,
          controller: controller,
          onChanged: vm.setWhatsapp,
          keyboardType: TextInputType.phone,
        ),
        _FieldHint(l10n.partyFormWhatsappHint),
      ],
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
    return SimFormLineField(
      fieldKey: const Key('party_form_address_field'),
      hint: l10n.partyFormAddressLabel,
      controller: controller,
      onChanged: vm.setAddress,
      maxLines: 3,
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
    return SimFormLineField(
      fieldKey: const Key('party_form_area_field'),
      hint: l10n.partyFormAreaLabel,
      controller: controller,
      onChanged: vm.setArea,
    );
  }
}

/// حد الائتمان — دلالة القيمة الصارمة مشروحة تحت الحقل حرفياً
/// (فارغ = بلا حد · صفر = منع الآجل · رقم = الحد) مع رقاقة حية
/// بجانب الحقل تفسر القيمة الحالية.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SimFormLineField(
          fieldKey: const Key('party_form_credit_field'),
          hint: l10n.partyFormCreditLimitLabel,
          controller: controller,
          onChanged: vm.setCreditLimitText,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          // 🟡-12 — أرقام غربية فقط (نمط حقول المبالغ القائم بالتطبيق).
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,4}')),
          ],
          suffix: CreditLimitChip(creditLimit: state.parsedCreditLimit),
          validator: (value) {
            final text = (value ?? '').trim();
            if (text.isEmpty) return null;
            final parsed = double.tryParse(text);
            if (parsed == null || parsed < 0) {
              return l10n.partyFormCreditLimitInvalid;
            }
            return null;
          },
        ),
        _FieldHint(l10n.partyFormCreditLimitHelp),
      ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SimFormLineField(
          fieldKey: const Key('party_form_notes_field'),
          hint: l10n.partyFormNotesLabel,
          controller: controller,
          onChanged: vm.setNotes,
          maxLines: 3,
        ),
        _FieldHint(l10n.partyFormNotesHint),
      ],
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
