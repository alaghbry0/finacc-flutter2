/// SRS v1.5 — §5.3 المخطط الكامل (SQLite DDL) — **مجمّد (Frozen)**.
///
/// كل عبارة تُنفَّذ على حدة داخل هجرة موثقة (انظر `migrations.dart`).
/// لا يجوز تعديل أي عبارة هنا إلا بإضافة هجرة جديدة بإصدار أعلى —
/// القاعدة المرجعية هي القسم 5.3 من وثيقة `docs/finacc-srs-v1.5.md` حرفياً.
///
/// ملاحظة: جدول `_migrations` يُنشأ بواسطة مشغّل الهجرات نفسه (جدول النظام).
library;

/// جداول DDL لإصدار المخطط 1 — كامل القسم 5.3 من SRS v1.5.
const List<String> schemaV1Ddl = <String>[
  // ============ الترقيم الذري ============
  // الاستهلاك داخل Transaction واحدة بـ UPSERT ذري (لا MAX+1 أبداً).
  // (doc_sequence/doc_sequence.dart — قاعدة 5.4-1)
  '''
  CREATE TABLE doc_sequence (
    doc_type TEXT NOT NULL,
    year INTEGER NOT NULL,
    last_no INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY(doc_type, year)
  )
  ''',

  // ============ المراجع الأساسية ============
  '''
  CREATE TABLE company (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    phone TEXT, whatsapp TEXT, address TEXT,
    logo_path TEXT,
    currency_id INTEGER NOT NULL REFERENCES currency(id),
    tax_number TEXT, tax_rate NUMERIC(5,2) NOT NULL DEFAULT 0,
    invoice_prefix TEXT DEFAULT 'INV',
    footer_text TEXT,
    created_at TEXT, updated_at TEXT, created_by INTEGER
  )
  ''',
  '''
  CREATE TABLE currency (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    symbol_svg TEXT,
    is_base INTEGER NOT NULL DEFAULT 0,
    decimals INTEGER NOT NULL DEFAULT 2,
    is_active INTEGER NOT NULL DEFAULT 1
  )
  ''',
  '''
  CREATE TABLE exchange_rate (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    currency_id INTEGER NOT NULL REFERENCES currency(id),
    rate_date TEXT NOT NULL,
    rate NUMERIC(14,6) NOT NULL CHECK(rate > 0),
    source TEXT DEFAULT 'manual',
    created_at TEXT, created_by INTEGER,
    UNIQUE(currency_id, rate_date)
  )
  ''',
  '''
  CREATE TABLE category (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    parent_id INTEGER REFERENCES category(id),
    sort_order INTEGER DEFAULT 0,
    is_archived INTEGER DEFAULT 0,
    created_at TEXT, updated_at TEXT, created_by INTEGER
  )
  ''',
  '''
  CREATE TABLE unit (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    base_unit_id INTEGER REFERENCES unit(id),
    factor NUMERIC(12,4) DEFAULT 1,
    is_archived INTEGER DEFAULT 0,
    created_at TEXT, updated_at TEXT, created_by INTEGER
  )
  ''',
  '''
  CREATE TABLE warehouse (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    location TEXT,
    is_default INTEGER DEFAULT 0,
    is_archived INTEGER DEFAULT 0,
    created_at TEXT, updated_at TEXT, created_by INTEGER
  )
  ''',
  '''
  CREATE TABLE cashbox (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    currency_id INTEGER NOT NULL REFERENCES currency(id),
    is_default INTEGER DEFAULT 0,
    is_archived INTEGER DEFAULT 0,
    created_at TEXT, updated_at TEXT, created_by INTEGER
  )
  ''',
  '''
  CREATE TABLE expense_category (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    is_archived INTEGER DEFAULT 0,
    created_at TEXT, updated_at TEXT, created_by INTEGER
  )
  ''',

  // ============ الفترات المحاسبية (قرار 6 + م5) ============
  '''
  CREATE TABLE fiscal_year (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    year INTEGER NOT NULL UNIQUE,
    start_date TEXT NOT NULL, end_date TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'open' CHECK(status IN ('open','closed')),
    closed_at TEXT, closed_by INTEGER,
    created_at TEXT, updated_at TEXT
  )
  ''',

  // ============ الأصناف والمخزون ============
  '''
  CREATE TABLE product (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    barcode TEXT UNIQUE,
    category_id INTEGER REFERENCES category(id),
    unit_id INTEGER REFERENCES unit(id),
    cost_price NUMERIC(14,4) NOT NULL DEFAULT 0,
    min_stock NUMERIC(12,3) NOT NULL DEFAULT 0,
    is_service INTEGER NOT NULL DEFAULT 0,
    track_batches INTEGER NOT NULL DEFAULT 0,
    track_serials INTEGER NOT NULL DEFAULT 0,
    image_path TEXT, notes TEXT,
    is_archived INTEGER NOT NULL DEFAULT 0,
    created_at TEXT, updated_at TEXT, created_by INTEGER
  )
  ''',
  'CREATE INDEX idx_product_name ON product(name)',
  'CREATE INDEX idx_product_barcode ON product(barcode)',
  '''
  CREATE TABLE product_price (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL REFERENCES product(id),
    currency_id INTEGER NOT NULL REFERENCES currency(id),
    price NUMERIC(14,4) NOT NULL CHECK(price >= 0),
    price_level TEXT NOT NULL DEFAULT 'retail'
      CHECK(price_level IN ('retail','wholesale','credit')),
    margin_percent NUMERIC(5,2) NOT NULL DEFAULT 0,
    updated_at TEXT,
    UNIQUE(product_id, currency_id, price_level)
  )
  ''',
  '''
  CREATE TABLE stock_level (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL REFERENCES product(id),
    warehouse_id INTEGER NOT NULL REFERENCES warehouse(id),
    qty NUMERIC(12,3) NOT NULL DEFAULT 0,
    UNIQUE(product_id, warehouse_id),
    CHECK(qty >= 0)
  )
  ''',
  '''
  CREATE TABLE stock_movement (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL REFERENCES product(id),
    warehouse_id INTEGER NOT NULL REFERENCES warehouse(id),
    movement_type TEXT NOT NULL CHECK(movement_type IN
      ('purchase','sale','sale_return','purchase_return',
       'stocktake_adjust','manual_adjust','transfer_in','transfer_out','opening')),
    qty NUMERIC(12,3) NOT NULL CHECK(qty <> 0),
    unit_cost NUMERIC(14,4) NOT NULL,
    ref_type TEXT, ref_id INTEGER,
    moved_at TEXT NOT NULL, notes TEXT,
    created_at TEXT, created_by INTEGER
  )
  ''',
  'CREATE INDEX idx_move_product_date ON stock_movement(product_id, moved_at)',
  'CREATE INDEX idx_move_warehouse ON stock_movement(warehouse_id, moved_at)',
  'CREATE INDEX idx_move_ref ON stock_movement(ref_type, ref_id)',
  // الدفعات وتواريخ الصلاحية (FEFO) — نشطة في V1 (FR-01-10).
  '''
  CREATE TABLE batch (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL REFERENCES product(id),
    warehouse_id INTEGER NOT NULL REFERENCES warehouse(id),
    batch_number TEXT NOT NULL,
    expiry_date TEXT NOT NULL,
    cost_price NUMERIC(14,4) NOT NULL DEFAULT 0,
    qty NUMERIC(12,3) NOT NULL DEFAULT 0,
    is_archived INTEGER DEFAULT 0,
    created_at TEXT, updated_at TEXT
  )
  ''',
  'CREATE INDEX idx_batch_product ON batch(product_id, expiry_date)',
  'CREATE INDEX idx_batch_expiry ON batch(expiry_date)',
  '''
  CREATE TABLE stocktake (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    warehouse_id INTEGER NOT NULL REFERENCES warehouse(id),
    counted_at TEXT NOT NULL,
    total_diff NUMERIC(14,4) DEFAULT 0,
    status TEXT DEFAULT 'completed', notes TEXT,
    created_at TEXT, created_by INTEGER
  )
  ''',
  '''
  CREATE TABLE stocktake_line (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    stocktake_id INTEGER NOT NULL REFERENCES stocktake(id),
    product_id INTEGER NOT NULL REFERENCES product(id),
    book_qty NUMERIC(12,3) NOT NULL,
    counted_qty NUMERIC(12,3) NOT NULL,
    diff_qty NUMERIC(12,3) NOT NULL,
    unit_cost NUMERIC(14,4) NOT NULL,
    created_at TEXT, created_by INTEGER
  )
  ''',

  // ============ الأطراف ============
  '''
  CREATE TABLE customer (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL, phone TEXT, whatsapp TEXT, address TEXT,
    area TEXT,
    credit_limit NUMERIC(14,4) DEFAULT NULL,
    opening_balance NUMERIC(14,4) DEFAULT 0,
    opening_balance_currency_id INTEGER REFERENCES currency(id),
    opening_balance_rate NUMERIC(12,6),
    opening_balance_date TEXT,
    notes TEXT, image_path TEXT,
    is_archived INTEGER NOT NULL DEFAULT 0,
    created_at TEXT, updated_at TEXT, created_by INTEGER
  )
  ''',
  'CREATE INDEX idx_customer_name ON customer(name)',
  'CREATE INDEX idx_customer_phone ON customer(phone)',
  '''
  CREATE TABLE supplier (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL, phone TEXT, address TEXT,
    opening_balance NUMERIC(14,4) DEFAULT 0,
    opening_balance_currency_id INTEGER REFERENCES currency(id),
    opening_balance_rate NUMERIC(12,6),
    opening_balance_date TEXT,
    notes TEXT, is_archived INTEGER DEFAULT 0,
    created_at TEXT, updated_at TEXT, created_by INTEGER
  )
  ''',

  // ============ الفوترة ============
  '''
  CREATE TABLE invoice (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_no TEXT UNIQUE,
    doc_type TEXT NOT NULL
      CHECK(doc_type IN ('sale','purchase','sale_return','purchase_return')),
    pay_status TEXT NOT NULL CHECK(pay_status IN ('cash','credit','mixed')),
    status TEXT NOT NULL DEFAULT 'completed'
      CHECK(status IN ('draft','completed','void')),
    issued_at TEXT NOT NULL,
    converted_at TEXT,
    original_invoice_id INTEGER REFERENCES invoice(id),
    quotation_id INTEGER REFERENCES quotation(id),
    due_date TEXT,
    customer_id INTEGER REFERENCES customer(id),
    supplier_id INTEGER REFERENCES supplier(id),
    sales_rep_id INTEGER,
    cashbox_id INTEGER REFERENCES cashbox(id),
    warehouse_id INTEGER NOT NULL REFERENCES warehouse(id),
    currency_id INTEGER NOT NULL REFERENCES currency(id),
    exchange_rate NUMERIC(12,6) NOT NULL,
    rate_is_fallback INTEGER NOT NULL DEFAULT 0,
    subtotal NUMERIC(14,4) NOT NULL DEFAULT 0,
    discount_amount NUMERIC(14,4) NOT NULL DEFAULT 0,
    tax_rate NUMERIC(5,2) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(14,4) NOT NULL DEFAULT 0,
    total NUMERIC(14,4) NOT NULL CHECK(total > 0),
    total_base NUMERIC(14,4) NOT NULL DEFAULT 0,
    paid_amount NUMERIC(14,4) NOT NULL DEFAULT 0,
    due_amount NUMERIC(14,4) NOT NULL DEFAULT 0 CHECK(due_amount >= 0),
    cost_total NUMERIC(14,4) NOT NULL DEFAULT 0,
    notes_internal TEXT, notes_printed TEXT,
    created_at TEXT, updated_at TEXT, created_by INTEGER,
    CHECK(paid_amount <= total)
  )
  ''',
  'CREATE INDEX idx_invoice_type_date ON invoice(doc_type, issued_at)',
  'CREATE INDEX idx_invoice_customer ON invoice(customer_id, issued_at)',
  'CREATE INDEX idx_invoice_supplier ON invoice(supplier_id, issued_at)',
  'CREATE INDEX idx_invoice_no ON invoice(invoice_no)',
  'CREATE INDEX idx_invoice_original ON invoice(original_invoice_id)',
  '''
  CREATE TABLE invoice_item (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_id INTEGER NOT NULL REFERENCES invoice(id),
    product_id INTEGER REFERENCES product(id),
    line_desc TEXT,
    qty NUMERIC(12,3) NOT NULL CHECK(qty > 0),
    unit_id INTEGER REFERENCES unit(id),
    unit_factor NUMERIC(12,4) NOT NULL DEFAULT 1,
    unit_price NUMERIC(14,4) NOT NULL,
    discount_percent NUMERIC(5,2) DEFAULT 0,
    discount_amount NUMERIC(14,4) DEFAULT 0,
    tax_percent NUMERIC(5,2) DEFAULT 0,
    line_total NUMERIC(14,4) NOT NULL,
    line_cost NUMERIC(14,4) NOT NULL DEFAULT 0,
    batch_id INTEGER REFERENCES batch(id),
    serial_numbers TEXT,
    notes TEXT,
    created_at TEXT
  )
  ''',
  'CREATE INDEX idx_item_invoice ON invoice_item(invoice_id)',
  'CREATE INDEX idx_item_product ON invoice_item(product_id)',

  // ============ عروض الأسعار (Quotations — نشطة في V1) ============
  '''
  CREATE TABLE quotation (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    quotation_no TEXT NOT NULL UNIQUE,
    customer_id INTEGER REFERENCES customer(id),
    warehouse_id INTEGER NOT NULL REFERENCES warehouse(id),
    currency_id INTEGER NOT NULL REFERENCES currency(id),
    exchange_rate NUMERIC(12,6) NOT NULL,
    issued_at TEXT NOT NULL,
    valid_until TEXT,
    status TEXT NOT NULL DEFAULT 'draft'
      CHECK(status IN ('draft','sent','converted','expired','rejected')),
    converted_invoice_id INTEGER REFERENCES invoice(id),
    subtotal NUMERIC(14,4) NOT NULL DEFAULT 0,
    discount_amount NUMERIC(14,4) NOT NULL DEFAULT 0,
    tax_rate NUMERIC(5,2) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(14,4) NOT NULL DEFAULT 0,
    total NUMERIC(14,4) NOT NULL CHECK(total > 0),
    notes_internal TEXT, notes_printed TEXT,
    created_at TEXT, updated_at TEXT, created_by INTEGER
  )
  ''',
  'CREATE INDEX idx_quotation_customer ON quotation(customer_id)',
  'CREATE INDEX idx_quotation_status ON quotation(status)',
  '''
  CREATE TABLE quotation_item (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    quotation_id INTEGER NOT NULL REFERENCES quotation(id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES product(id),
    line_desc TEXT,
    qty NUMERIC(12,3) NOT NULL CHECK(qty > 0),
    unit_id INTEGER REFERENCES unit(id),
    unit_factor NUMERIC(12,4) NOT NULL DEFAULT 1,
    unit_price NUMERIC(14,4) NOT NULL,
    discount_percent NUMERIC(5,2) DEFAULT 0,
    discount_amount NUMERIC(14,4) DEFAULT 0,
    tax_percent NUMERIC(5,2) DEFAULT 0,
    line_total NUMERIC(14,4) NOT NULL,
    batch_id INTEGER REFERENCES batch(id),
    notes TEXT,
    created_at TEXT
  )
  ''',
  'CREATE INDEX idx_quote_item_quotation ON quotation_item(quotation_id)',

  // ============ النقدية ============
  '''
  CREATE TABLE cash_tx (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tx_type TEXT NOT NULL CHECK(tx_type IN
      ('receipt','payment','expense','owner_draw','capital_in',
       'box_transfer','bank_deposit','bank_withdraw','opening',
       'employee_advance','commission_payout','salary_batch')),
    cashbox_id INTEGER NOT NULL REFERENCES cashbox(id),
    to_cashbox_id INTEGER REFERENCES cashbox(id),
    currency_id INTEGER NOT NULL REFERENCES currency(id),
    amount NUMERIC(14,4) NOT NULL CHECK(amount > 0),
    exchange_rate NUMERIC(12,6) NOT NULL,
    settlement_rate NUMERIC(12,6),
    fx_gain_loss NUMERIC(14,4) NOT NULL DEFAULT 0,
    voucher_no TEXT,
    tx_date TEXT NOT NULL,
    ref_type TEXT, ref_id INTEGER,
    expense_category_id INTEGER REFERENCES expense_category(id),
    employee_id INTEGER,
    customer_id INTEGER REFERENCES customer(id),
    supplier_id INTEGER REFERENCES supplier(id),
    is_voided INTEGER NOT NULL DEFAULT 0,
    reversal_of INTEGER REFERENCES cash_tx(id),
    description TEXT,
    created_at TEXT, created_by INTEGER
  )
  ''',
  'CREATE INDEX idx_cash_tx_date ON cash_tx(tx_date)',
  'CREATE INDEX idx_cash_tx_box ON cash_tx(cashbox_id, tx_date)',
  'CREATE INDEX idx_cash_tx_ref ON cash_tx(ref_type, ref_id)',
  'CREATE INDEX idx_cash_tx_voucher ON cash_tx(voucher_no)',
  // تخصيص المدفوعات: سند واحد يغطي عدة فواتير + قبض حر on_account.
  '''
  CREATE TABLE payment_allocation (
    cash_tx_id INTEGER NOT NULL REFERENCES cash_tx(id),
    invoice_id INTEGER NOT NULL REFERENCES invoice(id),
    allocated_amount NUMERIC(14,4) NOT NULL CHECK(allocated_amount > 0),
    allocated_at TEXT NOT NULL, created_by INTEGER,
    PRIMARY KEY(cash_tx_id, invoice_id)
  )
  ''',
  'CREATE INDEX idx_alloc_invoice ON payment_allocation(invoice_id)',
  '''
  CREATE TABLE shift (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cashbox_id INTEGER NOT NULL REFERENCES cashbox(id),
    user_id INTEGER REFERENCES app_user(id),
    opened_at TEXT NOT NULL, closed_at TEXT,
    opening_count NUMERIC(14,4),
    expected NUMERIC(14,4), counted NUMERIC(14,4),
    difference NUMERIC(14,4), notes TEXT,
    created_at TEXT, updated_at TEXT
  )
  ''',

  // ============ الشيكات (DDL محجوز لهجرات V1.1 — §11) ============
  '''
  CREATE TABLE cheque (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    direction TEXT NOT NULL CHECK(direction IN ('in','out')),
    party_type TEXT NOT NULL CHECK(party_type IN ('customer','supplier')),
    party_id INTEGER NOT NULL,
    cheque_no TEXT NOT NULL, bank_name TEXT,
    amount NUMERIC(14,4) NOT NULL CHECK(amount > 0),
    currency_id INTEGER NOT NULL REFERENCES currency(id),
    exchange_rate NUMERIC(12,6) NOT NULL,
    issue_date TEXT NOT NULL, due_date TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending'
      CHECK(status IN ('pending','deposited','cleared','bounced','void')),
    bounced_at TEXT, bounce_fee NUMERIC(14,4) DEFAULT 0,
    ref_invoice_id INTEGER REFERENCES invoice(id),
    cleared_cash_tx_id INTEGER REFERENCES cash_tx(id),
    notes TEXT,
    created_at TEXT, updated_at TEXT, created_by INTEGER
  )
  ''',
  'CREATE INDEX idx_cheque_due ON cheque(due_date, status)',
  'CREATE INDEX idx_cheque_party ON cheque(party_type, party_id)',

  // ============ التقسيط (DDL محجوز لهجرات V1.1 — §11) ============
  '''
  CREATE TABLE installment_plan (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id INTEGER NOT NULL REFERENCES customer(id),
    invoice_id INTEGER NOT NULL REFERENCES invoice(id),
    currency_id INTEGER NOT NULL REFERENCES currency(id),
    exchange_rate NUMERIC(12,6) NOT NULL,
    principal NUMERIC(14,4) NOT NULL,
    down_payment NUMERIC(14,4) DEFAULT 0,
    down_payment_cash_tx_id INTEGER REFERENCES cash_tx(id),
    months INTEGER NOT NULL,
    cycle TEXT DEFAULT 'monthly' CHECK(cycle IN ('monthly','weekly')),
    first_due TEXT NOT NULL,
    total_paid NUMERIC(14,4) DEFAULT 0,
    status TEXT DEFAULT 'active'
      CHECK(status IN ('active','completed','defaulted','cancelled')),
    created_at TEXT, updated_at TEXT, created_by INTEGER
  )
  ''',
  '''
  CREATE TABLE installment (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plan_id INTEGER NOT NULL REFERENCES installment_plan(id),
    seq INTEGER NOT NULL,
    due_date TEXT NOT NULL, amount NUMERIC(14,4) NOT NULL,
    paid_amount NUMERIC(14,4) DEFAULT 0,
    status TEXT DEFAULT 'pending'
      CHECK(status IN ('pending','partial','paid','late')),
    paid_at TEXT, cash_tx_id INTEGER REFERENCES cash_tx(id),
    created_at TEXT, updated_at TEXT,
    UNIQUE(plan_id, seq)
  )
  ''',
  'CREATE INDEX idx_installment_due ON installment(due_date, status)',

  // ============ المستخدمون والأمان ============
  '''
  CREATE TABLE app_user (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'admin' CHECK(role IN ('admin','cashier','viewer')),
    pin_hash TEXT,
    failed_attempts INTEGER NOT NULL DEFAULT 0,
    locked_until TEXT,
    permissions TEXT NOT NULL DEFAULT '{}',
    default_cashbox_id INTEGER REFERENCES cashbox(id),
    is_active INTEGER DEFAULT 1,
    last_login_at TEXT, created_at TEXT, updated_at TEXT
  )
  ''',
  '''
  CREATE TABLE audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER REFERENCES app_user(id),
    action TEXT NOT NULL,
    entity TEXT, entity_id INTEGER,
    details TEXT,
    at TEXT NOT NULL
  )
  ''',
  'CREATE INDEX idx_audit_at ON audit_log(at)',
  // حماية داخل الملف: السجل للإضافة فقط (FR-12-04).
  '''
  CREATE TRIGGER audit_log_no_update BEFORE UPDATE ON audit_log
  BEGIN SELECT RAISE(ABORT, 'audit_log is append-only'); END
  ''',
  '''
  CREATE TRIGGER audit_log_no_delete BEFORE DELETE ON audit_log
  BEGIN SELECT RAISE(ABORT, 'audit_log is append-only'); END
  ''',
  '''
  CREATE TABLE backup_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    kind TEXT NOT NULL CHECK(kind IN ('manual','auto','cloud','pre_restore')),
    file_name TEXT, file_size INTEGER, checksum TEXT,
    cloud_path TEXT,
    status TEXT DEFAULT 'ok', at TEXT NOT NULL, user_id INTEGER,
    created_at TEXT
  )
  ''',
  '''
  CREATE TABLE settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TEXT, updated_by INTEGER
  )
  ''',
];

/// جدول الهجرات — §5.3 (آخر جدول في المخطط).
const String migrationsTableDdl = '''
  CREATE TABLE IF NOT EXISTS _migrations (
    id INTEGER PRIMARY KEY,
    version INTEGER NOT NULL,
    applied_at TEXT
  )
''';

/// أسماء كل جداول المخطط (للتحقق في اختبارات الوحدة — SRS §10.2).
const List<String> schemaTableNames = <String>[
  'doc_sequence',
  'company',
  'currency',
  'exchange_rate',
  'category',
  'unit',
  'warehouse',
  'cashbox',
  'expense_category',
  'fiscal_year',
  'product',
  'product_price',
  'stock_level',
  'stock_movement',
  'batch',
  'stocktake',
  'stocktake_line',
  'customer',
  'supplier',
  'invoice',
  'invoice_item',
  'quotation',
  'quotation_item',
  'cash_tx',
  'payment_allocation',
  'shift',
  'cheque',
  'installment_plan',
  'installment',
  'app_user',
  'audit_log',
  'backup_log',
  'settings',
];
