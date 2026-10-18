/// شاشة استيراد الأصناف (FR-01-13 / AC-14): وضعان (ملف CSV/Excel عبر
/// file_picker أو لصق CSV) → ربط أعمدة مُخمَّن → معاينة فحص بلا كتابة →
/// إقرار صريح عند وجود صفوف فاشلة → إدخال الصفوف الصالحة فقط + بطاقة
/// النتيجة. المراحل والويدجت بملفاتها المركزّة بجوارها (R19-D3b) —
/// هذا الملف: إدارة الحالة والتنقل بين المراحل.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/services/item_import_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../view_models/import_view_model.dart';
import 'widgets/import_stages.dart';

class ImportScreen extends StatelessWidget {
  const ImportScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً — عند غيابه تُنشئ الشاشة نموذجها.
  final ImportViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final ImportViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = ImportViewModel(
        importService: ItemImportService(app.database!.db),
        companyRepo: app.companies!,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<ImportViewModel>.value(
      value: vm,
      child: const _ImportBody(),
    );
  }
}

class _ImportBody extends StatefulWidget {
  const _ImportBody();

  @override
  State<_ImportBody> createState() => _ImportBodyState();
}

class _ImportBodyState extends State<_ImportBody> {
  final TextEditingController _pasteController = TextEditingController();

  /// النموذج يُخزَّن حقلاً عند التركيب — القراءة من context داخل dispose
  /// غير آمنة (عنصر معطّل) وتكسر تفكيك الشجرة في الاختبارات.
  late final ImportViewModel _storedVm;
  ImportViewModel get _vm => _storedVm;

  @override
  void initState() {
    super.initState();
    _storedVm = context.read<ImportViewModel>();
    _storedVm.addListener(_onVmChanged);
  }

  @override
  void dispose() {
    _storedVm.removeListener(_onVmChanged);
    _pasteController.dispose();
    super.dispose();
  }

  /// مزامنة حقل اللصق مع الحالة (يُمسح عند «بدء استيراد جديد»).
  void _onVmChanged() {
    if (!mounted) return;
    if (_vm.state.pasteText != _pasteController.text) {
      _pasteController.text = _vm.state.pasteText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ImportViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.importTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: switch (state.stage) {
          ImportStage.input => buildImportInputStage(
            context,
            vm,
            l10n,
            state,
            _pasteController,
          ),
          ImportStage.mapping => buildImportMappingStage(
            context,
            vm,
            l10n,
            state,
          ),
          ImportStage.preview => buildImportPreviewStage(
            context,
            vm,
            l10n,
            state,
          ),
          ImportStage.done => buildImportDoneStage(context, vm, l10n, state),
        },
      ),
    );
  }
}
