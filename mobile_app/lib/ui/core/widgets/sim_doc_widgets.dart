/// مكتبة مستندات Simple Invoice Manager المشتركة (V6-B) — مكونات Flutter
/// (لا PDF) قابلة لإعادة الاستخدام بين معاينة الفاتورة A4 (شاشة البيع)
/// ومعاينة الإيصال/سند القبض (ميزة النقدية)، مطابقة لقسم A4 بالنموذج
/// الأولي `upload/invoice-manager.html` (CSS الورقة 615–680 ودالة
/// `renderA4Preview` 1967–2027) والمرجع التصميمي
/// `docs/sim-design-reference.md` §2:
///
/// - [SimA4Sheet]: غلاف صفحة A4 — خلفية منطقة `#CFD8DC` (داكن: سطح
///   أدكن منسجم) وحشوة خارجية 14 وورقة بيضاء **دائماً** بحشوة 18 وظل
///   `0,2,8 rgba(0,0,0,0.15)` وحد أدنى ارتفاع 460 (معاينة مستند مطبوع).
/// - [SimDocOrgHeader]: اسم المنشأة عريضاً بحد سفلي مصمت 2px `#333333`.
/// - [SimDocTitleRow]: العنوان الكبير (يمين القراءة RTL) والرقم/التاريخ
///   بأقصى اليسار البصري (درس الطباعة العربية).
/// - [SimDocLogoBox]: صندوق الشعار 70×70 بخلفية `#ECEFF1` (لنموذج
///   الإيصال على خلفية التطبيق — داكن: رمادي منسجم).
/// - [SimDocBlueBar]: شريط رقم/تاريخ الإيصال الأزرق `#0288D1`.
/// - [SimDocItemsTable] + [SimDocTableCell]: جدول البنود برأس أزرق
///   وصفوف بحد `#EEEEEE` وأرقام LTR جدولية.
/// - [SimDocBlueTotalBar]: شريط «المبلغ الإجمالي» الأزرق.
/// - [SimDocRow]: صف ملخص مسافة-بين بحد `#CCCCCC` اختياري.
/// - [SimDocSignatureArea]: منطقة «يرجى الملاحظة / التوقيع» السفلية.
///
/// **قرار الألوان الموثق**: الورقة بيضاء في الوضعين معاً (مستند مطبوع)،
/// لذا ألوان *محتوى* المستند ثابتة صراحة (`#0288D1`/`#333333`/`#78909C`
/// …) ولا تتبع الثيم — تباينها مضمون فوق الأبيض دائماً. المتكيّف حصراً:
/// خلفية منطقة المعاينة الخارجية ([SimA4Sheet.pageBackgroundOf])، ومكوّنا
/// نموذج الإيصال اللذان يجلسان على خلفية التطبيق لا على الورقة
/// ([SimDocLogoBox]/[SimDocBlueBar] — بنمط `sim_list_widgets`).
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_typography.dart';

/// مواصفة عمود جدول المستندات — (label, flex) زوج تسمية/مرونة.
typedef SimDocColumnSpec = ({String label, int flex});

/// غلاف صفحة A4 — منطقة معاينة رمادية بورقة بيضاء مركزية (`.a4-preview-
/// wrapper` + `.a4-paper` بالنموذج الأولي). الورقة بيضاء في الوضعين
/// (مستند مطبوع) والنص الأساسي `#263238` بحجم 11.5sp.
class SimA4Sheet extends StatelessWidget {
  const SimA4Sheet({super.key, required this.child});

  /// محتوى الورقة (بنية المستند كاملة).
  final Widget child;

  /// خلفية منطقة المعاينة خلف الورقة — فاتح `#CFD8DC` / داكن أدكن سطح
  /// منسجم. عامة ليستعملها مستضيف المعاينة (منطقة التمرير) فتبقى منطقة
  /// A4 بلون واحد متصل فوق الورقة وتحتها.
  static Color pageBackgroundOf(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return scheme.brightness == Brightness.dark
        ? scheme.surfaceContainerLowest
        : const Color(0xFFCFD8DC);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: pageBackgroundOf(context),
      padding: const EdgeInsets.all(14),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 460),
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            // ظل الورقة بالنموذج: 0 2px 8px rgba(0,0,0,0.15).
            BoxShadow(
              offset: Offset(0, 2),
              blurRadius: 8,
              color: Color(0x26000000),
            ),
          ],
        ),
        // النص الأساسي للمستند — ثابت فوق الأبيض في الوضعين.
        child: DefaultTextStyle(
          style: const TextStyle(
            fontFamily: FinText.fontFamily,
            fontSize: 11.5,
            height: 1.45,
            color: Color(0xFF263238),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// ترويسة اسم المنشأة — عريضة ببداية القراءة (يمين RTL) وحد سفلي مصمت
/// 2px `#333333` وحشوة سفلية 8 وهامش سفلي 10 (`.a4-header` بالنموذج).
class SimDocOrgHeader extends StatelessWidget {
  const SimDocOrgHeader({super.key, required this.orgName});

  /// اسم المنشأة (ترويسة خطاب المستند).
  final String orgName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(width: 2, color: Color(0xFF333333))),
      ),
      child: Text(
        orgName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: FinText.fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF212121),
        ),
      ),
    );
  }
}

/// صف العنوان — **درس الطباعة العربية** (موثق بالنموذج الأولي
/// `a4-title-row`): العنوان الكبير «فاتورة» في أقصى اليمين (بداية
/// القراءة RTL) وعمود رقم المستند/التاريخ بأقصى اليسار البصري — في
/// Flutter RTL يظهر الابن الأول يميناً لذا **العنوان هو الابن الأول**.
class SimDocTitleRow extends StatelessWidget {
  const SimDocTitleRow({
    super.key,
    required this.docNo,
    required this.dateLabel,
    required this.title,
  });

  /// رقم المستند (INV-…) — أزرق `#0288D1` عريض 13sp أعلى العمود.
  final String docNo;

  /// التاريخ المعروض تحته — رمادي `#78909C` بحجم 11sp.
  final String dateLabel;

  /// العنوان الكبير (مثل «فاتورة») — عريض 18sp بأقصى اليمين.
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // الابن الأول في RTL = أقصى اليمين: العنوان الكبير.
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: FinText.fontFamily,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF212121),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // نهاية الصف = أقصى اليسار البصري: رقم المستند فوق التاريخ.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                docNo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: FinText.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0288D1),
                  fontFeatures: FinText.tabularNums,
                ),
              ),
              Text(
                dateLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: FinText.fontFamily,
                  fontSize: 11,
                  color: Color(0xFF78909C),
                  fontFeatures: FinText.tabularNums,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// صندوق الشعار 70×70 — خلفية `#ECEFF1` بنصف قطر 8 وحرف أول عريض
/// `#546E7A` بحجم 26sp عند غياب الصورة (ترويسة نموذج الإيصال بالنموذج
/// الأولي — يجلس على خلفية التطبيق لا على الورقة، لذا نسخته الداكنة
/// رمادي منسجم بنمط sim_list_widgets).
class SimDocLogoBox extends StatelessWidget {
  const SimDocLogoBox({super.key, this.logoPng, required this.fallbackInitial});

  /// bytes شعار المنشأة (company.logoPng) — null يعرض الحرف الأول.
  final Uint8List? logoPng;

  /// الحرف الأول من اسم المنشأة (احتياط غياب الشعار).
  final String fallbackInitial;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    return Container(
      width: 70,
      height: 70,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerHigh : const Color(0xFFECEFF1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: logoPng != null
          ? Image.memory(logoPng!, fit: BoxFit.contain, gaplessPlayback: true)
          : Text(
              fallbackInitial,
              style: TextStyle(
                fontFamily: FinText.fontFamily,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? scheme.onSurfaceVariant
                    : const Color(0xFF546E7A),
              ),
            ),
    );
  }
}

/// شريط رقم/تاريخ الإيصال الأزرق (`.screen-receipt` بالنموذج الأولي) —
/// `#0288D1` بنص أبيض عريض 14sp وحشوة 10/14: رقم المستند يميناً (أول
/// ابن في RTL) والتاريخ يساراً مع أيقونة تقويم صغيرة 14px. يجلس على
/// خلفية التطبيق (نموذج الإيصال) فنسخته الداكنة دلالية بنمط sim_list.
class SimDocBlueBar extends StatelessWidget {
  const SimDocBlueBar({
    super.key,
    required this.docNo,
    required this.dateLabel,
  });

  /// رقم المستند (RECPT…) — يمين الشريط.
  final String docNo;

  /// التاريخ المعروض — يسار الشريط مع أيقونة التقويم.
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final background = isDark ? scheme.primary : const Color(0xFF0288D1);
    final foreground = isDark ? scheme.onPrimary : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: background,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              docNo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: FinText.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: foreground,
                fontFeatures: FinText.tabularNums,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today_outlined, size: 14, color: foreground),
              const SizedBox(width: 6),
              Text(
                dateLabel,
                style: TextStyle(
                  fontFamily: FinText.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                  fontFeatures: FinText.tabularNums,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// خلية جدول المستندات — نص (أو [child] مخصص مثل سطر «مجاني: N» تحت
/// اسم المنتج). [isNumeric] يلف النص بـ LTR (Directionality.ltr) بأرقام
/// جدولية محاذاةً لبداية LTR — نمط `AmountText`/DS-18n نفسه. [flex]
/// يتجاوز مرونة عموده عند الحاجة.
class SimDocTableCell extends StatelessWidget {
  const SimDocTableCell({
    super.key,
    this.text = '',
    this.isNumeric = false,
    this.flex,
    this.child,
  });

  /// نص الخلية (يُتجاهل عند تمرير [child] — اختياري لهذا).
  final String text;

  /// خلية رقمية؟ (LTR + أرقام جدولية + محاذاة بداية LTR).
  final bool isNumeric;

  /// مرونة الخلية عند تجاوز مرونة العمود (اختياري).
  final int? flex;

  /// محتوى مخصص بديل للنص (اختياري).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      // حد أدنى ارتفاع صريح للصف (`.a4-table td` — خلايا 10sp).
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      alignment: AlignmentDirectional.centerStart,
      child:
          child ??
          Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: FinText.fontFamily,
              fontSize: 10,
              color: const Color(0xFF37474F),
              fontFeatures: isNumeric ? FinText.tabularNums : null,
            ),
          ),
    );
    // الأرقام LTR دائماً (يحتضن المحاذاة نفسها فتحل لبداية LTR).
    return isNumeric
        ? Directionality(textDirection: TextDirection.ltr, child: body)
        : body;
  }
}

/// جدول بنود المستند (`.a4-table`) — رأس أزرق `#0288D1` بنص أبيض 10sp
/// (خلايا بحشوة 5) وصفوف بحد سفلي 1px `#EEEEEE`. الأعمدة قائمة أزواج
/// (label, flex) والصفوف قوائم خلايا [SimDocTableCell].
class SimDocItemsTable extends StatelessWidget {
  const SimDocItemsTable({
    super.key,
    required this.columns,
    required this.rows,
  });

  /// أعمدة الجدول (تسمية + مرونة) بترتيب القراءة RTL.
  final List<SimDocColumnSpec> columns;

  /// صفوف الجدول — كل صف قائمة خلايا بطول الأعمدة.
  final List<List<SimDocTableCell>> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // الرأس الأزرق.
        Container(
          color: const Color(0xFF0288D1),
          child: Row(
            children: [
              for (final column in columns)
                Expanded(
                  flex: column.flex,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 26),
                    padding: const EdgeInsets.all(5),
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      column.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: FinText.fontFamily,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // الصفوف — حد سفلي رقيق لكل صف.
        for (final row in rows)
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < row.length; i++)
                  Expanded(
                    flex: i < columns.length
                        ? (row[i].flex ?? columns[i].flex)
                        : (row[i].flex ?? 1),
                    child: row[i],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// شريط «المبلغ الإجمالي» الأزرق (a4 — `background:#0288D1;color:#fff;
/// padding:5px 8px;font-weight:700`): التسمية يميناً والمبلغ يساراً LTR
/// بأرقام جدولية. على الورقة البيضاء فألوانه ثابتة في الوضعين.
class SimDocBlueTotalBar extends StatelessWidget {
  const SimDocBlueTotalBar({
    super.key,
    required this.label,
    required this.amountLabel,
  });

  /// التسمية (مثل «المبلغ الإجمالي») — يمين الشريط.
  final String label;

  /// المبلغ المنسَّق (LTR — قد يحمل رمز العملة).
  final String amountLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0288D1),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: FinText.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              amountLabel,
              style: const TextStyle(
                fontFamily: FinText.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFeatures: FinText.tabularNums,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// صف ملخص مسافة-بين (مثل «الخصم»/«توازن») — التسمية يميناً والقيمة
/// يساراً (LTR جدولية عند [isNumeric]) بحد سفلي `#CCCCCC` اختياري وحشوة
/// 5/8 كالنموذج الأولي.
class SimDocRow extends StatelessWidget {
  const SimDocRow({
    super.key,
    required this.label,
    required this.value,
    this.bold = false,
    this.showDivider = false,
    this.isNumeric = false,
  });

  /// التسمية — يمين الصف.
  final String label;

  /// القيمة المنسَّقة — يسار الصف.
  final String value;

  /// عريض؟ (صف «توازن» عريض بالنموذج).
  final bool bold;

  /// حد سفلي `#CCCCCC`؟ (توازن يحمله؛ الخصم لا).
  final bool showDivider;

  /// قيمة رقمية؟ (LTR + أرقام جدولية).
  final bool isNumeric;

  @override
  Widget build(BuildContext context) {
    final valueText = Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: FinText.fontFamily,
        fontSize: 11.5,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        color: const Color(0xFF263238),
        fontFeatures: isNumeric ? FinText.tabularNums : null,
      ),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: showDivider
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFCCCCCC))),
            )
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: FinText.fontFamily,
                fontSize: 11.5,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: const Color(0xFF263238),
              ),
            ),
          ),
          isNumeric
              ? Directionality(
                  textDirection: TextDirection.ltr,
                  child: valueText,
                )
              : valueText,
        ],
      ),
    );
  }
}

/// منطقة الملاحظات/التوقيع السفلية (a4 — `margin-top:24px` بمسافة بين
/// «يرجى الملاحظة:» يميناً وعمود [التوقيع + الاسم] يساراً). **لا زر
/// إضافة توقيع** — مُرحَّل بقرار موثق (النموذج يعرض توقيعاً مرسوماً
/// مسبقاً ونطاق المسودة الحية بلا توقيع مخزَّن).
class SimDocSignatureArea extends StatelessWidget {
  const SimDocSignatureArea({
    super.key,
    required this.notesLabel,
    required this.signatureLabel,
    required this.signerName,
  });

  /// تسمية الملاحظات (مثل «يرجى الملاحظة:») — يمين المنطقة.
  final String notesLabel;

  /// تسمية التوقيع (مثل «التوقيع:») — أعلى عمود اليسار.
  final String signatureLabel;

  /// اسم الموقِّع (العميل عادة) — رمادي تحت التسمية.
  final String signerName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Text(
              notesLabel,
              style: const TextStyle(
                fontFamily: FinText.fontFamily,
                fontSize: 11.5,
                color: Color(0xFF263238),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // نهاية الصف (أقصى اليسار البصري) — محاذاة الطرف الأيسر
          // كتسمية text-align:left بالنموذج الأولي.
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                signatureLabel,
                style: const TextStyle(
                  fontFamily: FinText.fontFamily,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF263238),
                ),
              ),
              Text(
                signerName,
                style: const TextStyle(
                  fontFamily: FinText.fontFamily,
                  fontSize: 11.5,
                  color: Color(0xFF78909C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
