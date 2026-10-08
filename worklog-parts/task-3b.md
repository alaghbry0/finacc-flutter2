# تسليم المهمة 3-b — طبقة بيانات الأطراف وأسعار الصرف (المرحلة 3)

Task ID: 3-b
Agent: Z.ai Code (وكيل بيانات الأطراف — Flutter/Dart)
Task: بناء طبقة بيانات العملاء والموردين وأسعار الصرف كاملة + اختبارات وحدة شاملة (وحدة FR-03 + FR-08-03/05/09) وفق خطة المهمة 5.

## Work Log

- قراءة worklog.md (قسم المهمة 5) ودراسة المراجع المعمارية: company_repository (الذرّية)، user_repository (نمط audit_log)، result.dart، doc_sequence.dart، اختبارات company_repository.
- التحقق من DDL الفعلي في schema.dart: مطابقة تامة مع جدول customer/supplier/exchange_rate/invoice/cash_tx — **ملاحظة**: عمود cash_tx النصي اسمه `description` في المخطط المجمد (لا `notes` كما في نص المهمة) — لم أتأثر لأن قراءتي تتم عبر customer_id/tx_type فقط.
- إنشاء lib/domain/models/party.dart: Customer/Supplier (fromRow) + CustomerDraft/SupplierDraft (دلالة creditLimit الثلاثية: null بلا حد / 0 منع الآجل / قيمة = الحد — FR-03-01) + PartyBalance + StatementEntryCode (enum بتسمية عربية جاهزة `label`) + StatementEntry + StatementResult.
- إنشاء lib/domain/models/exchange_rate.dart: ExchangeRateEntry + rateDateUtc.
- إنشاء lib/data/repositories/customer_repository.dart: createCustomer/updateCustomer/archiveCustomer (كل منها Transaction ذرّية + قيد audit_log)، hasMovements، listWithBalances (استعلام واحد بـ CTE يجمع مستحقات البيع/سندات القبض/مرتجعات البيع/الافتتاحي لكل (عميل × عملة))، balanceInCurrency، receivablesList، checkCredit (سجل مسمى)، statement.
- إنشاء lib/data/repositories/supplier_repository.dart: مرآة كاملة باتجاه الشراء (purchase + / payment − / purchase_return − / opening +) مع payablesList.
- إنشاء lib/data/repositories/exchange_rate_repository.dart: setRate (UPSERT على UNIQUE(currency_id, rate_date) يحدّث rate/source ويحفظ created_at الأصلي + رفض العملة الأساسية والسعر ≤ 0 والعملة غير الموجودة)، rateFor، latestBefore (شامل ≤)، history (DESC)، todayRates، hasRateFor.
- كتابة 42 اختباراً عبر 3 ملفات: حقن صفوف invoice/cash_tx خامّة للتحقق من الصيغ مباشرة (AC-02 حرفياً: 500+1000−400−200=900)، فصل العملات، استثناء void/draft/السند الملغى، حد الائتمان الثلاثي، كشف الحساب بالرصيد الرأسي و«رصيد ماضٍ»، ترتيب المتعثرين وأيام التأخير، UPSERT سعر الصرف بلا تكرار، ورفض الأساسية.
- إصلاحان أثناء الاختبارات: (1) معاملات البحث الخامسة في listWithBalances (search × 3)، (2) عبارات «audit فارغ» صارت تُفلتر بـ action لأن openSeededApp يكتب قيد app_setup.

## النتائج (بوابات الجودة)

- `dart format` على ملفاتي الثمانية: 0 تغييرات متبقية.
- `dart analyze` (المشروع كاملاً): **صفر ملاحظات في ملفاتي**؛ 4 ملاحظات فقط في ملفات الوكيل الموازي 3-a (item_repository_test.dart / item_import_service.dart) — خارج ملكيتي، تجاهلتها وفق التعليمات.
- `flutter test test/data/customer_repository_test.dart test/data/supplier_repository_test.dart test/data/exchange_rate_repository_test.dart`: **42/42 خضراء** (عميل 17 / مورد 12 / صرف 13).

## Stage Summary — واجهة برمجة الطبقة (لوكيل الواجهة)

### CustomerRepository(Database)
- `createCustomer(CustomerDraft, {required userId, now}) → Result<int, String>` — اسم إلزامي؛ رصيد افتتاحي ≠ 0 يتطلب عملة+سعر؛ التاريخ يفترض يوم now؛ تدقيق customer_create (details: name=...).
- `updateCustomer(id, CustomerDraft, {required userId, now}) → Result<Customer, String>` — يعيد الكيان الجديد؛ تدقيق customer_update.
- `archiveCustomer(id, {required userId, now}) → Result<void, String>` — أرشفة فقط، لا حذف أبداً (FR-03-09)؛ تدقيق customer_archive.
- `hasMovements(id) → bool` — فواتير أو سندات أو افتتاحي ≠ 0.
- `listWithBalances({search, includeArchived = false}) → List<PartyBalance>` — **سطر لكل (طرف × عملة)**؛ البلاحركة سطر واحد برصيد 0 بعملة القاعدة؛ بحث بالاسم/الهاتف؛ PartyBalance يضم lastPaymentDate وoldestOpenInvoiceDate للعرض.
- `balanceInCurrency(customerId, currencyId) → double` — الصيغة أحادية العملة (0 عند لا حركة).
- `receivablesList({minBalance = 1, now}) → List<PartyBalance>` — مرتب بأقدم فاتورة آجلة مفتوحة + daysLate («متأخر منذ X يوماً»).
- `checkCredit(customerId, currencyId, additionalAmount) → ({balance, creditLimit, overLimit})` — null لا تجاوز أبداً؛ 0 أي آجل تجاوز؛ قيمة: balance+additional > limit.
- `statement(customerId, {required currencyId, from, to}) → StatementResult` — قيود زمنية برصيد رأسي؛ قبل from يُجمع في قيد «رصيد ماضٍ» (StatementEntryCode.carryIn)؛ بعد to يُستبعد؛ finalBalance يطابق balanceInCurrency عند غياب to.

### SupplierRepository(Database)
- نفس البنية تماماً: createSupplier/updateSupplier/archiveSupplier/hasMovements/listWithBalances/balanceInCurrency/statement + `payablesList({minBalance, now})` (المبالغ المتبقية للموردين، مرتبة بأقدم فاتورة شراء مفتوحة).
- الموجب = دَين لنا في ذمة المورد.

### ExchangeRateRepository(Database)
- `setRate({currencyId, date, rate, userId, now}) → Result<void, String>` — UPSERT يومي؛ يحفظ created_at الأصلي؛ تدقيق fx_rate_set بتفاصيل `currency=CODE date=YYYY-MM-DD rate=...`؛ رفض الأساسية/≤0/عملة مجهولة.
- `rateFor(currencyId, date)`, `latestBefore(currencyId, date)` (شامل ≤), `history(currencyId, {limit = 60})`, `todayRates(today) → Map<int, double>` (الغائبة تغيب), `hasRateFor(currencyId, date)`.

### نماذج party.dart
- `Customer`/`Supplier` + `CustomerDraft`/`SupplierDraft` (openingBalance/…/openingBalanceDate كـ DateTime?).
- `StatementEntryCode.label` عربية جاهزة للعرض (فاتورة بيع/سند قبض/مرتجع بيع/فاتورة شراء/سند صرف/مرتجع شراء/رصيد افتتاحي/رصيد ماضٍ).
- `StatementResult.openingBalance` = رصيد أول الفترة (0 عند عدم تحديد from لأن الافتتاحي يظهر حينها كقيد داخل الكشف).

## الانحرافات والقرارات الموثقة

1. **ENUM إضافي carryIn**: قيد «رصيد ماضٍ» (المطلوب في FR-04/كشف الحساب بفترة) أُضيف كقيمة enum ثامنة StatementEntryCode.carryIn — القيم السبع المطلوبة كلها موجودة؛ إضافة تحسينية للعرض.
2. **استثناء فواتير الكاش التامة من الكشف**: فاتورة بيع completed بـ due_amount = 0 لا تُنشئ قيداً في كشف حساب الطرف (لا أثر لها في الرصيد أصلاً) — الكشف حساب دَين لا سجل مبيعات.
3. **الاصطلاح المعماري الأهم لموجة محرك البيع/الشراء**: `due_amount` يُقرأ كالجزء الآجل عند الإصدار ولا يُنقص عند التخصيص؛ الخصم يأتي من سندات القبض/الصرف المنفصلة (هكذا بُنيت صيغة AC-02 ومُحققت اختبارياً: 500+1000−400−200=900). على محرك الفواتير ألا ينقص due_amount عند الدفع وإلا تكرر الخصم — أو يقرر المنسق تعديل الصيغة قبل موجة المحرك.
4. **receivablesList/payablesList** أُضيف لهما معامل `now?` اختياري (تحديد لحظة حساب أيام التأخير في الاختبارات) — إضافة اختيارية لا تكسر التوقيع المطلوب.
5. **صفر حركة → عملة القاعدة**: العميل/المورد بلا أي حركة يظهر في listWithBalances بسطر واحد برصيد 0 برمز عملة القاعدة (سلوك عرضي موثق).
6. **payment_allocation خارج الصيغة**: الخصم يُحسب من cash_tx مباشرة (وفق نص المهمة)؛ جدول التخصيص تفصيل مستندي للمحرك اللاحق.
7. عمود cash_tx النصي `description` (لا notes) — انظر أعلاه؛ لا تأثير.

## الملفات المسلَّمة (ملكيتي حصراً)

- lib/domain/models/party.dart
- lib/domain/models/exchange_rate.dart
- lib/data/repositories/customer_repository.dart
- lib/data/repositories/supplier_repository.dart
- lib/data/repositories/exchange_rate_repository.dart
- test/data/customer_repository_test.dart (17)
- test/data/supplier_repository_test.dart (12)
- test/data/exchange_rate_repository_test.dart (13)

لم أمسّ أي ملف خارج القائمة (لا l10n ولا pubspec ولا schema ولا ملفات 3-a).
