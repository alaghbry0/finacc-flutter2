/// اختبارات مدقق تأسيس المنشأة — الأخطار بكلمات المستخدم والمسودة الناتجة.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/domain/core/result.dart';
import 'package:mobile_app/domain/use_cases/setup_company.dart';

void main() {
  const validator = SetupCompanyValidator();
  final now = DateTime(2026, 10, 6, 12);

  SetupCompanyDraft validateOk({
    String name = 'متجر النور',
    String currency = 'YER',
    String pin = '1234',
    String passphrase = 'Passphrase-2026',
  }) {
    final result = validator.validate(
      companyName: name,
      currencyCode: currency,
      pin: pin,
      passphrase: passphrase,
      now: now,
    );
    expect(result, isA<Ok<SetupCompanyDraft, DomainError>>());
    return (result as Ok<SetupCompanyDraft, DomainError>).value;
  }

  test('مسودة سليمة: قيم افتراضية للمخزن/الصندوق/المدير والسنة المالية', () {
    final draft = validateOk();
    expect(draft.companyName, 'متجر النور');
    expect(draft.currencyCode, 'YER');
    expect(draft.warehouseName, 'المخزن الرئيسي');
    expect(draft.cashboxName, 'الصندوق الرئيسي');
    expect(draft.adminDisplayName, 'متجر النور',
        reason: 'المدير يرث اسم المنشأة إن لم يُحدد');
    expect(draft.fiscalYear, 2026);
    expect(draft.fiscalStart, DateTime(2026, 1, 1));
    expect(draft.fiscalEnd, DateTime(2026, 12, 31));
    // الهاشات ليست النص الخام.
    expect(draft.pinHash, isNot(contains('1234')));
    expect(draft.passphraseHash, isNot(contains('Passphrase')));
  });

  test('اسم المنشأة إلزامي (فراغ ومسافات فقط)', () {
    for (final bad in ['', '   ', '\t']) {
      final result = validator.validate(
        companyName: bad,
        currencyCode: 'YER',
        pin: '1234',
        passphrase: 'Passphrase-2026',
        now: now,
      );
      expect(result, isA<Err<SetupCompanyDraft, DomainError>>());
      expect(
        (result as Err).error.message,
        contains('اسم المنشأة'),
      );
    }
  });

  test('رمز العملة ثلاثة أحرف لاتينية كبيرة', () {
    for (final bad in ['yer', 'US', 'USDD', '12A']) {
      final result = validator.validate(
        companyName: 'متجر',
        currencyCode: bad,
        pin: '1234',
        passphrase: 'Passphrase-2026',
        now: now,
      );
      expect(result, isA<Err<SetupCompanyDraft, DomainError>>(),
          reason: 'العملة $bad يجب أن ترفض');
    }
    expect(validateOk(currency: 'SAR').currencyCode, 'SAR');
  });

  test('PIN من 4-6 خانات وعبارة مرور ≥ 8 خانات', () {
    expect(
      validator.validate(
        companyName: 'متجر',
        currencyCode: 'YER',
        pin: '123',
        passphrase: 'Passphrase-2026',
        now: now,
      ),
      isA<Err<SetupCompanyDraft, DomainError>>(),
    );
    expect(
      validator.validate(
        companyName: 'متجر',
        currencyCode: 'YER',
        pin: '1234',
        passphrase: 'short',
        now: now,
      ),
      isA<Err<SetupCompanyDraft, DomainError>>(),
    );
  });

  test('ضريبة خارج 0-100 ترفض، والقيم المخصصة تُحترم', () {
    expect(
      validator.validate(
        companyName: 'متجر',
        currencyCode: 'YER',
        pin: '1234',
        passphrase: 'Passphrase-2026',
        now: now,
        taxRate: 101,
      ),
      isA<Err<SetupCompanyDraft, DomainError>>(),
    );
    final custom = validator.validate(
      companyName: ' متجر النور ',
      currencyCode: 'YER',
      pin: '555555',
      passphrase: 'Passphrase-2026',
      now: now,
      phone: ' 777123456 ',
      warehouseName: 'مستودع الفرع',
      cashboxName: 'صندوق الكاشير',
      adminDisplayName: 'أمين',
    ) as Ok<SetupCompanyDraft, DomainError>;
    expect(custom.value.companyName, 'متجر النور', reason: 'يقصّ الفراغات');
    expect(custom.value.phone, '777123456');
    expect(custom.value.warehouseName, 'مستودع الفرع');
    expect(custom.value.cashboxName, 'صندوق الكاشير');
    expect(custom.value.adminDisplayName, 'أمين');
  });
}
