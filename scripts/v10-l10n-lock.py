#!/usr/bin/env python3
"""V10-0: قفل مفاتيح l10n لنافذة الإضافة السريعة للصنف داخل الفاتورة."""
import json

AR = {
    "sellQuickAddTitle": "إضافة بند",
    "sellQuickAddNameHint": "اسم الصنف",
    "sellQuickAddPriceHint": "سعر الوحدة",
    "sellQuickAddSaveToProducts": "حفظ الصنف في قائمة المنتجات",
    "sellQuickAddOneOffHint": "بدون حفظ: يُنشأ الصنف لهذه الفاتورة فقط ويؤرشف من القوائم",
    "sellQuickAddContinue": "متابعة",
    "sellQuickAddNameRequired": "اسم الصنف مطلوب",
    "sellQuickAddPriceInvalid": "سعر الوحدة غير صالح",
    "sellQuickAddNewTile": "صنف جديد",
    "sellQuickAddCreated": "أُنشئ «{name}» وأُضيف للفاتورة",
    "sellQuickAddCreateError": "تعذر إنشاء الصنف",
}
AR_DESC = {
    "sellQuickAddTitle": "عنوان نافذة إضافة بند سريع داخل الفاتورة",
    "sellQuickAddNameHint": "تلميح حقل اسم الصنف بالنافذة السريعة",
    "sellQuickAddPriceHint": "تلميح حقل سعر الوحدة بالنافذة السريعة",
    "sellQuickAddSaveToProducts": "خيار حفظ الصنف الجديد في قائمة المنتجات",
    "sellQuickAddOneOffHint": "شرح خيار عدم الحفظ (صنف لهذه الفاتورة فقط)",
    "sellQuickAddContinue": "زر المتابعة بالنافذة السريعة",
    "sellQuickAddNameRequired": "خطأ: اسم الصنف مطلوب",
    "sellQuickAddPriceInvalid": "خطأ: سعر الوحدة غير صالح",
    "sellQuickAddNewTile": "تلميح بطاقة صنف جديد في منتقي الأصناف",
    "sellQuickAddCreated": "رسالة نجاح إنشاء الصنف وإضافته ({name})",
    "sellQuickAddCreateError": "خطأ فشل إنشاء الصنف",
}
EN = {
    "sellQuickAddTitle": "Add Item",
    "sellQuickAddNameHint": "Item name",
    "sellQuickAddPriceHint": "Unit price",
    "sellQuickAddSaveToProducts": "Save item to products list",
    "sellQuickAddOneOffHint": "Without saving: item is created for this invoice only and archived from lists",
    "sellQuickAddContinue": "Continue",
    "sellQuickAddNameRequired": "Item name is required",
    "sellQuickAddPriceInvalid": "Unit price is invalid",
    "sellQuickAddNewTile": "New item",
    "sellQuickAddCreated": "Created \"{name}\" and added to the invoice",
    "sellQuickAddCreateError": "Could not create the item",
}

for path, tail in [
    ("lib/l10n/app_ar.arb", (AR, AR_DESC)),
    ("lib/l10n/app_en.arb", (EN, None)),
]:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    pairs, descs = tail
    for k, v in pairs.items():
        if k in data and not k.startswith("@"):
            raise SystemExit(f"مفتاح موجود مسبقاً: {k} في {path}")
        data[k] = v
    if descs:
        for k, v in descs.items():
            data[f"@{k}"] = {"description": v}
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")

ar = json.load(open("lib/l10n/app_ar.arb", encoding="utf-8"))
en = json.load(open("lib/l10n/app_en.arb", encoding="utf-8"))
ar_real = {k for k in ar if not k.startswith("@")}
en_real = {k for k in en if not k.startswith("@")}
print(f"AR={len(ar_real)} EN={len(en_real)} parity={'OK' if ar_real == en_real else 'FAIL'}")
assert ar_real == en_real, "اختلال التكافؤ!"
print("V10-0 l10n lock: 11 keys added")
