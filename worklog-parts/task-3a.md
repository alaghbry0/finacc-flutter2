---
Task ID: 3-a
Agent: general-purpose (انقطع بمهلة زمنية قبل كتابة تسليمه — وثّقه المنسق بعد التحقق)
Task: طبقة بيانات المرحلة 2 — الأصناف/الدفعات FEFO/باركود EAN-13/استيراد Excel-CSV + اختبارات

Work Log:
- أنشأ الوكيل الملفات العشرة المملوكة له قبل انقطاع الاتصال: النماذج (item.dart 393 سطراً، batch.dart)، مولد EAN-13 (بادئة المتجر 2xx + خانة تحقق mod-10)، ItemRepository (createItem ذرّي مع توليد باركود تلقائي عند الفراغ مع 5 محاولات ضد التصادم + searchItems بـ LIKE مفهرس + findByBarcode يستثني المؤرشف + lowStockItems + itemMovements + فئات ووحدات CRUD)، BatchRepository (allocateFefo محرك FEFO + applyAllocation بحارس ضد السالب + expiryAlerts بدلاء 30/60/90)، ItemImportService (CSV عربي مقتبس + xlsx عبر حزمة excel + mapping أعمدة + معاينة فشل بأسباب + AC-14: لا إدخال جزئي دون إقرار).
- تحقق المنسق بعد الانقطاع: dart analyze = صفر أخطاء، اختبارات الوكيل 48/48 خضراء، المجموعة الكاملة 249/249 (فشل عابر واحد في pin_hasher عند التشغيل المتوازي لا يتكرر).

Stage Summary:
- API جاهزة لواجهات المرحلة 2: createItem(ItemDraft, warehouseId, userId) / updateItem / archiveItem / searchItems(query, categoryId?, includeArchived, currencyIdForPrice) / findByBarcode / detail / lowStockItems / itemMovements / listCategories+createCategory(شجرة مستويين) / listUnits+createUnit(factor) / batchesForProduct(FEFO مرتبة بالصلاحية) / allocateFefo(txn, ...) / expiryAlerts / parseAndValidate + commitValid(confirmed).
