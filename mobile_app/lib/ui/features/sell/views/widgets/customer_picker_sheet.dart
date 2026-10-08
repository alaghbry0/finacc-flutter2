/// نافذة اختيار العميل السريع لشاشة البيع — بحث بالاسم/الهاتف مع رصيد
/// العميل بعملته (معلوماتي فقط)، وخيار «عميل نقدي» المجهول أعلى القائمة،
/// و«+ عميل جديد» بنموذج مصغّر (اسم + هاتف) يعيد الطرف الجديد **مختاراً**
/// في المنتقي (P1-3 — بيع آجل لعميل جديد بلا مغادرة الكاشير).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../data/repositories/customer_repository.dart';
import '../../../../../domain/core/result.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../view_models/customer_picker_view_model.dart';

/// يفتح منتقي العميل — [onPick] عند اختيار عميل، [onCashCustomer] لعميل
/// نقدي مجهول (customerId = null)، و[onCreateCustomer] (P1-3 — اختياري)
/// ينشئ عميلاً جديداً من النموذج المصغّر ويعيده مختاراً؛ غيابه يخفي
/// الزر (السلوك القائم تماماً).
Future<void> showCustomerPickerSheet(
  BuildContext context, {
  required CustomerRepository customerRepo,
  required ValueChanged<CustomerPick> onPick,
  required VoidCallback onCashCustomer,
  Future<Result<CustomerPick, String>> Function(String name, String? phone)?
  onCreateCustomer,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // فوق شريط التبويبات (متصفح الفرع) — لا من أسفل الشاشة خلفه.
    useRootNavigator: false,
    builder: (_) => ChangeNotifierProvider<CustomerPickerViewModel>(
      create: (_) {
        final vm = CustomerPickerViewModel(customerRepo: customerRepo);
        unawaited(vm.search(''));
        return vm;
      },
      child: _CustomerPickerSheet(
        onPick: onPick,
        onCash: onCashCustomer,
        onCreateCustomer: onCreateCustomer,
      ),
    ),
  );
}

class _CustomerPickerSheet extends StatefulWidget {
  const _CustomerPickerSheet({
    required this.onPick,
    required this.onCash,
    this.onCreateCustomer,
  });

  final ValueChanged<CustomerPick> onPick;
  final VoidCallback onCash;

  /// إنشاء عميل جديد سريع (P1-3) — null = إخفاء الزر.
  final Future<Result<CustomerPick, String>> Function(
    String name,
    String? phone,
  )?
  onCreateCustomer;

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  /// يفتح نموذج «عميل جديد سريع» — عند نجاح الحفظ يُرجع الطرف الجديد
  /// **مختاراً**: يستدعي onPick ويغلق المنتقي كله (نمط اختيار صف قائم).
  Future<void> _openQuickCustomerForm() async {
    final create = widget.onCreateCustomer;
    if (create == null) return;
    final created = await showModalBottomSheet<CustomerPick>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: false,
      builder: (_) => _QuickCustomerSheet(onCreate: create),
    );
    if (created != null && mounted) {
      widget.onPick(created);
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CustomerPickerViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final height = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: height * 0.85,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.sellCustomerPickerTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.commonCancel,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('sell_customer_search_field'),
                controller: _searchController,
                onChanged: vm.onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.sellCustomerPickerSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            unawaited(vm.search(''));
                          },
                        ),
                ),
              ),
              const SizedBox(height: 12),
              _CashCustomerCard(
                onTap: () {
                  widget.onCash();
                  Navigator.of(context).pop();
                },
              ),
              if (widget.onCreateCustomer != null) ...[
                const SizedBox(height: 8),
                // P1-3: عميل جديد سريع داخل المنتقي نفسه — بيع آجل لعميل
                // جديد بدون مغادرة الكاشير إلى وحدة الأطراف.
                OutlinedButton.icon(
                  key: const Key('sell_customer_new_button'),
                  onPressed: () => unawaited(_openQuickCustomerForm()),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.person_add_alt_rounded, size: 20),
                  label: Text(l10n.sellFixNewCustomer),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(child: _buildList(context, vm)),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: Text(
                    l10n.sellCustomerPickerFooterNote,
                    style: Theme.of(context).textTheme.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, CustomerPickerViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    if (state.loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    if (state.error != null) {
      return Center(
        child: ErrorState(
          title: l10n.genericErrorTitle,
          message: l10n.dbOpenErrorMessage,
          technicalDetails: state.error.toString(),
          retryLabel: l10n.commonRetry,
          onRetry: () => vm.search(state.query),
          compact: true,
        ),
      );
    }
    if (state.matches.isEmpty) {
      return Center(
        child: state.query.isEmpty
            ? EmptyState(
                icon: Icons.person_rounded,
                title: l10n.sellCustomerPickerEmptyTitle,
                message: l10n.sellCustomerPickerEmptyBody,
                compact: true,
              )
            : EmptyState(
                icon: Icons.search_off_rounded,
                title: l10n.sellCustomerPickerNoResultsTitle,
                message: l10n.sellCustomerPickerNoResultsBody,
                compact: true,
              ),
      );
    }
    return ListView.builder(
      key: const Key('sell_customer_results'),
      itemCount: state.matches.length,
      itemBuilder: (context, index) {
        final match = state.matches[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _CustomerRow(
            match: match,
            onTap: () {
              widget.onPick(match);
              Navigator.of(context).pop();
            },
          ),
        );
      },
    );
  }
}

/// بطاقة «عميل نقدي» — الخيار الافتراضي للكاشير.
class _CashCustomerCard extends StatelessWidget {
  const _CashCustomerCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: scheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.sellCashCustomer,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      l10n.sellCashCustomerHint,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: scheme.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_left_rounded,
                color: scheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.match, required this.onTap});

  final CustomerPick match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final balanceColor = match.balance > 0
        ? colors.warning
        : match.balance < 0
        ? colors.positive
        : scheme.onSurfaceVariant;
    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.cardBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    match.name.trim().isEmpty
                        ? '؟'
                        : match.name.trim().characters.first,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.name,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (match.phone != null && match.phone!.isNotEmpty)
                      Text(
                        match.phone!,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(fontFeatures: FinText.tabularNums),
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      AmountText(
                        amount: match.balance.abs(),
                        size: AmountSize.row,
                        decimals: 2,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        match.currencyCode,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: balanceColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    match.balance > 0
                        ? AppLocalizations.of(context)!.sellCustomerOwes
                        : match.balance < 0
                        ? AppLocalizations.of(context)!.sellCustomerCredit
                        : AppLocalizations.of(context)!.sellCustomerClear,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: balanceColor),
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

/// نموذج «عميل جديد سريع» (P1-3) — اسم + هاتف فقط على نمط نموذج الطرف
/// القائم لكن مبسطاً؛ الحفظ عبر [onCreate] وبعد النجاح يُرجع الطرف
/// الجديد بالنافذة (pop بالنتيجة) ليُحدَّد مختاراً في المنتقي.
class _QuickCustomerSheet extends StatefulWidget {
  const _QuickCustomerSheet({required this.onCreate});

  final Future<Result<CustomerPick, String>> Function(
    String name,
    String? phone,
  )
  onCreate;

  @override
  State<_QuickCustomerSheet> createState() => _QuickCustomerSheetState();
}

class _QuickCustomerSheetState extends State<_QuickCustomerSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final name = _name.text.trim();
    final rawPhone = _phone.text.trim();
    final result = await widget.onCreate(
      name,
      rawPhone.isEmpty ? null : rawPhone,
    );
    if (!mounted) return;
    if (result.isOk) {
      Navigator.of(context).pop(result.valueOrNull);
      return;
    }
    setState(() {
      _saving = false;
      _error = result.errorOrNull;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.person_add_alt_rounded,
                    color: scheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.sellFixNewCustomerTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('sell_quick_customer_name'),
                controller: _name,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.sellFixNewCustomerNameLabel,
                  prefixIcon: const Icon(Icons.badge_rounded),
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? l10n.sellFixNewCustomerNameRequired
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('sell_quick_customer_phone'),
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => unawaited(_save()),
                decoration: InputDecoration(
                  labelText: l10n.sellFixNewCustomerPhoneLabel,
                  prefixIcon: const Icon(Icons.phone_rounded),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: FinColors.of(context).negative,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const Key('sell_quick_customer_save'),
                onPressed: _saving ? null : () => unawaited(_save()),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(Icons.check_rounded, size: 20),
                label: Text(l10n.sellFixNewCustomerSave),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: Text(l10n.commonCancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
