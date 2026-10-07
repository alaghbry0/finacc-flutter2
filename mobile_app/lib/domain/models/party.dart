/// نماذج الأطراف — العملاء والموردون وأرصدتهم وكشوف حساباتهم
/// (SRS v1.5 §5.3 + وحدة FR-03).
///
/// القاعدة المركزية (FR-03-02 / FR-08-11): **لا تُخلط العملات أبداً في رقم
/// واحد** — كل رصيد مقيد بعملة واحدة، والطرف ذو أرصدة في عملتين يظهر
/// في سطرين مستقلين لا في رقم مجمّع.
library;

/// عميل — جدول `customer` (§5.3).
class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.whatsapp,
    this.address,
    this.area,
    this.creditLimit,
    this.openingBalance = 0,
    this.openingBalanceCurrencyId,
    this.openingBalanceRate,
    this.openingBalanceDate,
    this.notes,
    this.imagePath,
    this.isArchived = false,
  });

  /// المعرّف في جدول `customer`.
  final int id;

  /// اسم العميل (إلزامي — FR-03-01).
  final String name;

  /// الهاتف (اختياري — للبحث والتواصل).
  final String? phone;

  /// واتساب (اختياري — للمراسلة المباشرة).
  final String? whatsapp;

  /// العنوان (اختياري).
  final String? address;

  /// الحي/المنطقة (اختياري — لتقسيم طرق البيع والتوصيل).
  final String? area;

  /// حد الائتمان — **دلالة القيمة الفارغة ملزمة** (FR-03-01):
  /// `null` = بلا حد مطلقاً؛ `0` = منع الآجل كلياً؛ موجبة = الحد نفسه.
  /// يُفسَّر بعملة الفاتورة الجارية عند فحص التجاوز (FR-03-05).
  final double? creditLimit;

  /// الرصيد الافتتاحي بعملته الافتتاحية (0 = لا رصيد).
  final double openingBalance;

  /// عملة الرصيد الافتتاحي (إلزامية عند رصيد غير صفري).
  final int? openingBalanceCurrencyId;

  /// سعر الصرف لحظة تسجيل الرصيد الافتتاحي (as-of).
  final double? openingBalanceRate;

  /// تاريخ الرصيد الافتتاحي بصيغة `YYYY-MM-DD` كما في القاعدة.
  final String? openingBalanceDate;

  /// ملاحظات داخلية (اختياري).
  final String? notes;

  /// مسار صورة العميل محلياً (اختياري).
  final String? imagePath;

  /// مؤشر الأرشفة (FR-03-09 — طرف له حركات يُؤرشف ولا يُحذف).
  final bool isArchived;

  /// ينشئ نسخة من صف قاعدة البيانات.
  factory Customer.fromRow(Map<String, Object?> row) => Customer(
    id: row['id'] as int,
    name: row['name'] as String,
    phone: row['phone'] as String?,
    whatsapp: row['whatsapp'] as String?,
    address: row['address'] as String?,
    area: row['area'] as String?,
    creditLimit: (row['credit_limit'] as num?)?.toDouble(),
    openingBalance: (row['opening_balance'] as num?)?.toDouble() ?? 0,
    openingBalanceCurrencyId: row['opening_balance_currency_id'] as int?,
    openingBalanceRate: (row['opening_balance_rate'] as num?)?.toDouble(),
    openingBalanceDate: row['opening_balance_date'] as String?,
    notes: row['notes'] as String?,
    imagePath: row['image_path'] as String?,
    isArchived: (row['is_archived'] as int? ?? 0) == 1,
  );
}

/// مورد — جدول `supplier` (§5.3 / FR-03-03).
class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.openingBalance = 0,
    this.openingBalanceCurrencyId,
    this.openingBalanceRate,
    this.openingBalanceDate,
    this.notes,
    this.isArchived = false,
  });

  /// المعرّف في جدول `supplier`.
  final int id;

  /// اسم المورد (إلزامي — FR-03-03).
  final String name;

  /// الهاتف (اختياري).
  final String? phone;

  /// العنوان (اختياري).
  final String? address;

  /// الرصيد الافتتاحي بعملته (موجب = دَين لنا عنده).
  final double openingBalance;

  /// عملة الرصيد الافتتاحي (إلزامية عند رصيد غير صفري).
  final int? openingBalanceCurrencyId;

  /// سعر الصرف لحظة تسجيل الرصيد الافتتاحي.
  final double? openingBalanceRate;

  /// تاريخ الرصيد الافتتاحي بصيغة `YYYY-MM-DD`.
  final String? openingBalanceDate;

  /// ملاحظات داخلية (اختياري).
  final String? notes;

  /// مؤشر الأرشفة.
  final bool isArchived;

  /// ينشئ نسخة من صف قاعدة البيانات.
  factory Supplier.fromRow(Map<String, Object?> row) => Supplier(
    id: row['id'] as int,
    name: row['name'] as String,
    phone: row['phone'] as String?,
    address: row['address'] as String?,
    openingBalance: (row['opening_balance'] as num?)?.toDouble() ?? 0,
    openingBalanceCurrencyId: row['opening_balance_currency_id'] as int?,
    openingBalanceRate: (row['opening_balance_rate'] as num?)?.toDouble(),
    openingBalanceDate: row['opening_balance_date'] as String?,
    notes: row['notes'] as String?,
    isArchived: (row['is_archived'] as int? ?? 0) == 1,
  );
}

/// مسودة إنشاء/تعديل عميل (مدخلات الواجهة — FR-03-01).
///
/// [creditLimit] بدلالتها الثلاثية الملزمة: `null` بلا حد، `0` منع الآجل،
/// قيمة موجبة حدّ ائتماني.
class CustomerDraft {
  const CustomerDraft({
    required this.name,
    this.phone,
    this.whatsapp,
    this.address,
    this.area,
    this.creditLimit,
    this.openingBalance = 0,
    this.openingBalanceCurrencyId,
    this.openingBalanceRate,
    this.openingBalanceDate,
    this.notes,
    this.imagePath,
  });

  /// اسم العميل (إلزامي بعد التقليم).
  final String name;

  /// الهاتف (اختياري).
  final String? phone;

  /// واتساب (اختياري).
  final String? whatsapp;

  /// العنوان (اختياري).
  final String? address;

  /// الحي/المنطقة (اختياري).
  final String? area;

  /// حد الائتمان (`null` بلا حد / `0` منع الآجل / قيمة = الحد).
  final double? creditLimit;

  /// الرصيد الافتتاحي (0 = بلا).
  final double openingBalance;

  /// عملة الرصيد الافتتاحي — إلزامية عند رصيد غير صفري.
  final int? openingBalanceCurrencyId;

  /// سعر الصرف as-of للرصيد الافتتاحي — إلزامي عند رصيد غير صفري.
  final double? openingBalanceRate;

  /// تاريخ الرصيد الافتتاحي (يفترض تاريخ اليوم إن لم يُمرَّر).
  final DateTime? openingBalanceDate;

  /// ملاحظات داخلية (اختياري).
  final String? notes;

  /// مسار صورة العميل محلياً (اختياري).
  final String? imagePath;
}

/// مسودة إنشاء/تعديل مورد (مدخلات الواجهة — FR-03-03).
class SupplierDraft {
  const SupplierDraft({
    required this.name,
    this.phone,
    this.address,
    this.openingBalance = 0,
    this.openingBalanceCurrencyId,
    this.openingBalanceRate,
    this.openingBalanceDate,
    this.notes,
  });

  /// اسم المورد (إلزامي بعد التقليم).
  final String name;

  /// الهاتف (اختياري).
  final String? phone;

  /// العنوان (اختياري).
  final String? address;

  /// الرصيد الافتتاحي (0 = بلا).
  final double openingBalance;

  /// عملة الرصيد الافتتاحي — إلزامية عند رصيد غير صفري.
  final int? openingBalanceCurrencyId;

  /// سعر الصرف as-of للرصيد الافتتاحي — إلزامي عند رصيد غير صفري.
  final double? openingBalanceRate;

  /// تاريخ الرصيد الافتتاحي (يفترض تاريخ اليوم إن لم يُمرَّر).
  final DateTime? openingBalanceDate;

  /// ملاحظات داخلية (اختياري).
  final String? notes;
}

/// رصيد طرف في عملة واحدة — سطر واحد في قائمة الأطراف (FR-03-02).
///
/// طرف له حركة في عملتين = سطران منفصلان؛ لا يُجمَّع أبداً (FR-08-11).
class PartyBalance {
  const PartyBalance({
    required this.partyId,
    required this.name,
    this.phone,
    required this.currencyCode,
    required this.balance,
    this.lastPaymentDate,
    this.oldestOpenInvoiceDate,
    this.daysLate,
  });

  /// معرّف الطرف (customer.id أو supplier.id).
  final int partyId;

  /// اسم الطرف للعرض.
  final String name;

  /// الهاتف للعرض (زر اتصال/واتساب).
  final String? phone;

  /// رمز العملة المقيد بها الرصيد (SAR / USD / …).
  final String currencyCode;

  /// الرصيد بعملته — للعميل: موجب = دَين عليه لنا؛ للمورد: موجب = دَين
  /// لنا في ذمته. السالب رصيد دائن للطرف.
  final double balance;

  /// تاريخ آخر سند قبض/صرف في هذه العملة (للعرض).
  final DateTime? lastPaymentDate;

  /// تاريخ أقدم فاتورة آجلة مفتوحة في هذه العملة (لعرض «متأخر منذ»).
  final DateTime? oldestOpenInvoiceDate;

  /// عدد أيام التأخير منذ أقدم فاتورة مفتوحة (تُحتسب في قوائم المتعثرين
  /// فقط — `متأخر منذ X يوماً`).
  final int? daysLate;
}

/// رمز نوع القيد في كشف حساب الطرف (FR-03-04).
enum StatementEntryCode {
  /// فاتورة بيع آجلة (+ دين على العميل).
  invoice('فاتورة بيع'),

  /// سند قبض (− يخفض دين العميل).
  receipt('سند قبض'),

  /// مرتجع بيع آجل (− يخفض دين العميل).
  saleReturn('مرتجع بيع'),

  /// فاتورة شراء آجلة (+ ما علينا للمورد).
  purchase('فاتورة شراء'),

  /// سند صرف للمورد (− يخفض ما علينا).
  payment('سند صرف'),

  /// مرتجع شراء آجل (− يخفض ما علينا).
  purchaseReturn('مرتجع شراء'),

  /// رصيد افتتاحي للطرف (بتماريخ تسجيله).
  opening('رصيد افتتاحي'),

  /// رصيد ماضٍ محمول من قبل بداية الفترة المطلوبة (يظهر عند تحديد
  /// تاريخ «من» في كشف الحساب).
  carryIn('رصيد ماضٍ');

  const StatementEntryCode(this.label);

  /// التسمية العربية الجاهزة للعرض في كشف الحساب.
  final String label;
}

/// قيد واحد في كشف حساب الطرف (FR-03-04).
class StatementEntry {
  const StatementEntry({
    required this.date,
    required this.code,
    required this.amount,
    required this.runningBalance,
    required this.currencyCode,
    this.docNo,
    this.refId,
  });

  /// تاريخ القيد (منتصف ليل UTC ليوم العمل).
  final DateTime date;

  /// نوع القيد (فاتورة/سند/مرتجع/افتتاحي/ماضٍ).
  final StatementEntryCode code;

  /// رقم المستند (INV-… / RVT-…) أو `null` لقيد الرصيد.
  final String? docNo;

  /// المبلغ الموقَّع بعملة الكشف:
  /// موجب = يزيد دين الطرف، سالب = يخفضه.
  final double amount;

  /// الرصيد الرأسي بعد هذا القيد (متجركماً من أول الكشف).
  final double runningBalance;

  /// رمز عملة الكشف (واحدة لكل الكشف).
  final String currencyCode;

  /// معرّف المستند المرجعي (invoice.id / cash_tx.id) أو `null`.
  final int? refId;
}

/// نتيجة كشف حساب طرف بعملة واحدة وفترة محددة (FR-03-04).
class StatementResult {
  const StatementResult({
    required this.entries,
    required this.openingBalance,
    required this.finalBalance,
    required this.currencyId,
    required this.currencyCode,
  });

  /// القيود داخل الفترة بترتيب زمني تصاعدي.
  final List<StatementEntry> entries;

  /// رصيد أول الفترة («رصيد ماضٍ») — صفر عند عدم تحديد تاريخ «من»
  /// (حينها يظهر الرصيد الافتتاحي نفسه كأول قيد داخل الكشف).
  final double openingBalance;

  /// الرصيد النهائي بعد آخر قيد — يطابق `balanceInCurrency` دائماً.
  final double finalBalance;

  /// معرّف عملة الكشف.
  final int currencyId;

  /// رمز عملة الكشف.
  final String currencyCode;
}
