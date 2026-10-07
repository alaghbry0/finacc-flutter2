/// حالة استخدام تأسيس المنشأة — SRS FR-13-01 (Onboarding).
///
/// الترتيب الملزم: بيانات المنشأة (اسم، هاتف، عملة أساسية، ضريبة 0%)
/// ثم خطوة ختامية تنشئ **ذرّياً في Transaction واحدة**:
/// `company` + «المخزن الرئيسي» (`warehouse`) + «الصندوق الرئيسي»
/// (`cashbox`) بالعملة الأساسية + مستخدم المدير (admin) بـ PIN مهشَّر +
/// عبارة مرور (مُتحقَّق منها) + السنة المالية الحالية + قيد audit.
///
/// الهدف المقيس: من التثبيت إلى أول فاتورة ≤ 5 دقائق (AC-24) — لذلك لا
/// خطوة إعداد إضافية بعد هذه.
library;

import '../core/result.dart';
import '../services/pin_hasher.dart';

/// مسوّدة تأسيس مكتملة القيم — جاهزة للتنفيذ الذرّي في طبقة البيانات.
class SetupCompanyDraft {
  const SetupCompanyDraft({
    required this.companyName,
    required this.currencyCode,
    required this.taxRate,
    required this.warehouseName,
    required this.cashboxName,
    required this.adminDisplayName,
    required this.pinHash,
    required this.passphraseHash,
    required this.fiscalYear,
    required this.fiscalStart,
    required this.fiscalEnd,
    this.phone,
  });

  /// اسم المنشأة (إلزامي).
  final String companyName;

  /// هاتف المنشأة (اختياري — لدعم واتساب لاحقاً).
  final String? phone;

  /// رمز العملة الأساسية (YER افتراضياً — تثبَّت بعدها، FR-08-01).
  final String currencyCode;

  /// نسبة الضريبة (0% افتراضياً للسوق اليمني).
  final double taxRate;

  /// اسم المخزن الافتراضي — قابل لإعادة التسمية لاحقاً.
  final String warehouseName;

  /// اسم الصندوق الافتراضي بالعملة الأساسية.
  final String cashboxName;

  /// اسم المدير الظاهر.
  final String adminDisplayName;

  /// PIN المهشَّر (pbkdf2-sha256).
  final String pinHash;

  /// عبارة المرور المهشَّرة (متحقق منها عند قفل 10 محاولات — AC-15).
  final String passphraseHash;

  /// السنة المالية الافتتاحية (سنة تقويمية).
  final int fiscalYear;
  final DateTime fiscalStart;
  final DateTime fiscalEnd;
}

/// مدقق التأسيس (نقي) — ينتج مسوّدة أو خطأً بكلمات المستخدم.
class SetupCompanyValidator {
  const SetupCompanyValidator();

  /// يتحقق من المدخلات وينتج المسوّدة.
  ///
  /// [pin] و[passphrase] نصوص خام تُهشَّر هنا قبل مغادرة النطاق.
  Result<SetupCompanyDraft, DomainError> validate({
    required String companyName,
    required String currencyCode,
    required String pin,
    required String passphrase,
    required DateTime now,
    String? phone,
    double taxRate = 0,
    String? warehouseName,
    String? cashboxName,
    String? adminDisplayName,
  }) {
    final name = companyName.trim();
    if (name.isEmpty) {
      return const Err(
        DomainError('اسم المنشأة مطلوب. اكتب اسم متجرك كما يظهر للعملاء.'),
      );
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currencyCode)) {
      return const Err(
        DomainError('رمز العملة غير صالح. اختر واحدة من العملات المعتمدة.'),
      );
    }
    if (!PinHasher.isValidPinFormat(pin)) {
      return const Err(
        DomainError(
          'رمز PIN يجب أن يكون من 4 إلى 6 خانات رقمية. أدخل رقماً صالحاً.',
        ),
      );
    }
    if (!PinHasher.isValidPassphrase(passphrase)) {
      return const Err(
        DomainError(
          'عبارة المرور يجب ألا تقل عن 8 خانات. اختر عبارة تحفظها جيداً — '
          'نسيانها يعني فقدان البيانات نهائياً.',
        ),
      );
    }
    if (taxRate < 0 || taxRate > 100) {
      return const Err(
        DomainError('نسبة الضريبة بين 0 و100. اتركها 0 إن لم تكن خاضعاً.'),
      );
    }
    return Ok(
      SetupCompanyDraft(
        companyName: name,
        phone: phone?.trim(),
        currencyCode: currencyCode,
        taxRate: taxRate,
        warehouseName: (warehouseName == null || warehouseName.trim().isEmpty)
            ? 'المخزن الرئيسي'
            : warehouseName.trim(),
        cashboxName: (cashboxName == null || cashboxName.trim().isEmpty)
            ? 'الصندوق الرئيسي'
            : cashboxName.trim(),
        adminDisplayName: (adminDisplayName?.trim().isEmpty ?? true)
            ? name
            : adminDisplayName!.trim(),
        pinHash: PinHasher.hash(pin),
        passphraseHash: PinHasher.hash(passphrase),
        fiscalYear: now.year,
        fiscalStart: DateTime(now.year, 1, 1),
        fiscalEnd: DateTime(now.year, 12, 31),
      ),
    );
  }
}
