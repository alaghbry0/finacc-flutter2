/// شاشة الجرد الفعلي (FR-01-08 + AC-04 — الشريحة 10): كشف عدّ للمخزن
/// المحدد — لكل صنف رصيد دفتري + لقطة تكلفة + حقل الرصيد الفعلي مع
/// رقاقة «＝ الدفتري» وشارة فرق ملوّنة (زيادة/عجز/مطابق)، وشريط سفلي
/// ثابت بالملخص الحي (المعدود/الزيادة/العجز/الصافي) وزر «اعتماد الجرد»
/// يفتح نافذة مراجعة للفروقات فقط (كمية + قيمة بتكلفة اللقطة + تحذير
/// قفل الأرصدة) ثم حوار نجاح. قسم سجل عمليات الجرد أسفل الكشف.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/stocktake_repository.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/fin_search_field.dart';
import '../../../core/widgets/hub_hero_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/refresh_on_active.dart';
import '../../../core/widgets/status_chip.dart';
import '../view_models/stocktake_session.dart';
import '../view_models/stocktake_view_model.dart';

/// تفاوت عشري مقارنات الكميات (نفس تعريف المستودع).
const double _qtyEps = 0.0005;

/// تاريخ `يوم/شهر/سنة` بأرقام بسيطة (نمط شاشة الوردية).
String stocktakeFormatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

/// كمية بثلاث منازل (NUMERIC(12,3)) — نص عربيّ بلا فواصل آلاف للحقول.
String stocktakeQty(double value) {
  final rounded = (value * 1000).round() / 1000;
  final text = rounded == rounded.truncateToDouble()
      ? rounded.truncate().toString()
      : rounded.toStringAsFixed(3);
  return text;
}

DateTime? _tryParseIso(String? iso) =>
    iso == null ? null : DateTime.tryParse(iso);

/// شاشة الجرد الفعلي — تُركَّب على مسار الجرد.
class StocktakeScreen extends StatelessWidget {
  const StocktakeScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً — عند غيابه تتصل الشاشة بجلسة
  /// الجرد التطبيقية (نمط SellCartSession — P0-1a) فتنجو مسودة العدّ من
  /// التنقل والقفل التلقائي وتبديل التبويبات.
  final StocktakeViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final provided = viewModel;
    late final StocktakeViewModel vm;
    if (provided != null) {
      vm = provided;
    } else {
      // المتحكم يُقرأ هنا حصراً — الجلسة تعيد النموذج الحي فوق القاعدة
      // الحالية (مسودة جديدة تلقائياً بعد مسح/استعادة يبدّلان القاعدة).
      final app = context.read<AppController>();
      vm = stocktakeSession.attach(
        database: app.database!,
        stocktakeRepo: StocktakeRepository(app.database!.db),
        userRepo: app.users!,
        companyRepo: app.companies!,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<StocktakeViewModel>.value(
      value: vm,
      child: RefreshOnActive(
        routePattern: RegExp(r'^/inventory/stocktake$'),
        // إعادة التحميل عند التنشيط تحفظ المسودة (تحديث مرجعي فقط —
        // الأعداد المُدخلة تُرحّل داخل load() لنفس المخزن).
        onActivate: vm.load,
        child: const _StocktakeBody(),
      ),
    );
  }
}

class _StocktakeBody extends StatefulWidget {
  const _StocktakeBody();

  @override
  State<_StocktakeBody> createState() => _StocktakeBodyState();
}

class _StocktakeBodyState extends State<_StocktakeBody> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _countedByController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _countedByController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(StocktakeViewModel vm) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.state.countedAt ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      vm.setCountedAt(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StocktakeViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    // مزامنة حقلي التوقيع/الملاحظات مع الحالة بعد إعادة التحميل (التعيين
    // البرمجي لا يطلق onChanged — فقط عند اختلاف النص فعلاً).
    if (_countedByController.text != state.countedBy) {
      _countedByController.text = state.countedBy;
    }
    if (_notesController.text != state.notes) {
      _notesController.text = state.notes;
    }

    final showBar =
        !state.loading && state.error == null && state.lines.isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.stocktakeTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (state.loading)
            const ListSkeleton(rows: 7)
          else if (state.error != null)
            ErrorState(
              title: l10n.genericErrorTitle,
              message: l10n.dbOpenErrorMessage,
              technicalDetails: state.error.toString(),
              retryLabel: l10n.commonRetry,
              onRetry: vm.load,
              compact: true,
            )
          else if (state.warehouseId == null)
            EmptyState(
              icon: Icons.warehouse_outlined,
              title: l10n.stocktakeNoWarehouseTitle,
              message: l10n.stocktakeNoWarehouseBody,
              compact: true,
            )
          else ...[
            const _HeroCard(),
            const SizedBox(height: 14),
            _MetaCard(
              countedByController: _countedByController,
              notesController: _notesController,
              onPickDate: () => unawaited(_pickDate(vm)),
            ),
            const SizedBox(height: 14),
            FinSearchField(
              controller: _searchController,
              onChanged: vm.setQuery,
              fieldKey: const Key('stocktake_search_field'),
              hint: l10n.stocktakeSearchHint,
              onCleared: () {
                _searchController.clear();
                vm.setQuery('');
              },
            ),
            const SizedBox(height: 14),
            if (state.lines.isEmpty)
              EmptyState(
                icon: Icons.celebration_rounded,
                title: l10n.stocktakeEmptyTitle,
                message: l10n.stocktakeEmptyBody,
                compact: true,
              )
            else if (state.visibleLines.isEmpty)
              EmptyState(
                icon: Icons.search_off_rounded,
                title: l10n.stocktakeSearchEmptyTitle,
                message: l10n.stocktakeSearchEmptyBody,
                compact: true,
              )
            else
              _CountedSheet(),
            const SizedBox(height: 20),
            const _HistorySection(),
          ],
        ],
      ),
      // الشريط السفلي الثابت — الملخص الحي + زر الاعتماد.
      bottomNavigationBar: showBar
          ? _SummaryBar(onPost: () => _openReview(context, vm))
          : null,
    );
  }
}

/// البطاقة البطلة — شرح مفهوم تكلفة اللقطة وقفل الأرصدة
/// (HubHeroCard الموحدة — W3/R17-b: سطر المستودع بفتحة underSubtitle
/// داخل عمود النص كما كان).
class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StocktakeViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);

    return HubHeroCard(
      icon: Icons.fact_check_rounded,
      title: l10n.stocktakeHeroTitle,
      subtitle: Text(
        l10n.stocktakeHeroSubtitle,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      underSubtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.warehouse_rounded, size: 14, color: colors.gold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  vm.state.warehouseName ?? '',
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// بطاقة بيانات الجرد: المخزن (عند التعدد) + تاريخ العدّ + اسم الجانِد +
/// الملاحظات المجموعة.
class _MetaCard extends StatelessWidget {
  const _MetaCard({
    required this.countedByController,
    required this.notesController,
    required this.onPickDate,
  });

  final TextEditingController countedByController;
  final TextEditingController notesController;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StocktakeViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    final countedAt = state.countedAt ?? DateTime.now();

    return FinCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.warehouses.length > 1) ...[
            DropdownButtonFormField<int>(
              initialValue: state.warehouseId,
              decoration: InputDecoration(
                labelText: l10n.stocktakeWarehouseLabel,
                prefixIcon: const Icon(Icons.warehouse_rounded),
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final warehouse in state.warehouses)
                  DropdownMenuItem<int>(
                    value: warehouse.id,
                    child: Text(warehouse.name),
                  ),
              ],
              onChanged: state.posting
                  ? null
                  : (value) {
                      if (value != null) unawaited(vm.setWarehouse(value));
                    },
            ),
            const SizedBox(height: 12),
          ],
          InkWell(
            onTap: state.posting ? null : onPickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.stocktakeCountedAtLabel,
                prefixIcon: const Icon(Icons.event_rounded),
                border: const OutlineInputBorder(),
              ),
              child: Text(
                stocktakeFormatDate(countedAt),
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(fontFeatures: FinText.tabularNums),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('stocktake_counted_by_field'),
            controller: countedByController,
            enabled: !state.posting,
            onChanged: vm.setCountedBy,
            decoration: InputDecoration(
              labelText: l10n.stocktakeCountedByLabel,
              helperText: l10n.stocktakeCountedByHint,
              prefixIcon: const Icon(Icons.badge_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesController,
            enabled: !state.posting,
            maxLines: 1,
            maxLength: 140,
            onChanged: vm.setNotes,
            decoration: InputDecoration(
              labelText: l10n.stocktakeNotesLabel,
              prefixIcon: const Icon(Icons.notes_rounded),
              counterText: '',
            ),
          ),
        ],
      ),
    );
  }
}

/// كشف العدّ — بطاقة واحدة تضم صفوف الأصناف بفواصل رقيقة (قابل للنمو).
class _CountedSheet extends StatelessWidget {
  const _CountedSheet();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StocktakeViewModel>();
    final lines = vm.state.visibleLines;

    return FinCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant
                    .withValues(alpha: 0.4),
              ),
            _CountedRow(index: i, line: lines[i], enabled: !vm.state.posting),
          ],
        ],
      ),
    );
  }
}

/// صف عدّ واحد: الاسم + شارة الفرق (عند العدّ) / دفتري + لقطة التكلفة +
/// حقل الفعلي + رقاقة «＝ الدفتري» — بدخول متدرج خفيف كصفوف محور المخزن.
class _CountedRow extends StatefulWidget {
  const _CountedRow({
    required this.index,
    required this.line,
    required this.enabled,
  });

  final int index;
  final StocktakeLineDraft line;
  final bool enabled;

  @override
  State<_CountedRow> createState() => _CountedRowState();
}

class _CountedRowState extends State<_CountedRow> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    final counted = widget.line.countedQty;
    _controller.text = counted == null ? '' : stocktakeQty(counted);
  }

  @override
  void didUpdateWidget(covariant _CountedRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // مزامنة مع الحالة: إعادة تحميل الكشف تمسح العدّ؛ والتحديث الخارجي
    // يكتب القيمة الجديدة (التعيين البرمجي لا يطلق onChanged).
    final counted = widget.line.countedQty;
    final text = counted == null ? '' : stocktakeQty(counted);
    if (_controller.text != text) {
      _controller.text = text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String raw, StocktakeViewModel vm) {
    final cleaned = raw.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) {
      vm.setCounted(widget.line.productId, null);
      return;
    }
    final value = double.tryParse(cleaned);
    if (value == null || value.isNaN || value.isInfinite || value < 0) {
      vm.setCounted(widget.line.productId, null);
      return;
    }
    vm.setCounted(widget.line.productId, value);
  }

  void _copyBook(StocktakeViewModel vm) {
    final book = stocktakeQty(widget.line.bookQty);
    _controller.text = book;
    vm.setCounted(widget.line.productId, widget.line.bookQty);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StocktakeViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final line = widget.line;
    final diff = line.diff;
    final decimals = vm.state.baseCurrencyDecimals;

    // حركة الدخول: تأخير خفيف بحسب الترتيب (نمط صفوف محور المخزن).
    final start = (widget.index * 0.05).clamp(0.0, 0.5);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 8),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    line.name,
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (line.unitName != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    line.unitName!,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(width: 8),
                if (diff == null)
                  Text(
                    '—',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: FinText.tabularNums,
                    ),
                  )
                else
                  StatusChip(
                    label: diff > _qtyEps
                        ? '+${stocktakeQty(diff)}'
                        : diff < -_qtyEps
                        ? '−${stocktakeQty(diff.abs())}'
                        : l10n.stocktakeMatched,
                    tone: diff > _qtyEps
                        ? ChipTone.positive
                        : diff < -_qtyEps
                        ? ChipTone.negative
                        : ChipTone.neutral,
                    dense: true,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _QtyColumn(
                  label: l10n.stocktakeBookQty,
                  value: stocktakeQty(line.bookQty),
                ),
                const SizedBox(width: 10),
                _QtyColumn(
                  label: l10n.stocktakeUnitCost,
                  value: AmountText.formatFor(context, line.unitCost, decimals),
                  gold: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: Key('stocktake_counted_field_${line.productId}'),
                    controller: _controller,
                    enabled: widget.enabled,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*[\.,]?\d{0,3}'),
                      ),
                    ],
                    onChanged: (raw) => _onChanged(raw, vm),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontFeatures: FinText.tabularNums,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.stocktakeCountedQty,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: l10n.stocktakeSetBook,
                  child: Material(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: widget.enabled ? () => _copyBook(vm) : null,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                        child: Text(
                          '＝',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: scheme.onSecondaryContainer,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// عمود كمية صغير (تسمية + قيمة جدولية) — دفتري/لقطة التكلفة.
class _QtyColumn extends StatelessWidget {
  const _QtyColumn({
    required this.label,
    required this.value,
    this.gold = false,
  });

  final String label;
  final String value;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return SizedBox(
      width: 74,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              value,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: gold ? colors.gold : null,
                fontWeight: FontWeight.w800,
                fontFeatures: FinText.tabularNums,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// الشريط السفلي الثابت — المعدود/الزيادة/العجز + الصافي الملوّن + زر
/// الاعتماد (معطّل أثناء الترحيل أو بلا عدّ).
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.onPost});

  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StocktakeViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final state = vm.state;
    final summary = state.summary;
    final decimals = state.baseCurrencyDecimals;
    final net = summary.netDiffValue;
    final netSign = net > 0.005
        ? FinSign.incoming
        : net < -0.005
        ? FinSign.outgoing
        : FinSign.neutral;

    return Material(
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.cardBorder, width: 1)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.stocktakeCountedProgress(
                        summary.countedCount,
                        summary.linesCount,
                      ),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFeatures: FinText.tabularNums,
                      ),
                    ),
                  ),
                  _ValueChip(
                    label: l10n.stocktakeSurplus,
                    value: summary.surplusValue,
                    decimals: decimals,
                    sign: FinSign.incoming,
                  ),
                  const SizedBox(width: 8),
                  _ValueChip(
                    label: l10n.stocktakeShortage,
                    value: summary.shortageValue,
                    decimals: decimals,
                    sign: FinSign.outgoing,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.stocktakeNetDiff,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        // scaleDown: هذا العمود قد يضيق بجوار زر الاعتماد
                        // (خطوط العربية أعرض) — كتلة واحدة تتقلص بلا فيض.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              AmountText(
                                amount: net.abs(),
                                size: AmountSize.large,
                                decimals: decimals,
                                sign: netSign,
                              ),
                              if (state.baseCurrencyCode.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(
                                  state.baseCurrencyCode,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: colors.gold,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    key: const Key('stocktake_post_button'),
                    onPressed: vm.canPost ? onPost : null,
                    // داخل صف أفقي (عرض غير مقيد) → حد أدنى بعرض المحتوى
                    // لا Size.fromHeight (عرضه لانهائي يكسر التخطيط هنا).
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      textStyle: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    child: vm.state.posting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : Text(l10n.stocktakePost),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// شريحة قيمة صغيرة في الشريط السفلي (زيادة/عجز).
class _ValueChip extends StatelessWidget {
  const _ValueChip({
    required this.label,
    required this.value,
    required this.decimals,
    required this.sign,
  });

  final String label;
  final double value;
  final int decimals;
  final FinSign sign;

  @override
  Widget build(BuildContext context) {
    final colors = FinColors.of(context);
    final (bg, fg) = switch (sign) {
      FinSign.incoming => (
        colors.positiveContainer,
        colors.onPositiveContainer,
      ),
      FinSign.outgoing => (
        colors.negativeContainer,
        colors.onNegativeContainer,
      ),
      FinSign.neutral => (
        Theme.of(context).colorScheme.surfaceContainerHigh,
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: fg, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 4),
          AmountText(amount: value.abs(), decimals: decimals, sign: sign),
        ],
      ),
    );
  }
}

/// قسم سجل عمليات الجرد — الأحدث أولاً بفرق ملوّن.
class _HistorySection extends StatelessWidget {
  const _HistorySection();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StocktakeViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final history = vm.state.history;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l10n.stocktakeHistoryTitle),
        if (history.isEmpty)
          EmptyState(
            icon: Icons.history_rounded,
            title: l10n.stocktakeHistoryTitle,
            message: l10n.stocktakeHistoryEmpty,
            compact: true,
          )
        else
          for (final row in history)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _HistoryCard(row: row),
            ),
      ],
    );
  }
}

/// بطاقة جرد واحد في السجل — التاريخ + عدد البنود + الصافي الملوّن +
/// الملاحظات (باسم الجانِد).
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.row});

  final StocktakeHistoryRow row;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StocktakeViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final decimals = vm.state.baseCurrencyDecimals;
    final counted = _tryParseIso(row.countedAt)?.toLocal();
    final net = row.totalDiff;
    final netSign = net > 0.005
        ? FinSign.incoming
        : net < -0.005
        ? FinSign.outgoing
        : FinSign.neutral;

    return FinCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.fact_check_outlined,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  counted == null ? '—' : stocktakeFormatDate(counted),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: FinText.tabularNums,
                  ),
                ),
              ),
              Text(
                l10n.stocktakeHistoryLines(row.linesCount),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: FinText.tabularNums,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  row.notes ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              AmountText(amount: net.abs(), decimals: decimals, sign: netSign),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// نافذة المراجعة قبل الاعتماد (نمط payment_sheet السفلية)
// ─────────────────────────────────────────────────────────────────────

/// مقبض النافذة السفلية (نمط موحّد).
class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 4,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

/// يفتح نافذة مراجعة الفروقات — الفروقات فقط + القيم بتكلفة اللقطة +
/// تحذير قفل الأرصدة + تأكيد يرحّل ثم حوار نجاح.
Future<void> _openReview(BuildContext context, StocktakeViewModel vm) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // فوق شريط التبويبات (متصفح الفرع) — لا من أسفل الشاشة خلفه.
    useRootNavigator: false,
    builder: (_) => ChangeNotifierProvider<StocktakeViewModel>.value(
      value: vm,
      child: const _ReviewSheet(),
    ),
  );
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet();

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  Future<void> _confirm(StocktakeViewModel vm) async {
    final result = await vm.post();
    if (!mounted) return;
    if (result.isErr) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.errorOrNull!)));
      return;
    }
    Navigator.of(context).pop();
    unawaited(_showSuccess(context, result.valueOrNull!));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StocktakeViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final state = vm.state;
    final summary = state.summary;
    final decimals = state.baseCurrencyDecimals;
    final countedAt = state.countedAt ?? DateTime.now();

    // أسطر الفروقات فقط (المعدودة ذات فرق ≠ 0).
    final diffLines = <StocktakeLineDraft>[
      for (final line in state.lines)
        if (line.diff != null && line.diff!.abs() > _qtyEps) line,
    ];
    final uncounted = summary.linesCount - summary.countedCount;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetDragHandle(),
            Text(
              l10n.stocktakeReviewTitle,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '${l10n.stocktakeCountedAtLabel}: ${stocktakeFormatDate(countedAt)}'
              ' · ${l10n.stocktakeCountedByLabel}: ${state.countedBy.trim()}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            if (diffLines.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.positiveContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      color: colors.onPositiveContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.stocktakeReviewNoDiffs,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onPositiveContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final line in diffLines)
                _ReviewLineRow(line: line, decimals: decimals),
            const SizedBox(height: 12),
            Divider(height: 1, thickness: 0.8, color: colors.divider),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ReviewTotalColumn(
                    label: l10n.stocktakeSurplus,
                    value: summary.surplusValue,
                    decimals: decimals,
                    sign: FinSign.incoming,
                  ),
                ),
                Expanded(
                  child: _ReviewTotalColumn(
                    label: l10n.stocktakeShortage,
                    value: summary.shortageValue,
                    decimals: decimals,
                    sign: FinSign.outgoing,
                  ),
                ),
                Expanded(
                  child: _ReviewTotalColumn(
                    label: l10n.stocktakeNetDiff,
                    value: summary.netDiffValue,
                    decimals: decimals,
                    net: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.negativeContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_rounded, color: colors.negative, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.stocktakeReviewWarning,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onNegativeContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (uncounted > 0) ...[
              const SizedBox(height: 8),
              Text(
                l10n.stocktakeReviewSkipNote(uncounted),
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              key: const Key('stocktake_confirm_button'),
              onPressed: state.posting ? null : () => unawaited(_confirm(vm)),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                textStyle: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              child: state.posting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : Text(l10n.stocktakeConfirmPost),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: state.posting
                  ? null
                  : () => Navigator.of(context).pop(),
              child: Text(l10n.commonCancel),
            ),
          ],
        ),
      ),
    );
  }
}

/// سطر فرق واحد في المراجعة: الاسم + الفرق بإشارة + القيمة بتكلفة اللقطة.
class _ReviewLineRow extends StatelessWidget {
  const _ReviewLineRow({required this.line, required this.decimals});

  final StocktakeLineDraft line;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final diff = line.diff!;
    final value = diff * line.unitCost;
    final sign = diff > 0 ? FinSign.incoming : FinSign.outgoing;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${l10n.stocktakeBookQty} ${stocktakeQty(line.bookQty)}'
                  ' ← ${l10n.stocktakeCountedQty} '
                  '${stocktakeQty(line.countedQty!)}'
                  '${line.unitName == null ? '' : ' ${line.unitName}'}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: FinText.tabularNums,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AmountText(amount: diff.abs(), decimals: 3, sign: sign),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: AmountText(
                    amount: value.abs(),
                    decimals: decimals,
                    sign: sign,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// عمود إجمالي في المراجعة (زيادة/عجز/صافي).
class _ReviewTotalColumn extends StatelessWidget {
  const _ReviewTotalColumn({
    required this.label,
    required this.value,
    required this.decimals,
    this.sign = FinSign.neutral,
    this.net = false,
  });

  final String label;
  final double value;
  final int decimals;
  final FinSign sign;
  final bool net;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveSign = net
        ? (value > 0.005
              ? FinSign.incoming
              : value < -0.005
              ? FinSign.outgoing
              : FinSign.neutral)
        : sign;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        AmountText(
          amount: value.abs(),
          decimals: decimals,
          sign: effectiveSign,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// حوار النجاح
// ─────────────────────────────────────────────────────────────────────

/// حوار نجاح الاعتماد: التاريخ + أسطر الفروقات + الصافي الملوّن.
Future<void> _showSuccess(BuildContext context, StocktakePosted posted) {
  final l10n = AppLocalizations.of(context)!;
  final colors = FinColors.of(context);
  final net = posted.netDiffValue;
  final netSign = net > 0.005
      ? FinSign.incoming
      : net < -0.005
      ? FinSign.outgoing
      : FinSign.neutral;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: colors.positive, size: 26),
          const SizedBox(width: 10),
          Expanded(child: Text(l10n.stocktakeSuccessTitle)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.stocktakeSuccessBody,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          _SuccessRow(
            label: l10n.stocktakeCountedAtLabel,
            value: stocktakeFormatDate(posted.countedAt),
          ),
          _SuccessRow(
            label: l10n.stocktakeSuccessDiffs,
            value: posted.diffsCount.toString(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.stocktakeNetDiff,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(dialogContext)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AmountText(amount: net.abs(), sign: netSign),
              ],
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.commonDone),
        ),
      ],
    ),
  );
}

/// سطر قيمة داخل حوار النجاح.
class _SuccessRow extends StatelessWidget {
  const _SuccessRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 8),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
