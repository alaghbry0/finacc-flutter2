/// نافذة معاينة/طباعة/مشاركة PDF — الشريحة 7 (FR-10-02/05/09).
///
/// توليد البايتات (مستقبل يبدأ فور فتح النافذة) → تحويل أول صفحة إلى
/// صورة عبر `Printing.raster` وعرضها في بطاقة قابلة للتمرير؛ إن فشل
/// التحويل (بيئة الويب) نعرض بطاقة نجاح باسم الملف وحجمه — لا انهيار
/// أبداً. أزرار: طباعة نظامية، مشاركة نظامية، وواتساب (إن أُمرر رابط)
/// يفتح التطبيق الخارجي ضمن try/catch.
library;

import 'dart:async' show unawaited;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// نتيجة التحميل: البايتات + صورة المعاينة (null عند فشل التحويل).
class _PdfPayload {
  const _PdfPayload({required this.bytes, this.png});

  final Uint8List bytes;
  final Uint8List? png;
}

/// يفتح نافذة معاينة مستند PDF مع أزرار الطباعة/المشاركة/واتساب.
///
/// [build] يولّد البايتات عند الطلب (يُستدعى مرة واحدة عند الفتح)،
/// [fileName] اسم الملف عند المشاركة، و[whatsappUri] رابط wa.me مع
/// رسالة جاهزة (null يخفي الزر).
Future<void> showPdfPreviewDialog(
  BuildContext context, {
  required String title,
  required Future<Uint8List> Function() build,
  required String fileName,
  Uri? whatsappUri,
}) async {
  final future = _generate(build);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(dialogContext).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      tooltip: AppLocalizations.of(dialogContext)!
                          .printingClose,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: FutureBuilder<_PdfPayload>(
                    future: future,
                    builder: (dialogContext, snapshot) {
                      final l10n = AppLocalizations.of(dialogContext)!;
                      final payload = snapshot.data;
                      return SingleChildScrollView(
                        child: switch (snapshot.connectionState) {
                          ConnectionState.done when payload != null =>
                            _PreviewContent(
                              payload: payload,
                              fileName: fileName,
                              whatsappUri: whatsappUri,
                            ),
                          ConnectionState.done => _ErrorContent(
                            error: snapshot.error,
                          ),
                          _ => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Column(
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 14),
                                Text(l10n.printingPreviewTitle),
                              ],
                            ),
                          ),
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// يولّد البايتات ثم يحوّل الصفحة الأولى إلى PNG (يُتسامح مع الفشل).
Future<_PdfPayload> _generate(Future<Uint8List> Function() build) async {
  final bytes = await build();
  try {
    // 150 نقطة/بوصة: معاينة حادة تُقرأ فيها الأرقام الصغيرة بوضوح
    // (الافتراضي 72 يُظهر نصوص الفاتورة ضبابية على الشاشات الكثيفة).
    final page = await Printing.raster(bytes, pages: const [0], dpi: 150).first;
    final png = await page.toPng();
    return _PdfPayload(bytes: bytes, png: png);
  } catch (_) {
    // فشل التحويل (ويب عادة) — بطاقة النجاح بالاسم والحجم بدل الصورة.
    return _PdfPayload(bytes: bytes);
  }
}

/// يبتلع فشل عمليات الطباعة/المشاركة في البيئات التي لا تدعمها
/// (navigator.share غير متاح في بعض المتصفحات والبيئات الآلية) — أندرويد
/// لا يتأثر إطلاقاً (ورقة المشاركة/الطباعة الأصلية).
Future<void> _guard(Future<Object?> future) async {
  try {
    await future;
  } catch (_) {
    // نتقبل الفشل بصمت — لا شيء يُقفل على المستخدم.
  }
}

/// جسم المعاينة بعد جاهزية البايتات: الصورة/البطاقة + الحجم + الأزرار.
class _PreviewContent extends StatelessWidget {
  const _PreviewContent({
    required this.payload,
    required this.fileName,
    required this.whatsappUri,
  });

  final _PdfPayload payload;
  final String fileName;
  final Uri? whatsappUri;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final bytes = payload.bytes;
    final sizeKb = (bytes.length / 1024).round();
    final whatsapp = whatsappUri;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (payload.png != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.cardBorder),
              ),
              child: Image.memory(
                payload.png!,
                height: MediaQuery.sizeOf(context).height * 0.55,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
          )
        else
          // بديل الويب: بطاقة نجاح باسم الملف وحجمه.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.positiveContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: colors.onPositiveContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        l10n.printingPreviewFileSize(sizeKb),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colors.onPositiveContainer),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (payload.png != null) ...[
          const SizedBox(height: 8),
          Text(
            l10n.printingPreviewFileSize(sizeKb),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.icon(
              // نفس التحوط: حوار الطباعة قد يغلق بلا نتيجة في البيئات
              // الآلية — نتحمل الفشل بصمت (سلوك أندرويد سليم).
              onPressed: () => unawaited(
                _guard(
                  Printing.layoutPdf(
                    name: fileName,
                    onLayout: (format) async => bytes,
                  ),
                ),
              ),
              icon: const Icon(Icons.print),
              label: Text(l10n.printingPrint),
            ),
            OutlinedButton.icon(
              // try/catch: مشاركة الويب (navigator.share) غير متاحة في بعض
              // المتصفحات/البيئات الآلية — نتحمل الفشل بصمت بدل استثناء
              // يقفز في الكونسول (اكتُشف حياً 2026-10-07). أندرويد يستعمل
              // ورقة المشاركة الأصلية ولا يتأثر.
              onPressed: () => unawaited(
                _guard(Printing.sharePdf(bytes: bytes, filename: fileName)),
              ),
              icon: const Icon(Icons.share),
              label: Text(l10n.printingShare),
            ),
            if (whatsapp != null)
              OutlinedButton.icon(
                onPressed: () => unawaited(_openWhatsApp(context, whatsapp)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF25D366),
                  side: const BorderSide(color: Color(0xFF25D366)),
                ),
                icon: const Icon(Icons.chat),
                label: Text(l10n.printingWhatsApp),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.printingClose),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openWhatsApp(BuildContext context, Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // لا معالج للرابط على هذا الجهاز — نتجاهل بهدوء.
    }
  }
}

/// بطاقة خطأ التوليد (خطأ المتصل نفسه — لا نص جديد، مفاتيح عامة قائمة).
class _ErrorContent extends StatelessWidget {
  const _ErrorContent({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.negativeContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: colors.onNegativeContainer,
              ),
              const SizedBox(width: 10),
              Text(
                l10n.genericErrorTitle,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(
              error.toString(),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
