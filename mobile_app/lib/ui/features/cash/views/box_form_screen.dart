/// نموذج الصندوق (إضافة/تعديل — FR-04-01) — مسار `/cash/box-form(/:id)`:
/// اسم + عملة من عملات المنشأة (تُثبَّت عند الإنشاء) + تعيين افتراضي.
/// عند التعديل يُحلّ الصندوق من المستودع (عقد النموذج يستقبل
/// CashboxInfo جاهزاً) قبل بناء النموذج نفسه.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/cash.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/fin_error_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../view_models/box_form_view_model.dart';

/// نموذج الصندوق — [editId] من المسار (null = إضافة).
class BoxFormScreen extends StatefulWidget {
  const BoxFormScreen({super.key, this.editId});

  final int? editId;

  @override
  State<BoxFormScreen> createState() => _BoxFormScreenState();
}

class _BoxFormScreenState extends State<BoxFormScreen> {
  BoxFormViewModel? _vm;
  bool _notFound = false;
  Object? _resolveError;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppController>();
    unawaited(_resolveAndCreate(app));
  }

  Future<void> _resolveAndCreate(AppController app) async {
    try {
      final results = await Future.wait<Object?>([
        app.companies!.findAdminUserId(),
        if (widget.editId != null) app.cash!.listBoxes(includeArchived: true),
      ]);
      final userId = results[0] as int?;
      CashboxInfo? editBox;
      if (widget.editId != null) {
        final boxes = results[1]! as List<CashboxWithBalance>;
        for (final b in boxes) {
          if (b.box.id == widget.editId) {
            editBox = b.box;
            break;
          }
        }
      }
      if (!mounted) return;
      if (widget.editId != null && editBox == null) {
        setState(() => _notFound = true);
        return;
      }
      final vm = BoxFormViewModel(
        cashRepo: app.cash!,
        companyRepo: app.companies!,
        userId: userId,
        editBox: editBox,
      );
      setState(() => _vm = vm);
      unawaited(vm.load());
    } catch (error) {
      if (!mounted) return;
      setState(() => _resolveError = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/cash/boxes')),
        title: Text(
          widget.editId == null
              ? AppLocalizations.of(context)!.cashBoxFormNewTitle
              : AppLocalizations.of(context)!.cashBoxFormEditTitle,
        ),
      ),
      body: _notFound
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                ErrorState(
                  title: AppLocalizations.of(context)!.cashBoxFormNotFound,
                  message: AppLocalizations.of(context)!.dbOpenErrorMessage,
                  compact: true,
                ),
              ],
            )
          : _resolveError != null
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                ErrorState(
                  title: AppLocalizations.of(context)!.genericErrorTitle,
                  message: AppLocalizations.of(context)!.dbOpenErrorMessage,
                  technicalDetails: _resolveError.toString(),
                  retryLabel: AppLocalizations.of(context)!.commonRetry,
                  onRetry: () => unawaited(
                    _resolveAndCreate(context.read<AppController>()),
                  ),
                  compact: true,
                ),
              ],
            )
          : vm == null
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: const [ListSkeleton(rows: 3)],
            )
          : ChangeNotifierProvider<BoxFormViewModel>.value(
              value: vm,
              child: _BoxFormBody(vm: vm),
            ),
    );
  }
}

class _BoxFormBody extends StatelessWidget {
  const _BoxFormBody({required this.vm});

  final BoxFormViewModel vm;

  Future<void> _save(BuildContext context) async {
    final result = await vm.save();
    if (!context.mounted) return;
    if (result.isOk) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.cashBoxFormSaved)));
      context.go('/cash/boxes');
    }
    // الرفض → vm.saveError تُعرض فوق زر الحفظ.
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                if (vm.loading)
                  const ListSkeleton(rows: 3)
                else if (vm.error != null)
                  ErrorState(
                    title: l10n.genericErrorTitle,
                    message: l10n.dbOpenErrorMessage,
                    technicalDetails: vm.error.toString(),
                    retryLabel: l10n.commonRetry,
                    onRetry: vm.load,
                    compact: true,
                  )
                else ...[
                  FinCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          vm.isEdit
                              ? l10n.cashBoxFormEditTitle
                              : l10n.cashBoxFormNewTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (!vm.isEdit) ...[
                          const SizedBox(height: 4),
                          Text(
                            l10n.cashBoxesEmptyBody,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                        const SizedBox(height: 14),
                        _NameField(vm: vm),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: vm.currencyId,
                          onChanged: vm.isEdit || vm.saving
                              ? null
                              : vm.setCurrency,
                          decoration: InputDecoration(
                            labelText: l10n.cashBoxFormCurrencyLabel,
                            helperText: vm.isEdit
                                ? l10n.cashBoxFormCurrencyLocked
                                : null,
                            prefixIcon: const Icon(
                              Icons.currency_exchange_rounded,
                            ),
                          ),
                          items: [
                            for (final currency in vm.currencies)
                              DropdownMenuItem<int>(
                                value: currency.id,
                                child: Text(
                                  '${currency.code} — ${currency.name}',
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            l10n.cashBoxFormMakeDefault,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(l10n.cashBoxFormMakeDefaultHint),
                          value: vm.makeDefault,
                          onChanged: vm.saving ? null : vm.setMakeDefault,
                        ),
                      ],
                    ),
                  ),
                  if (vm.saveError != null) ...[
                    const SizedBox(height: 12),
                    FinErrorCard(message: vm.saveError!),
                  ],
                ],
              ],
            ),
          ),
          _SaveBar(vm: vm, onSave: () => unawaited(_save(context))),
        ],
      ),
    );
  }
}

class _NameField extends StatefulWidget {
  const _NameField({required this.vm});

  final BoxFormViewModel vm;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // يُنشأ بعد اكتمال تحميل النموذج (اسم التعديل جاهز حينها).
    _controller = TextEditingController(text: widget.vm.name);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TextField(
      controller: _controller,
      enabled: !widget.vm.saving,
      onChanged: widget.vm.setName,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: l10n.cashBoxFormNameLabel,
        helperText: l10n.cashBoxFormNameHint,
        prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.vm, required this.onSave});

  final BoxFormViewModel vm;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: FilledButton(
            onPressed: vm.saving || vm.loading ? null : onSave,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              textStyle: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            child: vm.saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : Text(l10n.cashBoxFormSave),
          ),
        ),
      ),
    );
  }
}
