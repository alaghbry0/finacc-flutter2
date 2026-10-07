/// نموذج سعر الصرف — صف من جدول `exchange_rate` (§5.3 / FR-08-03).
///
/// العملة الأساسية لا يُدخل لها سعر أبداً (سعرها 1 دائماً)؛ لكل عملة
/// أخرى سعر واحد على الأكثر في اليوم الواحد — `UNIQUE(currency_id,
/// rate_date)` — والإدخال اليدوي اليومي هو المصدر المعتمد في V1.
library;

/// سعر عملة واحدة في تاريخ معيّن.
class ExchangeRateEntry {
  const ExchangeRateEntry({
    required this.id,
    required this.currencyId,
    required this.rateDate,
    required this.rate,
    this.source = 'manual',
  });

  /// المعرّف في جدول `exchange_rate`.
  final int id;

  /// معرّف العملة (غير الأساسية).
  final int currencyId;

  /// تاريخ السعر بصيغة `YYYY-MM-DD` كما في القاعدة (تاريخ عمل يومي).
  final String rateDate;

  /// السعر مقابل العملة الأساسية (دائماً > 0).
  final double rate;

  /// مصدر السعر: `manual` افتراضياً (FR-08-03 — إدخال يدوي يومي).
  final String source;

  /// ينشئ نسخة من صف قاعدة البيانات.
  factory ExchangeRateEntry.fromRow(Map<String, Object?> row) =>
      ExchangeRateEntry(
        id: row['id'] as int,
        currencyId: row['currency_id'] as int,
        rateDate: row['rate_date'] as String,
        rate: (row['rate'] as num?)?.toDouble() ?? 0,
        source: (row['source'] as String?) ?? 'manual',
      );

  /// التاريخ محلولاً (منتصف ليل UTC ليوم العمل) — للعرض والترتيب.
  DateTime get rateDateUtc {
    final parsed = DateTime.parse(rateDate);
    return DateTime.utc(parsed.year, parsed.month, parsed.day);
  }
}
