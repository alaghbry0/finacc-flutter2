/// نافذة معاينة الطباعة (الشريحة 7 — FR-10-01/02/09): تُبنى الوثيقة،
/// تُحوَّل بايتات PDF إلى صور **لكل الصفحات** (raster بدقة 150dpi
/// لمعاينة حادة — إصلاح UX-audit A8: كانت الصفحة الأولى وحدها تُعرض)،
/// وتُعرض الصفحات عمودياً بتمرير واحد مع مؤشر «صفحة X من الكلي»
/// تحت كل صفحة عند التعدد، مع صف إجراءات: **طباعة** (حوار الطباعة
/// الأصلي) + **مشاركة** PDF + **واتساب** (رابط wa.me) — كل إجراء
/// دفاعي: أي فشل يظهر SnackBar عربي ولا يكسر النافذة.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/widgets/error_state.dart';

/// تفتح نافذة معاينة PDF لمستند يُبنى عند الطلب.
///
/// [title] يظهر في رأس النافذة ويُشتق منه اسم الملف (docNo عادة).
/// [build] يُستدعى مرة عند الفتح ومرة عند كل «إعادة محاولة» بعد خطأ.
/// [whatsappPhone] يُظهر زر واتساب فقط عند وجود أرقام فيه.
Future<void> showPdfPreviewDialog(
  BuildContext context, {
  required String title,
  required Future<pw.Document> Function() build,
  String? whatsappPhone,
  String? shareMessage,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _PdfPreviewDialog(
      title: title,
      build: build,
      whatsappPhone: whatsappPhone,
      shareMessage: shareMessage,
    ),
  );
}

class _PdfPreviewDialog extends StatefulWidget {
  const _PdfPreviewDialog({
    required this.title,
    required this.build,
    this.whatsappPhone,
    this.shareMessage,
  });

  final String title;
  final Future<pw.Document> Function() build;
  final String? whatsappPhone;
  final String? shareMessage;

  @override
  State<_PdfPreviewDialog> createState() => _PdfPreviewDialogState();
}

/// ناتج البناء: بايتات PDF (للطباعة/المشاركة) + صور PNG **لكل الصفحات**.
class _PdfPreviewData {
  const _PdfPreviewData({required this.bytes, required this.pagePngs});

  final Uint8List bytes;
  final List<Uint8List> pagePngs;
}

class _PdfPreviewDialogState extends State<_PdfPreviewDialog> {
  bool _loading = true;
  Object? _error;
  _PdfPreviewData? _data;
  bool _actionBusy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_build());
  }

  Future<void> _build() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final doc = await widget.build();
      final bytes = await doc.save();
      // **كل** الصفحات — الكشوف والفواتير الطويلة تُعاين كاملة
      // (إصلاح UX-audit A8)، بدقة 150 لمعاينة حادة.
      final pages = await Printing.raster(bytes, dpi: 150).toList();
      final pngs = <Uint8List>[];
      for (final page in pages) {
        pngs.add(await page.toPng());
      }
      if (!mounted) return;
      setState(() {
        _data = _PdfPreviewData(bytes: bytes, pagePngs: pngs);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  /// اسم ملف PDF المشترك/المطبوع — من عنوان النافذة بتنظيف محارف
  /// المسارات.
  String get _fileName =>
      '${widget.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')}.pdf';

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _print() async {
    final l10n = AppLocalizations.of(context)!;
    final data = _data;
    if (data == null) return;
    setState(() => _actionBusy = true);
    try {
      await Printing.layoutPdf(
        name: _fileName,
        onLayout: (format) async => data.bytes,
      );
    } catch (_) {
      if (!mounted) return;
      _toast(l10n.printingPrintFailed);
    }
    if (!mounted) return;
    setState(() => _actionBusy = false);
  }

  Future<void> _share() async {
    final l10n = AppLocalizations.of(context)!;
    final data = _data;
    if (data == null) return;
    setState(() => _actionBusy = true);
    try {
      await Printing.sharePdf(bytes: data.bytes, filename: _fileName);
    } catch (_) {
      // مشاركة printing على الويب ترمي استثناء في المتصفحات بلا sheet —
      // دفاعي حصراً: SnackBar بدل الانهيار.
      if (!mounted) return;
      _toast(l10n.printingShareFailed);
    }
    if (!mounted) return;
    setState(() => _actionBusy = false);
  }

  Future<void> _whatsapp() async {
    final l10n = AppLocalizations.of(context)!;
    final digits = (widget.whatsappPhone ?? '').replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    if (digits.isEmpty) return;
    setState(() => _actionBusy = true);
    final message = (widget.shareMessage ?? '').trim();
    final uri = Uri.parse(
      'https://wa.me/$digits'
      '${message.isEmpty ? '' : '?text=${Uri.encodeComponent(message)}'}',
    );
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) _toast(l10n.printingWhatsAppFailed);
    } catch (_) {
      if (!mounted) return;
      _toast(l10n.printingWhatsAppFailed);
    }
    if (!mounted) return;
    setState(() => _actionBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final digits = (widget.whatsappPhone ?? '').replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.printingPreviewTitle,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.printingClose,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Flexible(child: _buildPreviewArea(context, l10n)),
              if (!_loading && _error == null && _data != null) ...[
                const SizedBox(height: 12),
                _buildActions(context, l10n, hasWhatsApp: digits.isNotEmpty),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewArea(BuildContext context, AppLocalizations l10n) {
    if (_loading) {
      return SizedBox(
        height: 320,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(strokeWidth: 2.5),
              const SizedBox(height: 12),
              Text(
                l10n.printingPreviewTitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return SizedBox(
        height: 360,
        child: ErrorState(
          title: l10n.printingBuildError,
          message: l10n.printingBuildErrorBody,
          technicalDetails: _error.toString(),
          retryLabel: l10n.commonRetry,
          onRetry: () => unawaited(_build()),
          compact: true,
        ),
      );
    }
    final data = _data;
    if (data == null) {
      return const SizedBox(height: 8);
    }
    // كل صفحة بعرض كامل داخل بطاقة بظل ورقي، بتمرير عمودي واحد —
    // ومؤشر «صفحة X من الكلي» تحت كل صفحة عند التعدد (إصلاح A8).
    // تحتها شريط حجم الملف (ميزة مستعادة من جولة مفقودة — 2026-10-07).
    final sizeKb = (data.bytes.length / 1024).round();
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      children: [
        for (var i = 0; i < data.pagePngs.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  data.pagePngs[i],
                  fit: BoxFit.fitWidth,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
          if (data.pagePngs.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.pdfFixPageIndicator(i + 1, data.pagePngs.length),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
            ),
        ],
        const SizedBox(height: 8),
        Text(
          l10n.printingPreviewFileSize(sizeKb),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
      ],
    );
  }

  Widget _buildActions(
    BuildContext context,
    AppLocalizations l10n, {
    required bool hasWhatsApp,
  }) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _actionBusy ? null : () => unawaited(_print()),
            icon: const Icon(Icons.print_rounded, size: 18),
            label: Text(l10n.printingPrint),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _actionBusy ? null : () => unawaited(_share()),
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            label: Text(l10n.printingShare),
          ),
        ),
        if (hasWhatsApp) ...[
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.tonalIcon(
              // لمسة خضراء بروح واتساب فوق الطابع التونالي.
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD7F2E4),
                foregroundColor: const Color(0xFF075E54),
              ),
              onPressed: _actionBusy ? null : () => unawaited(_whatsapp()),
              icon: const Icon(Icons.chat_rounded, size: 18),
              label: Text(l10n.printingWhatsApp),
            ),
          ),
        ],
      ],
    );
  }
}
