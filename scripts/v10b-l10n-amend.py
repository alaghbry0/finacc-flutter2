#!/usr/bin/env python3
"""V10-0b: تعديل قفل l10n — عناوين/أزرار النماذج بنص النموذج الأولي
حرفياً (قرار النقد 🔴-3) + إعادة صياغة تلميح الصنف العابر (🟡-15)."""
import json

AR_NEW = {
    "itemFormSimTitle": "نموذج إدخال المنتج",
    "itemFormSimSave": "حفظ المنتج",
    "partyFormSimAddTitle": "إضافة عميل / مورد جديد",
    "partyFormSimSave": "حفظ هذا",
}
AR_DESC = {
    "itemFormSimTitle": "عنوان نموذج الصنف بنص النموذج الأولي (modal-product-edit)",
    "itemFormSimSave": "زر حفظ نموذج الصنف بنص النموذج الأولي",
    "partyFormSimAddTitle": "عنوان نموذج الطرف بنص النموذج الأولي (modal-add-client)",
    "partyFormSimSave": "زر حفظ نموذج الطرف بنص لقطة 064839",
}
EN_NEW = {
    "itemFormSimTitle": "Product Entry Form",
    "itemFormSimSave": "Save Product",
    "partyFormSimAddTitle": "Add New Client / Supplier",
    "partyFormSimSave": "Save This",
}
# 🟡-15 — صياغة صادقة مع الأرشفة بعد الترحيل لا قبله.
AR_REWORD = {
    "sellQuickAddOneOffHint": "بدون حفظ: يُنشأ الصنف لهذه الفاتورة فقط ويؤرشف من القوائم بعد إتمامها",
}
EN_REWORD = {
    "sellQuickAddOneOffHint": "Without saving: the item is created for this invoice only and archived from lists after it completes",
}

for path, new, reword in [
    ("lib/l10n/app_ar.arb", (AR_NEW, AR_DESC), AR_REWORD),
    ("lib/l10n/app_en.arb", (EN_NEW, None), EN_REWORD),
]:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    pairs, descs = new
    for k, v in pairs.items():
        if k in data and not k.startswith("@"):
            raise SystemExit(f"مفتاح موجود مسبقاً: {k} في {path}")
        data[k] = v
    if descs:
        for k, v in descs.items():
            data[f"@{k}"] = {"description": v}
    for k, v in reword.items():
        if k not in data:
            raise SystemExit(f"مفتاح إعادة الصياغة مفقود: {k} في {path}")
        data[k] = v
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")

ar = json.load(open("lib/l10n/app_ar.arb", encoding="utf-8"))
en = json.load(open("lib/l10n/app_en.arb", encoding="utf-8"))
ar_real = {k for k in ar if not k.startswith("@")}
en_real = {k for k in en if not k.startswith("@")}
assert ar_real == en_real, "اختلال التكافؤ!"
print(f"AR={len(ar_real)} EN={len(en_real)} parity=OK")
print("V10-0b: 4 مفاتيح جديدة + إعادة صياغة التلميح")
