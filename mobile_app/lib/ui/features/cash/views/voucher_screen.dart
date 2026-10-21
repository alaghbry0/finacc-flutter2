/// شاشة سند القبض/الصرف بهوية Simple Invoice Manager (V6-C — FR-04-02/03/10):
/// مسار `/cash/voucher/:type` بترويسة فرعية (رجوع محروس + «سند قبض/صرف»)
/// تحتها تبويبان بأسلوب النموذج الأولي `screen-receipt`: **«إيصال/سند»**
/// (نموذج الإدخال الوظيفي الكامل: منتقي طرف ببحث + مبلغ وعملة + صندوق
/// وتاريخ + تخصيص FIFO/على الحساب + ملاحظات) و**«معاينة»** (مستند
/// قراءة فقط من المسودة الحية بورقة A4: شعار + اسم المنشأة + الشريط
/// الأزرق بمعاينة رقم RVT/PMT القادم + «تسلم من:/دفع إلى:» والمبلغ +
/// نص الشكر + مراجع الفواتير أو «على الحساب» + سطر التفقيط العربي +
/// منطقة التوقيع). تحته شريط إجراءات SIM ثلاثي (حفظ = الترحيل،
/// وإرسال/طباعة = معاينة PDF مسودة موسومة) يعرض رفض الترحيل فوقه.
///
/// ## قرارات V6-C الموثقة
/// - **تبديل شرطي `if` لا IndexedStack** (نمط V6-B بالبيع): شجرة تبويب
///   واحد فقط كل لحظة — لا ازدواج نصوص بين الوضعين.
/// - الافتراضي تبويب النموذج («إيصال») — المستخدم يملأ ثم يطّلع.
/// - العنوان الفرعي القديم تحت AppBar سقط مع انتقال هوية SIM إلى
///   الترويسة الفرعية أحادية السطر (نمط screen-receipt/sub-header).
/// - صف «تسلم من:/دفع إلى: + المبلغ» رسم خاص داخل المعاينة (لا
///   `SimDocRow`): خطوطه الثابتة 11.5sp لا تعبّر عن بنية النموذج الأولي
///   (تسمية عادية + اسم عريض يميناً، ومبلغ 16sp عريض LTR جدولي يساراً
///   بحد سفلي `#EEEEEE`) — مكون خاص داخل هذا الملف حصراً.
/// - منطق FIFO والعملات والبوابة والعجلة في النموذج — الشاشة عرض
///   وإدخال حصراً، وسلوك ما بعد الترحيل (SnackBar برقم السند + عودة
///   `/cash`) باقٍ حرفياً.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/company.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/dirty_form_guard.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/sim_doc_widgets.dart';
import '../../../core/widgets/sim_list_widgets.dart';
import '../view_models/voucher_view_model.dart';
import 'widgets/cash_widgets.dart';
import 'widgets/voucher_allocation_card.dart';
import 'widgets/voucher_amount_card.dart';
import 'widgets/voucher_draft_pdf.dart';
import 'widgets/voucher_party_card.dart';
import 'widgets/voucher_party_picker_sheet.dart';

/// حارس التأريخ الرجعي (UX-2a — `dating.max_backdate_days`): أقدم تاريخ
/// يسمح به منتقي تاريخ السند = `now − الحد` (حد 0 أو سالب = اليوم فقط).
/// كان المنتقي يقبل سنتين رجعياً بلا أي سقف من الإعدادات.
///
/// (علنية لتُختبر مباشرة — نفس نمط sellFormatDate بالوحدة.)
DateTime voucherBackdateLowerBound(DateTime now, int maxBackdateDays) {
  if (maxBackdateDays <= 0) return now;
  return now.subtract(Duration(days: maxBackdateDays));
}

/// شاشة السند — `type` من المسار: `receipt` (قبض من عميل) أو `payment`
/// (صرف لمورد؛ أي قيمة أخرى تُعامل صرفاً).
class VoucherScreen extends StatelessWidget {
  const VoucherScreen({super.key, required this.isReceipt});

  final bool isReceipt;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final VoucherViewModel vm;
    vm = VoucherViewModel(
      cashRepo: app.cash!,
      customerRepo: app.customers!,
      supplierRepo: app.suppliers!,
      fxRepo: app.fxRates!,
      companyRepo: app.companies!,
      isReceipt: isReceipt,
    );
    unawaited(vm.load());
    return ChangeNotifierProvider<VoucherViewModel>.value(
      value: vm,
      child: const _VoucherScreenBody(),
    );
  }
}

class _VoucherScreenBody extends StatefulWidget {
  const _VoucherScreenBody();

  @override
  State<_VoucherScreenBody> createState() => _VoucherScreenBodyState();
}

class _VoucherScreenBodyState extends State<_VoucherScreenBody> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  /// V6-C — تبويب الوضع النشط: 0 = النموذج («إيصال/سند»)، 1 = المعاينة.
  /// الافتراضي النموذج — المستخدم يملأ ثم يطّلع على المستند.
  int _modeTab = 0;

  /// لقطة ما بعد التحميل — حماية «التغييرات غير المحفوظة» (P1-4).
  bool _baselineReady = false;
  double? _bAmount;
  String _bNotes = '';
  int? _bPartyId;
  int? _bBoxId;
  int? _bCurrencyId;
  DateTime _bDate = DateTime.now();
  bool _bFifo = true;

  /// يلتقط لقطة الحالة الأولى القابلة للتحرير (مرة واحدة بعد التحميل).
  void _captureBaseline(VoucherViewModel vm) {
    if (_baselineReady || vm.loading || vm.error != null) return;
    _baselineReady = true;
    _bAmount = vm.amount;
    _bNotes = vm.notes;
    _bPartyId = vm.partyId;
    _bBoxId = vm.boxId;
    _bCurrencyId = vm.voucherCurrencyId;
    _bDate = vm.txDate;
    _bFifo = vm.allocateFifo;
  }

  /// هل في السند تغييرات غير محفوظة؟
  bool _isDirty(VoucherViewModel vm) {
    if (!_baselineReady) return false;
    return vm.amount != _bAmount ||
        vm.notes != _bNotes ||
        vm.partyId != _bPartyId ||
        vm.boxId != _bBoxId ||
        vm.voucherCurrencyId != _bCurrencyId ||
        vm.txDate != _bDate ||
        vm.allocateFifo != _bFifo;
  }

  /// رجوع محروس: زر الرجوع الصريح (go) يمر بنفس حوار الحماية (P1-4).
  Future<void> _guardedBack(VoucherViewModel vm) async {
    if (_isDirty(vm) && !await confirmDiscardChanges(context)) {
      return;
    }
    if (mounted) context.go('/cash');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(VoucherViewModel vm) async {
    // UX-2a — حارس التأريخ الرجعي: سقف الرجوع من الإعدادات
    // (`dating.max_backdate_days`، افتراضي 30 يوماً) بدل سنتين مفتوحتين.
    final settings = context.read<AppController>().settings;
    final maxDays = settings == null ? 30 : await settings.maxBackdateDays();
    if (!mounted) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.txDate,
      firstDate: voucherBackdateLowerBound(now, maxDays),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (picked != null) {
      vm.setDate(picked);
    }
  }

  Future<void> _openPartyPicker(VoucherViewModel vm) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => VoucherPartyPickerSheet(vm: vm),
    );
  }

  Future<void> _post(VoucherViewModel vm) async {
    // بوابة سعر اليوم لعملة السند غير الأساس (FR-08-09).
    if (vm.voucherRateMissing) {
      final saved = await showCashFxGateSheet(
        context,
        currencyCode: vm.voucherCurrencyCode ?? '',
        onSave: vm.saveTodayRate,
      );
      if (!saved || !mounted) return;
    }
    final result = await vm.save();
    if (!mounted) return;
    if (result.isOk) {
      final receipt = result.valueOrNull!;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              l10n.cashVoucherPostedSnackBar(
                receipt.voucherNo,
                AmountText.format(receipt.amount, 2),
                receipt.currencyCode,
              ),
            ),
          ),
        );
      // العودة للمحور — RefreshOnActive (^/cash$) يعيد تحميل الأرصدة حياً.
      context.go('/cash');
    }
    // الرفض → vm.saveError تُعرض فوق شريط الإجراءات.
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VoucherViewModel>();
    _captureBaseline(vm);

    // حماية التغييرات غير المحفوظة (P1-4): الرجوع المباشر (النظام/الزر)
    // يعرض حوار «مغادرة/بقاء».
    return DirtyFormGuard(
      isDirty: _isDirty(vm),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: _buildBody(context, vm),
      ),
    );
  }

  /// جسم الشاشة: ترويسة فرعية + تبويبات النمط ثم الجسم المتحول
  /// (تحميل ← خطأ ← النموذج/المعاينة) ثم منطقة الحالة فوق شريط
  /// الإجراءات — نفس دلالة السلاسل المتداخلة الأصلية حرفياً.
  Widget _buildBody(BuildContext context, VoucherViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      bottom: false,
      child: Column(
        children: [
          SimSubHeader(
            title: vm.isReceipt
                ? l10n.cashVoucherReceiptTitle
                : l10n.cashVoucherPaymentTitle,
            onBack: () => unawaited(_guardedBack(vm)),
          ),
          SimModeTabs(
            tabs: [
              SimModeTabSpec(
                label: vm.isReceipt
                    ? l10n.simRcptDocTabReceipt
                    : l10n.simRcptDocTabPayment,
                onTap: () {
                  if (_modeTab != 0) setState(() => _modeTab = 0);
                },
              ),
              SimModeTabSpec(
                label: l10n.simModeTabPreview,
                onTap: () {
                  if (_modeTab != 1) setState(() => _modeTab = 1);
                },
              ),
            ],
            selectedIndex: _modeTab,
          ),
          // تبديل شرطي `if` (لا IndexedStack) — شجرة تبويب واحد فقط
          // كل لحظة (نمط V6-B): النموذج الوظيفي أو مستند المعاينة.
          Expanded(
            child: vm.loading
                ? _buildLoading()
                : vm.error != null
                ? _buildError(context, vm)
                : _modeTab == 0
                ? _buildForm(context, vm)
                : _VoucherReceiptPreview(vm: vm),
          ),
          // منطقة الحالة فوق الشريط: رفض الترحيل (يبقى ظاهراً) وعجلة
          // الترحيل الجارية — إرث VoucherBottomPostBar بنمط صف رقيق.
          if (vm.saveError != null) _SaveErrorStrip(message: vm.saveError!),
          if (vm.saving) const _SavingStrip(),
          SimBottomActionBar(
            items: [
              SimBottomActionItem(
                icon: Icons.save_rounded,
                label: l10n.simActionSave,
                onTap: () => unawaited(_post(vm)),
                enabled: !vm.saving,
                primary: true,
              ),
              SimBottomActionItem(
                icon: Icons.send_rounded,
                label: l10n.simRcptSendAction,
                onTap: () => openVoucherDraftPdfPreview(context, vm),
                enabled: !vm.saving,
              ),
              SimBottomActionItem(
                icon: Icons.print_rounded,
                label: l10n.simRcptPrintAction,
                onTap: () => openVoucherDraftPdfPreview(context, vm),
                enabled: !vm.saving,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: const [ListSkeleton()],
    );
  }

  Widget _buildError(BuildContext context, VoucherViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        ErrorState(
          title: l10n.genericErrorTitle,
          message: l10n.dbOpenErrorMessage,
          technicalDetails: vm.error.toString(),
          retryLabel: l10n.commonRetry,
          onRetry: vm.load,
          compact: true,
        ),
      ],
    );
  }

  /// تبويب النموذج («إيصال/سند») — كل بطاقات V-6 القائمة حرفياً.
  Widget _buildForm(BuildContext context, VoucherViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      children: [
        VoucherPartyCard(vm: vm, onPick: () => unawaited(_openPartyPicker(vm))),
        const SizedBox(height: 12),
        VoucherAmountCurrencyCard(vm: vm, controller: _amountController),
        const SizedBox(height: 12),
        VoucherBoxDateCard(vm: vm, onPickDate: () => unawaited(_pickDate(vm))),
        if (vm.partyId != null) ...[
          const SizedBox(height: 12),
          VoucherAllocationCard(vm: vm),
        ],
        if (vm.isCrossCurrency && vm.projectedBoxDeposit != null) ...[
          const SizedBox(height: 12),
          VoucherCrossCurrencyNote(vm: vm),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          enabled: !vm.saving,
          maxLines: 2,
          maxLength: 200,
          onChanged: vm.setNotes,
          decoration: InputDecoration(
            labelText: l10n.cashVoucherNotesLabel,
            helperText: l10n.cashVoucherNotesHint,
            prefixIcon: const Icon(Icons.notes_rounded),
          ),
        ),
      ],
    );
  }
}

/// صف رفض الترحيل الرقيق فوق شريط الإجراءات — إرث منطق عرض الخطأ من
/// `VoucherBottomPostBar` القديم (أيقونة + رسالة بالسلبية) على سطح
/// الشريط نفسه؛ لا يُخسر عرض الخطأ أبداً مع هوية SIM الجديدة.
class _SaveErrorStrip extends StatelessWidget {
  const _SaveErrorStrip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return Container(
      width: double.infinity,
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: colors.negative),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.negative,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// شريط عجلة الترحيل الرقيق (بدل عجلة زر الترحيل الضخم القديم) —
/// مؤشر خطي غير محدد فوق شريط الإجراءات أثناء `saving` (زر الحفظ معطل
/// بالتوازي — `SimBottomActionItem` لا يقبل عنصر عجلة).
class _SavingStrip extends StatelessWidget {
  const _SavingStrip();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: const LinearProgressIndicator(minHeight: 3),
    );
  }
}

/// مستند معاينة السند (تبويب «معاينة») — ورقة A4 من المسودة الحية
/// بترتيب `screen-receipt` بالنموذج الأولي حرفياً: صف الرأس (شعار يمين
/// + اسم المنشأة) ← الشريط الأزرق (معاينة رقم السند + التاريخ) ← صف
/// «تسلم من:/دفع إلى:» بالمبلغ 16sp ← نص الشكر ← مراجع الفواتير (أو
/// «على الحساب») ← سطر التفقيط ← منطقة التوقيع.
///
/// **قارئ فقط** — يُبنى من الحالة الحية فيكل إطار فيتحدث فورياً مع كل
/// تعديل بالنموذج؛ لا يلمس النموذج إطلاقاً.
class _VoucherReceiptPreview extends StatelessWidget {
  const _VoucherReceiptPreview({required this.vm});

  final VoucherViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final Company? company = context.read<AppController>().company;
    final currency = vm.voucherCurrency;
    final decimals = vm.voucherDecimals;
    final orgName = company?.name ?? '';
    final plan = vm.previewPlan;

    // المبلغ: المدخل أو 0 بمنازل عملة السند (مسودة صادقة) + الرمز —
    // `formatFor` (لا `format`) توحيداً مع معاينة فاتورة V6-B: إعداد
    // الأرقام الشرقية (display.numerals) يسري على المستندين معاً.
    final amountLabel = AmountText.formatFor(context, vm.amount ?? 0, decimals);
    final currencyCode = currency?.code ?? vm.voucherCurrencyCode ?? '';
    final amountWithCode = currencyCode.isEmpty
        ? amountLabel
        : '$amountLabel $currencyCode';

    // سطر التفقيط — قارئ النموذج (مراجعة 🟡-3): مصدر واحد مع مسودة
    // PDF؛ حارس السقف (🔴-1) داخل القارئ (لصق رقم ضخم فوق
    // 999,999,999,999.99 أو سالب/غير منته → يُتخطى السطر بلا كذب —
    // الرقم ظاهر أعلاه أصلاً)، والفراغ يُفلق «صفر … فقط» صادقاً.
    final words = vm.amountWords;

    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: SimA4Sheet(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // صف الرأس: الشعار يميناً (أول ابن RTL) واسم المنشأة
                // عريضاً 15sp — justify-between بالنموذج الأولي.
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      SimDocLogoBox(
                        logoPng: company?.logoPng,
                        fallbackInitial: orgName.trim().isEmpty
                            ? '؟'
                            : orgName.trim().characters.first,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          orgName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: FinText.fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF263238),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // الشريط الأزرق: معاينة رقم السند القادم (لا استهلاك)
                // والتاريخ بتاريخ السند نفسه.
                SimDocBlueBar(
                  docNo: vm.previewVoucherNo ?? 'RVT/PMT',
                  dateLabel: cashFormatDate(vm.txDate),
                ),
                const SizedBox(height: 14),
                // صف الطرف والمبلغ — حد سفلي #EEEEEE كالنموذج.
                _PartyAmountRow(
                  label: vm.isReceipt
                      ? l10n.simRcptReceivedFrom
                      : l10n.simRcptPaidTo,
                  partyName: vm.partyName,
                  amountLabel: amountWithCode,
                ),
                // كتلة النصوص: الشكر + مراجع الفواتير + التفقيط.
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vm.isReceipt
                            ? l10n.simRcptThanksReceipt
                            : l10n.simRcptThanksPayment,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF455A64),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.simRcptAgainstInvoices,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF455A64),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // القسم لا يُحذف أبداً (يمنع قفز التخطيط): تخصيصات
                      // FIFO فعلاً، أو سطر «على الحساب» الصادق البديل عند
                      // إيقاف FIFO / لا فواتير مفتوحة / لا خطة بعد.
                      if (plan.isEmpty)
                        Text(
                          l10n.simRcptOnAccount,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF455A64),
                          ),
                        )
                      else
                        for (var i = 0; i < plan.length; i++)
                          _InvoiceRefLine(
                            number: i + 1,
                            invoiceNo: plan[i].invoiceNo,
                            amountLabel: AmountText.format(
                              plan[i].amount,
                              decimals,
                            ),
                          ),
                      if (words != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${l10n.simRcptWordsPrefix} $words',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF455A64),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SimDocSignatureArea(
                  notesLabel: vm.notes.trim().isEmpty
                      ? l10n.cashVoucherNotesLabel
                      : vm.notes.trim(),
                  signatureLabel: l10n.printingLblSignature,
                  signerName: vm.partyName ?? '—',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// صف «تسلم من:/دفع إلى: + المبلغ» — بنية النموذج الأولي حرفياً
/// (`.screen-receipt` 1123-1126): تسمية عادية واسم الطرف عريض يميناً،
/// والمبلغ 16sp عريض LTR جدولي بعملة السند يساراً، بحد سفلي `#EEEEEE`
/// وحشوة عمودية 10. (رسم خاص — انظر قرارات V6-C برأس المكتبة.)
class _PartyAmountRow extends StatelessWidget {
  const _PartyAmountRow({
    required this.label,
    required this.partyName,
    required this.amountLabel,
  });

  final String label;

  /// اسم الطرف المختار (null = شرطة احتياطية للمسودة الفارغة).
  final String? partyName;

  /// المبلغ المنسَّق بعملة السند (LTR).
  final String amountLabel;

  @override
  Widget build(BuildContext context) {
    final name = partyName?.trim() ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          Flexible(
            child: Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: FinText.fontFamily,
                    fontSize: 12,
                    color: Color(0xFF263238),
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    name.isEmpty ? '—' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: FinText.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF263238),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // مبلغ طويل (لصق رقم ضخم مثلاً) لا يفيض: Flexible +
          // scaleDown يقيسه كاملاً للعرض المتاح بدل اقتصاصه — كل
          // الخانات تبقى مقروءة في مستند مالي (كشفه اختبار الحارس ١١).
          Flexible(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  amountLabel,
                  maxLines: 1,
                  style: const TextStyle(
                    fontFamily: FinText.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF263238),
                    fontFeatures: FinText.tabularNums,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// سطر مرجع فاتورة واحد بالتخصيص — «N. INV-2026-00012  500.00» LTR
/// بأرقام جدولية (الرقم التسلسلي + رقم الفاتورة + المخصص).
class _InvoiceRefLine extends StatelessWidget {
  const _InvoiceRefLine({
    required this.number,
    required this.invoiceNo,
    required this.amountLabel,
  });

  final int number;
  final String invoiceNo;
  final String amountLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$number. $invoiceNo',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: FinText.fontFamily,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF37474F),
                fontFeatures: FinText.tabularNums,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              amountLabel,
              style: const TextStyle(
                fontFamily: FinText.fontFamily,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF37474F),
                fontFeatures: FinText.tabularNums,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
