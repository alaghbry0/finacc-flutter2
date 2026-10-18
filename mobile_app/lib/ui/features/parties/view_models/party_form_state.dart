/// حالة نموذج الطرف النقية (أخطاء التحقق + قيم الحقول كنصوص) — مستخرجة
/// من party_form_view_model (R20-D3c: نقل حرفي بلا أي تغيير سلوكي؛
/// تُصدَّر من ملف المتحكم فبقيت استيرادات المستدعين كما هي).
library;

import '../../../../domain/models/company.dart';
import 'party_kind.dart';

/// أخطاء التحقق القابلة للترجمة (تُعرض فوق زر الحفظ).
enum PartyFormError {
  /// الاسم فارغ.
  nameRequired,

  /// حد الائتمان ليس رقماً صالحاً (فارغ/صفر/موجب فقط).
  creditLimitInvalid,

  /// الرصيد الافتتاحي ليس رقماً موجباً.
  openingInvalid,

  /// رصيد افتتاحي غير صفري بلا عملة.
  openingCurrencyRequired,

  /// لا سعر صرف للعملة المحددة (FR-08-09 — يمنع الحفظ).
  noRate,

  /// لا مستخدم مدير (تعذر قيد التدقيق).
  noUser,
}

/// حالة نموذج الطرف — قيم الحقول كنصوص كما يكتبها المستخدم.
class PartyFormState {
  const PartyFormState({
    required this.loading,
    required this.kind,
    required this.editMode,
    required this.currencies,
    this.loadError,
    this.baseCurrency,
    this.userId,
    this.name = '',
    this.phone = '',
    this.whatsapp = '',
    this.address = '',
    this.area = '',
    this.creditLimitText = '',
    this.openingText = '',
    this.openingCurrencyId,
    required this.openingDate,
    this.notes = '',
    this.openingLocked = false,
    this.saving = false,
    this.saved = false,
    this.validationError,
    this.repoError,
  });

  final bool loading;

  /// نوع الطرف — يحدد الحقول الزائدة (واتساب/حي/حد ائتمان للعملاء).
  final PartyKind kind;

  /// وضع التعديل.
  final bool editMode;

  /// العملات النشطة — الأساسية أولاً.
  final List<Currency> currencies;

  final Object? loadError;

  final Currency? baseCurrency;
  final int? userId;

  // ── الحقول النصية ──
  final String name;
  final String phone;
  final String whatsapp;
  final String address;
  final String area;

  /// حد الائتمان كنص: فارغ = بلا حد، «0» = منع الآجل، رقم = الحد.
  final String creditLimitText;

  /// الرصيد الافتتاحي كنص.
  final String openingText;

  /// عملة الرصيد الافتتاحي (null = بلا — ممنوع مع رصيد غير صفري).
  final int? openingCurrencyId;

  /// تاريخ الرصيد الافتتاحي (اليوم افتراضياً).
  final DateTime openingDate;

  final String notes;

  /// الافتتاحي مقفل (تعديل لطرف له حركات) — للقراءة فقط في العرض.
  final bool openingLocked;

  final bool saving;
  final bool saved;
  final PartyFormError? validationError;

  /// خطأ المستودع (عربي جاهز — SnackBar).
  final String? repoError;

  /// حد الائتمان المفسر بدلالته الثلاثية — أو null عند نص غير صالح.
  double? get parsedCreditLimit {
    final text = creditLimitText.trim();
    if (text.isEmpty) return null; // بلا حد.
    return double.tryParse(text);
  }

  /// الرصيد الافتتاحي المفسر — أو null عند نص غير صالح.
  double? get parsedOpening {
    final text = openingText.trim();
    if (text.isEmpty) return 0;
    return double.tryParse(text);
  }

  /// العملة الافتتاحية المحددة ككيان (null عند عدم الاختيار).
  Currency? get selectedOpeningCurrency {
    for (final currency in currencies) {
      if (currency.id == openingCurrencyId) return currency;
    }
    return null;
  }

  static PartyFormState initial(PartyKind kind, DateTime today) =>
      PartyFormState(
        loading: true,
        kind: kind,
        editMode: false,
        currencies: const <Currency>[],
        openingDate: today,
      );
}

/// نسخ الحالة مع تجاوز الحقول المطلوبة فقط — الجسم منقول حرفياً من
/// `_mutate` بمتحكم النموذج (علامات التصفير كما كانت).
PartyFormState partyFormStateWith(
  PartyFormState state, {
  String? name,
  String? phone,
  String? whatsapp,
  String? address,
  String? area,
  String? creditLimitText,
  String? openingText,
  int? openingCurrencyId,
  bool clearOpeningCurrency = false,
  DateTime? openingDate,
  String? notes,
  bool? saving,
  bool? saved,
  PartyFormError? validationError,
  bool clearValidationError = false,
  String? repoError,
  bool clearRepoError = false,
}) => PartyFormState(
  loading: state.loading,
  kind: state.kind,
  editMode: state.editMode,
  currencies: state.currencies,
  loadError: state.loadError,
  baseCurrency: state.baseCurrency,
  userId: state.userId,
  name: name ?? state.name,
  phone: phone ?? state.phone,
  whatsapp: whatsapp ?? state.whatsapp,
  address: address ?? state.address,
  area: area ?? state.area,
  creditLimitText: creditLimitText ?? state.creditLimitText,
  openingText: openingText ?? state.openingText,
  openingCurrencyId: clearOpeningCurrency
      ? null
      : (openingCurrencyId ?? state.openingCurrencyId),
  openingDate: openingDate ?? state.openingDate,
  notes: notes ?? state.notes,
  openingLocked: state.openingLocked,
  saving: saving ?? state.saving,
  saved: saved ?? state.saved,
  validationError: clearValidationError
      ? null
      : (validationError ?? state.validationError),
  repoError: clearRepoError ? null : (repoError ?? state.repoError),
);
