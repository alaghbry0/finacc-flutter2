/// شاشة بيانات المنشأة (UX-2a) — محرر كامل لأعمدة company الموجودة منذ v1
/// والمستغلة الآن: الاسم/الهاتف/الواتساب/العنوان/الرقم الضريبي/نسبة
/// الضريبة/نص التذييل + **رفع الشعار** (image_picker → PNG مضغوط → BLOB
/// بهجرة v3 ينجو مع النسخة الاحتياطية) مع معاينة حيّة.
///
/// رافع الشعار seam: النموذج يقبل دالة رفع قابلة للحقن — الإنتاج يمرر
/// image_picker (المعرض) والاختبارات بايتات جاهزة بلا منصة.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../view_models/company_profile_view_model.dart';

/// شاشة محرر بيانات المنشأة — مسار `/more/company`.
class CompanyProfileScreen extends StatelessWidget {
  const CompanyProfileScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً (داخل runAsync) — عند غيابه
  /// تُنشئ الشاشة نموذجها وتحمّله بنفسها.
  final CompanyProfileViewModel? viewModel;

  /// رافع الشعار للإنتاج (image_picker) — المعرض حصراً (لا كاميرا:
  /// شعار ملف على الجهاز دائماً) مع ضغط 85% وحد أبعاد 1024.
  static Future<Uint8List?> _galleryLogoPicker() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file == null) return null;
    return file.readAsBytes();
  }

  @override
  Widget build(BuildContext context) {
    // نمط change_pin/backup: مستودع المنشأة من AppController فوق شجرة
    // المزودات — أو النموذج المحقون (seam الاختبار).
    late final CompanyProfileViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      final app = context.read<AppController>();
      vm = CompanyProfileViewModel(
        companyRepo: app.companies!,
        logoPicker: _galleryLogoPicker,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<CompanyProfileViewModel>.value(
      value: vm,
      child: const _CompanyProfileBody(),
    );
  }
}

class _CompanyProfileBody extends StatelessWidget {
  const _CompanyProfileBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CompanyProfileViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.settings2CompanyTitle)),
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
          : _CompanyForm(vm: vm),
    );
  }
}

class _CompanyForm extends StatefulWidget {
  const _CompanyForm({required this.vm});

  final CompanyProfileViewModel vm;

  @override
  State<_CompanyForm> createState() => _CompanyFormState();
}

class _CompanyFormState extends State<_CompanyForm> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _whatsapp;
  late final TextEditingController _address;
  late final TextEditingController _taxNumber;
  late final TextEditingController _taxRate;
  late final TextEditingController _footer;

  @override
  void initState() {
    super.initState();
    final vm = widget.vm;
    _name = TextEditingController(text: vm.name);
    _phone = TextEditingController(text: vm.phone);
    _whatsapp = TextEditingController(text: vm.whatsapp);
    _address = TextEditingController(text: vm.address);
    _taxNumber = TextEditingController(text: vm.taxNumber);
    _taxRate = TextEditingController(text: vm.taxRateText);
    _footer = TextEditingController(text: vm.footerText);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _address.dispose();
    _taxNumber.dispose();
    _taxRate.dispose();
    _footer.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final failure = await widget.vm.pickLogo();
    if (!mounted || failure == null) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.settings2CompanyLogoTooLarge)),
      );
  }

  Future<void> _save() async {
    final vm = widget.vm;
    final ok = await vm.save();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final scaffold = ScaffoldMessenger.of(context);
    if (ok) {
      scaffold
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.settings2CompanySaved)));
    } else if (vm.state.saveError != null) {
      final message = switch (vm.state.saveError) {
        'NAME_REQUIRED' => l10n.settings2CompanyNameRequired,
        'TAX_RATE_INVALID' => l10n.settings2CompanyInvalidTaxRate,
        _ => l10n.settings2CompanySaveFailed,
      };
      scaffold
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CompanyProfileViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // ── الشعار ──
        FinCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    l10n.settings2CompanyLogoSection,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(child: _LogoTile(bytes: vm.logoPng)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (vm.canPickLogo)
                    OutlinedButton.icon(
                      onPressed: _pickLogo,
                      icon: const Icon(Icons.image_rounded, size: 20),
                      label: Text(
                        vm.logoPng == null
                            ? l10n.settings2CompanyLogoPick
                            : l10n.settings2CompanyLogoChange,
                      ),
                    ),
                  if (vm.logoPng != null)
                    OutlinedButton.icon(
                      onPressed: vm.clearLogo,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: colors.negative,
                      ),
                      label: Text(l10n.settings2CompanyLogoRemove),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.settings2CompanyLogoHint,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── حقول الهوية ──
        FinCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Field(
                controller: _name,
                label: l10n.settings2CompanyNameLabel,
                icon: Icons.storefront_rounded,
                onChanged: vm.setName,
              ),
              _Field(
                controller: _phone,
                label: l10n.settings2CompanyPhoneLabel,
                icon: Icons.call_rounded,
                keyboardType: TextInputType.phone,
                onChanged: vm.setPhone,
              ),
              _Field(
                controller: _whatsapp,
                label: l10n.settings2CompanyWhatsappLabel,
                icon: Icons.chat_rounded,
                keyboardType: TextInputType.phone,
                onChanged: vm.setWhatsapp,
              ),
              _Field(
                controller: _address,
                label: l10n.settings2CompanyAddressLabel,
                icon: Icons.location_on_rounded,
                onChanged: vm.setAddress,
              ),
              _Field(
                controller: _taxNumber,
                label: l10n.settings2CompanyTaxNumberLabel,
                icon: Icons.receipt_long_rounded,
                onChanged: vm.setTaxNumber,
              ),
              _Field(
                controller: _taxRate,
                label: l10n.settings2CompanyTaxRateLabel,
                icon: Icons.percent_rounded,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: vm.setTaxRateText,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── التذييل + العملة ──
        FinCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Field(
                controller: _footer,
                label: l10n.settings2CompanyFooterLabel,
                icon: Icons.notes_rounded,
                multiline: true,
                onChanged: vm.setFooterText,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.settings2CompanyFooterHint,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (state.currency != null) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.settings2CompanyCurrencyNote(state.currency!.code),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── الحفظ ──
        FilledButton.icon(
          onPressed: state.saving ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          icon: state.saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : const Icon(Icons.save_rounded),
          label: Text(l10n.settings2CompanySave),
        ),
      ],
    );
  }
}

/// بلاطة الشعار — الصورة الحية من BLOB أو بديل أيقونة المنشأة.
class _LogoTile extends StatelessWidget {
  const _LogoTile({required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes == null
          ? Icon(Icons.storefront_rounded, size: 44, color: scheme.primary)
          : Image.memory(
              bytes!,
              fit: BoxFit.contain,
              // BLOB تالف (نسخة مستعادة قديمة/تدخل يدوي بالقاعدة): أيقونة
              // بديلة بدل انفجار فك الترميز — الحفظ يظل ممكناً فوقه.
              errorBuilder: (_, _, _) => Icon(
                Icons.broken_image_outlined,
                size: 44,
                color: scheme.outlineVariant,
              ),
            ),
    );
  }
}

/// حقل نموذج موحّد بأسلوب FinAcc.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    required this.onChanged,
    this.keyboardType,
    this.multiline = false,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        key: Key('settings2_company_field_$label'),
        controller: controller,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        keyboardType: keyboardType,
        maxLines: multiline ? 3 : 1,
        onChanged: onChanged,
      ),
    );
  }
}
