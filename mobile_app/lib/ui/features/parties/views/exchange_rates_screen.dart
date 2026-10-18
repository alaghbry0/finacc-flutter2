/// شاشة أسعار الصرف اليومية (FR-08-03 — مرجع إدارة العملات 11/14):
/// بطاقة اليوم بتاريخ هجري، صف لكل عملة نشطة غير الأساسية (الأساس لا
/// تظهر — سعرها 1 دائماً) بحقل سعر اليوم وحفظه الفردي، ومؤشر حالة لكل
/// عملة (✓ مُدخل اليوم / آخر سعر بتاريخه)، وقسم سجل آخر الأسعار،
/// وشارة تحذيرية عند نقص إدخال اليوم (FR-08-09 عرضاً).
///
/// (R20-D3c: البطاقات الثلاث والتنسيقات في views/widgets/
/// exchange_rates_* — هذه الشاشة: Scaffold والحرّاس وآلة الحقول.)
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/core/numbers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../view_models/exchange_rates_view_model.dart';
import 'widgets/exchange_rates_currency_card.dart';
import 'widgets/exchange_rates_today_card.dart';

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
              text: entry.todayRate == null ? '' : numToText(entry.todayRate!),
            ),
        });
    } else if (_controllersReady && state.savedCurrencyId != null) {
      // مزامنة الحقل المحفوظ بالنص القانوني.
      final savedId = state.savedCurrencyId!;
      final entry = _entryOf(savedId);
      final controller = _rateControllers[savedId];
      if (entry?.todayRate != null && controller != null) {
        final canonical = numToText(entry!.todayRate!);
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
                ExchangeRatesTodayCard(state: state),
                const SizedBox(height: 14),
                for (final entry in state.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: ExchangeRatesCurrencyCard(
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
