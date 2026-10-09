/// شاشة أسعار الصرف اليومية (FR-08-03 — مرجع إدارة العملات 11/14):
/// بطاقة اليوم بتاريخ هجري، صف لكل عملة نشطة غير الأساسية (الأساس لا
/// تظهر — سعرها 1 دائماً) بحقل سعر اليوم وحفظه الفردي، ومؤشر حالة لكل
/// عملة (✓ مُدخل اليوم / آخر سعر بتاريخه)، وقسم سجل آخر الأسعار،
/// وشارة تحذيرية عند نقص إدخال اليوم (FR-08-09 عرضاً).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/exchange_rate.dart';
import '../../../../domain/services/hijri_date.dart';
import '../../../../domain/services/numerals.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/fin_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/numerals_scope.dart';
import '../../../core/widgets/status_chip.dart';
import '../view_models/exchange_rates_view_model.dart';
import 'widgets/parties_widgets.dart';

class ExchangeRatesScreen extends StatelessWidget {
  const ExchangeRatesScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً — عند غيابه تُنشئ الشاشة نموذجها.
  final ExchangeRatesViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final ExchangeRatesViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = ExchangeRatesViewModel(
        companyRepo: app.companies!,
        fxRepo: app.fxRates!,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<ExchangeRatesViewModel>.value(
      value: vm,
      child: const _ExchangeRatesBody(),
    );
  }
}

class _ExchangeRatesBody extends StatefulWidget {
  const _ExchangeRatesBody();

  @override
  State<_ExchangeRatesBody> createState() => _ExchangeRatesBodyState();
}

class _ExchangeRatesBodyState extends State<_ExchangeRatesBody> {
  /// متحكم إدخال سعر لكل عملة (معرّف العملة → المتحكم).
  final Map<int, TextEditingController> _rateControllers =
      <int, TextEditingController>{};

  /// العملات الموسَّع سجلها.
  final Set<int> _expandedHistory = <int>{};

  bool _controllersReady = false;

  late final ExchangeRatesViewModel _storedVm;

  @override
  void initState() {
    super.initState();
    _storedVm = context.read<ExchangeRatesViewModel>();
    _storedVm.addListener(_onVmChanged);
  }

  @override
  void dispose() {
    _storedVm.removeListener(_onVmChanged);
    for (final controller in _rateControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// تعبئة الحقول مرة واحدة بعد التحميل (آخر سعر كتلميح) + مزامنة
  /// سعر اليوم بعد نجاح الحفظ.
  void _onVmChanged() {
    if (!mounted) return;
    final state = _storedVm.state;
    if (!_controllersReady && !state.loading && state.error == null) {
      _controllersReady = true;
      _rateControllers
        ..clear()
        ..addAll({
          for (final entry in state.entries)
            entry.currency.id: TextEditingController(
              text: entry.todayRate == null ? '' : _numToText(entry.todayRate!),
            ),
        });
    } else if (_controllersReady && state.savedCurrencyId != null) {
      // مزامنة الحقل المحفوظ بالنص القانوني.
      final savedId = state.savedCurrencyId!;
      final entry = _entryOf(savedId);
      final controller = _rateControllers[savedId];
      if (entry?.todayRate != null && controller != null) {
        final canonical = _numToText(entry!.todayRate!);
        if (controller.text.trim() != canonical) {
          controller.text = canonical;
        }
      }
      _storedVm.clearSavedFlag();
    }
  }

  ExchangeRatesViewModel get _vm => _storedVm;

  FxCurrencyEntry? _entryOf(int currencyId) {
    for (final entry in _storedVm.state.entries) {
      if (entry.currency.id == currencyId) return entry;
    }
    return null;
  }

  static String _numToText(double value) {
    if (value == value.truncateToDouble() && value.abs() < 1e15) {
      return value.truncate().toString();
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ExchangeRatesViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.fxRatesTitle)),
      body: state.loading
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: const [ListSkeleton(rows: 5)],
            )
          : state.error != null
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                ErrorState(
                  title: l10n.genericErrorTitle,
                  message: l10n.dbOpenErrorMessage,
                  technicalDetails: state.error.toString(),
                  retryLabel: l10n.commonRetry,
                  onRetry: vm.load,
                  compact: true,
                ),
              ],
            )
          : state.entries.isEmpty
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                EmptyState(
                  icon: Icons.currency_exchange_rounded,
                  title: l10n.fxNoRateYet,
                  message: l10n.fxBaseNote(state.baseCurrency?.code ?? ''),
                  compact: true,
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _TodayCard(state: state),
                const SizedBox(height: 14),
                for (final entry in state.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _FxCurrencyCard(
                      entry: entry,
                      controller: _rateControllers[entry.currency.id],
                      expanded: _expandedHistory.contains(entry.currency.id),
                      onToggleHistory: () => setState(() {
                        final added = _expandedHistory.add(entry.currency.id);
                        if (!added) {
                          _expandedHistory.remove(entry.currency.id);
                        }
                      }),
                      onSave: () =>
                          unawaited(_saveEntry(context, entry.currency.id)),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _saveEntry(BuildContext context, int currencyId) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final controller = _rateControllers[currencyId];
    if (controller == null) return;
    _vm.clearFieldError(currencyId);
    final ok = await _vm.setRateFor(currencyId, controller.text);
    if (!mounted) return;
    if (ok) {
      final entry = _entryOf(currencyId);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.fxRateSaved(entry?.currency.code ?? ''))),
      );
    }
    // الفشل (رقم غير صالح أو خطأ المستودع) يظهر في الحقل/الشريط.
  }
}

/// بطاقة اليوم — التاريخ الهجري والميلادي وحالة الإدخال الكاملة.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.state});

  final ExchangeRatesState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final arabicIndic = NumeralsScope.of(context);
    String localizeDigits(String plain) =>
        arabicIndic ? Numerals.toArabicIndic(plain) : plain;

    final now = DateTime.now();
    final hijri = HijriCalendar.fromDateTime(now);
    final hijriText = localizeDigits(
      '${hijri.day} ${hijri.monthName} ${hijri.year} هـ',
    );
    final gregorianText = localizeDigits('${now.day}/${now.month}/${now.year}');

    return FinCard(
      accent: colors.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primary,
                      Color.lerp(scheme.primary, Colors.black, 0.25)!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(FinRadius.control),
                ),
                child: Icon(
                  Icons.currency_exchange_rounded,
                  color: scheme.onPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.fxTodayHijriDate(hijriText),
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      gregorianText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (state.complete)
            StatusChip(
              label: l10n.fxAllComplete,
              tone: ChipTone.positive,
              icon: Icons.check_circle_rounded,
            )
          else
            StatusChip(
              label: l10n.fxMissingWarning,
              tone: ChipTone.warning,
              icon: Icons.warning_amber_rounded,
            ),
          const SizedBox(height: 10),
          Text(
            l10n.fxBaseNote(state.baseCurrency?.code ?? ''),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// بطاقة عملة واحدة — آخر سعر معروف + حقل سعر اليوم + الحفظ + السجل.
class _FxCurrencyCard extends StatelessWidget {
  const _FxCurrencyCard({
    required this.entry,
    required this.controller,
    required this.expanded,
    required this.onToggleHistory,
    required this.onSave,
  });

  final FxCurrencyEntry entry;
  final TextEditingController? controller;
  final bool expanded;
  final VoidCallback onToggleHistory;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final currency = entry.currency;
    final latest = entry.latest;

    return FinCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CurrencyCodePill(code: currency.code),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  currency.name,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              StatusChip(
                label: entry.enteredToday
                    ? l10n.fxEnteredToday
                    : l10n.fxMissingToday,
                tone: entry.enteredToday ? ChipTone.positive : ChipTone.warning,
                icon: entry.enteredToday
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            latest == null
                ? l10n.fxNoRateYet
                : l10n.fxLastKnownRate(
                    _formatRate(context, latest.rate),
                    partyFormatDate(context, latest.rateDateUtc),
                  ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  key: Key('fx_field_${currency.code}'),
                  controller: controller,
                  enabled: !entry.saving,
                  onChanged: (_) => context
                      .read<ExchangeRatesViewModel>()
                      .clearFieldError(currency.id),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.fxRateFieldLabel,
                    helperText: l10n.fxAgainstBase(_baseCode(context)),
                    errorText: entry.fieldError ? l10n.fxRateInvalid : null,
                    prefixIcon: const Icon(Icons.price_change_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                key: Key('fx_save_${currency.code}'),
                onPressed: entry.saving ? null : onSave,
                icon: entry.saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(
                  entry.saving ? l10n.fxSavingLabel : l10n.fxSaveLabel,
                ),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              ),
            ],
          ),
          if (entry.fieldError) ...[
            const SizedBox(height: 6),
            Text(
              l10n.fxRateInvalid,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.negative,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: onToggleHistory,
              icon: Icon(
                expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 18,
              ),
              label: Text(expanded ? l10n.fxHideHistory : l10n.fxShowHistory),
            ),
          ),
          if (expanded) _HistoryList(entry: entry),
        ],
      ),
    );
  }

  static String _baseCode(BuildContext context) {
    final state = context.read<ExchangeRatesViewModel>().state;
    return state.baseCurrency?.code ?? '';
  }

  static String _formatRate(BuildContext context, double rate) {
    final plain = rate == rate.truncateToDouble()
        ? rate.truncate().toString()
        : rate.toStringAsFixed(4);
    return NumeralsScope.of(context) ? Numerals.toArabicIndic(plain) : plain;
  }
}

/// سجل آخر الأسعار لعملة — تاريخ + سعر بأرقام جدولية LTR.
class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.entry});

  final FxCurrencyEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    if (entry.history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          l10n.fxHistoryEmpty,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          for (final rate in entry.history.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(
                    Icons.event_rounded,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      partyFormatDate(context, rate.rateDateUtc),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      NumeralsScope.of(context)
                          ? Numerals.toArabicIndic(_plainRate(rate))
                          : _plainRate(rate),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _plainRate(ExchangeRateEntry rate) {
    final value = rate.rate;
    if (value == value.truncateToDouble()) {
      return value.truncate().toString();
    }
    return value.toStringAsFixed(4);
  }
}
