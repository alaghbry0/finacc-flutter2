/// حسابات نموذج الطرف النقية (تنظيف النصوص + تاريخ الافتتاحي + بناء
/// الحالة من السجل + بناء مسودات الحفظ) — مستخرجة من
/// party_form_view_model (R20-D3c: نقل حرفي بلا أي تغيير سلوكي؛ دوال
/// الفئة الخاصة صارت علوية بادئة partyForm).
library;

import '../../../../domain/core/numbers.dart';
import '../../../../domain/models/company.dart';
import '../../../../domain/models/party.dart';
import 'party_form_state.dart';
import 'party_kind.dart';

/// نص فارغ (فراغات فقط) → `null`.
String? partyFormCleanText(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// تاريخ Y-M-D كنص → بداية اليوم المحلي (أو null).
DateTime? partyFormTryParseYmd(String? ymd) {
  if (ymd == null || ymd.isEmpty) return null;
  final parsed = DateTime.tryParse(ymd);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

/// حالة «تعديل عميل» من سجله المحمّل — الجسم منقول حرفياً من `load`
/// بمتحكم النموذج (فرع العميل).
PartyFormState partyFormStateFromCustomer({
  required PartyKind kind,
  required List<Currency> currencies,
  required Currency? baseCurrency,
  required int? userId,
  required Customer customer,
  required DateTime today,
  required DateTime? origOpeningDate,
  required bool openingLocked,
}) => PartyFormState(
  loading: false,
  kind: kind,
  editMode: true,
  currencies: currencies,
  baseCurrency: baseCurrency,
  userId: userId,
  name: customer.name,
  phone: customer.phone ?? '',
  whatsapp: customer.whatsapp ?? '',
  address: customer.address ?? '',
  area: customer.area ?? '',
  creditLimitText: customer.creditLimit == null
      ? ''
      : numToText(customer.creditLimit!),
  openingText: numToText(customer.openingBalance),
  openingCurrencyId: customer.openingBalanceCurrencyId ?? baseCurrency?.id,
  openingDate: origOpeningDate ?? today,
  notes: customer.notes ?? '',
  openingLocked: openingLocked,
);

/// حالة «تعديل مورد» من سجله المحمّل — الجسم منقول حرفياً من `load`
/// بمتحكم النموذج (فرع المورد).
PartyFormState partyFormStateFromSupplier({
  required PartyKind kind,
  required List<Currency> currencies,
  required Currency? baseCurrency,
  required int? userId,
  required Supplier supplier,
  required DateTime today,
  required DateTime? origOpeningDate,
  required bool openingLocked,
}) => PartyFormState(
  loading: false,
  kind: kind,
  editMode: true,
  currencies: currencies,
  baseCurrency: baseCurrency,
  userId: userId,
  name: supplier.name,
  phone: supplier.phone ?? '',
  address: supplier.address ?? '',
  openingText: numToText(supplier.openingBalance),
  openingCurrencyId: supplier.openingBalanceCurrencyId ?? baseCurrency?.id,
  openingDate: origOpeningDate ?? today,
  notes: supplier.notes ?? '',
  openingLocked: openingLocked,
);

/// مسودة حفظ العميل من قيم النموذج — الجسم منقول حرفياً من `save`
/// بمتحكم النموذج (فرع العميل).
CustomerDraft buildCustomerDraftFromPartyForm(
  PartyFormState state, {
  required String name,
  required double? creditLimit,
  required double openingBalance,
  required int? openingCurrencyId,
  required double? openingRate,
  required DateTime openingDate,
  required String? imagePath,
}) => CustomerDraft(
  name: name,
  phone: partyFormCleanText(state.phone),
  whatsapp: partyFormCleanText(state.whatsapp),
  address: partyFormCleanText(state.address),
  area: partyFormCleanText(state.area),
  creditLimit: creditLimit,
  openingBalance: openingBalance,
  openingBalanceCurrencyId: openingCurrencyId,
  openingBalanceRate: openingRate,
  openingBalanceDate: openingDate,
  notes: partyFormCleanText(state.notes),
  imagePath: imagePath,
);

/// مسودة حفظ المورد من قيم النموذج — الجسم منقول حرفياً من `save`
/// بمتحكم النموذج (فرع المورد).
SupplierDraft buildSupplierDraftFromPartyForm(
  PartyFormState state, {
  required String name,
  required double openingBalance,
  required int? openingCurrencyId,
  required double? openingRate,
  required DateTime openingDate,
}) => SupplierDraft(
  name: name,
  phone: partyFormCleanText(state.phone),
  address: partyFormCleanText(state.address),
  openingBalance: openingBalance,
  openingBalanceCurrencyId: openingCurrencyId,
  openingBalanceRate: openingRate,
  openingBalanceDate: openingDate,
  notes: partyFormCleanText(state.notes),
);
