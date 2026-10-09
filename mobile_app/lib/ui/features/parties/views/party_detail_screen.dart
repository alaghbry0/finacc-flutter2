/// شاشتا تفاصيل الطرف — العميل والمورد (دليل 06/… و05/05): بطاقة
/// البيانات وشارات حد الائتمان والأرشفة، توزيع الرصيد **لكل عملة على
/// حدة**، وكشف الحساب (FR-03-04) بعملة وفترة ورصيد رأسي متحرك في
/// خط زمني بأيقونات دلالية لكل قيد.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/party.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/info_note.dart';
import '../../../core/widgets/fin_section_title.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/status_chip.dart';
import '../../printing/services/statement_pdf_builder.dart';
import '../../printing/statement_print_doc.dart';
import '../../printing/views/pdf_preview_dialog.dart';
import '../view_models/party_detail_view_model.dart';
import '../view_models/party_kind.dart';
import '../view_models/party_lookup.dart';
import '../view_models/party_repo_gate.dart';
import 'widgets/parties_widgets.dart';
import '../../../core/widgets/refresh_on_return.dart';

/// شاشة تفاصيل العميل.
class CustomerDetailScreen extends StatelessWidget {
  const CustomerDetailScreen({super.key, this.viewModel, this.customerId});

  /// Seam اختبار: نموذج محمّل مسبقاً.
  final PartyDetailViewModel? viewModel;

  /// معرّف العميل.
  final int? customerId;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final PartyDetailViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = PartyDetailViewModel(
        gate: CustomerRepoGate(app.customers!),
        companyRepo: app.companies!,
        partyLookup: PartyLookup(app.database!.db),
        partyKind: PartyKind.customer,
        id: customerId ?? -1,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<PartyDetailViewModel>.value(
      value: vm,
      // تحديث التفاصيل عند العودة من مسار التعديل الفرعي (:id/edit).
      child: RefreshOnReturn(
        onReappear: vm.load,
        child: const _PartyDetailBody(),
      ),
    );
  }
}

/// شاشة تفاصيل المورد (دليل 05/05 — كشف الحساب والتقرير).
class SupplierDetailScreen extends StatelessWidget {
  const SupplierDetailScreen({super.key, this.viewModel, this.supplierId});

  /// Seam اختبار: نموذج محمّل مسبقاً.
  final PartyDetailViewModel? viewModel;

  /// معرّف المورد.
  final int? supplierId;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final PartyDetailViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = PartyDetailViewModel(
        gate: SupplierRepoGate(app.suppliers!),
        companyRepo: app.companies!,
        partyLookup: PartyLookup(app.database!.db),
        partyKind: PartyKind.supplier,
        id: supplierId ?? -1,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<PartyDetailViewModel>.value(
      value: vm,
      child: RefreshOnReturn(
        onReappear: vm.load,
        child: const _PartyDetailBody(),
      ),
    );
  }
}

class _PartyDetailBody extends StatelessWidget {
  const _PartyDetailBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PartyDetailViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    final record = state.record;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(record?.name ?? ''),
        actions: [
          // طباعة/مشاركة كشف الحساب PDF (الشريحة 7 — مستند #3) — متاح
          // فور اكتمال الكشف المعروض (بعملته وفترته كما اختيرا أعلاه).
          IconButton(
            tooltip: l10n.printingPdfTooltip,
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed:
                record == null ||
                    state.statement == null ||
                    state.loadingStatement
                ? null
                : () => _openStatementPdf(context, state),
          ),
          // تعديل الطرف — يفتح النموذج بنفس المعرّف (مسار :id/edit).
          IconButton(
            tooltip: l10n.partyDetailEditAction,
            icon: const Icon(Icons.edit_outlined),
            onPressed: record == null
                ? null
                : () => context.go(
                    state.kind.isCustomer
                        ? '/parties/customers/${state.partyId}/edit'
                        : '/parties/suppliers/${state.partyId}/edit',
                  ),
          ),
        ],
      ),
      body: state.loading
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: const [ListSkeleton(rows: 6)],
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
          : state.notFound
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                EmptyState(
                  icon: Icons.person_off_rounded,
                  title: l10n.partyDetailNotFoundTitle,
                  message: l10n.partyDetailNotFoundBody,
                  compact: true,
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (record!.archived) ...[
                  InfoNote(
                    icon: Icons.archive_rounded,
                    message: l10n.partyDetailArchivedBanner,
                    warning: true,
                  ),
                  const SizedBox(height: 14),
                ],
                _InfoCard(state: state),
                const SizedBox(height: 18),
                FinSectionTitle(
                  icon: Icons.account_balance_wallet_rounded,
                  title: l10n.partyDetailBalancesSection,
                ),
                const SizedBox(height: 8),
                _BalancesCard(state: state),
                const SizedBox(height: 18),
                FinSectionTitle(
                  icon: Icons.receipt_long_rounded,
                  title: l10n.partyDetailStatementSection,
                ),
                const SizedBox(height: 8),
                _StatementCard(state: state),
              ],
            ),
    );
  }
}

/// بطاقة البيانات — الاسم والهواتف والعنوان وحد الائتمان والافتتاحي.
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.state});

  final PartyDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final record = state.record!;
    final isCustomer = state.kind == PartyKind.customer;

    return FinCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PartyAvatar(kind: state.kind, name: record.name, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.name,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (isCustomer)
                          CreditLimitChip(creditLimit: record.creditLimit),
                        if (record.archived)
                          StatusChip(
                            label: l10n.partiesArchivedBadge,
                            tone: ChipTone.neutral,
                            icon: Icons.archive_rounded,
                            dense: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.call_rounded,
            label: l10n.partyFormPhoneLabel,
            child: (record.phone ?? '').isNotEmpty
                ? PartyPhoneText(record.phone!)
                : Text(
                    l10n.partiesNoPhone,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
          ),
          if (isCustomer && (record.whatsapp ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.chat_rounded,
              label: l10n.partyFormWhatsappLabel,
              child: PartyPhoneText(record.whatsapp!),
            ),
          ],
          if ((record.address ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.location_on_rounded,
              label: l10n.partyFormAddressLabel,
              child: Expanded(
                child: Text(
                  record.address!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
          if (isCustomer && (record.area ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.map_rounded,
              label: l10n.partyFormAreaLabel,
              child: Text(
                record.area!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          if (record.openingBalance != 0) ...[
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.savings_rounded,
              label: l10n.statementKindOpening,
              child: Expanded(
                child: Text(
                  l10n.partyDetailOpeningRow(
                    partyFormatDate(context, record.openingDate),
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
          if ((record.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.sticky_note_2_rounded,
              label: l10n.partyDetailNotesLabel,
              child: Expanded(
                child: Text(
                  record.notes!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// سطر معلومة — أيقونة + تسمية + قيمة.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        SizedBox(
          width: 86,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (child is Expanded) child else Expanded(child: child),
      ],
    );
  }
}

/// بطاقة الأرصدة — سطر لكل عملة (قد تكون واحدة صفرياً)؛ النقر على سطر
/// يختار عملة الكشف.
class _BalancesCard extends StatelessWidget {
  const _BalancesCard({required this.state});

  final PartyDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    if (state.balances.isEmpty) {
      return FinCard(
        child: Text(
          l10n.partyDetailBalancesEmpty,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }
    return FinCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < state.balances.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            _BalanceRow(
              row: state.balances[i],
              selected:
                  _currencyIdOfCode(state, state.balances[i].currencyCode) ==
                  state.statementCurrencyId,
              decimals: state.decimalsFor(state.balances[i].currencyCode),
              onTap: () => _selectCurrency(
                context,
                _currencyIdOfCode(state, state.balances[i].currencyCode),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static int? _currencyIdOfCode(PartyDetailState state, String code) {
    for (final currency in state.currencies) {
      if (currency.code == code) return currency.id;
    }
    return null;
  }

  static void _selectCurrency(BuildContext context, int? currencyId) {
    final vm = context.read<PartyDetailViewModel>();
    if (currencyId != null) {
      unawaited(vm.setStatementCurrency(currencyId));
    }
  }
}

/// سطر رصيد بعملة واحدة — النقر يجعلها عملة الكشف.
class _BalanceRow extends StatelessWidget {
  const _BalanceRow({
    required this.row,
    required this.selected,
    required this.decimals,
    required this.onTap,
  });

  final PartyBalance row;
  final bool selected;
  final int decimals;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer.withValues(alpha: 0.30)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: selected
              ? Border.all(color: scheme.primary.withValues(alpha: 0.5))
              : null,
        ),
        child: Row(
          children: [
            CurrencyCodePill(code: row.currencyCode),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                partyFormatDate(context, row.lastPaymentDate),
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            PartyBalanceText(balance: row.balance, decimals: decimals),
            if (selected) ...[
              const SizedBox(width: 6),
              Icon(Icons.check_circle_rounded, size: 16, color: colors.gold),
            ],
          ],
        ),
      ),
    );
  }
}

/// بطاقة كشف الحساب — عناصر التحكم بالعملة والفترة + الرصيد النهائي +
/// الخط الزمني للقيود برصيد رأسي متحرك.
class _StatementCard extends StatelessWidget {
  const _StatementCard({required this.state});

  final PartyDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vm = context.read<PartyDetailViewModel>();
    return FinCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int>(
            key: const Key('party_detail_currency'),
            initialValue: state.statementCurrencyId,
            onChanged: (value) {
              if (value != null) unawaited(vm.setStatementCurrency(value));
            },
            decoration: InputDecoration(
              labelText: l10n.partyDetailStatementCurrency,
              prefixIcon: const Icon(Icons.currency_exchange_rounded),
            ),
            items: [
              for (final currency in state.currencies)
                DropdownMenuItem<int>(
                  value: currency.id,
                  child: Text('${currency.name} (${currency.code})'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _PeriodControls(state: state),
          const SizedBox(height: 14),
          if (state.loadingStatement)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            _StatementBody(state: state),
        ],
      ),
    );
  }
}

/// أدوات الفترة — من/إلى + رقائق سريعة (الكل/هذا الشهر/هذه السنة).
class _PeriodControls extends StatelessWidget {
  const _PeriodControls({required this.state});

  final PartyDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vm = context.read<PartyDetailViewModel>();
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);
    final thisYear = DateTime(now.year, 1, 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _DateChip(
                key: const Key('party_detail_from_date'),
                icon: Icons.event_rounded,
                label: l10n.partyDetailStatementFrom,
                text: state.from == null
                    ? l10n.partyDetailPeriodAll
                    : partyFormatDate(context, state.from),
                onTap: () => unawaited(_pickFrom(context, vm)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DateChip(
                key: const Key('party_detail_to_date'),
                icon: Icons.event_available_rounded,
                label: l10n.partyDetailStatementTo,
                text: partyFormatDate(context, state.to),
                onTap: () => unawaited(_pickTo(context, vm)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              _QuickChip(
                label: l10n.partyDetailPeriodAll,
                selected: state.from == null,
                onTap: () => unawaited(vm.clearPeriod()),
              ),
              const SizedBox(width: 8),
              _QuickChip(
                label: l10n.partyDetailPeriodThisMonth,
                selected: _sameDay(state.from, thisMonth),
                onTap: () => unawaited(vm.setFrom(thisMonth)),
              ),
              const SizedBox(width: 8),
              _QuickChip(
                label: l10n.partyDetailPeriodThisYear,
                selected: _sameDay(state.from, thisYear),
                onTap: () => unawaited(vm.setFrom(thisYear)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static bool _sameDay(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  static Future<void> _pickFrom(
    BuildContext context,
    PartyDetailViewModel vm,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.state.from ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      await vm.setFrom(DateTime(picked.year, picked.month, picked.day));
    }
  }

  static Future<void> _pickTo(
    BuildContext context,
    PartyDetailViewModel vm,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.state.to ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      await vm.setTo(DateTime(picked.year, picked.month, picked.day));
    }
  }
}

/// رقاقة تاريخ (من/إلى) — تفتح المنتقي.
class _DateChip extends StatelessWidget {
  const _DateChip({
    super.key,
    required this.icon,
    required this.label,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  Text(
                    text,
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// رقاقة فترة سريعة.
class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.14)
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(alpha: 0.55)
                : scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected ? scheme.primary : scheme.onSurface,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// جسم الكشف — الرصيد النهائي + «رصيد ماضٍ» + الخط الزمني للقيود.
class _StatementBody extends StatelessWidget {
  const _StatementBody({required this.state});

  final PartyDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statement = state.statement;
    if (statement == null) {
      return Text(
        l10n.partyDetailNoEntries,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    final decimals = state.statementDecimals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.from != null) ...[
          _CarryInRow(
            label: l10n.partyDetailCarryInBalance,
            amount: statement.openingBalance,
            decimals: decimals,
          ),
          const SizedBox(height: 12),
        ],
        _FinalBalanceHeader(
          label: l10n.partyDetailFinalBalance,
          code: statement.currencyCode,
          amount: statement.finalBalance,
          decimals: decimals,
        ),
        const SizedBox(height: 14),
        if (statement.entries.isEmpty)
          Text(
            l10n.partyDetailNoEntries,
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          for (var i = 0; i < statement.entries.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StatementEntryRow(
                key: Key('statement_entry_$i'),
                entry: statement.entries[i],
                decimals: decimals,
              ),
            ),
      ],
    );
  }
}

/// رأس الرصيد النهائي — بطاقة داخل البطاقة بلون دلالي ومبلغ ضخم.
class _FinalBalanceHeader extends StatelessWidget {
  const _FinalBalanceHeader({
    required this.label,
    required this.code,
    required this.amount,
    required this.decimals,
  });

  final String label;
  final String code;
  final double amount;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          CurrencyCodePill(code: code),
          const SizedBox(width: 8),
          PartyBalanceText(
            balance: amount,
            decimals: decimals,
            size: AmountSize.large,
            showChip: false,
          ),
        ],
      ),
    );
  }
}

/// سطر «رصيد ماضٍ» عند تحديد بداية فترة.
class _CarryInRow extends StatelessWidget {
  const _CarryInRow({
    required this.label,
    required this.amount,
    required this.decimals,
  });

  final String label;
  final double amount;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.history_rounded, size: 15, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        PartyBalanceText(balance: amount, decimals: decimals, showChip: false),
      ],
    );
  }
}

/// قيد واحد في الخط الزمني — أيقونة دلالية + تاريخ ونوع ورقم المستند +
/// المبلغ الموقَّع + الرصيد الرأسي بعد القيد.
class _StatementEntryRow extends StatelessWidget {
  const _StatementEntryRow({
    super.key,
    required this.entry,
    required this.decimals,
  });

  final StatementEntry entry;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final isDebit = entry.amount > 0;
    final amountColor = entry.amount == 0
        ? scheme.onSurfaceVariant
        : (isDebit ? colors.negative : colors.positive);
    final iconColor =
        entry.code == StatementEntryCode.receipt ||
            entry.code == StatementEntryCode.payment
        ? colors.positive
        : entry.code == StatementEntryCode.opening ||
              entry.code == StatementEntryCode.carryIn
        ? colors.gold
        : scheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            statementEntryIcon(entry.code),
            size: 17,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      statementEntryLabel(l10n, entry.code),
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      '${isDebit ? '+' : '−'}'
                      '${AmountText.formatFor(context, entry.amount.abs(), decimals)}',
                      style: FinText.amountRow(amountColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${partyFormatDate(context, entry.date)}'
                '${entry.docNo != null ? ' · ${entry.docNo}' : ''}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              l10n.statementBalanceColumn,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                AmountText.formatFor(context, entry.runningBalance, decimals),
                style: FinText.amountRow(scheme.onSurface)
                    .copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────
/// طباعة كشف الحساب PDF (الشريحة 7 — مستند #3) — إسقاط + معاينة
/// ─────────────────────────────────────────────────────────────────────

/// يفتح نافذة معاينة طباعة كشف حساب الطرف — القيم كلها تُلتقط قبل أي
/// await (لا سياق عبر فجوة غير متزامنة). يطبع الكشف **كما هو معروض**:
/// بعملته المحددة وفترته المختارة (افتراضياً من أول حركة حتى اليوم)،
/// والرصيد الافتتاحي/«رصيد ماضٍ» يظهر كأول سطر داخل الجدول كما في
/// الشاشة. واتساب = واتساب المنشأة وإلا واتساب الطرف فهاتفه، ورسالة
/// المشاركة تحمل اسم الطرف ورصيده الختامي.
void _openStatementPdf(BuildContext context, PartyDetailState state) {
  final l10n = AppLocalizations.of(context)!;
  final company = context.read<AppController>().company;
  final record = state.record!;
  final statement = state.statement!;
  final doc = buildStatementPrintDoc(
    l10n: l10n,
    statement: statement,
    partyName: record.name,
    partyPhone: record.phone,
    company: company,
    decimals: state.statementDecimals,
    from: state.from,
    to: state.to,
  );
  unawaited(
    showPdfPreviewDialog(
      context,
      title: '${l10n.printingStatementDocTitle} - ${record.name}',
      build: () => const StatementPdfBuilder().build(doc),
      whatsappPhone: company?.whatsapp ?? record.whatsapp ?? record.phone,
      shareMessage: l10n.printingShareMessageStatement(
        record.name,
        AmountText.format(statement.finalBalance, state.statementDecimals),
      ),
    ),
  );
}
