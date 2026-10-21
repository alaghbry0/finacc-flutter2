/// معاينة A4 لفاتورة البيع من المسودة الحية (V6-B) — بنية مطابقة لدالة
/// `renderA4Preview` بالنموذج الأولي `upload/invoice-manager.html`
/// (1967–2027) عبر مكوّنات `sim_doc_widgets.dart`:
///
/// ورقة A4 ← ترويسة المنشأة ← صف العنوان (فاتورة/رقم/تاريخ) ← «فاتورة
/// إلى:» (اسم العميل/هاتفه — **بلا صف شحن ship-to**: نطاقنا بلا شحن،
/// انحراف موثق) ← جدول البنود (رقم/المنتج/كمية/معدل/المبلغ — **تصحيح
/// العمود الخامس**: النموذج الأصلي يكرر «كمية» خطأً مطبعياً) ← صف الخصم
/// عند وجوده ← شريط «المبلغ الإجمالي» الأزرق (grandTotal الصافي بعد
/// الخصومات لا subtotal — Σ netFinal = grandTotal فيتساقس الجدول مع
/// الشريط) ← صف «توازن» (= المجموع الصافي؛ لا دفع في المسودة فيُحذف صف
/// «دفعت» بنمط النموذج نفسه الذي يخفيه عند paid=0) ← منطقة الملاحظات
/// والتوقيع (بلا زر إضافة توقيع — مُرحَّل بقرار موثق).
///
/// **قارئة فقط**: لا تلمس السلة/الدفع/pricedCart — تبني عرضها من القيم
/// الممرَّرة لحظة البناء. أسماء المنتجات تُقرأ من أسطر السلة الحية
/// (`SellCartViewModel.state.lines` — `CartUiLine.name`) بمحاذاة الفهرس
/// مع أسطر `pricedCart` لأن `PricedCartLine` الخالص لا يحمل اسماً
/// (النطاق غير قابل للتعديل — وكيل آخر) — قراءة صرفة بلا أي أثر.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/sim_doc_widgets.dart';
import '../../../../../domain/models/sale.dart';
import '../../view_models/sell_cart_view_model.dart';
import 'sell_format.dart';

/// معاينة A4 لفاتورة البيع — من مسودة الكاشير الحية (بلا قاعدة بيانات).
class SimInvoiceA4Preview extends StatelessWidget {
  const SimInvoiceA4Preview({
    super.key,
    required this.invoiceNo,
    required this.customer,
    required this.pricedCart,
    required this.companyName,
    required this.currencyCode,
    required this.decimals,
  });

  /// رقم الفاتورة القادم (INV-… — معاينة الترقيم قبل الترحيل).
  final String invoiceNo;

  /// عميل السلة (null = عميل نقدي مجهول).
  final CartCustomer? customer;

  /// السلة المُسعَّرة الحية (null = سلة فارغة → حالة فراغ صادقة).
  final PricedCart? pricedCart;

  /// اسم المنشأة (ترويسة المستند).
  final String companyName;

  /// رمز عملة الفاتورة (يُعرض بجانب المبلغ الإجمالي الرئيسي — null يخفيه).
  final String? currencyCode;

  /// منازل عرض المبالغ (نمط `_decimalsFor` بالقائمة).
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cart = pricedCart;
    final totals = cart?.totals;
    final grandTotal = totals?.grandTotal ?? 0;
    final totalDiscount = totals?.totalDiscount ?? 0;

    // اسم العميل الفعلي — «عميل نقدي» عند الغياب أو العميل المجهول.
    final customerName = customer?.id != null
        ? customer!.name
        : l10n.sellCashCustomer;

    String fmt(double value) => AmountText.formatFor(context, value, decimals);

    // رمز العملة بجانب المبلغ الرئيسي (شريط الإجمالي الأزرق) — صفوف
    // «توازن»/«الخصم» وخلايا الجدول بالمبلغ المجرد كالنموذج الأولي.
    final totalLabel = currencyCode == null
        ? fmt(grandTotal)
        : '${fmt(grandTotal)} $currencyCode';

    return SimA4Sheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SimDocOrgHeader(orgName: companyName),
          SimDocTitleRow(
            docNo: invoiceNo,
            dateLabel: sellFormatDate(DateTime.now()),
            title: l10n.simA4InvoiceTitle,
          ),
          // «فاتورة إلى:» — عمود يمين بحد علوي (border-top #eee +
          // padding-top:8 + margin-bottom:10 بالنموذج) بلا صف شحن.
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.simA4BillTo,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF263238),
                  ),
                ),
                Text(customerName),
                if (customer?.phone != null && customer!.phone!.isNotEmpty)
                  Text(customer!.phone!),
              ],
            ),
          ),
          // جدول البنود — أو حالة فراغ صادقة عند سلة فارغة.
          if (cart == null || cart.lines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                l10n.simA4EmptyItems,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF78909C),
                ),
              ),
            )
          else
            SimDocItemsTable(
              columns: [
                (label: l10n.simA4ColNo, flex: 1),
                (label: l10n.simA4ColProduct, flex: 3),
                (label: l10n.simA4ColQty, flex: 2),
                (label: l10n.simA4ColRate, flex: 2),
                (label: l10n.simA4ColAmount, flex: 2),
              ],
              rows: [
                for (var i = 0; i < cart.lines.length; i++)
                  _buildRow(context, l10n, cart.lines[i], i),
              ],
            ),
          // صف الخصم — حصراً عند خصم فعلي (أسطر + رأس).
          if (totalDiscount > 0)
            SimDocRow(
              label: l10n.simA4DiscountRowLabel,
              value: '−${fmt(totalDiscount)}',
              isNumeric: true,
            ),
          // المبلغ الإجمالي — الصافي بعد الخصومات (لا subtotal).
          SimDocBlueTotalBar(
            label: l10n.simA4TotalLabel,
            amountLabel: totalLabel,
          ),
          // «توازن» = المجموع الصافي (لا دفع في المسودة الحية).
          SimDocRow(
            label: l10n.simA4BalanceLabel,
            value: fmt(grandTotal),
            isNumeric: true,
            bold: true,
            showDivider: true,
          ),
          SimDocSignatureArea(
            notesLabel: l10n.simA4NotesLabel,
            signatureLabel: l10n.simA4SignatureLabel,
            signerName: customerName,
          ),
        ],
      ),
    );
  }

  /// صف جدول واحد — الرقم/المنتج (مع سطر المجانية تحته)/الكمية/معدل/
  /// المبلغ (netFinal الصافي الفعلي).
  List<SimDocTableCell> _buildRow(
    BuildContext context,
    AppLocalizations l10n,
    PricedCartLine line,
    int index,
  ) {
    // الاسم من سطر الواجهة بمحاذاة الفهرس (PricedCartLine بلا اسم).
    final uiLines = context.read<SellCartViewModel>().state.lines;
    final name = index < uiLines.length ? uiLines[index].name : '—';
    String qtyLabel(double qty) => AmountText.formatFor(
      context,
      qty,
      qty == qty.truncateToDouble() ? 0 : 3,
    );
    return [
      SimDocTableCell(text: '${index + 1}', isNumeric: true),
      SimDocTableCell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF37474F),
              ),
            ),
            // «مجاني: N» تحت الاسم — 9sp أخضر teal كالنموذج (small).
            if (line.line.freeQty > 0)
              Text(
                '${l10n.simA4FreeLabel} ${qtyLabel(line.line.freeQty)}',
                style: const TextStyle(fontSize: 9, color: Color(0xFF26A69A)),
              ),
          ],
        ),
      ),
      SimDocTableCell(text: qtyLabel(line.line.qty), isNumeric: true),
      SimDocTableCell(
        text: AmountText.formatFor(context, line.line.unitPrice, decimals),
        isNumeric: true,
      ),
      SimDocTableCell(
        text: AmountText.formatFor(context, line.netFinal, decimals),
        isNumeric: true,
      ),
    ];
  }
}
