/// شاشة العملاء والموردين — نمط Simple Invoice Manager (V5): استنساخ
/// `screen-clients` من النموذج الأولي: ترويسة فرعية (رجوع + بحث مضمّن +
/// تصدير CSV + قائمة المزيد) + بانر تعليمي + **تبويبات عميل/مورد** +
/// زر إضافة أزرق عريض + رقائق التصفية + بطاقات أطراف SIM بسحب الأرشفة.
/// تحل محل محور الأطراف كهدف الدرج «عميل / المورد» (المحور يبقى
/// في `/parties/hub` من قائمة المزيد — كل مساراته العميقة كما هي).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/party.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_search_field.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/refresh_on_return.dart';
import '../../../core/widgets/sim_list_widgets.dart';
import '../view_models/party_kind.dart';
import '../view_models/party_list_view_model.dart';
import '../view_models/party_repo_gate.dart';
import 'widgets/parties_filter_bar.dart';
import 'widgets/sim_client_row.dart';

/// شاشة العملاء والموردين بنمط SIM — تبويبات في شاشة واحدة.
class SimClientsScreen extends StatefulWidget {
  const SimClientsScreen({
    super.key,
    this.initialKind = PartyKind.customer,
    this.customerViewModel,
    this.supplierViewModel,
  });

  /// التبويب المفتوح ابتداءً (العميل افتراضياً).
  final PartyKind initialKind;

  /// Seam اختبار: نموذج العملاء محمّل مسبقاً.
  final PartyListViewModel? customerViewModel;

  /// Seam اختبار: نموذج الموردين محمّل مسبقاً.
  final PartyListViewModel? supplierViewModel;

  @override
  State<SimClientsScreen> createState() => _SimClientsScreenState();
}

class _SimClientsScreenState extends State<SimClientsScreen> {
  late final PartyListViewModel _customerVm;
  late final PartyListViewModel _supplierVm;
  late PartyKind _kind;
  bool _searchVisible = false;
  bool _ownsViewModels = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    final app = context.read<AppController>();
    if (widget.customerViewModel != null && widget.supplierViewModel != null) {
      _customerVm = widget.customerViewModel!;
      _supplierVm = widget.supplierViewModel!;
    } else {
      _customerVm = PartyListViewModel(
        gate: CustomerRepoGate(app.customers!),
        companyRepo: app.companies!,
        partyKind: PartyKind.customer,
      );
      _supplierVm = PartyListViewModel(
        gate: SupplierRepoGate(app.suppliers!),
        companyRepo: app.companies!,
        partyKind: PartyKind.supplier,
      );
      _ownsViewModels = true;
      unawaited(_customerVm.load());
      unawaited(_supplierVm.load());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (_ownsViewModels) {
      _customerVm.dispose();
      _supplierVm.dispose();
    }
    super.dispose();
  }

  PartyListViewModel get _activeVm =>
      _kind == PartyKind.customer ? _customerVm : _supplierVm;

  void _switchKind(PartyKind kind) {
    if (_kind == kind) return;
    setState(() => _kind = kind);
    // البحث يلازم التبويب النشط — يُطبَّق على النموذج الجديد فوراً.
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      unawaited(_activeVm.setQuery(query));
    }
  }

  void _toggleSearch() {
    setState(() => _searchVisible = !_searchVisible);
    if (!_searchVisible) {
      _searchController.clear();
      unawaited(_activeVm.setQuery(''));
    }
  }

  Future<void> _exportCsv() async {
    final rows = _activeVm.state.rows;
    final buffer = StringBuffer('name,phone,currency,balance\n');
    for (final row in rows) {
      buffer
        ..write('"${row.name.replaceAll('"', '""')}",')
        ..write('"${row.phone ?? ''}",')
        ..write('${row.currencyCode},')
        ..write('${row.balance.toStringAsFixed(2)}\n');
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.simExportCopiedToast(rows.length))),
    );
  }

  void _showMoreSheet() {
    final l10n = AppLocalizations.of(context)!;
    void go(String location) {
      Navigator.of(context).pop();
      context.go(location);
    }

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.simMoreActionsTitle,
                    style: Theme.of(sheetContext).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const Divider(height: 1),
              SimSheetTile(
                icon: Icons.diversity_3_rounded,
                label: l10n.simPartyHubLink,
                onTap: () => go('/parties/hub'),
              ),
              SimSheetTile(
                icon: Icons.trending_up_rounded,
                label: l10n.partiesHubReceivables,
                onTap: () => go('/parties/receivables'),
              ),
              SimSheetTile(
                icon: Icons.trending_down_rounded,
                label: l10n.partiesHubPayables,
                onTap: () => go('/parties/payables'),
              ),
              SimSheetTile(
                icon: Icons.currency_exchange_rounded,
                label: l10n.partiesHubRates,
                onTap: () => go('/parties/rates'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpDialog() {
    final l10n = AppLocalizations.of(context)!;
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.simClientsTutorial),
          content: Text(l10n.simClientsHelpSteps),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonDone),
            ),
          ],
        ),
      ),
    );
  }

  /// تأكيد الأرشفة ثم تنفيذها — يعيد true إذا أُزيل السطر (نجحت الأرشفة
  /// للطرف بلا حركات) وfalse إذا بقي (رفض أو حركات) — نمط القائمة الأصلية.
  Future<bool> _confirmArchive(
    PartyListViewModel vm,
    PartyBalance row,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.partiesArchiveConfirmTitle(row.name)),
        content: Text(l10n.partiesArchiveConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.partiesSwipeArchiveLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;
    final outcome = await vm.archive(row.partyId);
    if (!mounted) return false;
    if (outcome == PartyArchiveOutcome.done) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.partiesArchivedDone)),
      );
      return true;
    }
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.partiesArchiveHasMovements(row.name))),
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isCustomer = _kind == PartyKind.customer;
    final formRoute =
        isCustomer ? '/parties/customers/form' : '/parties/suppliers/form';

    return ChangeNotifierProvider<PartyListViewModel>.value(
      value: _activeVm,
      child: RefreshOnReturn(
        onReappear: () {
          // كلا النموذجين — إضافة عميل من نموذج العميل تُنعش تبويب
          // الموردين أيضاً إن عاد المستخدم للشاشة بعد التبديل.
          unawaited(_customerVm.refresh());
          unawaited(_supplierVm.refresh());
        },
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                SimSubHeader(
                  titleKey: const Key('sim_clients_title'),
                  title: l10n.simClientsTitle,
                  onBack: () => context.go('/home'),
                  actions: [
                    SimSubHeaderAction(
                      icon: Icons.search_rounded,
                      tooltip: l10n.partiesListSearchHint,
                      active: _searchVisible,
                      onPressed: _toggleSearch,
                    ),
                    SimSubHeaderAction(
                      icon: Icons.file_download_outlined,
                      tooltip: l10n.simExportTooltip,
                      onPressed: _exportCsv,
                    ),
                    SimSubHeaderAction(
                      icon: Icons.more_vert_rounded,
                      tooltip: l10n.simMoreActionsTitle,
                      onPressed: _showMoreSheet,
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  sizeCurve: Curves.easeOutCubic,
                  crossFadeState: _searchVisible
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                    child: FinSearchField(
                      controller: _searchController,
                      onChanged: _activeVm.onQueryChanged,
                      fieldKey: const Key('parties_search_field'),
                      hint: l10n.partiesListSearchHint,
                      onCleared: () {
                        _searchController.clear();
                        unawaited(_activeVm.setQuery(''));
                      },
                    ),
                  ),
                  secondChild: const SizedBox(width: double.infinity),
                ),
                SimTutorialBanner(
                  text: l10n.simClientsTutorial,
                  onTap: _showHelpDialog,
                ),
                SimModeTabs(
                  selectedIndex: isCustomer ? 0 : 1,
                  tabs: [
                    SimModeTabSpec(
                      label: l10n.simClientsTabClient,
                      onTap: () => _switchKind(PartyKind.customer),
                    ),
                    SimModeTabSpec(
                      label: l10n.simClientsTabSupplier,
                      onTap: () => _switchKind(PartyKind.supplier),
                    ),
                  ],
                ),
                SimAddWideButton(
                  buttonKey: const Key('sim_clients_add'),
                  label: isCustomer
                      ? l10n.simAddClientAction
                      : l10n.simAddSupplierAction,
                  onPressed: () => context.go(formRoute),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: PartiesFilterBar(
                    selected: _activeVm.state.filter,
                    onSelect: _activeVm.setFilter,
                  ),
                ),
                Expanded(
                  child: _ClientsListBody(onArchive: _confirmArchive),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// جسم القائمة — الحرّاس (تحميل ← خطأ ← لا نتائج ← القائمة).
class _ClientsListBody extends StatelessWidget {
  const _ClientsListBody({required this.onArchive});

  /// تأكيد الأرشفة (يمرّ عبر شاشة الأب لعرض التوست).
  final Future<bool> Function(PartyListViewModel vm, PartyBalance row)
      onArchive;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PartyListViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    final isCustomer = state.kind == PartyKind.customer;

    if (state.loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: const [ListSkeleton()],
      );
    }
    if (state.error != null) {
      return ListView(
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
      );
    }
    final filtered =
        state.query.trim().isNotEmpty || state.filter != PartyListFilter.all;
    if (state.rows.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          EmptyState(
            icon: filtered
                ? Icons.search_off_rounded
                : (isCustomer
                    ? Icons.person_rounded
                    : Icons.local_shipping_rounded),
            title: filtered
                ? l10n.partiesListSearchEmptyTitle
                : (isCustomer
                    ? l10n.partiesListEmptyCustomersTitle
                    : l10n.partiesListEmptySuppliersTitle),
            message: filtered
                ? l10n.partiesListSearchEmptyBody
                : (isCustomer
                    ? l10n.partiesListEmptyCustomersBody
                    : l10n.partiesListEmptySuppliersBody),
            compact: true,
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final row in state.rows)
          SimClientRow(
            row: row,
            kind: state.kind,
            showArchivedBadge: state.filter == PartyListFilter.archived,
            decimals: state.decimalsFor(row.currencyCode),
            onArchive: () => onArchive(vm, row),
          ),
      ],
    );
  }
}
