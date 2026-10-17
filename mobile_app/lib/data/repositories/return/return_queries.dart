/// استعلامات وحوارس المرتجعات فوق القاعدة (تحميل الفاتورة الأصلية
/// والبنود والسقوف والدفعات) — دوال حرة تأخذ القاعدة/المنفِّذ صراحة.
/// مُستخرجة من return_repository.dart ضمن تقسيم R18-D3a.

library;

import 'package:sqflite/sqflite.dart';

import '../../../domain/core/numbers.dart';
import '../../../domain/services/purchase_pricing.dart';
import '../exchange_rate_repository.dart' show ExchangeRateRepository;
import 'return_flow_types.dart';
import 'return_helpers.dart';
import 'return_models.dart';
import '../settings_repository.dart' show SettingsRepository;

Future<List<ReturnableLine>> returnableLines(
  Database db,
  int invoiceId,
  String originalType,
  String returnType,
) async {
  final origRows = await db.query(
    'invoice',
    columns: ['id'],
    where: 'id = ? AND doc_type = ? AND status = ?',
    whereArgs: [invoiceId, originalType, 'completed'],
    limit: 1,
  );
  if (origRows.isEmpty) return const [];
  final items = await db.query(
    'invoice_item',
    where: 'invoice_id = ?',
    whereArgs: [invoiceId],
    orderBy: 'id ASC',
  );
  final returned = await returnedQtyByLine(db, invoiceId, returnType);
  return [
    for (final item in items)
      ReturnableLine(
        invoiceItemId: item['id'] as int,
        productId: item['product_id'] as int?,
        lineDesc: item['line_desc'] as String?,
        originalQty: (item['qty'] as num?)?.toDouble() ?? 0,
        returnedQty: returned[item['id'] as int] ?? 0,
        availableQty: availableForReturn(
          (item['qty'] as num?)?.toDouble() ?? 0,
          returned[item['id'] as int] ?? 0,
        ),
        unitPrice: (item['unit_price'] as num?)?.toDouble() ?? 0,
        unitPriceEffective: roundMoney(
          ((item['line_total'] as num?)?.toDouble() ?? 0) /
              ((item['qty'] as num?)?.toDouble() ?? 1),
        ),
        // تكلفة الوحدة على المنصرف الكلي — البونص داخل line_cost
        // (القرار 8) فلا تتضخم تكلفة العودة بنسبة المجاني.
        unitCostSnapshot: roundCost(
          ((item['line_cost'] as num?)?.toDouble() ?? 0) /
              dispatchedDivisor(item),
        ),
        batchId: item['batch_id'] as int?,
      ),
  ];
}

// ───────────────────────────────────────────────────────────────────
// مساعدات خاصة — التحميل والتحقق المشترك
// ───────────────────────────────────────────────────────────────────

/// يحمل الفاتورة الأصلية ويتحقق من نوعها وحالتها (FR-02-07).
Future<({Map<String, Object?> row, String? error})> loadOriginalInvoice(
  Database db,
  int invoiceId,
  String expectedType,
) async {
  final rows = await db.query(
    'invoice',
    where: 'id = ?',
    whereArgs: [invoiceId],
    limit: 1,
  );
  if (rows.isEmpty) {
    return (
      row: const <String, Object?>{},
      error: 'الفاتورة رقم #$invoiceId غير موجودة.',
    );
  }
  final row = rows.first;
  final docType = row['doc_type'] as String;
  if (docType != expectedType) {
    final label = expectedType == 'sale' ? 'بيع' : 'شراء';
    return (
      row: row,
      error:
          'الفاتورة رقم #$invoiceId ليست فاتورة $label (نوعها '
          '«$docType») — لا يُنشأ مرتجع إلا عن النوع المطابق.',
    );
  }
  final status = row['status'] as String;
  if (status == 'void') {
    return (
      row: row,
      error:
          'الفاتورة ${row['invoice_no']} ملغاة — لا يُنشأ مرتجع عن '
          'فاتورة ملغاة (FR-02-07).',
    );
  }
  if (status != 'completed') {
    return (
      row: row,
      error:
          'الفاتورة ${row['invoice_no']} ليست مكتملة (حالتها '
          '«$status») — لا يُنشأ مرتجع إلا عن فاتورة مكتملة.',
    );
  }
  return (row: row, error: null);
}

/// فحص انتساب البنود للفاتورة الأصلية + سقف الكميات لكل بند
/// (المباع/المشترى − المرتجع سابقاً) — القرار 1.
Future<({Map<int, Map<String, Object?>> items, String? error})>
checkMembershipAndCaps(
  Database db,
  int originalInvoiceId,
  String returnType,
  List<ReturnLineInput> lines,
) async {
  final itemRows = await db.query(
    'invoice_item',
    where: 'invoice_id = ?',
    whereArgs: [originalInvoiceId],
    orderBy: 'id ASC',
  );
  final items = {for (final row in itemRows) row['id'] as int: row};
  final returned = await returnedQtyByLine(db, originalInvoiceId, returnType);
  final requested = <int, double>{};
  for (final line in lines) {
    final item = items[line.invoiceItemId];
    if (item == null) {
      return (
        items: items,
        error:
            'البند رقم #${line.invoiceItemId} لا ينتمي إلى الفاتورة '
            'الأصلية — اختر بنوداً من الفاتورة نفسها.',
      );
    }
    requested[line.invoiceItemId] =
        (requested[line.invoiceItemId] ?? 0) + line.qty;
  }
  for (final entry in requested.entries) {
    final item = items[entry.key]!;
    final origQty = (item['qty'] as num?)?.toDouble() ?? 0;
    final alreadyReturned = returned[entry.key] ?? 0;
    final available = availableForReturn(origQty, alreadyReturned);
    if (entry.value > available + qtyEpsilon) {
      return (
        items: items,
        error:
            'الكمية المطلوب إرجاعها من البند '
            '«${item['line_desc'] ?? entry.key}» (${formatNum(entry.value)}) '
            'تتجاوز المتاح للإرجاع (${formatNum(available)}) — الأصلي '
            '${formatNum(origQty)} والمرتجع سابقاً ${formatNum(alreadyReturned)}.',
      );
    }
  }
  return (items: items, error: null);
}

/// حراسة السقف داخل المعاملة (كتابات متوازية) — القرار 1.
Future<void> assertReturnCapsInside(
  DatabaseExecutor txn,
  int originalInvoiceId,
  String returnType,
  List<ReturnLineInput> lines,
) async {
  final itemRows = await txn.query(
    'invoice_item',
    columns: ['id', 'qty', 'line_desc'],
    where: 'invoice_id = ?',
    whereArgs: [originalInvoiceId],
  );
  final origQty = {
    for (final row in itemRows)
      row['id'] as int: (row['qty'] as num?)?.toDouble() ?? 0,
  };
  final names = {
    for (final row in itemRows) row['id'] as int: row['line_desc'] as String?,
  };
  final returned = await returnedQtyByLineInside(
    txn,
    originalInvoiceId,
    returnType,
  );
  final requested = <int, double>{};
  for (final line in lines) {
    requested[line.invoiceItemId] =
        (requested[line.invoiceItemId] ?? 0) + line.qty;
  }
  for (final entry in requested.entries) {
    final available = availableForReturn(
      origQty[entry.key] ?? 0,
      returned[entry.key] ?? 0,
    );
    if (entry.value > available + qtyEpsilon) {
      throw ReturnFlowError(
        'تغيّر المتبقي للإرجاع من البند '
        '«${names[entry.key] ?? entry.key}» قبل الحفظ — المتاح الآن '
        '${formatNum(available)} والمطلوب ${formatNum(entry.value)}. أعد المحاولة.',
      );
    }
  }
}

/// يحل سعر الصرف وفق FR-08-09 (نفس نمط البيع/الشراء حرفياً).
Future<({double rate, bool isFallback, String? error})> resolveReturnRate(
  Database db,
  ExchangeRateRepository rates,
  SettingsRepository settings,
  int currencyId,
  DateTime issuedAt,
) async {
  final currencyRows = await db.query(
    'currency',
    columns: ['code', 'is_base'],
    where: 'id = ?',
    whereArgs: [currencyId],
    limit: 1,
  );
  if (currencyRows.isEmpty) {
    return (rate: 1.0, isFallback: false, error: 'عملة الفاتورة غير موجودة.');
  }
  if ((currencyRows.first['is_base'] as int? ?? 0) == 1) {
    return (rate: 1.0, isFallback: false, error: null);
  }
  final code = currencyRows.first['code'] as String;
  final todayRate = await rates.rateFor(currencyId, issuedAt);
  if (todayRate != null && todayRate > 0) {
    return (rate: todayRate, isFallback: false, error: null);
  }
  final fallbackOn =
      (await settings.getString('fx.fallback', 'off')) == 'last_known';
  if (!fallbackOn) {
    return (
      rate: 1.0,
      isFallback: false,
      error:
          'لا يوجد سعر صرف لعملة $code بتاريخ اليوم — أدخل سعر اليوم '
          'أولاً ثم احفظ (لا يُحفظ بسعر افتراضي).',
    );
  }
  final lastKnown = await rates.latestBefore(currencyId, issuedAt);
  if (lastKnown == null || lastKnown <= 0) {
    return (
      rate: 1.0,
      isFallback: false,
      error:
          'لا يوجد أي سعر صرف معروف لعملة $code — أدخل سعراً واحداً '
          'على الأقل قبل الحفظ بها.',
    );
  }
  return (rate: lastKnown, isFallback: true, error: null);
}

/// الصندوق الافتراضي أو null.
Future<int?> defaultCashboxId(Database db) async {
  final rows = await db.query(
    'cashbox',
    columns: ['id'],
    where: 'is_default = 1 AND is_archived = 0',
    limit: 1,
  );
  return rows.isEmpty ? null : rows.first['id'] as int;
}

/// معلومات الأصناف لبنود الفاتورة الأصلية (خدمي/متتبع).
Future<Map<int, ReturnProductInfo>> loadProductsForReturnItems(
  Database db,
  Map<int, Map<String, Object?>> items,
) async {
  final ids = {
    for (final item in items.values)
      if (item['product_id'] != null) item['product_id'] as int,
  };
  if (ids.isEmpty) return const {};
  final rows = await db.rawQuery(
    'SELECT id, name, is_service, track_batches FROM product '
    'WHERE id IN (${List.filled(ids.length, '?').join(',')})',
    ids.toList(),
  );
  return {
    for (final row in rows)
      row['id'] as int: ReturnProductInfo(
        id: row['id'] as int,
        name: row['name'] as String,
        isService: (row['is_service'] as int? ?? 0) == 1,
        trackBatches: (row['track_batches'] as int? ?? 0) == 1,
      ),
  };
}

/// فحص توفر المخزون مسبقاً لمرتجع الشراء (5.4-5): العادي من
/// `stock_level` والمتتبع من مجموع دفعاته غير المؤرشفة.
Future<String?> checkPurchaseReturnStock(
  Database db,
  Map<int, Map<String, Object?>> origItems,
  Map<int, ReturnProductInfo> products,
  List<ReturnLineInput> lines,
  int warehouseId,
) async {
  final requested = <int, double>{};
  final names = <int, String>{};
  for (final line in lines) {
    final item = origItems[line.invoiceItemId]!;
    final productId = item['product_id'] as int?;
    if (productId == null) continue;
    final info = products[productId];
    if (info == null || info.isService) continue;
    requested[productId] = (requested[productId] ?? 0) + line.qty;
    names[productId] = info.name;
  }
  if (requested.isEmpty) return null;
  final ids = requested.keys.toList();
  final inClause = List.filled(ids.length, '?').join(',');

  final plainRows = await db.rawQuery(
    'SELECT product_id, qty FROM stock_level '
    'WHERE warehouse_id = ? AND product_id IN ($inClause)',
    [warehouseId, ...ids],
  );
  final plainQty = {
    for (final row in plainRows)
      row['product_id'] as int: (row['qty'] as num?)?.toDouble() ?? 0,
  };
  final batchRows = await db.rawQuery(
    'SELECT product_id, SUM(qty) AS q FROM batch '
    'WHERE warehouse_id = ? AND product_id IN ($inClause) '
    '  AND qty > 0 AND is_archived = 0 GROUP BY product_id',
    [warehouseId, ...ids],
  );
  final batchQty = {
    for (final row in batchRows)
      row['product_id'] as int: (row['q'] as num?)?.toDouble() ?? 0,
  };
  for (final entry in requested.entries) {
    final tracked = products[entry.key]!.trackBatches;
    final available = tracked
        ? (batchQty[entry.key] ?? 0)
        : (plainQty[entry.key] ?? 0);
    if (available + qtyEpsilon < entry.value) {
      return 'الكمية غير متوفرة للصنف «${names[entry.key]}»: المتاح '
          '${formatNum(available)} والمطلوب إرجاعه ${formatNum(entry.value)} — '
          'لا يسمح النظام بمخزون سالب.';
    }
  }
  return null;
}

/// يقرأ حالة WAC (التكلفة + الكمية الكلية عبر المخازن) داخل المعاملة.
Future<({double cost, double qty})> readWacState(
  DatabaseExecutor txn,
  int productId,
) async {
  final rows = await txn.rawQuery(
    'SELECT p.cost_price AS cost, '
    '       COALESCE((SELECT SUM(sl.qty) FROM stock_level sl '
    '                 WHERE sl.product_id = p.id), 0) AS qty '
    'FROM product p WHERE p.id = ?',
    [productId],
  );
  return (
    cost: (rows.first['cost'] as num?)?.toDouble() ?? 0,
    qty: (rows.first['qty'] as num?)?.toDouble() ?? 0,
  );
}

// ───────────────────────────────────────────────────────────────────
// مساعدات الدفعات
// ───────────────────────────────────────────────────────────────────

/// **سعات عودة دفعات مرتجع البيع** (القرار 3): لكل دفعة استُهلكت في
/// البيع الأصلي — السعة = ما استُهلك منها − ما أُعيد إليها سابقاً
/// (حركات SRN سابقة بنفس صيغة الملاحظة)، مع مطابقة صف `batch` الحي
/// بالرقم والتاريخ معاً؛ الدفعات غير القابلة للتتبع تُتخطى (كميتها
/// تذهب للمخزون العام عبر «المتبقي»).
Future<List<ReturnBatchCap>> loadBatchReturnCaps(
  DatabaseExecutor txn, {
  required int productId,
  required int warehouseId,
  required int originalInvoiceId,
}) async {
  // استهلاك البيع الأصلي لكل دفعة (حركة لكل دفعة برجوع للفاتورة).
  final saleMoves = await txn.rawQuery(
    'SELECT notes, qty FROM stock_movement '
    "WHERE movement_type = 'sale' AND ref_type = 'invoice' AND ref_id = ? "
    'AND product_id = ? AND warehouse_id = ? ORDER BY id ASC',
    [originalInvoiceId, productId, warehouseId],
  );
  // (رقم الدفعة، تاريخ الصلاحية) → الكمية المستهلكة.
  final consumed = <String, double>{};
  final order = <String>[];
  for (final move in saleMoves) {
    final match = batchNotePattern.firstMatch((move['notes'] as String?) ?? '');
    if (match == null) continue; // حركة غير دفعية (مخزون عام).
    final key = '${match.group(1)!.trim()}|${match.group(2)!}';
    consumed[key] =
        (consumed[key] ?? 0) - ((move['qty'] as num?)?.toDouble() ?? 0);
    if (!order.contains(key)) order.add(key);
  }
  // ما أُعيد سابقاً لكل دفعة (حركات SRN مكتملة سابقة بنفس الصيغة).
  final priorMoves = await txn.rawQuery(
    'SELECT sm.notes AS notes, sm.qty AS qty FROM stock_movement sm '
    "WHERE sm.movement_type = 'sale_return' AND sm.ref_type = 'invoice' "
    'AND sm.ref_id IN (SELECT id FROM invoice '
    "  WHERE doc_type = 'sale_return' AND status = 'completed' "
    '    AND original_invoice_id = ?) '
    'AND sm.product_id = ? AND sm.warehouse_id = ?',
    [originalInvoiceId, productId, warehouseId],
  );
  final priorReturned = <String, double>{};
  for (final move in priorMoves) {
    final match = batchNotePattern.firstMatch((move['notes'] as String?) ?? '');
    if (match == null) continue; // عودة سابقة بلا دفعة (مخزون عام).
    final key = '${match.group(1)!.trim()}|${match.group(2)!}';
    priorReturned[key] =
        (priorReturned[key] ?? 0) + ((move['qty'] as num?)?.toDouble() ?? 0);
  }

  // السعة الفعالة لكل دفعة (بترتيب استهلاك FEFO الأصلي) مع مطابقة
  // الصف الحي — نفس ترتيب allocateFefo الأصلي (id ASC) عند التكرار.
  final caps = <ReturnBatchCap>[];
  for (final key in order) {
    final effective = (consumed[key] ?? 0) - (priorReturned[key] ?? 0);
    if (effective <= qtyEpsilon) continue;
    final parts = key.split('|');
    final batchRows = await txn.query(
      'batch',
      columns: ['id'],
      where:
          'product_id = ? AND warehouse_id = ? AND batch_number = ? '
          'AND expiry_date = ? AND is_archived = 0',
      whereArgs: [productId, warehouseId, parts[0], parts[1]],
      orderBy: 'id ASC',
      limit: 1,
    );
    if (batchRows.isEmpty) continue; // غير قابلة للتتبع → متبقٍ عام.
    caps.add(
      ReturnBatchCap(
        batchId: batchRows.first['id'] as int,
        batchNumber: parts[0],
        expiryDate: parts[1],
        qty: effective,
      ),
    );
  }
  return caps;
}

/// المرتجع سابقاً لكل بند أصلي (خارج المعاملة) — عبر علامة «أصل البند».
Future<Map<int, double>> returnedQtyByLine(
  Database db,
  int originalInvoiceId,
  String returnType,
) async {
  final rows = await db.rawQuery(
    'SELECT ii.notes AS notes, ii.qty AS qty '
    'FROM invoice_item ii JOIN invoice i ON i.id = ii.invoice_id '
    'WHERE i.doc_type = ? AND i.status = ? AND i.original_invoice_id = ?',
    [returnType, 'completed', originalInvoiceId],
  );
  return sumByOriginMarker(rows);
}

/// مثلها داخل معاملة نشطة (حراسة التزامن).
Future<Map<int, double>> returnedQtyByLineInside(
  DatabaseExecutor txn,
  int originalInvoiceId,
  String returnType,
) async {
  final rows = await txn.rawQuery(
    'SELECT ii.notes AS notes, ii.qty AS qty '
    'FROM invoice_item ii JOIN invoice i ON i.id = ii.invoice_id '
    'WHERE i.doc_type = ? AND i.status = ? AND i.original_invoice_id = ?',
    [returnType, 'completed', originalInvoiceId],
  );
  return sumByOriginMarker(rows);
}
